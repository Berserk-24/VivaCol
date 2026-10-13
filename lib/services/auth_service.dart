import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Encapsula la autenticacion con Firebase Auth y el perfil del
/// usuario almacenado en la coleccion `users` de Cloud Firestore.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Crea la cuenta en Auth y guarda el perfil con su rol en Firestore.
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final user =
        AppUser(id: uid, name: name.trim(), email: email.trim(), role: role);
    await _users.doc(uid).set(user.toMap());
    await cred.user!.updateDisplayName(name.trim());
    return user;
  }

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Lee el perfil extendido (nombre, rol) desde Firestore.
  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return AppUser.fromMap(doc.id, data);
  }
}
