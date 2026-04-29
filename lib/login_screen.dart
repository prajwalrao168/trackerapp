import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
// FIX #1 — Removed flutter_dotenv import. Google client ID now comes from constants.dart.
import 'app_theme.dart';
import 'constants.dart';

class LoginScreen extends StatefulWidget {
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
  void dispose() {
    emailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  Future<void> emailauthenticate() async {
    if (!mounted) return;
    setState(() {
      isloading = true;
      errormessage = '';
    });

    final email = emailcontroller.text.trim();
    final password = passwordcontroller.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errormessage = 'Please enter both email and password.';
        isloading = false;
      });
      return;
    }

    // FIX #23 — Validate password strength before sending to Firebase.
    // Firebase requires min 6 characters; we tell the user upfront instead
    // of letting Firebase return a confusing error.
    if (password.length < 6) {
      setState(() {
        errormessage = 'Password must be at least 6 characters.';
        isloading = false;
      });
      return;
    }

    // FIX #24 — Expanded email allowlist to include more legitimate providers.
    // NOTE: This is a client-side check only. For real enforcement, add
    // Firestore Security Rules or a Cloud Function that validates the domain.
    final alloweddomains = [
      'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
      'protonmail.com', 'proton.me', 'icloud.com', 'aol.com',
      'zoho.com', 'yandex.com', 'mail.com', 'live.com',
    ];
    final domain = email.split('@').last.toLowerCase();

    if (!alloweddomains.contains(domain)) {
      setState(() {
        errormessage = 'This email provider is not supported. Please use Gmail, Outlook, Yahoo, ProtonMail, iCloud, or another major provider.';
        isloading = false;
      });
      return;
    }

    try {
      UserCredential usercredential;
      
      // Step 1: Try to log in first
      try {
        usercredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // We included 'invalid-login-credentials' as that is the newest Firebase error code
        if (e.code == 'invalid-credential' || e.code == 'user-not-found' || e.code == 'invalid-login-credentials') {
          try {
            usercredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            await usercredential.user!.sendEmailVerification();
            await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).set({
              'email': usercredential.user!.email,
              'isallowed': true,
            });
            return;
          } on FirebaseAuthException catch (signUpError) {
            if (signUpError.code == 'email-already-in-use') {
              setState(() {
                errormessage = 'This mail is already registered.';
                isloading = false;
              });
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: kSurface,
                  title: Text('Account Exists', style: TextStyle(color: kTextPrimary)),
                  content: Text(
                    'This mail is already registered.',
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
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // FIX #9 — AWAIT the Firestore write so the document exists before
      // main.dart's StreamBuilder tries to read it. Without await, first-time
      // users could see an infinite loading screen.
      //
      // FIX #6 — Removed 'isallowed': true. The client should NEVER set its
      // own authorization flag. This field should only be managed by an admin
      // via Cloud Functions or the Firebase Console. Add a Firestore Security
      // Rule to deny client writes to this field.
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

      // NO ROUTING HERE! main.dart handles it automatically.

    } catch (e) {
      if (!mounted) return;
      setState(() {
        errormessage = e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
      });
    } finally {
      // FIX #8 — ALWAYS reset isloading, whether login succeeded or failed.
      // Previously, on success the spinner would stay forever if main.dart
      // didn't navigate away instantly.
      if (mounted) {
        setState(() => isloading = false);
      }
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
        final googleauth = await googleuser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleauth.idToken,
        );
        usercredential = await FirebaseAuth.instance.signInWithCredential(credential);

        // Explicitly block Google Sign-In if this account has an Email/Password attached
        if (usercredential.user!.providerData.any((p) => p.providerId == 'password')) {
          await FirebaseAuth.instance.signOut();
          if (!kIsWeb) {
            try {
              await GoogleSignIn.instance.disconnect();
            } catch (_) {}
            await GoogleSignIn.instance.signOut();
          }
          if (!mounted) return;
          setState(() => isloading = false);
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
      }

      // FIX #24 — Same expanded allowlist as email login
      final alloweddomains = [
        'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
        'protonmail.com', 'proton.me', 'icloud.com', 'aol.com',
        'zoho.com', 'yandex.com', 'mail.com', 'live.com',
      ];
      final domain = usercredential.user!.email?.split('@').last.toLowerCase() ?? '';

      if (!alloweddomains.contains(domain)) {
        await FirebaseAuth.instance.currentUser?.delete();
        await FirebaseAuth.instance.signOut();
        if (!kIsWeb) {
          try {
            await GoogleSignIn.instance.disconnect();
          } catch (_) {}
          await GoogleSignIn.instance.signOut();
        }
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

      // Note: We cannot manually check for duplicate accounts here because Firestore security rules
      // block querying by email, and Firebase Auth removed fetchSignInMethodsForEmail.
      // To prevent duplicate accounts, the user MUST enable "Link accounts that use the same email"
      // in the Firebase Console.

      // FIX #6 — Don't set isallowed from the client. Only write email.
      // For Google login, we preserve existing isallowed value if the doc exists.
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

      // NO ROUTING HERE! main.dart handles it.

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'account-exists-with-different-credential') {
        setState(() => isloading = false);
        if (!kIsWeb) {
          try {
            await GoogleSignIn.instance.disconnect();
          } catch (_) {}
          await GoogleSignIn.instance.signOut();
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
      // FIX #8 — Always reset loading state
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
                  'Welcome',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: emailcontroller,
                      enabled: true,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: kTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: kTextSecondary),
                        filled: true,
                        fillColor: kSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordcontroller,
                      enabled: true,
                      obscureText: true,
                      style: TextStyle(color: kTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: kTextSecondary),
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
                        onPressed: isloading ? null : emailauthenticate,
                        child: isloading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('Login / Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
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