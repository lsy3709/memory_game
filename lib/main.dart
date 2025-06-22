import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

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
import 'screens/online_player_name_setup_screen.dart';
import 'screens/online_room_list_screen.dart';
import 'screens/online_room_creation_screen.dart';
import 'screens/online_multiplayer_game_screen.dart';
import 'screens/friend_management_screen.dart';
import 'models/card_model.dart';
import 'models/online_room.dart';
import 'services/sound_service.dart';
import 'services/firebase_service.dart';
import 'firebase_options.dart'; // Firebase 옵션 파일

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // Impeller 렌더링 엔진 비활성화 (Skia 사용)
  if (Platform.isAndroid) {
    // Android에서 Impeller 비활성화
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
  }
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Firebase App Check 초기화 (프로덕션 배포용)
  await FirebaseAppCheck.instance.activate(
    // 개발 중에는 디버그 토큰 사용, 프로덕션에서는 실제 토큰 사용
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  
  // 사운드 서비스 초기화 및 배경음악 시작
  try {
    await SoundService.instance.playBackgroundMusic();
    print('사운드 서비스 초기화 완료');
  } catch (e) {
    print('사운드 서비스 초기화 오류: $e');
  }
  
  runApp(const MemoryGameApp());
}

class MemoryGameApp extends StatelessWidget {
  const MemoryGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Card Game',
      debugShowCheckedModeBanner: false,
      // 렌더링 성능 최적화
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // 텍스트 스케일 고정으로 렌더링 안정성 향상
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
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
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const PlayerRegistrationScreen(),
        '/ranking': (context) => const RankingScreen(),
        '/multiplayer_setup': (context) => const MultiplayerSetupScreen(),
        '/online_login': (context) => const OnlineLoginScreen(),
        '/online_main': (context) => const OnlineMainScreen(),
        '/online-game': (context) => const OnlineGameScreen(),
        '/online-ranking': (context) => const OnlineRankingScreen(),
        '/online-my-records': (context) => const OnlineMyRecordsScreen(),
        '/online-multiplayer-setup': (context) => const OnlineMultiplayerSetupScreen(),
        '/online-player-name-setup': (context) => const OnlinePlayerNameSetupScreen(),
        '/online-room-list': (context) => const OnlineRoomListScreen(),
        '/online-room-creation': (context) => const OnlineRoomCreationScreen(),
        '/friend-management': (context) => const FriendManagementScreen(),
      },
      onGenerateRoute: (settings) {
        // 싱글 플레이어 게임 화면 - 동적 라우팅
        if (settings.name == '/game') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => GameScreen(
                playerName: args['playerName'] ?? '게스트',
                email: args['email'],
              ),
            );
          }
        }
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
        // 온라인 멀티플레이어 게임 화면 - 동적 라우팅
        if (settings.name == '/online-multiplayer-game') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args['room'] != null) {
            final room = args['room'] as OnlineRoom;
            return MaterialPageRoute(
              builder: (context) => OnlineMultiplayerGameScreen(room: room),
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