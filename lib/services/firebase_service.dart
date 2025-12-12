import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/bill_hive.dart';
import 'hive_service.dart';

/// Singleton GoogleSignIn instance for consistent state management
/// This prevents issues with multiple instances having different cached states
GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Reset and get a fresh GoogleSignIn instance
  /// Call this before sign-in to ensure no stale tokens
  static Future<void> resetGoogleSignIn() async {
    try {
      // Try to sign out any existing session
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    // Create fresh instance
    _googleSignIn = GoogleSignIn(scopes: ['email']);
    debugPrint('[Auth] GoogleSignIn instance reset');
  }

  /// Sign in with Google - OPTIMIZED for speed
  /// Uses singleton GoogleSignIn and handles edge cases
  static Future<UserCredential?> signInWithGoogle() async {
    debugPrint('[Auth] Starting Google sign-in');

    try {
      // First, ensure we have a clean state
      // Check if already signed in silently
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

      // If not silently signed in, show account picker
      if (googleUser == null) {
        googleUser = await _googleSignIn.signIn();
      }

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
    } catch (e) {
      debugPrint('[Auth] Google sign-in error: $e');
      rethrow;
    }
  }

  /// Complete sign out from Google and Firebase
  /// This ensures account picker appears next time
  /// CRITICAL: Clears local bills to prevent data leak between accounts
  static Future<void> signOutGoogle() async {
    debugPrint('[Auth] Starting complete sign out');

    // 0. CRITICAL: Clear local bills BEFORE signing out to prevent data leak
    // This ensures no bills from this account remain in local storage
    try {
      await HiveService.clearBillsOnly();
      debugPrint('[Auth] Local bills cleared');
    } catch (e) {
      debugPrint('[Auth] Failed to clear local bills: $e');
      // Continue with sign out even if clearing fails
    }

    // 1. Disconnect Google (removes app authorization, forces account picker)
    try {
      await _googleSignIn.disconnect();
      debugPrint('[Auth] Google disconnected');
    } catch (e) {
      debugPrint('[Auth] Google disconnect failed: $e');
      // Try signOut as fallback
      try {
        await _googleSignIn.signOut();
        debugPrint('[Auth] Google signed out (fallback)');
      } catch (_) {}
    }

    // 2. Sign out from Firebase Auth
    try {
      await _auth.signOut();
      debugPrint('[Auth] Firebase signed out');
    } catch (e) {
      debugPrint('[Auth] Firebase sign out error: $e');
    }

    // 3. Reset the GoogleSignIn instance for next login
    _googleSignIn = GoogleSignIn(scopes: ['email']);
    debugPrint('[Auth] Sign out completed');
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

  // Firestore: Batch sync local bills to server
  static Future<void> syncLocalBillsToServer(List<BillHive> bills) async {
    final batch = _firestore.batch();
    final collection = _getUserBillsCollection();

    for (var bill in bills) {
      batch.set(collection.doc(bill.id), bill.toFirestore());
    }

    await batch.commit();
  }

  /// Delete all user data from Firestore
  /// This deletes all bills and the user document
  /// Used for account deletion
  static Future<void> deleteAllUserData(String userId) async {
    debugPrint('[Firebase] Deleting all data for user: $userId');

    // Delete all bills in batches of 500
    final billsCollection = _firestore
        .collection('users')
        .doc(userId)
        .collection('bills');

    const batchSize = 500;
    while (true) {
      final snapshot = await billsCollection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[Firebase] Deleted ${snapshot.docs.length} bills');

      if (snapshot.docs.length < batchSize) break;
    }

    // Delete the user document
    await _firestore.collection('users').doc(userId).delete();
    debugPrint('[Firebase] User document deleted');
  }
}
