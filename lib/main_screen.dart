import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'anime_list.dart';
import 'movies_list.dart';
import 'games_list.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'list_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int bottomindex = 0;
  int categoryindex = 0;

  final List<String> categories = ['ANIME', 'CINEMA', 'GAMES'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ListProvider>(context, listen: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ismylist = bottomindex == 1;

    return Scaffold(
      extendBody: true,
      backgroundColor: kBg,
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 24,
        title: Text(
          categories[categoryindex],
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: kSurface,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.search_rounded, color: kTextPrimary, size: 24),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: kSurface,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.person_outline_rounded, color: kTextPrimary, size: 24),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isselected = categoryindex == index;
                return GestureDetector(
                  onTap: () => setState(() => categoryindex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isselected ? kAccent : kSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: isselected ? Colors.transparent : kBorder),
                    ),
                    child: Text(
                      categories[index],
                      style: TextStyle(
                        color: isselected ? Colors.black : kTextSecondary,
                        fontWeight: isselected ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: categoryindex,
              children: [
                AnimeListScreen(isMyList: ismylist),
                MoviesListScreen(ismylist: ismylist),
                GamesListScreen(ismylist: ismylist),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FloatingBottomNav(
        selectedindex: bottomindex,
        ontap: (i) => setState(() => bottomindex = i),
      ),
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  final int selectedindex;
  final void Function(int) ontap;

  const _FloatingBottomNav({
    required this.selectedindex,
    required this.ontap,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [Icons.explore_rounded, Icons.bookmark_rounded];
    final labels = ['DISCOVER', 'VAULT'];

    return Padding(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: kSurface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: kBorder, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(icons.length, (i) {
                final selected = i == selectedindex;
                return GestureDetector(
                  onTap: () => ontap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutQuart,
                          padding: EdgeInsets.all(selected ? 8 : 4),
                          decoration: BoxDecoration(
                            color: selected ? kAccent.withOpacity(0.15) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icons[i],
                            color: selected ? kAccent : kTextSecondary,
                            size: selected ? 24 : 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: selected ? kAccent : kTextSecondary,
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}