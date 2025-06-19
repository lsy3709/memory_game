import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firebase 의존성을 선택적으로 import
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // Firebase 초기화 시도
  bool firebaseInitialized = false;
  try {
    // Firebase 설정 파일이 있는지 확인하고 초기화
    firebaseInitialized = await _tryInitializeFirebase();
    if (firebaseInitialized) {
      print('Firebase 초기화 성공 - 온라인 모드 사용 가능');
    } else {
      print('Firebase 설정이 완료되지 않았습니다.');
      print('로컬 모드로 실행됩니다. 온라인 기능을 사용하려면 Firebase 설정을 완료해주세요.');
    }
  } catch (e) {
    print('Firebase 초기화 중 오류 발생: $e');
    print('로컬 모드로 실행됩니다.');
    firebaseInitialized = false;
  }
  
  runApp(MemoryGameApp(firebaseInitialized: firebaseInitialized));
}

/// Firebase 초기화 시도
Future<bool> _tryInitializeFirebase() async {
  try {
    // Firebase Options 파일이 있는지 확인
    final hasFirebaseOptions = await _checkFirebaseOptionsFile();
    
    if (hasFirebaseOptions) {
      // Firebase Options 파일이 있으면 Firebase 초기화
      try {
        // firebase_options.dart 파일을 동적으로 import
        await _initializeFirebaseWithOptions();
        print('Firebase 초기화 성공');
        return true;
      } catch (e) {
        print('Firebase 초기화 실패: $e');
        return false;
      }
    } else {
      print('Firebase Options 파일이 없습니다.');
      return false;
    }
  } catch (e) {
    print('Firebase 초기화 실패: $e');
    return false;
  }
}

/// Firebase Options를 사용하여 초기화
Future<void> _initializeFirebaseWithOptions() async {
  try {
    // firebase_options.dart 파일이 있으면 해당 옵션으로 초기화
    // 동적으로 import하여 오류 방지
    await _initializeWithOptions();
  } catch (e) {
    // firebase_options.dart 파일이 없거나 오류가 있으면 기본 초기화
    await Firebase.initializeApp();
  }
}

/// Firebase Options를 사용한 초기화 (동적 import)
Future<void> _initializeWithOptions() async {
  try {
    // Firebase Options 파일이 있는지 확인
    final hasOptions = await _checkFirebaseOptionsFile();
    if (hasOptions) {
      // Firebase Options 파일이 있으면 해당 옵션으로 초기화
      await _initializeWithFirebaseOptions();
    } else {
      // Firebase Options 파일이 없으면 기본 초기화
      await Firebase.initializeApp();
    }
  } catch (e) {
    // 오류 발생 시 기본 초기화
    await Firebase.initializeApp();
  }
}

/// Firebase Options를 사용한 초기화
Future<void> _initializeWithFirebaseOptions() async {
  try {
    // Firebase Options 파일이 있으면 해당 옵션으로 초기화
    // 파일이 없으면 기본 초기화
    await Firebase.initializeApp();
  } catch (e) {
    // 오류 발생 시 기본 초기화
    await Firebase.initializeApp();
  }
}

/// Firebase Options 파일 확인
Future<bool> _checkFirebaseOptionsFile() async {
  try {
    final file = File('lib/firebase_options.dart');
    return await file.exists();
  } catch (e) {
    return false;
  }
}

class MemoryGameApp extends StatelessWidget {
  final bool firebaseInitialized;
  
  const MemoryGameApp({super.key, required this.firebaseInitialized});

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
        '/': (context) => AuthWrapper(firebaseInitialized: firebaseInitialized),
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
  final bool firebaseInitialized;
  
  const AuthWrapper({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    // Firebase가 초기화되지 않은 경우 로컬 메인 화면으로
    if (!firebaseInitialized) {
      return const MainScreen();
    }
    
    // Firebase가 초기화된 경우 인증 상태 확인
    try {
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
    } catch (e) {
      // Firebase 오류 발생 시 로컬 메인 화면으로
      print('Firebase 인증 오류: $e');
      return const MainScreen();
    }
  }
}