import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Estado de autenticacion de la app expuesto a la UI con Provider.
/// Escucha los cambios de sesion de Firebase y carga el perfil con rol.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    _sub = _service.authState.listen(_onAuthChanged);
  }

  final AuthService _service;
  late final StreamSubscription<User?> _sub;

  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  Future<void> _onAuthChanged(User? fbUser) async {
    if (fbUser == null) {
      _user = null;
    } else {
      _user = await _service.fetchProfile(fbUser.uid);
    }
    _loading = false;
    notifyListeners();
  }

  /// Inicia sesion. Devuelve null si todo bien, o un mensaje de error.
  Future<String?> signIn(String email, String password) async {
    try {
      await _service.signIn(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    } catch (_) {
      return 'No se pudo iniciar sesion. Intenta de nuevo.';
    }
  }

  /// Registra una cuenta nueva. Devuelve null si todo bien, o un error.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      _user = await _service.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    } catch (_) {
      return 'No se pudo crear la cuenta. Intenta de nuevo.';
    }
  }

  Future<void> signOut() => _service.signOut();

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contrasena es muy debil (minimo 6 caracteres).';
      default:
        return 'Error de autenticacion: ${e.code}';
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
