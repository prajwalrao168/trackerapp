import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'account_conflict_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  final TextEditingController confirmpasswordcontroller = TextEditingController();
  final TextEditingController usernamecontroller = TextEditingController();

  bool isloading = false;
  String errormessage = '';

  @override
  void dispose() {
    emailcontroller.dispose();
    passwordcontroller.dispose();
    confirmpasswordcontroller.dispose();
    usernamecontroller.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (!mounted) return;
    setState(() {
      isloading = true;
      errormessage = '';
    });

    final email = emailcontroller.text.trim();
    final password = passwordcontroller.text;
    final confirmpassword = confirmpasswordcontroller.text;
    final username = usernamecontroller.text.trim();

    if (email.isEmpty || password.isEmpty || confirmpassword.isEmpty || username.isEmpty) {
      setState(() {
        errormessage = 'Please fill in all fields.';
        isloading = false;
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        errormessage = 'Username must be at least 3 characters.';
        isloading = false;
      });
      return;
    }

    if (username.length > 20) {
      setState(() {
        errormessage = 'Username must be 20 characters or less.';
        isloading = false;
      });
      return;
    }

    // Only allow letters, numbers, underscores, and spaces
    if (!RegExp(r'^[a-zA-Z0-9_ ]+$').hasMatch(username)) {
      setState(() {
        errormessage = 'Username can only contain letters, numbers, underscores, and spaces.';
        isloading = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errormessage = 'Password must be at least 6 characters.';
        isloading = false;
      });
      return;
    }

    if (password != confirmpassword) {
      setState(() {
        errormessage = 'Passwords do not match.';
        isloading = false;
      });
      return;
    }

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
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        setState(() {
          errormessage = 'Username is already taken. Please choose another one.';
          isloading = false;
        });
        return;
      }

      final usercredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name
      await usercredential.user!.updateDisplayName(username);

      // Send verification email
      await usercredential.user!.sendEmailVerification();

      // Create user doc with username included
      await FirebaseFirestore.instance.collection('users').doc(usercredential.user!.uid).set({
        'email': usercredential.user!.email,
        'username': username,
        'isallowed': true,
      });

      // Register in email_lookup for cross-provider conflict detection
      await FirebaseFirestore.instance
          .collection('email_lookup')
          .doc(email.toLowerCase())
          .set({
        'provider': 'password',
        'uid': usercredential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // main.dart StreamBuilder will detect the new user and show VerificationScreen

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        setState(() => isloading = false);
        // Check email_lookup to find the actual provider
        String existingProvider = 'password';
        try {
          final lookupDoc = await FirebaseFirestore.instance
              .collection('email_lookup')
              .doc(email.toLowerCase())
              .get();
          if (lookupDoc.exists) {
            existingProvider = lookupDoc.data()?['provider'] ?? 'password';
          }
        } catch (_) {}
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountConflictScreen(existingProvider: existingProvider),
          ),
        );
        return;
      }
      setState(() {
        errormessage = e.message ?? e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
        isloading = false;
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
                Icon(Icons.person_add_rounded, size: 80, color: kAccent),
                const SizedBox(height: 24),
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to start tracking your media',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextSecondary, fontSize: 14),
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
                TextField(
                  controller: usernamecontroller,
                  enabled: !isloading,
                  style: TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(color: kTextSecondary),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: kTextSecondary),
                    filled: true,
                    fillColor: kSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextField(
                  controller: confirmpasswordcontroller,
                  enabled: !isloading,
                  obscureText: true,
                  style: TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',
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
                    onPressed: isloading ? null : register,
                    child: isloading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('REGISTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Log In', style: TextStyle(color: kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
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
