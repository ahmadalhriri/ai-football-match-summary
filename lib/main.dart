import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fball/screens/LoginScreen.dart';
import 'package:fball/screens/summarization_user_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/championships_screen.dart';
import 'screens/search_screen.dart';
import 'screens/summarization_admin_screen.dart';
import 'screens/RegisterScreen.dart';

import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Football App',
      theme: AppTheme.darkTheme,
      // Define routes here
      routes: {
        'LoginScreen': (context) => const LoginScreen(),
        'summarization_admin_screen': (context) =>
            const SummarizationAdminScreen(),
        'summarization_user_screen': (context) => const SummarizationScreen(),
        'RegisterScreen': (context) => const Register(),
      },
      home: const MainApp(),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const MatchesScreen(),
    const ChampionshipsScreen(),
    // For index 2, we do NOT want to show a widget directly here
    // So just add a placeholder container for safety
    Container(),
    const SearchScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Instead of setting tab to 2, navigate to LoginScreen via route
      Navigator.of(context).pushNamed('LoginScreen');
      // Do NOT update _selectedIndex to 2, keep previous tab selected
    } else if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: SizedBox(
        height: 110,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white,
          selectedLabelStyle: const TextStyle(
            color: Colors.blueAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_soccer),
              label: 'مباريات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              label: 'البطولات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_library),
              label: 'الملخصات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'بحث',
            ),
          ],
        ),
      ),
    );
  }
}
