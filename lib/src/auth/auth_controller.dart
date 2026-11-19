import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import 'auth_repository.dart';
import 'user.dart';

enum AuthStatus { checking, signedOut, submitting, signedIn }

/// Holds the session state the UI renders from. Screens never call the
/// repository directly and never see a raw exception that is not an
/// [ApiException].
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.checking;
  User? _user;
  ApiException? _error;
  bool _isReloading = false;

  AuthStatus get status => _status;
  User? get user => _user;
  ApiException? get error => _error;
  bool get isSubmitting => _status == AuthStatus.submitting;
  bool get isReloading => _isReloading;

  /// Called once at launch to pick up a saved session.
  Future<void> restore() async {
    try {
      _user = await _repository.restoreSession();
      _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    } on ApiException catch (error) {
      _error = error;
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (isSubmitting) return; // Ignore double taps.
    _error = null;
    _status = AuthStatus.submitting;
    notifyListeners();

    try {
      _user = await _repository.signIn(email: email.trim(), password: password);
      _status = AuthStatus.signedIn;
    } on ApiException catch (error) {
      _error = error;
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  /// Refreshes the profile. An expired session signs the user out and keeps
  /// the reason, so the login screen can explain what happened.
  Future<void> reloadProfile() async {
    if (_isReloading) return;
    _error = null;
    _isReloading = true;
    notifyListeners();

    try {
      _user = await _repository.fetchProfile();
    } on UnauthorizedException catch (error) {
      await _repository.signOut();
      _user = null;
      _error = error;
      _status = AuthStatus.signedOut;
    } on ApiException catch (error) {
      _error = error;
    }
    _isReloading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _user = null;
    _error = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
