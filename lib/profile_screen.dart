import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'list_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // FIX #22 — Getter instead of a field. This way it always returns the
  // LATEST user object from Firebase, so changes like updateDisplayName()
  // are reflected immediately without needing to leave and come back.
  User? get user => FirebaseAuth.instance.currentUser;
  final TextEditingController namecontroller = TextEditingController();
  bool iseditingname = false;

  @override
  void initState() {
    super.initState();
    namecontroller.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    namecontroller.dispose();
    super.dispose();
  }

  Future<void> updatename() async {
    if (namecontroller.text.trim().isNotEmpty) {
      await user?.updateDisplayName(namecontroller.text.trim());
      setState(() {
        iseditingname = false;
      });
    }
  }

  Future<void> handlelogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessiontoken');
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    
    // FIX: Clear the entire navigation stack and push to Login
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listprovider = Provider.of<ListProvider>(context);
    final themeprovider = Provider.of<ThemeProvider>(context);
    final items = listprovider.items;

    final totalitems = items.length;
    final completeditems = items.where((i) => i.status == TrackingStatus.completed).length;
    final activeitems = items.where((i) => i.status == TrackingStatus.active).length;
    final planningitems = items.where((i) => i.status == TrackingStatus.planning).length;

    final animecount = items.where((i) => i.mediatype == 'anime').length;
    final cinemacount = items.where((i) => i.mediatype == 'cinema').length;
    final gamescount = items.where((i) => i.mediatype == 'game').length;

    final completionrate = totalitems > 0 ? (completeditems / totalitems) : 0.0;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 40,
                backgroundColor: kSurface,
                child: Icon(Icons.person_rounded, size: 40, color: kAccent),
              ),
              const SizedBox(height: 16),
              iseditingname
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: namecontroller,
                            style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              isDense: true,
                              border: UnderlineInputBorder(borderSide: BorderSide(color: kAccent)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.check_circle_rounded, color: kAccent),
                          onPressed: updatename,
                        )
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.displayName == null || user!.displayName!.isEmpty 
                              ? 'Tracker User' 
                              : user!.displayName!,
                          style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_rounded, color: kTextSecondary, size: 18),
                          onPressed: () => setState(() => iseditingname = true),
                        )
                      ],
                    ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: TextStyle(color: kTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 40),
              buildsectiontitle('OVERVIEW'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Completion Rate', style: TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${(completionrate * 100).toStringAsFixed(1)}%', style: TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 32),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: completionrate,
                        minHeight: 10,
                        backgroundColor: kCard,
                        valueColor: AlwaysStoppedAnimation<Color>(kAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              buildsectiontitle('TRACKING STATUS'),
              const SizedBox(height: 16),
              Row(
                children: [
                  buildstatcard('Total', totalitems.toString(), kSurface, kTextPrimary),
                  const SizedBox(width: 12),
                  buildstatcard('Completed', completeditems.toString(), Colors.purpleAccent.withOpacity(0.1), Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  buildstatcard('Active', activeitems.toString(), Colors.greenAccent.withOpacity(0.1), Colors.greenAccent),
                  const SizedBox(width: 12),
                  buildstatcard('Planning', planningitems.toString(), kAccent.withOpacity(0.1), kAccent),
                ],
              ),
              const SizedBox(height: 40),
              buildsectiontitle('MEDIA BREAKDOWN'),
              const SizedBox(height: 16),
              Row(
                children: [
                  buildstatcard('Anime', animecount.toString(), kSurface, kTextPrimary),
                  const SizedBox(width: 10),
                  buildstatcard('Cinema', cinemacount.toString(), kSurface, kTextPrimary),
                  const SizedBox(width: 10),
                  buildstatcard('Games', gamescount.toString(), kSurface, kTextPrimary),
                ],
              ),
              const SizedBox(height: 40),
              buildsectiontitle('SETTINGS'),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: kAccent,
                      title: Text('AMOLED Dark Mode', style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      value: themeprovider.isAmoled,
                      onChanged: (val) => themeprovider.toggleAmoled(),
                    ),
                    Divider(color: kBorder, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Accent Color', style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          Row(
                            children: List.generate(themeprovider.accentColors.length, (index) {
                              final isselected = themeprovider.accentIndex == index;
                              return GestureDetector(
                                onTap: () => themeprovider.setAccent(index),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: themeprovider.accentColors[index],
                                    shape: BoxShape.circle,
                                    border: isselected ? Border.all(color: Colors.white, width: 2) : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: kBorder, height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      title: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onTap: handlelogout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildsectiontitle(String title) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
      ],
    );
  }

  Widget buildstatcard(String label, String value, Color bgcolor, Color textcolor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: bgcolor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: textcolor, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}