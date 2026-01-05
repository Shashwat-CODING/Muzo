import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/services/storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(storageServiceProvider));
});

class AuthService {
  final StorageService _storage;
  static const String _baseUrl = 'https://mowttvwofyojqsowpsga.supabase.co/functions/v1/express/api/auth';

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
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
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

  Future<void> logout() async {
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
        headers: {
          'Authorization': 'Bearer $currentToken',
        },
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
