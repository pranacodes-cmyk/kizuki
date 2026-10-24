import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// Native credentials are verified by the existing account backend; no custom sessions.
class NativeAuth {
  static Future<void>? _googleReady;

  /// The learner closed the Google / Apple sheet: not an error, nothing to retry.
  static bool isCancel(Object e) =>
      (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) ||
      (e is SignInWithAppleAuthorizationException && e.code == AuthorizationErrorCode.canceled);

  static Future<void> signIn(String provider) async {
    final auth = Supabase.instance.client.auth;
    if (provider == 'google') {
      _googleReady ??= GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? AppConfig.googleIosClientId : null,
        serverClientId: AppConfig.googleWebClientId,
      ).catchError((Object error) { _googleReady = null; throw error; });
      final ready = _googleReady;
      if (ready == null) throw const AuthException('Google sign-in could not initialize.');
      await ready;
      const scopes = ['email', 'profile'];
      final account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
      final token = account.authentication.idToken;
      if (token == null) throw const AuthException('Google did not return a sign-in token. Please try again.');
      final authorization = await account.authorizationClient.authorizationForScopes(scopes) ?? await account.authorizationClient.authorizeScopes(scopes);
      await auth.signInWithIdToken(provider: OAuthProvider.google, idToken: token, accessToken: authorization.accessToken);
      return;
    }
    if (provider != 'apple' || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const AuthException('This sign-in method is not available on this device.');
    }
    final nonce = auth.generateRawNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
    );
    final token = credential.identityToken;
    if (token == null) throw const AuthException('Apple did not return a sign-in token. Please try again.');
    await auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: token, nonce: nonce);
    final name = [credential.givenName, credential.familyName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    if (name.isNotEmpty) {
      try {
        await auth.updateUser(UserAttributes(data: {'full_name': name}));
      } catch (e) {
        // The account is signed in; a missing display name must not fail sign-in.
        debugPrint('apple name update failed: $e');
      }
    }
  }
}
