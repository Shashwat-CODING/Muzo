// Copyright 2024 Muzo. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//
// A no-op Windows stub for the google_sign_in federated plugin.
// Google Sign-In via Google's native SDK is not available on Windows.
// This stub allows the app to compile on Windows and gracefully
// informs users that Google Sign-In is unavailable.

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// Windows stub implementation of [GoogleSignInPlatform].
/// All operations return null / false; callers should check
/// [GoogleSignInPlatform.instance] or guard with Platform.isWindows.
class GoogleSignInWindows extends GoogleSignInPlatform {
  /// Called by Flutter's plugin registration system.
  static void registerWith() {
    GoogleSignInPlatform.instance = GoogleSignInWindows();
  }

  @override
  Future<void> initWithParams(SignInInitParameters params) async {
    // No-op on Windows.
  }

  @override
  Future<GoogleSignInUserData?> signInSilently() async => null;

  @override
  Future<GoogleSignInUserData?> signIn() async => null;

  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    return GoogleSignInTokenData(
      idToken: null,
      accessToken: null,
      serverAuthCode: null,
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isSignedIn() async => false;

  @override
  Future<void> clearAuthCache({required String token}) async {}

  @override
  Future<bool> requestScopes(List<String> scopes) async => false;

  @override
  Future<bool> canAccessScopes(
    List<String> scopes, {
    String? accessToken,
  }) async => false;
}
