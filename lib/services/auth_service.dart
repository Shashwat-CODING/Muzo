import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/services/storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(storageServiceProvider));
});

class AuthService {
  final StorageService _storage;
  static const String _baseUrl = 'https://veltrixcode-ytify.hf.space/api/auth';
  static const String _webClientId = '1023316916513-0ceeamcb82h4c5j27p7pnrbq0fl9udhd.apps.googleusercontent.com';
  static const String _androidClientId = '1023316916513-gf1k3aqschlblasfafsl0bs4mcc1ebcn.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
    clientId: defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS
        ? null
        : _androidClientId,
  );

  AuthService(this._storage);

  String? get token => _storage.authToken;
  bool get isAuthenticated => token != null;

  Future<void> signup(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final user = data['user'];

      await _storage.setAuthToken(token);
      await _storage.setUserInfo(user['username'], user['email']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Signup failed');
    }
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final user = data['user'];

      await _storage.setAuthToken(token);
      await _storage.setUserInfo(user['username'], user['email']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Login failed');
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final user = data['user'];

        await _storage.setAuthToken(token);
        await _storage.setUserInfo(user['username'], user['email']);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Google Login failed on server');
      }
    } catch (e) {
      throw Exception('Google Sign-In Error: $e');
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _storage.clearUserSession();
  }

  Future<String?> refreshToken() async {
    final currentToken = _storage.authToken;
    if (currentToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/refresh'),
        headers: {
          'Authorization': 'Bearer $currentToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'];
        final user = data['user'];

        await _storage.setAuthToken(newToken);
        if (user != null) {
          await _storage.setUserInfo(user['username'], user['email']);
        }
        return newToken;
      } else {
        debugPrint('Token refresh failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return null;
    }
  }

  Future<bool> verifyToken() async {
    final currentToken = _storage.authToken;
    if (currentToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/verify'),
        headers: {'Authorization': 'Bearer $currentToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['valid'] == true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error verifying token: $e');
      return false;
    }
  }
}
