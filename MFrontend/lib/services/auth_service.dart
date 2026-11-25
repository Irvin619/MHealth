import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthService {
  AuthService(this._api);

  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _userIdKey = 'user_id';

  final ApiClient _api;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String passwordConfirmation,
    String? anonymousAlias,
    String? licenseNumber,
    String? specialization,
  }) async {
    final result = await _api.post(
      '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
        if (role == 'client' && anonymousAlias?.trim().isNotEmpty == true)
          'anonymous_alias': anonymousAlias!.trim(),
        if (role == 'therapist') 'license_number': licenseNumber,
        if (role == 'therapist' && specialization?.trim().isNotEmpty == true)
          'specialization': specialization!.trim(),
      },
    );
    await _saveSession(result);
    return result;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.post(
      '/login',
      body: {'email': email, 'password': password},
    );
    await _saveSession(result);
    return result;
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } finally {
      await clearSession();
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final preferences = await SharedPreferences.getInstance();
    final user = response['user'];
    final token = response['token'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw const ApiException(
        'The server did not return a valid session.',
        200,
      );
    }
    await preferences.setString(_tokenKey, token);
    final role = user['role'];
    if (role is String) await preferences.setString(_roleKey, role);
    final id = user['id'];
    if (id != null) await preferences.setString(_userIdKey, id.toString());
  }

  Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<String?> role() async =>
      (await SharedPreferences.getInstance()).getString(_roleKey);

  Future<String?> userId() async =>
      (await SharedPreferences.getInstance()).getString(_userIdKey);

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
    await preferences.remove(_userIdKey);
  }
}
