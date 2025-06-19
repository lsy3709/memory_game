import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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

  /// Firebase 초기화 확인
  bool get isInitialized => _isInitialized;

  /// Firebase 초기화
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Firebase가 초기화되었는지 확인
      try {
        _auth = FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        print('Firebase 인스턴스 생성 실패: $e');
        throw Exception('Firebase가 설정되지 않았습니다. firebase_options.dart 파일을 확인해주세요.');
      }
      
      // Firebase 연결 테스트 (선택적)
      try {
        await _firestore!.collection('connection_test').doc('test').get();
      } catch (e) {
        print('Firebase 연결 테스트 실패: $e');
        // 연결 테스트 실패해도 초기화는 성공으로 처리
      }
      
      _isInitialized = true;
      print('Firebase 서비스 초기화 성공');
    } catch (e) {
      print('Firebase 서비스 초기화 실패: $e');
      _isInitialized = false;
      _auth = null;
      _firestore = null;
      
      // Firebase 초기화 실패 시 상세한 오류 정보 제공
      if (e.toString().contains('firebase_core') || e.toString().contains('no-app')) {
        throw Exception('Firebase가 설정되지 않았습니다. firebase_options.dart 파일을 확인해주세요.');
      } else if (e.toString().contains('network')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else if (e.toString().contains('permission')) {
        throw Exception('Firebase 권한 설정을 확인해주세요.');
      } else {
        throw Exception('Firebase 초기화에 실패했습니다: $e');
      }
    }
  }

  /// Firebase 초기화 상태 확인 및 재시도
  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;
    
    try {
      await _initialize();
      return _isInitialized;
    } catch (e) {
      print('Firebase 초기화 재시도 실패: $e');
      return false;
    }
  }

  /// 현재 로그인된 사용자
  User? get currentUser {
    if (!_isInitialized) return null;
    return _auth?.currentUser;
  }

  /// 로그인 상태 변경 스트림
  Stream<User?> get authStateChanges {
    if (!_isInitialized) return Stream.value(null);
    return _auth?.authStateChanges() ?? Stream.value(null);
  }

  /// 이메일/비밀번호로 회원가입
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String playerName,
  }) async {
    await _initialize();
    if (!_isInitialized || _auth == null || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
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
    if (!_isInitialized || _auth == null || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
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
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }
    await _auth!.signOut();
  }

  /// 비밀번호 재설정 이메일 발송
  Future<void> sendPasswordResetEmail(String email) async {
    await _initialize();
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
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
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
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