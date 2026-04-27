import 'package:flutter/material.dart';

// FIX #20 — KNOWN LIMITATION: These are mutable top-level globals that get
// modified by ThemeProvider._updateTheme(). This works because main.dart wraps
// the entire app in Consumer<ThemeProvider>, which triggers a full widget tree
// rebuild when the theme changes. However, this pattern is fragile:
//
//   - Widgets that cache these values (e.g. in initState) won't update.
//   - Hot-reload during development may show stale colors.
//
// LONG-TERM FIX: Refactor all widgets to read colors from the ThemeProvider
// via context.watch<ThemeProvider>() instead of referencing these globals.
// That change touches every file in the project and is best done separately.

Color kAccent = const Color(0xFF00E5FF);
Color kBg = const Color(0xFF080809);
Color kSurface = const Color(0xFF141416);
Color kCard = const Color(0xFF1A1A1D);
Color kBorder = const Color(0xFF2A2A2E);
Color kTextPrimary = Colors.white;
Color kTextSecondary = Colors.white70;

class ThemeProvider extends ChangeNotifier {
  bool _isAmoled = false;
  int _accentIndex = 0;

  final List<Color> accentColors = [
    const Color(0xFF00E5FF),
    const Color(0xFFFF2A5F),
    const Color(0xFFB534FF),
    const Color(0xFF00E676),
    const Color(0xFFFFD600),
  ];

  bool get isAmoled => _isAmoled;
  Color get currentAccent => accentColors[_accentIndex];
  int get accentIndex => _accentIndex;

  void toggleAmoled() {
    _isAmoled = !_isAmoled;
    _updateTheme();
  }

  void setAccent(int index) {
    _accentIndex = index;
    _updateTheme();
  }

  void _updateTheme() {
    kAccent = accentColors[_accentIndex];
    if (_isAmoled) {
      kBg = Colors.black;
      kSurface = const Color(0xFF0A0A0C);
      kCard = const Color(0xFF121214);
    } else {
      kBg = const Color(0xFF080809);
      kSurface = const Color(0xFF141416);
      kCard = const Color(0xFF1A1A1D);
    }
    notifyListeners();
  }
}