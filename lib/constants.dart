import 'package:firebase_auth/firebase_auth.dart';

/// Centralized constants for proxy configuration.
///
/// The proxy server validates Firebase Auth tokens.
const String kProxyBaseUrl = 'https://alltrackerappproxy.onrender.com';

Future<Map<String, String>> getProxyHeaders() async {
  final user = FirebaseAuth.instance.currentUser;
  final token = await user?.getIdToken() ?? '';
  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
}

/// Google Web Client ID for Google Sign-In.
/// This is a public client identifier (not a secret).
const String kGoogleWebClientId =
    '1048129569498-7to85j6pfgvg4bk7705ptvt4k5u3hou2.apps.googleusercontent.com';
