import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import 'screens/main_screen.dart';
import 'screens/game_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/login_screen.dart';
import 'screens/player_registration_screen.dart';
import 'screens/multiplayer_setup_screen.dart';
import 'screens/multiplayer_game_screen.dart';
import 'models/card_model.dart';
import 'services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MemoryGameApp());
}

class MemoryGameApp extends StatelessWidget {
  const MemoryGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Card Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/game': (context) => const GameScreen(),
        '/ranking': (context) => const RankingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const PlayerRegistrationScreen(),
        '/multiplayer-setup': (context) => const MultiplayerSetupScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/multiplayer-game') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => MultiplayerGameScreen(
              player1Name: args['player1Name'],
              player2Name: args['player2Name'],
              player1Email: args['player1Email'],
              player2Email: args['player2Email'],
            ),
          );
        }
        return null;
      },
    );
  }
}