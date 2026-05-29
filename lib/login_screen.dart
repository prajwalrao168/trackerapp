import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_theme.dart';
import 'register_screen.dart';
import 'account_conflict_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Set by Google sign-in when a conflict is detected. Survives the
  /// widget rebuild triggered by FirebaseAuth.signOut().
  static String? pendingConflictProvider;

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();

  bool isloading = false;
  String errormessage = '';

  @override
  void initState() {
    super.initState();
    // If we just came back from a Google sign-in conflict,
    // navigate to the conflict screen after the first frame.
    if (LoginScreen.pendingConflictProvider != null) {
      final provider = LoginScreen.pendingConflictProvider!;
      LoginScreen.pendingConflictProvider = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountConflictScreen(existingProvider: provider),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    emailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  Future<void> emaillogin() async {
    if (!mounted) return;
    setState(() {
      isloading = true;
      errormessage = '';
    });

    final email = emailcontroller.text.trim();
    final password = passwordcontroller.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errormessage = 'Please enter both email and password.';
        isloading = false;
      });
      return;
    }

    try {
      final usercredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure Firestore docs are up to date
      final userdoc = await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).get();
      if (!userdoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).set({
          'email': usercredential.user!.email,
          'isallowed': true,
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).set({
          'email': usercredential.user!.email,
        }, SetOptions(merge: true));
      }

      // Backfill email_lookup for existing users
      final emailLookupRef = FirebaseFirestore.instance.collection('email_lookup').doc(email.toLowerCase());
      final lookupDoc = await emailLookupRef.get();
      if (!lookupDoc.exists) {
        await emailLookupRef.set({
          'provider': 'password',
          'uid': usercredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // main.dart StreamBuilder handles navigation

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials' || e.code == 'wrong-password') {
        setState(() {
          errormessage = 'Incorrect email or password. Please try again.';
          isloading = false;
        });
      } else {
        setState(() {
          errormessage = e.message ?? e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
          isloading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errormessage = e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
      });
    } finally {
      if (mounted) {
        setState(() => isloading = false);
      }
    }
  }

  /// Helper to sign out of Google completely.
  Future<void> _signOutGoogle() async {
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb) {
      GoogleSignIn.instance.disconnect().catchError((_) => null);
      GoogleSignIn.instance.signOut().catchError((_) => null);
    }
  }

  Future<void> googleauthenticate() async {
    if (!mounted) return;
    setState(() {
      isloading = true;
      errormessage = '';
    });

    try {
      UserCredential usercredential;

      if (kIsWeb) {
        final googleprovider = GoogleAuthProvider();
        usercredential = await FirebaseAuth.instance.signInWithPopup(googleprovider);
      } else {
        // ignore: await_only_futures
        final googleuser = await GoogleSignIn.instance.authenticate();
        final googleauth = googleuser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleauth.idToken,
        );

        // Sign in with Firebase (user becomes authenticated)
        usercredential = await FirebaseAuth.instance.signInWithCredential(credential);

        // Now authenticated — check email_lookup for cross-provider conflict
        final googleEmail = usercredential.user!.email?.toLowerCase() ?? '';
        if (googleEmail.isNotEmpty) {
          final lookupDoc = await FirebaseFirestore.instance
              .collection('email_lookup')
              .doc(googleEmail)
              .get();

          if (lookupDoc.exists && lookupDoc.data()?['provider'] == 'password') {
            // Conflict: email was registered via email/password.
            // Set static flag, sign out, and let the rebuilt LoginScreen
            // navigate to the conflict screen.
            LoginScreen.pendingConflictProvider = 'password';
            await FirebaseAuth.instance.signOut();
            if (!kIsWeb) {
              GoogleSignIn.instance.disconnect().catchError((_) => null);
              GoogleSignIn.instance.signOut().catchError((_) => null);
            }
            return;
          }
        }
      }

      // Domain allowlist check
      final alloweddomains = [
        'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
        'protonmail.com', 'proton.me', 'icloud.com', 'aol.com',
        'zoho.com', 'yandex.com', 'mail.com', 'live.com',
      ];
      final domain = usercredential.user!.email?.split('@').last.toLowerCase() ?? '';

      if (!alloweddomains.contains(domain)) {
        try {
          // Clean up Firestore docs before deleting the auth account
          final uid = usercredential.user!.uid;
          final cleanupEmail = usercredential.user!.email?.toLowerCase() ?? '';
          await FirebaseFirestore.instance.collection('users').doc(uid).delete();
          if (cleanupEmail.isNotEmpty) {
            await FirebaseFirestore.instance.collection('email_lookup').doc(cleanupEmail).delete();
          }
          // Removed currentUser?.delete() here to prevent orphaned auth accounts
          // if Firestore cleanup failed. User is signed out immediately.
        } catch (e) {
          debugPrint('Cleanup error on domain rejection: $e');
        }
        await _signOutGoogle();
        if (!mounted) return;
        setState(() => isloading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kSurface,
            title: Text('Sign-In Denied', style: TextStyle(color: kTextPrimary)),
            content: Text(
              'This email provider is not supported.\n\nPlease sign in with a Gmail, Outlook, Yahoo, ProtonMail, or iCloud account.',
              style: TextStyle(color: kTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
        return;
      }

      // Write/update user document in Firestore
      final userdoc = await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).get();
      if (!userdoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).set({
          'email': usercredential.user!.email,
          'isallowed': true,
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).set({
          'email': usercredential.user!.email,
        }, SetOptions(merge: true));
      }

      // Register in email_lookup for cross-provider conflict detection
      final userEmail = usercredential.user!.email?.toLowerCase() ?? '';
      if (userEmail.isNotEmpty) {
        final lookupRef = FirebaseFirestore.instance.collection('email_lookup').doc(userEmail);
        final lookupDoc = await lookupRef.get();
        if (!lookupDoc.exists) {
          await lookupRef.set({
            'provider': 'google.com',
            'uid': usercredential.user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // main.dart StreamBuilder handles navigation

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'account-exists-with-different-credential') {
        setState(() => isloading = false);
        if (!kIsWeb) {
          GoogleSignIn.instance.disconnect().catchError((_) => null);
          GoogleSignIn.instance.signOut().catchError((_) => null);
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kSurface,
            title: Text('Account Exists', style: TextStyle(color: kTextPrimary)),
            content: Text(
              'This email is already registered with a password. Please sign in using your email and password instead.',
              style: TextStyle(color: kTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: kAccent)),
              ),
            ],
          ),
        );
        return;
      }
      setState(() {
        errormessage = e.message ?? e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errormessage = e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
      });
    } finally {
      if (mounted) {
        setState(() => isloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.track_changes_rounded, size: 80, color: kAccent),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 40),
                if (errormessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Text(
                      errormessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isloading ? null : googleauthenticate,
                    child: isloading
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: kBg, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.g_mobiledata_rounded, size: 32, color: kBg),
                              const SizedBox(width: 8),
                              const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: Divider(color: kBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: kBorder)),
                  ],
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailcontroller,
                  enabled: !isloading,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: kTextSecondary),
                    prefixIcon: Icon(Icons.email_outlined, color: kTextSecondary),
                    filled: true,
                    fillColor: kSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordcontroller,
                  enabled: !isloading,
                  obscureText: true,
                  style: TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: kTextSecondary),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: kTextSecondary),
                    filled: true,
                    fillColor: kSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isloading ? null : emaillogin,
                    child: isloading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('LOG IN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: kTextSecondary, fontSize: 14)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: Text('Create Account', style: TextStyle(color: kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}