import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

/// GVSU brand colors.
const gvsuBlue = Color(0xFF0065A4);
const gvsuBlack = Color(0xFF000000);

void main() {
  runApp(const WalkWithMeApp());
}

class WalkWithMeApp extends StatelessWidget {
  const WalkWithMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk With Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: gvsuBlue,
          primary: gvsuBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: gvsuBlue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
