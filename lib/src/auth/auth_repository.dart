import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'token_store.dart';
import 'user.dart';

class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore tokens})
      : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  Future<User> signIn({required String email, required String password}) async {
    final json = await _api.post(
      'auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );

    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const UnexpectedResponseException();
    }
    await _tokens.write(token);

    try {
      return await fetchProfile();
    } on ApiException {
      // Don't keep a token for a session that never finished starting.
      await _tokens.clear();
      rethrow;
    }
  }

  Future<User> fetchProfile() async => User.fromJson(await _api.get('me'));

  /// Returns the signed-in user when a stored token is still valid.
  /// A rejected token is removed. Other failures (offline, server down) are
  /// rethrown with the token left in place, so the next launch can try again.
  Future<User?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await fetchProfile();
    } on UnauthorizedException {
      await _tokens.clear();
      return null;
    }
  }

  Future<void> signOut() => _tokens.clear();
}
