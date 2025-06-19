import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/main_screen.dart';
import 'screens/game_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/login_screen.dart';
import 'screens/player_registration_screen.dart';
import 'screens/multiplayer_setup_screen.dart';
import 'screens/multiplayer_game_screen.dart';
import 'screens/multiplayer_comparison_screen.dart';
import 'screens/online_login_screen.dart';
import 'screens/online_main_screen.dart';
import 'screens/online_game_screen.dart';
import 'screens/online_ranking_screen.dart';
import 'screens/online_my_records_screen.dart';
import 'screens/online_multiplayer_setup_screen.dart';
import 'models/card_model.dart';
import 'services/sound_service.dart';
import 'services/firebase_service.dart';
import 'firebase_options.dart'; // Firebase 옵션 파일

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        '/': (context) => const AuthWrapper(),
        '/main': (context) => const MainScreen(),
        '/game': (context) => const GameScreen(),
        '/login': (context) => const LoginScreen(),
        '/player-registration': (context) => const PlayerRegistrationScreen(),
        '/ranking': (context) => const RankingScreen(),
        '/multiplayer-setup': (context) => const MultiplayerSetupScreen(),
        '/online-login': (context) => const OnlineLoginScreen(),
        '/online-main': (context) => const OnlineMainScreen(),
        '/online-game': (context) => const OnlineGameScreen(),
        '/online-ranking': (context) => const OnlineRankingScreen(),
        '/online-my-records': (context) => const OnlineMyRecordsScreen(),
        '/online-multiplayer-setup': (context) => const OnlineMultiplayerSetupScreen(),
      },
      onGenerateRoute: (settings) {
        // 멀티플레이어 게임 화면 - 동적 라우팅
        if (settings.name == '/multiplayer-game') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(
                player1Name: args['player1Name'] ?? '',
                player2Name: args['player2Name'] ?? '',
              ),
            );
          }
        }
        // 멀티플레이어 비교 화면 - 동적 라우팅
        if (settings.name == '/multiplayer-comparison') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => MultiplayerComparisonScreen(
                player1: args['player1'],
                player2: args['player2'],
                gameTime: args['totalTime'] ?? 0,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}

/// 인증 상태에 따른 화면 분기 처리
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Firebase 인증 상태 확인
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase 인증 상태 확인 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        // 로그인된 사용자가 있으면 온라인 메인 화면으로
        if (snapshot.hasData && snapshot.data != null) {
          return const OnlineMainScreen();
        }
        // 로그인되지 않은 경우 로컬 메인 화면으로
        return const MainScreen();
      },
    );
  }
}