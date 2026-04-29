import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// FIX #1 — Removed flutter_dotenv. Secrets now live only on the proxy server.
// FIX #3 — TODO: Enable Firebase App Check in the Firebase Console to protect
//          your project from unauthorized access. See:
//          https://firebase.google.com/docs/app-check
import 'firebase_options.dart';
import 'app_theme.dart';
import 'list_provider.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'verification_screen.dart';
import 'disabled_screen.dart';
import 'proxy_keepalive.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'username_screen.dart';
import 'constants.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FIX #1 — Removed: await dotenv.load(fileName: ".env");
  // All API keys now live on the proxy server (Render.com env vars).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleWebClientId,
    );
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ListProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MediaTrackerApp(),
    ),
  );
}

class MediaTrackerApp extends StatelessWidget {
  const MediaTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeprovider, child) {
        return MaterialApp(
          title: 'Tracker',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: kBg,
            colorScheme: ColorScheme.dark(
              primary: kAccent,
              surface: kSurface,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
              },
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            tabBarTheme: TabBarThemeData(
              labelColor: kTextPrimary,
              unselectedLabelColor: kTextSecondary,
              indicator: BoxDecoration(
                border: Border(bottom: BorderSide(color: kAccent, width: 3)),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.0),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
            ),
            dividerColor: kBorder,
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(backgroundColor: kBg, body: Center(child: CircularProgressIndicator(color: kAccent)));
              }

              if (!snapshot.hasData) {
                ProxyKeepAlive.stop();
                return const LoginScreen();
              }

              // User is logged in — keep the proxy warm
              ProxyKeepAlive.start();

              final user = snapshot.data!;

              // Intercept users who haven't verified their email yet
              if (!user.emailVerified && user.providerData.any((p) => p.providerId == 'password')) {
                return const VerificationScreen();
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, usersnap) {
                  // If the user document hasn't been created yet, show a loader instead of throwing them to login
                  if (!usersnap.hasData || !usersnap.data!.exists) {
                    return Scaffold(backgroundColor: kBg, body: Center(child: CircularProgressIndicator(color: kAccent)));
                  }

                  final data = usersnap.data!.data() as Map<String, dynamic>?;

                  if (data?['isallowed'] != true) {
                    return const DisabledScreen();
                  }

                  if (data?['username'] == null || data!['username'].toString().trim().isEmpty) {
                    return const UsernameScreen();
                  }

                  return const MainScreen();
                },
              );
            },
          ),
        );
      },
    );
  }
}