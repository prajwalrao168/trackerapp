import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool isloading = false;
  String errormessage = '';

  Future<void> checkverification() async {
    setState(() {
      isloading = true;
      errormessage = '';
    });
    
    try {
      // Reloading forces Firebase to pull the latest verification status
      await FirebaseAuth.instance.currentUser?.reload();
      
      // If verification is still false, stop loading and show a message.
      // If true, we don't need to do anything! main.dart's userChanges() 
      // stream will instantly detect the change and pull us to the MainScreen.
      if (FirebaseAuth.instance.currentUser?.emailVerified == false) {
        if (mounted) {
          setState(() {
            errormessage = 'Not verified yet. Check your inbox, spam, and bin folders.';
            isloading = false;
          });
        }
      }
    } catch (e) {
      // If Firebase throws a 400 error or network glitch, catch it and stop loading!
      if (mounted) {
        setState(() {
          errormessage = e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
          isloading = false;
        });
      }
    }
  }

  Future<void> resendverification() async {
    setState(() { isloading = true; errormessage = ''; });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() {
        errormessage = 'Verification email resent!';
        isloading = false;
      });
    } catch (e) {
      setState(() {
        errormessage = e.toString().replaceAll(RegExp(r'\[.*?\] '), '');
        isloading = false;
      });
    }
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
              Icon(Icons.mark_email_unread_rounded, size: 80, color: kAccent),
              const SizedBox(height: 24),
              Text(
                'AWAITING VERIFICATION',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to your email. Click it to authorize this device.\n\nCheck your spam and bin folders!',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              if (errormessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: errormessage.contains('resent') ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: errormessage.contains('resent') ? Colors.greenAccent : Colors.redAccent),
                  ),
                  child: Text(
                    errormessage,
                    style: TextStyle(color: errormessage.contains('resent') ? Colors.greenAccent : Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: kAccent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5)),
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
                  onPressed: isloading ? null : checkverification,
                  child: isloading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text("I'VE VERIFIED MY EMAIL", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isloading ? null : resendverification,
                child: Text('RESEND LINK', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
              TextButton(
                onPressed: isloading ? null : () => FirebaseAuth.instance.signOut(),
                child: Text('CANCEL', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}