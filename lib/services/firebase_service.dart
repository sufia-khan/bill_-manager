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

  // Delete ALL user data from Firestore - COMPLETE CLEANUP
  static Future<void> deleteAllUserData(String userId) async {
    debugPrint('[Delete] Starting complete deletion for user: $userId');

    try {
      // Delete all subcollections and user doc in parallel with individual timeouts
      await Future.wait([
        _deleteCollection(userId, 'bills').timeout(const Duration(seconds: 5)),
        _deleteCollection(
          userId,
          'recurring_bills',
        ).timeout(const Duration(seconds: 3)),
        _deleteCollection(
          userId,
          'archives',
        ).timeout(const Duration(seconds: 3)),
        _deleteCollection(
          userId,
          'notifications',
        ).timeout(const Duration(seconds: 3)),
        _deleteAllSettings(userId).timeout(const Duration(seconds: 2)),
        _firestore
            .collection('users')
            .doc(userId)
            .delete()
            .timeout(const Duration(seconds: 2)),
      ]);

      debugPrint('[Delete] ✅ All Firestore data deleted for user: $userId');
    } catch (e) {
      debugPrint('[Delete] ⚠️ Error during Firestore deletion: $e');
      // Continue anyway - best effort
    }
  }

  // Delete entire subcollection using batched deletes
  static Future<void> _deleteCollection(
    String userId,
    String collectionName,
  ) async {
    final collection = _firestore
        .collection('users')
        .doc(userId)
        .collection(collectionName);

    final snapshot = await collection.get();
    final docCount = snapshot.docs.length;

    if (docCount == 0) {
      debugPrint('[Delete] No documents in $collectionName');
      return;
    }

    debugPrint('[Delete] Deleting $docCount documents from $collectionName');

    // Batch delete (max 500 per batch)
    if (docCount <= 500) {
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } else {
      // Multiple batches in parallel
      final batches = <Future>[];
      for (var i = 0; i < docCount; i += 500) {
        final batch = _firestore.batch();
        final end = (i + 500 < docCount) ? i + 500 : docCount;
        for (var j = i; j < end; j++) {
          batch.delete(snapshot.docs[j].reference);
        }
        batches.add(batch.commit());
      }
      await Future.wait(batches);
    }

    debugPrint('[Delete] ✅ Deleted $docCount documents from $collectionName');
  }

  // Delete all settings subcollection documents
  static Future<void> _deleteAllSettings(String userId) async {
    final settingsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('settings');

    final snapshot = await settingsRef.get();

    if (snapshot.docs.isEmpty) {
      debugPrint('[Delete] No settings to delete');
      return;
    }

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    debugPrint('[Delete] ✅ Deleted ${snapshot.docs.length} settings documents');
  }

  // Delete user profile image from Storage (if exists)
  static Future<void> deleteUserProfileImage(String userId) async {
    try {
      // Assuming profile images are stored at: /users/{userId}/profile.jpg
      // Adjust path based on your actual storage structure
      // If you're not using Firebase Storage, remove this method
      debugPrint('[Delete] Profile image deletion not implemented');
      // Example:
      // final ref = FirebaseStorage.instance.ref('users/$userId/profile.jpg');
      // await ref.delete();
    } catch (e) {
      debugPrint('[Delete] Profile image deletion skipped: $e');
    }
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
