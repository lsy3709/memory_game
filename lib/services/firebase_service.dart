import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import '../models/game_record.dart';
import '../models/player_stats.dart';
import '../models/multiplayer_game_record.dart';

/// Firebase 서비스 클래스
/// 인증, Firestore 데이터베이스 작업을 담당
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;

  /// Firebase 초기화 확인
  bool get isInitialized => _isInitialized;

  /// Firebase 사용 가능 여부
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  /// Firebase 초기화
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // 디버깅을 위한 파일 시스템 확인
      await debugCheckFiles();

      // 직접 파일 확인
      await manualCheckFiles();

      // Firebase가 사용 가능한지 확인
      _isFirebaseAvailable = await _checkFirebaseAvailability();

      if (!_isFirebaseAvailable) {
        print('Firebase 설정이 완료되지 않았습니다.');
        print('로컬 모드로 실행됩니다. 온라인 기능을 사용하려면 Firebase 설정을 완료해주세요.');
        _isInitialized = true; // 초기화는 성공으로 처리하되 Firebase는 사용하지 않음
        return;
      }

      // Firebase 인스턴스 생성
      try {
        _auth = FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        print('Firebase 인스턴스 생성 실패: $e');
        _isFirebaseAvailable = false;
        _isInitialized = true; // 초기화는 성공으로 처리하되 Firebase는 사용하지 않음
        return;
      }

      // Firebase 연결 테스트 (선택적)
      try {
        await _firestore!.collection('connection_test').doc('test').get();
        print('Firebase 연결 테스트 성공');
      } catch (e) {
        print('Firebase 연결 테스트 실패: $e');
        // 연결 테스트 실패해도 초기화는 성공으로 처리
      }

      _isInitialized = true;
      print('Firebase 서비스 초기화 성공 - 온라인 기능 사용 가능');
    } catch (e) {
      print('Firebase 서비스 초기화 중 오류 발생: $e');
      _isInitialized = true; // 초기화는 성공으로 처리하되 Firebase는 사용하지 않음
      _isFirebaseAvailable = false;
      _auth = null;
      _firestore = null;
    }
  }

  /// 디버깅을 위한 파일 시스템 확인
  Future<void> debugCheckFiles() async {
    final currentDir = Directory.current.absolute.path;
    print('디버그: 현재 작업 디렉토리 (절대 경로): $currentDir');

    // 파일 시스템 목록 확인
    try {
      print('디버그: 현재 디렉토리 파일 목록:');
      final entities = Directory(currentDir).listSync();
      for (var entity in entities) {
        print('  - ${entity.path}');
      }
    } catch (e) {
      print('디버그: 디렉토리 목록 확인 중 오류: $e');
    }

    // lib 디렉토리 확인
    try {
      final libPath = '$currentDir${Platform.pathSeparator}lib';
      if (await Directory(libPath).exists()) {
        print('디버그: lib 디렉토리 파일 목록:');
        final entities = Directory(libPath).listSync();
        for (var entity in entities) {
          print('  - ${entity.path}');
        }
      } else {
        print('디버그: lib 디렉토리가 존재하지 않습니다.');
      }
    } catch (e) {
      print('디버그: lib 디렉토리 확인 중 오류: $e');
    }

    // android/app 디렉토리 확인
    try {
      final androidPath = '$currentDir${Platform.pathSeparator}android${Platform.pathSeparator}app';
      if (await Directory(androidPath).exists()) {
        print('디버그: android/app 디렉토리 파일 목록:');
        final entities = Directory(androidPath).listSync();
        for (var entity in entities) {
          print('  - ${entity.path}');
        }
      } else {
        print('디버그: android/app 디렉토리가 존재하지 않습니다.');
      }
    } catch (e) {
      print('디버그: android/app 디렉토리 확인 중 오류: $e');
    }
  }

  /// 직접 파일 확인
  Future<void> manualCheckFiles() async {
    print('수동 파일 확인 시작...');

    // Firebase Options 파일 확인
    final optionsPath = 'lib/firebase_options.dart';
    final optionsFile = File(optionsPath);
    print('Firebase Options 파일 존재: ${await optionsFile.exists()}');
    if (await optionsFile.exists()) {
      print('Firebase Options 파일 내용 미리보기:');
      final content = await optionsFile.readAsString();
      print(content.substring(0, content.length > 200 ? 200 : content.length));
    }

    // Android 설정 파일 확인
    final androidPath = 'android/app/google-services.json';
    final androidFile = File(androidPath);
    print('Android 설정 파일 존재: ${await androidFile.exists()}');
    if (await androidFile.exists()) {
      print('Android 설정 파일 내용 미리보기:');
      final content = await androidFile.readAsString();
      print(content.substring(0, content.length > 200 ? 200 : content.length));
    }

    print('수동 파일 확인 완료');
  }

  /// Firebase 사용 가능 여부 확인
  Future<bool> _checkFirebaseAvailability() async {
    try {
      // Firebase 설정 파일 존재 여부 확인
      final hasFirebaseOptions = await _checkFirebaseOptionsFile();
      final hasAndroidConfig = await _checkAndroidConfig();
      final hasIOSConfig = await _checkIOSConfig();

      print('=== Firebase 설정 상태 확인 ===');
      print('Firebase Options 파일: ${hasFirebaseOptions ? '있음' : '없음'}');
      print('Android 설정 파일: ${hasAndroidConfig ? '있음' : '없음'}');
      print('iOS 설정 파일: ${hasIOSConfig ? '있음' : '없음'}');

      if (!hasFirebaseOptions) {
        print('누락된 설정: lib/firebase_options.dart 파일이 없습니다.');
        print('해결 방법: flutterfire configure 명령어를 실행하세요.');
      }

      if (!hasAndroidConfig) {
        print('누락된 설정: android/app/google-services.json 파일이 없습니다.');
        print('해결 방법: Firebase Console에서 Android 앱을 등록하고 설정 파일을 다운로드하세요.');
      }

      if (!hasIOSConfig) {
        print('누락된 설정: ios/Runner/GoogleService-Info.plist 파일이 없습니다.');
        print('해결 방법: Firebase Console에서 iOS 앱을 등록하고 설정 파일을 다운로드하세요.');
      }

      // Firebase가 실제로 초기화되었는지 확인
      bool isFirebaseInitialized = false;
      try {
        // Firebase Auth 인스턴스에 접근 시도
        final auth = FirebaseAuth.instance;
        isFirebaseInitialized = true;
      } catch (e) {
        print('Firebase 인스턴스 접근 실패: $e');
        isFirebaseInitialized = false;
      }

      // 모든 설정이 완료되었는지 확인
      final isComplete = hasFirebaseOptions && hasAndroidConfig && isFirebaseInitialized;
      print('Firebase 설정 완료 상태: ${isComplete ? '완료' : '미완료'}');
      print('Firebase 초기화 상태: ${isFirebaseInitialized ? '성공' : '실패'}');
      print('=== Firebase 설정 상태 확인 완료 ===');

      return isComplete;
    } catch (e) {
      print('Firebase 설정 확인 중 오류: $e');
      return false;
    }
  }

  /// Firebase Options 파일 확인
  Future<bool> _checkFirebaseOptionsFile() async {
    try {
      // 현재 작업 디렉토리 확인
      final currentDir = Directory.current.absolute.path;
      print('현재 작업 디렉토리 (절대 경로): $currentDir');

      // 프로젝트의 최상위 디렉토리를 찾기
      String projectRootDir = currentDir;
      if (currentDir.contains('android') || currentDir.contains('ios')) {
        // android/ios 디렉토리에 있는 경우 상위 디렉토리로 이동
        projectRootDir = Directory(currentDir).parent.path;
      }

      // 여러 가능한 경로 확인 (절대 경로 사용)
      final paths = [
        '$projectRootDir${Platform.pathSeparator}lib${Platform.pathSeparator}firebase_options.dart',
        '$currentDir${Platform.pathSeparator}lib${Platform.pathSeparator}firebase_options.dart',
        '$currentDir${Platform.pathSeparator}firebase_options.dart',
        'lib/firebase_options.dart',  // 상대 경로도 시도
        './lib/firebase_options.dart',
      ];

      print('확인할 Firebase Options 경로:');
      paths.forEach((path) => print('  - $path'));

      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          print('Firebase Options 파일 발견: $path');
          return true;
        }
      }

      print('Firebase Options 파일을 찾을 수 없습니다.');
      return false;
    } catch (e) {
      print('Firebase Options 파일 확인 중 오류: $e');
      return false;
    }
  }

  /// Android 설정 파일 확인
  Future<bool> _checkAndroidConfig() async {
    try {
      // 현재 작업 디렉토리 확인
      final currentDir = Directory.current.absolute.path;

      // 프로젝트의 최상위 디렉토리를 찾기
      String projectRootDir = currentDir;
      if (currentDir.contains('android') || currentDir.contains('ios')) {
        projectRootDir = Directory(currentDir).parent.path;
      }

      // 여러 가능한 경로 확인 (절대 경로 사용)
      final paths = [
        '$projectRootDir${Platform.pathSeparator}android${Platform.pathSeparator}app${Platform.pathSeparator}google-services.json',
        '$currentDir${Platform.pathSeparator}android${Platform.pathSeparator}app${Platform.pathSeparator}google-services.json',
        '$currentDir${Platform.pathSeparator}google-services.json',
        'android/app/google-services.json',  // 상대 경로도 시도
        './android/app/google-services.json',
      ];

      print('확인할 Android 설정 파일 경로:');
      paths.forEach((path) => print('  - $path'));

      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          print('Android 설정 파일 발견: $path');
          return true;
        }
      }

      print('Android 설정 파일을 찾을 수 없습니다.');
      return false;
    } catch (e) {
      print('Android 설정 파일 확인 중 오류: $e');
      return false;
    }
  }

  /// iOS 설정 파일 확인
  Future<bool> _checkIOSConfig() async {
    try {
      // iOS 설정은 선택사항으로 처리
      return true;
    } catch (e) {
      print('iOS 설정 파일 확인 중 오류: $e');
      return true; // iOS 설정은 필수가 아니므로 true 반환
    }
  }

  /// Firebase 초기화 상태 확인 및 재시도
  Future<bool> ensureInitialized() async {
    if (_isInitialized) return _isFirebaseAvailable;

    try {
      await _initialize();
      return _isFirebaseAvailable;
    } catch (e) {
      print('Firebase 초기화 재시도 실패: $e');
      return false;
    }
  }

  /// 현재 로그인된 사용자
  User? get currentUser {
    if (!_isInitialized || !_isFirebaseAvailable) return null;
    return _auth?.currentUser;
  }

  /// 로그인 상태 변경 스트림
  Stream<User?> get authStateChanges {
    if (!_isInitialized || !_isFirebaseAvailable) return Stream.value(null);
    return _auth?.authStateChanges() ?? Stream.value(null);
  }

  /// 이메일/비밀번호로 회원가입
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String playerName,
  }) async {
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _auth == null || _firestore == null) {
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }

    try {
      // 회원가입
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 사용자 프로필 업데이트
      await userCredential.user?.updateDisplayName(playerName);

      // Firestore에 사용자 정보 저장
      await _firestore!.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'playerName': playerName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _auth == null || _firestore == null) {
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }

    try {
      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 마지막 로그인 시간 업데이트
      await _firestore!.collection('users').doc(userCredential.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _auth == null) {
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }
    await _auth!.signOut();
  }

  /// 비밀번호 재설정 이메일 발송
  Future<void> sendPasswordResetEmail(String email) async {
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _auth == null) {
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }

    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return null;
    }

    try {
      final doc = await _firestore!.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      return null;
    }
  }

  /// 온라인 게임 기록 저장
  Future<void> saveOnlineGameRecord(GameRecord record) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      await _firestore!.collection('online_game_records').add({
        'userId': currentUser!.uid,
        'playerName': record.playerName,
        'email': record.email,
        'score': record.score,
        'matchCount': record.matchCount,
        'failCount': record.failCount,
        'maxCombo': record.maxCombo,
        'timeLeft': record.timeLeft,
        'totalTime': record.totalTime,
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': record.isCompleted,
      });
    } catch (e) {
      print('온라인 게임 기록 저장 오류: $e');
      throw Exception('게임 기록 저장에 실패했습니다.');
    }
  }

  /// 온라인 멀티플레이어 게임 기록 저장
  Future<void> saveOnlineMultiplayerGameRecord(MultiplayerGameRecord record) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      await _firestore!.collection('online_multiplayer_records').add({
        'userId': currentUser!.uid,
        'gameTitle': record.gameTitle,
        'players': record.players.map((player) => player.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': record.isCompleted,
        'totalTime': record.totalTime,
        'timeLeft': record.timeLeft,
      });
    } catch (e) {
      print('온라인 멀티플레이어 게임 기록 저장 오류: $e');
      throw Exception('멀티플레이어 게임 기록 저장에 실패했습니다.');
    }
  }

  /// 온라인 플레이어 통계 저장
  Future<void> saveOnlinePlayerStats(PlayerStats stats) async {
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _firestore == null) {
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      await _firestore!.collection('online_player_stats').doc(currentUser!.uid).set({
        'userId': currentUser!.uid,
        'playerName': stats.playerName,
        'email': stats.email,
        'totalGames': stats.totalGames,
        'totalWins': stats.totalWins,
        'bestScore': stats.bestScore,
        'bestTime': stats.bestTime,
        'maxCombo': stats.maxCombo,
        'totalMatchCount': stats.totalMatchCount,
        'totalFailCount': stats.totalFailCount,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('온라인 플레이어 통계 저장 오류: $e');
      throw Exception('플레이어 통계 저장에 실패했습니다.');
    }
  }

  /// 온라인 플레이어 통계 가져오기
  Future<PlayerStats?> getOnlinePlayerStats() async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return null;
    }

    if (currentUser == null) {
      return null;
    }

    try {
      final doc = await _firestore!.collection('online_player_stats').doc(currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return PlayerStats(
          id: currentUser!.uid,
          playerName: data['playerName'] ?? '',
          email: data['email'] ?? '',
          totalGames: data['totalGames'] ?? 0,
          totalWins: data['totalWins'] ?? 0,
          bestScore: data['bestScore'] ?? 0,
          bestTime: data['bestTime'] ?? 0,
          maxCombo: data['maxCombo'] ?? 0,
          totalMatches: data['totalMatchCount'] ?? 0,
          totalFails: data['totalFailCount'] ?? 0,
          totalMatchCount: data['totalMatchCount'] ?? 0,
          totalFailCount: data['totalFailCount'] ?? 0,
          lastPlayed: (data['lastUpdatedAt'] as Timestamp).toDate(),
          createdAt: (data['lastUpdatedAt'] as Timestamp).toDate(),
        );
      }
      return null;
    } catch (e) {
      print('온라인 플레이어 통계 가져오기 오류: $e');
      return null;
    }
  }

  /// 온라인 랭킹 가져오기 (싱글플레이어)
  Future<List<GameRecord>> getOnlineRankings({
    int limit = 50,
    String orderBy = 'score',
    bool descending = true,
  }) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return [];
    }

    try {
      Query query = _firestore!.collection('online_game_records')
          .where('isCompleted', isEqualTo: true);

      switch (orderBy) {
        case 'score':
          query = query.orderBy('score', descending: descending);
          break;
        case 'timeLeft':
          query = query.orderBy('timeLeft', descending: descending);
          break;
        case 'maxCombo':
          query = query.orderBy('maxCombo', descending: descending);
          break;
        case 'createdAt':
          query = query.orderBy('createdAt', descending: descending);
          break;
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return GameRecord(
          id: doc.id,
          playerName: data['playerName'] ?? '',
          email: data['email'] ?? '',
          score: data['score'] ?? 0,
          matchCount: data['matchCount'] ?? 0,
          failCount: data['failCount'] ?? 0,
          maxCombo: data['maxCombo'] ?? 0,
          timeLeft: data['timeLeft'] ?? 0,
          totalTime: data['totalTime'] ?? 0,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          isCompleted: data['isCompleted'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('온라인 랭킹 가져오기 오류: $e');
      return [];
    }
  }

  /// 온라인 멀티플레이어 랭킹 가져오기
  Future<List<MultiplayerGameRecord>> getOnlineMultiplayerRankings({
    int limit = 50,
  }) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return [];
    }

    try {
      final snapshot = await _firestore!.collection('online_multiplayer_records')
          .where('isCompleted', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MultiplayerGameRecord(
          id: doc.id,
          gameTitle: data['gameTitle'] ?? '',
          players: (data['players'] as List)
              .map((playerData) => PlayerGameResult.fromJson(playerData))
              .toList(),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          isCompleted: data['isCompleted'] ?? false,
          totalTime: data['totalTime'] ?? 0,
          timeLeft: data['timeLeft'] ?? 0,
        );
      }).toList();
    } catch (e) {
      print('온라인 멀티플레이어 랭킹 가져오기 오류: $e');
      return [];
    }
  }

  /// 사용자의 온라인 게임 기록 가져오기
  Future<List<GameRecord>> getUserOnlineGameRecords() async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return [];
    }

    if (currentUser == null) {
      return [];
    }

    try {
      final snapshot = await _firestore!.collection('online_game_records')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GameRecord(
          id: doc.id,
          playerName: data['playerName'] ?? '',
          email: data['email'] ?? '',
          score: data['score'] ?? 0,
          matchCount: data['matchCount'] ?? 0,
          failCount: data['failCount'] ?? 0,
          maxCombo: data['maxCombo'] ?? 0,
          timeLeft: data['timeLeft'] ?? 0,
          totalTime: data['totalTime'] ?? 0,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          isCompleted: data['isCompleted'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('사용자 온라인 게임 기록 가져오기 오류: $e');
      return [];
    }
  }

  /// 비밀번호 해시화
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Firebase 인증 오류 처리
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return '비밀번호가 너무 약합니다.';
        case 'email-already-in-use':
          return '이미 사용 중인 이메일입니다.';
        case 'user-not-found':
          return '등록되지 않은 이메일입니다.';
        case 'wrong-password':
          return '비밀번호가 올바르지 않습니다.';
        case 'invalid-email':
          return '올바르지 않은 이메일 형식입니다.';
        case 'too-many-requests':
          return '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
        default:
          return '인증 오류가 발생했습니다: ${error.message}';
      }
    }
    return '알 수 없는 오류가 발생했습니다.';
  }

  /// 네트워크 연결 상태 확인
  Future<bool> checkNetworkConnection() async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return false;
    }

    try {
      await _firestore!.collection('connection_test').doc('test').get();
      return true;
    } catch (e) {
      return false;
    }
  }
}