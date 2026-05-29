import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController namecontroller = TextEditingController();
  bool isloading = false;
  String errormessage = '';

  @override
  void dispose() {
    namecontroller.dispose();
    super.dispose();
  }

  Future<void> submitUsername() async {
    final username = namecontroller.text.trim();
    if (username.isEmpty) {
      setState(() {
        errormessage = 'Please enter a username.';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        errormessage = 'Username must be at least 3 characters.';
      });
      return;
    }

    if (username.length > 20) {
      setState(() {
        errormessage = 'Username must be 20 characters or less.';
      });
      return;
    }

    // Only allow letters, numbers, underscores, and spaces
    if (!RegExp(r'^[a-zA-Z0-9_ ]+$').hasMatch(username)) {
      setState(() {
        errormessage = 'Username can only contain letters, numbers, underscores, and spaces.';
      });
      return;
    }

    setState(() {
      isloading = true;
      errormessage = '';
    });

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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(username);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': username,
        }, SetOptions(merge: true));
        // Force refresh user to trigger StreamBuilder in main.dart
        await user.reload();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errormessage = e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isloading = false;
        });
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
                Icon(Icons.person_pin_rounded, size: 80, color: kAccent),
                const SizedBox(height: 24),
                Text(
                  'Set Your Username',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose a unique username so others can find you!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
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
                  controller: namecontroller,
                  enabled: !isloading,
                  style: TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Username',
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
                    onPressed: isloading ? null : submitUsername,
                    child: isloading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('CONTINUE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
