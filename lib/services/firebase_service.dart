import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/bill_hive.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Auth: Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    // Trigger the authentication flow
    debugPrint('[Auth] Starting Google sign-in');
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    // User cancelled the sign-in
    if (googleUser == null) {
      debugPrint('[Auth] Google sign-in cancelled by user');
      return null;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    debugPrint('[Auth] Signing in to Firebase with Google credential');
    final result = await _auth.signInWithCredential(credential);
    debugPrint(
      '[Auth] Firebase sign-in completed for uid: \'${result.user?.uid}\'',
    );
    return result;
  }

  // Auth: Sign out from Google
  static Future<void> signOutGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
    await _auth.signOut();
  }

  // Auth: Delete user account and all data (OPTIMIZED FOR SPEED)
  static Future<void> deleteUserAccount() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    await deleteUserAccountWithId(currentUserId!, _auth.currentUser);
  }

  // Auth: Delete user account - FAST parallel deletion
  static Future<void> deleteUserAccountWithId(
    String userId,
    User? authUser,
  ) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();

    // Run ALL deletions in parallel for maximum speed
    await Future.wait([
      _deleteUserBillsCollection(userId),
      _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('currency')
          .delete()
          .catchError((_) => null),
      _firestore
          .collection('users')
          .doc(userId)
          .delete()
          .catchError((_) => null),
      googleSignIn.signOut(),
      _auth.signOut(),
    ]);

    // Try to delete auth account (may fail, that's ok - data is gone)
    try {
      await authUser?.delete();
    } catch (_) {}
  }

  // ULTRA FAST: Delete only user data (not auth) - for instant deletion
  static Future<void> deleteUserDataOnly(String userId) async {
    // Delete everything in parallel, ignore errors
    await Future.wait([
      _deleteUserBillsCollection(userId).catchError((_) => null),
      _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('currency')
          .delete()
          .catchError((_) => null),
      _firestore
          .collection('users')
          .doc(userId)
          .delete()
          .catchError((_) => null),
    ]);
  }

  // Sign out and delete auth in background (fire and forget)
  static void signOutAndDeleteAuth(User? authUser) {
    final GoogleSignIn googleSignIn = GoogleSignIn();

    // Don't await - let it happen in background
    Future.wait([
      googleSignIn.signOut().catchError((_) => null),
      _auth.signOut().catchError((_) => null),
    ]).then((_) {
      // Try to delete auth account after signout
      authUser?.delete().catchError((_) => null);
    });
  }

  // Helper: Delete all bills in user's collection (optimized)
  static Future<void> _deleteUserBillsCollection(String userId) async {
    final billsCollection = _firestore
        .collection('users')
        .doc(userId)
        .collection('bills');

    final billsSnapshot = await billsCollection.get();
    final billCount = billsSnapshot.docs.length;

    if (billCount == 0) {
      debugPrint('[Auth] No bills to delete');
      return;
    }

    debugPrint('[Auth] Deleting $billCount bills...');

    // Delete all bills in a single batch (up to 500) or multiple parallel batches
    if (billCount <= 500) {
      // Single batch - fastest for small collections
      final batch = _firestore.batch();
      for (var doc in billsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } else {
      // Multiple parallel batches for large collections
      final batchSize = 500;
      final batches = <Future>[];

      for (var i = 0; i < billCount; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < billCount) ? i + batchSize : billCount;

        for (var j = i; j < end; j++) {
          batch.delete(billsSnapshot.docs[j].reference);
        }

        batches.add(batch.commit());
      }

      // Execute all batches in parallel
      await Future.wait(batches);
    }

    debugPrint('[Auth] ✅ $billCount bills deleted');
  }

  // Firestore: Get user's bills collection reference
  static CollectionReference _getUserBillsCollection() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('bills');
  }

  // Firestore: Add or update bill
  static Future<void> saveBill(BillHive bill) async {
    final collection = _getUserBillsCollection();
    await collection.doc(bill.id).set(bill.toFirestore());
  }

  // Firestore: Get all bills
  static Future<List<BillHive>> getAllBills() async {
    final collection = _getUserBillsCollection();
    final snapshot = await collection
        .where('isDeleted', isEqualTo: false)
        .get();

    return snapshot.docs.map((doc) {
      return BillHive.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Firestore: Get bill by ID
  static Future<BillHive?> getBillById(String id) async {
    final collection = _getUserBillsCollection();
    final doc = await collection.doc(id).get();

    if (doc.exists) {
      return BillHive.fromFirestore(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Firestore: Delete bill (soft delete)
  static Future<void> deleteBill(String id) async {
    final collection = _getUserBillsCollection();
    await collection.doc(id).update({
      'isDeleted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Firestore: Sync bills from server
  static Future<List<BillHive>> syncBillsFromServer(
    DateTime lastSyncTime,
  ) async {
    final collection = _getUserBillsCollection();
    final snapshot = await collection
        .where('updatedAt', isGreaterThan: lastSyncTime.toIso8601String())
        .get();

    return snapshot.docs.map((doc) {
      return BillHive.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // REMOVED: Real-time listener - causes excessive reads
  // Use HiveService.getAllBills() for local data instead
  // Only sync with Firebase on login and when pushing changes

  // Firestore: Batch sync local bills to server
  static Future<void> syncLocalBillsToServer(List<BillHive> bills) async {
    final batch = _firestore.batch();
    final collection = _getUserBillsCollection();

    for (var bill in bills) {
      batch.set(collection.doc(bill.id), bill.toFirestore());
    }

    await batch.commit();
  }
}
