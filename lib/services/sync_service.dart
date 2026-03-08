import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/snippet.dart';
import '../models/category.dart';
import 'database_service.dart';

class SyncService {
  final DatabaseService _db = DatabaseService();

  bool get _isFirebaseAvailable {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool get isSignedIn {
    if (!_isFirebaseAvailable) return false;
    try {
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser {
    if (!_isFirebaseAvailable) return null;
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get userId => currentUser?.uid;

  // Sign in with email
  Future<UserCredential> signInWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase가 설정되지 않았습니다. google-services.json / GoogleService-Info.plist을 추가해주세요.');
    }
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign up with email
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase가 설정되지 않았습니다. google-services.json / GoogleService-Info.plist을 추가해주세요.');
    }
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Sign out
  Future<void> signOut() async {
    if (!_isFirebaseAvailable) return;
    await _auth.signOut();
  }

  // Upload all local data to Firestore
  Future<void> uploadAll() async {
    if (!isSignedIn) return;
    final uid = userId!;

    final categories = await _db.getAllCategories();
    final snippets = await _db.getAllSnippets();

    final batch = _firestore.batch();

    for (final cat in categories) {
      final ref = _firestore.collection('users').doc(uid).collection('categories').doc(cat.id);
      batch.set(ref, cat.toMap());
    }

    for (final snippet in snippets) {
      final ref = _firestore.collection('users').doc(uid).collection('snippets').doc(snippet.id);
      batch.set(ref, snippet.toMap());
    }

    await batch.commit();
  }

  // Download all data from Firestore to local
  Future<void> downloadAll() async {
    if (!isSignedIn) return;
    final uid = userId!;

    final catSnapshot = await _firestore.collection('users').doc(uid).collection('categories').get();
    for (final doc in catSnapshot.docs) {
      final category = Category.fromMap(doc.data());
      await _db.insertCategory(category);
    }

    final snippetSnapshot = await _firestore.collection('users').doc(uid).collection('snippets').get();
    for (final doc in snippetSnapshot.docs) {
      final snippet = Snippet.fromMap(doc.data());
      await _db.insertSnippet(snippet);
    }
  }

  // Full sync: merge local and remote
  Future<void> syncAll() async {
    if (!isSignedIn) return;
    await uploadAll();
    await downloadAll();
  }

  // Update sync timestamp
  Future<void> updateSyncTimestamp() async {
    if (!isSignedIn) return;
    final uid = userId!;
    await _firestore.collection('users').doc(uid).set({
      'lastSyncAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    if (!isSignedIn) return null;
    final uid = userId!;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data()?['lastSyncAt'] != null) {
      return (doc.data()!['lastSyncAt'] as Timestamp).toDate();
    }
    return null;
  }
}
