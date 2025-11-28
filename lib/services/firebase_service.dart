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
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    // User cancelled the sign-in
    if (googleUser == null) return null;

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    return await _auth.signInWithCredential(credential);
  }

  // Auth: Sign out from Google
  static Future<void> signOutGoogle() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
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

  // Firestore: Listen to bills changes (real-time)
  static Stream<List<BillHive>> watchBills() {
    final collection = _getUserBillsCollection();
    return collection.where('isDeleted', isEqualTo: false).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return BillHive.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();
    });
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
}
