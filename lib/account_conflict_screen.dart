import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'app_theme.dart';

class AccountConflictScreen extends StatelessWidget {
  final String existingProvider;

  const AccountConflictScreen({
    super.key,
    required this.existingProvider,
  });

  String get _providerLabel {
    if (existingProvider == 'password') {
      return 'Email & Password';
    } else if (existingProvider == 'google.com') {
      return 'Google Sign-In';
    }
    return existingProvider;
  }

  String get _suggestion {
    if (existingProvider == 'password') {
      return 'Please go back and sign in using your email and password instead.';
    } else if (existingProvider == 'google.com') {
      return 'Please go back and use the "Continue with Google" button instead.';
    }
    return 'Please go back and use your original sign-in method.';
  }

  Future<void> _goBack(BuildContext context) async {
    // Pop this screen first so it's not on the stack
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Firebase sign-out is fast and triggers StreamBuilder → LoginScreen
    await FirebaseAuth.instance.signOut();

    // Google cleanup is slow (network call) — fire-and-forget in background
    if (!kIsWeb) {
      GoogleSignIn.instance.disconnect().catchError((_) => null);
      GoogleSignIn.instance.signOut().catchError((_) => null);
    }
    // main.dart's StreamBuilder will automatically show LoginScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orangeAccent),
              const SizedBox(height: 24),
              Text(
                'EMAIL ALREADY REGISTERED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This email is already registered with $_providerLabel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextPrimary, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                _suggestion,
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: kAccent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 5)),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _goBack(context),
                  child: const Text(
                    'GO BACK TO LOGIN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
