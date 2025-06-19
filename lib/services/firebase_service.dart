import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';

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
      print('Firebase 초기화 시도...');

      // Firebase가 사용 가능한지 확인 (파일 시스템 검사 대신 직접 접근 시도)
      _isFirebaseAvailable = await _checkFirebaseAvailability();

      if (!_isFirebaseAvailable) {
        print('Firebase 설정이 완료되지 않았습니다.');
        print('로컬 모드로 실행됩니다. 온라인 기능을 사용하려면 Firebase 설정을 완료해주세요.');
        _isInitialized = true; // 초기화는 성공으로 처리하되 Firebase는 사용하지 않음
        return;
      }

      // Firebase 인스턴스 생성 (이미 확인 단계에서 접근했으므로 성공할 가능성이 높음)
      try {
        _auth = FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
        
        // 현재 사용자 상태 확인
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          print('기존 로그인된 사용자 발견: ${currentUser.email}');
        }
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

  /// Firebase 사용 가능 여부 확인 (파일 검사 대신 인스턴스 접근으로 확인)
  Future<bool> _checkFirebaseAvailability() async {
    try {
      print('=== Firebase 설정 상태 확인 ===');

      // Firebase가 실제로 초기화되었는지 확인
      bool isFirebaseInitialized = false;
      try {
        // Firebase Auth 인스턴스에 접근 시도
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;
        isFirebaseInitialized = true;
        print('Firebase 인스턴스 접근 성공');
      } catch (e) {
        print('Firebase 인스턴스 접근 실패: $e');
        isFirebaseInitialized = false;

        // 오류 메시지로 설정 문제 추정
        if (e.toString().contains('options') || e.toString().contains('Firebase App')) {
          print('누락된 설정: lib/firebase_options.dart 파일이 누락되었거나 올바르지 않습니다.');
          print('해결 방법: flutterfire configure 명령어를 실행하세요.');
        }

        if (e.toString().contains('google-services.json') || e.toString().contains('configuration')) {
          print('누락된 설정: android/app/google-services.json 파일이 누락되었거나 올바르지 않습니다.');
          print('해결 방법: Firebase Console에서 Android 앱을 등록하고 설정 파일을 다운로드하세요.');
        }
      }

      print('Firebase 설정 완료 상태: ${isFirebaseInitialized ? '완료' : '미완료'}');
      print('Firebase 초기화 상태: ${isFirebaseInitialized ? '성공' : '실패'}');
      print('=== Firebase 설정 상태 확인 완료 ===');

      return isFirebaseInitialized;
    } catch (e) {
      print('Firebase 설정 확인 중 오류: $e');
      return false;
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
    print('FirebaseService: 로그인 시작');
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _auth == null || _firestore == null) {
      print('FirebaseService: Firebase 사용 불가');
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }

    try {
      print('FirebaseService: Firebase Auth 로그인 시도');
      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('FirebaseService: Firebase Auth 로그인 성공');

      // 로그인 성공 후 추가 정보 처리는 완전히 선택적으로 수행
      // 어떤 오류가 발생하더라도 로그인 자체는 성공으로 처리
      print('FirebaseService: 사용자 정보 처리 시작');
      _processUserDataAfterLogin(userCredential, email);

      print('FirebaseService: 로그인 완료 - UserCredential 반환');
      return userCredential;
    } catch (e) {
      print('FirebaseService: 로그인 중 예외 발생: $e');
      throw _handleAuthError(e);
    }
  }

  /// 로그인 후 사용자 정보 처리 (선택적)
  void _processUserDataAfterLogin(UserCredential userCredential, String email) {
    // 비동기로 처리하되 결과를 기다리지 않음
    Future.microtask(() async {
      try {
        // 사용자 정보 가져오기
        final userData = await getUserData(userCredential.user!.uid);
        if (userData != null && userData['playerName'] != null) {
          print('기존 플레이어 이름 발견: ${userData['playerName']}');
        } else {
          // 사용자 문서가 없으면 기본 정보로 생성
          await _firestore!.collection('users').doc(userCredential.user!.uid).set({
            'email': email,
            'playerName': userCredential.user!.displayName ?? '플레이어',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          print('새로운 사용자 문서 생성: ${userCredential.user!.uid}');
        }

        // 마지막 로그인 시간 업데이트
        await _firestore!.collection('users').doc(userCredential.user!.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // 추가 정보 처리 실패는 로그인 실패로 처리하지 않음
        print('사용자 정보 처리 중 오류 (로그인은 성공): $e');
      }
    });
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
      if (doc.exists) {
        final data = doc.data()!;
        print('사용자 정보 로드 성공: ${data['playerName']}');
        return data;
      } else {
        print('사용자 문서가 존재하지 않습니다: $uid');
        return null;
      }
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      return null;
    }
  }

  /// 플레이어 이름 업데이트
  Future<void> updatePlayerName(String uid, String playerName) async {
    await _initialize();
    if (!_isInitialized || !_isFirebaseAvailable || _firestore == null) {
      throw Exception('Firebase가 사용할 수 없습니다. 로컬 모드로 실행 중입니다.');
    }

    try {
      print('플레이어 이름 업데이트 시작: $uid -> $playerName');
      
      // 사용자 문서가 존재하는지 확인
      final userDoc = await _firestore!.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        // 기존 문서 업데이트
        await _firestore!.collection('users').doc(uid).update({
          'playerName': playerName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('기존 사용자 문서 업데이트 완료');
      } else {
        // 새 문서 생성
        await _firestore!.collection('users').doc(uid).set({
          'playerName': playerName,
          'email': _auth?.currentUser?.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('새 사용자 문서 생성 완료');
      }
      
      print('플레이어 이름 업데이트 완료: $playerName');
    } catch (e) {
      print('플레이어 이름 업데이트 오류: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception('권한이 없습니다. Firestore 보안 규칙을 확인해주세요.');
      } else if (e.toString().contains('unavailable')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('플레이어 이름 업데이트에 실패했습니다: ${e.toString().replaceAll('Exception: ', '')}');
      }
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
    print('FirebaseService: _handleAuthError 호출됨 - 오류 타입: ${error.runtimeType}');
    print('FirebaseService: 오류 내용: $error');
    
    // App Check 관련 오류는 무시 (개발 환경에서 정상적인 경고)
    if (error.toString().contains('No AppCheckProvider installed')) {
      print('App Check 경고 무시 (개발 환경에서 정상)');
      return ''; // 빈 문자열 반환하여 오류 메시지 표시하지 않음
    }
    
    if (error is FirebaseAuthException) {
      print('FirebaseService: FirebaseAuthException 처리');
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
    } else if (error is FirebaseException) {
      print('FirebaseService: FirebaseException 처리');
      // FirebaseException 처리
      if (error.message?.contains('permission-denied') == true) {
        return '권한이 없습니다. Firestore 보안 규칙을 확인해주세요.';
      } else if (error.message?.contains('unavailable') == true) {
        return '네트워크 연결을 확인해주세요.';
      } else {
        return 'Firebase 오류가 발생했습니다: ${error.message}';
      }
    }
    
    print('FirebaseService: 알 수 없는 오류 처리');
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