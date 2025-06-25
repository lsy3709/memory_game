import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/game_record.dart';
import '../models/multiplayer_game_record.dart';
import '../models/player_stats.dart';
import '../models/online_room.dart';
import '../models/friend.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';

/// Firebase 서비스를 관리하는 클래스
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  bool _isInitialized = false;
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  User? _currentUser;
  
  // 스레드 안전성을 위한 뮤텍스
  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitializing = false;

  /// Firebase 초기화 (스레드 안전)
  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;
    
    // 이미 초기화 중인 경우 대기
    if (_isInitializing) {
      await _initCompleter.future;
      return _isInitialized;
    }
    
    _isInitializing = true;

    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _currentUser = _auth!.currentUser;
      _isInitialized = true;
      
      print('Firebase 초기화 성공');
      _initCompleter.complete();
      return true;
    } catch (e) {
      print('Firebase 초기화 실패: $e');
      _initCompleter.completeError(e);
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Firebase 초기화 상태 확인
  Future<bool> _initialize() async {
    if (!_isInitialized) {
      return await ensureInitialized();
    }
    return true;
  }

  /// 현재 사용자 가져오기
  User? get currentUser => _currentUser;

  /// Firebase 사용 가능 여부
  bool get isFirebaseAvailable => _isInitialized;

  /// 에러 로깅 및 사용자 친화적 메시지 생성
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('permission-denied')) {
      return '권한이 없습니다. 다시 로그인해주세요.';
    } else if (errorString.contains('unavailable') || errorString.contains('network')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (errorString.contains('not-found')) {
      return '요청한 데이터를 찾을 수 없습니다.';
    } else if (errorString.contains('already-exists')) {
      return '이미 존재하는 데이터입니다.';
    } else if (errorString.contains('invalid-argument')) {
      return '잘못된 입력값입니다.';
    } else if (errorString.contains('failed-precondition')) {
      return 'Firebase 인덱스 설정이 필요합니다.';
    } else if (errorString.contains('resource-exhausted')) {
      return '서버 리소스가 부족합니다. 잠시 후 다시 시도해주세요.';
    } else if (errorString.contains('deadline-exceeded')) {
      return '요청 시간이 초과되었습니다.';
    } else {
      return '오류가 발생했습니다: ${error.toString().replaceAll('Exception: ', '')}';
    }
  }

  /// 안전한 Firebase 작업 실행
  Future<T> _safeFirebaseOperation<T>(Future<T> Function() operation, String operationName) async {
    try {
      await _initialize();
      if (!_isInitialized || _firestore == null) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }
      
      return await operation();
    } catch (e) {
      print('$operationName 오류: $e');
      final userMessage = _getUserFriendlyErrorMessage(e);
      throw Exception(userMessage);
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _initialize();
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      // 로그인 시도 (이메일을 소문자로 변환하여 일관성 유지)
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.toLowerCase(),
        password: password,
      );
      
      // 사용자 정보 업데이트 (안전하게 처리)
      try {
        _currentUser = credential.user;
        
        // 로그인 성공 후 사용자 데이터 확인 및 생성
        if (_currentUser != null) {
          await _ensureUserDataExists(_currentUser!);
        }
      } catch (e) {
        print('사용자 정보 처리 오류 (무시됨): $e');
        // 사용자 정보 처리 오류가 발생해도 로그인은 성공으로 처리
      }
      
      return credential;
    } catch (e) {
      print('로그인 오류: $e');
      
      // PigeonUserDetails 오류인 경우 특별 처리
      if (e.toString().contains('PigeonUserDetails') || 
          e.toString().contains('List<Object?>')) {
        print('Firebase Auth 내부 오류 감지 - 로그인은 성공했을 가능성이 높음');
        
        // 현재 사용자 상태 확인
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          print('사용자가 실제로 로그인되어 있음: ${currentUser.email}');
          _currentUser = currentUser;
          
          // 사용자 데이터 확인 및 생성
          try {
            await _ensureUserDataExists(currentUser);
          } catch (e) {
            print('사용자 데이터 생성 오류 (무시됨): $e');
          }
          
          // 성공적인 로그인으로 처리 (오류를 던지지 않음)
          print('PigeonUserDetails 오류 무시하고 로그인 성공으로 처리');
          // 원래 예외를 다시 던지되, 로그인은 실제로 성공했음을 표시
          throw Exception('Firebase Auth 내부 오류 (로그인은 성공)');
        }
      }
      
      rethrow;
    }
  }

  /// 사용자 데이터가 존재하는지 확인하고 없으면 생성
  Future<void> _ensureUserDataExists(User user) async {
    if (!_isInitialized || _firestore == null) return;

    try {
      final userDoc = await _firestore!.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // 사용자 데이터가 없으면 기본 데이터 생성
        await _firestore!.collection('users').doc(user.uid).set({
          'playerName': user.displayName ?? '플레이어',
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('새로운 사용자 데이터 생성: ${user.uid}');
      } else {
        // 마지막 로그인 시간 업데이트
        await _firestore!.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('기존 사용자 데이터 확인: ${user.uid}');
      }
    } catch (e) {
      print('사용자 데이터 확인/생성 오류: $e');
      // 오류가 발생해도 로그인은 성공으로 처리
    }
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
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 사용자 프로필 업데이트
      await credential.user!.updateDisplayName(playerName);

      // Firestore에 사용자 데이터 저장
      await _firestore!.collection('users').doc(credential.user!.uid).set({
        'playerName': playerName,
        'email': email.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _currentUser = credential.user;
      
      // 회원가입 완료 후 로그인 상태 유지 (자동 로그아웃 제거)
      print('회원가입 완료 - 사용자 로그인 상태 유지');
      
      return credential;
    } catch (e) {
      print('회원가입 오류: $e');
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _initialize();
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _auth!.signOut();
      _currentUser = null;
      print('로그아웃 성공');
    } catch (e) {
      print('로그아웃 오류: $e');
      rethrow;
    }
  }

  /// 비밀번호 재설정 이메일 발송
  Future<void> sendPasswordResetEmail(String email) async {
    await _initialize();
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _auth!.sendPasswordResetEmail(email: email);
      print('비밀번호 재설정 이메일 발송 성공');
    } catch (e) {
      print('비밀번호 재설정 이메일 발송 오류: $e');
      rethrow;
    }
  }

  /// 사용자 데이터 가져오기
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return null;
    }

    try {
      final doc = await _firestore!.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('사용자 데이터 가져오기 오류: $e');
      return null;
    }
  }

  /// 플레이어 이름 업데이트
  Future<void> updatePlayerName(String userId, String playerName) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('users').doc(userId).update({
        'playerName': playerName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('플레이어 이름 업데이트 완료: $playerName');
    } catch (e) {
      print('플레이어 이름 업데이트 오류: $e');
      throw Exception('플레이어 이름 업데이트에 실패했습니다: ${e.toString()}');
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
      // 먼저 users 컬렉션에서 기본 정보 가져오기
      Map<String, dynamic>? userData;
      try {
        final userDoc = await _firestore!.collection('users').doc(currentUser!.uid).get();
        if (userDoc.exists) {
          userData = userDoc.data()!;
        }
      } catch (e) {
        print('사용자 기본 정보 가져오기 오류: $e');
      }

      // online_player_stats 컬렉션에서 상세 통계 가져오기
      Map<String, dynamic>? statsData;
      try {
        final statsDoc = await _firestore!.collection('online_player_stats').doc(currentUser!.uid).get();
        if (statsDoc.exists) {
          statsData = statsDoc.data()!;
        }
      } catch (e) {
        print('온라인 플레이어 통계 가져오기 오류: $e');
      }

      // 기본값 설정
      final playerName = userData?['playerName'] ?? statsData?['playerName'] ?? '';
      final email = userData?['email'] ?? statsData?['email'] ?? '';
      final level = userData?['level'] ?? 1;
      final exp = userData?['exp'] ?? 0;
      
      // 통계 데이터가 있으면 사용, 없으면 기본값
      final totalGames = statsData?['totalGames'] ?? 0;
      final totalWins = statsData?['totalWins'] ?? 0;
      final bestScore = statsData?['bestScore'] ?? 0;
      final bestTime = statsData?['bestTime'] ?? 0;
      final maxCombo = statsData?['maxCombo'] ?? 0;
      final totalMatches = statsData?['totalMatchCount'] ?? 0;
      final totalFails = statsData?['totalFailCount'] ?? 0;
      final totalMatchCount = statsData?['totalMatchCount'] ?? 0;
      final totalFailCount = statsData?['totalFailCount'] ?? 0;

      // lastUpdatedAt 처리
      DateTime lastPlayed;
      DateTime createdAt;
      try {
        if (statsData?['lastUpdatedAt'] != null) {
          lastPlayed = (statsData!['lastUpdatedAt'] as Timestamp).toDate();
          createdAt = lastPlayed;
        } else if (userData?['lastUpdatedAt'] != null) {
          lastPlayed = (userData!['lastUpdatedAt'] as Timestamp).toDate();
          createdAt = lastPlayed;
        } else {
          lastPlayed = DateTime.now();
          createdAt = DateTime.now();
        }
      } catch (e) {
        print('날짜 처리 오류: $e');
        lastPlayed = DateTime.now();
        createdAt = DateTime.now();
      }

      return PlayerStats(
        id: currentUser!.uid,
        playerName: playerName,
        email: email,
        totalGames: totalGames,
        totalWins: totalWins,
        bestScore: bestScore,
        bestTime: bestTime,
        maxCombo: maxCombo,
        totalMatches: totalMatches,
        totalFails: totalFails,
        totalMatchCount: totalMatchCount,
        totalFailCount: totalFailCount,
        level: level,
        exp: exp,
        lastPlayed: lastPlayed,
        createdAt: createdAt,
      );
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

      // 서버 사이드 정렬 사용 (인덱스가 있는 경우)
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
      
      // 인덱스 오류인 경우 클라이언트 사이드 정렬로 대체
      if (e.toString().contains('failed-precondition') || e.toString().contains('requires an index')) {
        print('인덱스 오류 발생 - 클라이언트 사이드 정렬로 대체');
        
        try {
          // 단순한 쿼리로 데이터 가져오기
          final snapshot = await _firestore!.collection('online_game_records')
              .where('isCompleted', isEqualTo: true)
              .limit(limit * 2) // 더 많은 데이터를 가져와서 클라이언트에서 필터링
              .get();

          List<GameRecord> records = snapshot.docs.map((doc) {
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

          // 클라이언트에서 정렬
          switch (orderBy) {
            case 'score':
              records.sort((a, b) => descending ? b.score.compareTo(a.score) : a.score.compareTo(b.score));
              break;
            case 'timeLeft':
              records.sort((a, b) => descending ? b.timeLeft.compareTo(a.timeLeft) : a.timeLeft.compareTo(b.timeLeft));
              break;
            case 'maxCombo':
              records.sort((a, b) => descending ? b.maxCombo.compareTo(a.maxCombo) : a.maxCombo.compareTo(b.maxCombo));
              break;
            case 'createdAt':
              records.sort((a, b) => descending ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));
              break;
          }

          // limit만큼 반환
          return records.take(limit).toList();
        } catch (fallbackError) {
          print('클라이언트 사이드 정렬도 실패: $fallbackError');
          return [];
        }
      }
      
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
      // 서버 사이드 정렬 사용 (인덱스가 있는 경우)
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
      
      // 인덱스 오류인 경우 클라이언트 사이드 정렬로 대체
      if (e.toString().contains('failed-precondition') || e.toString().contains('requires an index')) {
        print('인덱스 오류 발생 - 클라이언트 사이드 정렬로 대체');
        
        try {
          // 단순한 쿼리로 데이터 가져오기
          final snapshot = await _firestore!.collection('online_multiplayer_records')
              .where('isCompleted', isEqualTo: true)
              .limit(limit * 2) // 더 많은 데이터를 가져와서 클라이언트에서 필터링
              .get();

          List<MultiplayerGameRecord> records = snapshot.docs.map((doc) {
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

          // 클라이언트에서 최신순으로 정렬
          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // limit만큼 반환
          return records.take(limit).toList();
        } catch (fallbackError) {
          print('클라이언트 사이드 정렬도 실패: $fallbackError');
          return [];
        }
      }
      
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
      // 서버 사이드 정렬 사용 (인덱스가 있는 경우)
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
      
      // 인덱스 오류인 경우 클라이언트 사이드 정렬로 대체
      if (e.toString().contains('failed-precondition') || e.toString().contains('requires an index')) {
        print('인덱스 오류 발생 - 클라이언트 사이드 정렬로 대체');
        
        try {
          // 단순한 쿼리로 데이터 가져오기
          final snapshot = await _firestore!.collection('online_game_records')
              .where('userId', isEqualTo: currentUser!.uid)
              .limit(100)
              .get();

          List<GameRecord> records = snapshot.docs.map((doc) {
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

          // 클라이언트에서 최신순으로 정렬
          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return records;
        } catch (fallbackError) {
          print('클라이언트 사이드 정렬도 실패: $fallbackError');
          return [];
        }
      }
      
      return [];
    }
  }

  // ==================== 온라인 멀티플레이어 방 관리 ====================

  /// 온라인 게임 방 생성
  Future<OnlineRoom> createOnlineRoom({
    required String roomName,
    bool isPrivate = false,
    String? password,
    String? inviteEmail,
  }) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final userData = await getUserData(currentUser!.uid);
      final playerName = userData?['playerName'] ?? currentUser!.displayName ?? '플레이어';
      final email = userData?['email'] ?? currentUser!.email ?? '';
      final playerLevel = userData?['level'] ?? 1;

      final roomId = _firestore!.collection('online_rooms').doc().id;
      
      // 초대할 친구 정보 가져오기 (guestId는 설정하지 않음)
      String? inviteEmail;
      
      if (inviteEmail != null && inviteEmail.isNotEmpty) {
        try {
          final friendQuery = await _firestore!.collection('users')
              .where('email', isEqualTo: inviteEmail)
              .limit(1)
              .get();

          if (friendQuery.docs.isNotEmpty) {
            final friendDoc = friendQuery.docs.first;
            final friendData = friendDoc.data();
            
            // 자기 자신을 초대할 수 없도록 체크
            if (friendDoc.id == currentUser!.uid) {
              throw Exception('자기 자신을 초대할 수 없습니다.');
            }
            
            // 초대 이메일만 저장
            inviteEmail = friendData['email'] ?? inviteEmail;
          }
        } catch (e) {
          print('친구 초대 정보 가져오기 오류: $e');
          // 친구 초대 실패해도 방 생성은 계속 진행
        }
      }

      final room = OnlineRoom(
        id: roomId,
        roomName: roomName,
        hostId: currentUser!.uid,
        hostName: playerName,
        hostEmail: email,
        hostLevel: playerLevel,
        // guestId는 설정하지 않음 (초대받은 친구가 참가할 때 설정)
        status: RoomStatus.waiting,
        createdAt: DateTime.now(),
        isPrivate: isPrivate,
        password: password,
      );

      await _firestore!.collection('online_rooms').doc(roomId).set(room.toJson());
      
      // 친구 초대 알림 전송 (초대받은 친구의 ID로)
      if (inviteEmail != null && inviteEmail.isNotEmpty) {
        try {
          // 초대받은 친구의 ID 찾기
          final friendQuery = await _firestore!.collection('users')
              .where('email', isEqualTo: inviteEmail)
              .limit(1)
              .get();

          if (friendQuery.docs.isNotEmpty) {
            final friendId = friendQuery.docs.first.id;
            await sendGameInvite(friendId, roomId);
          }
        } catch (e) {
          print('게임 초대 알림 전송 실패: $e');
          // 초대 알림 실패해도 방 생성은 성공으로 처리
        }
      }
      
      print('온라인 게임 방 생성 완료: $roomName (초대: ${inviteEmail ?? '없음'})');
      return room;
    } catch (e) {
      print('온라인 게임 방 생성 오류: $e');
      
      // 구체적인 오류 상황에 맞는 메시지 제공
      if (e.toString().contains('permission-denied')) {
        throw Exception('권한이 없습니다. 다시 로그인해주세요.');
      } else if (e.toString().contains('unavailable')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else if (e.toString().contains('already-exists')) {
        throw Exception('이미 사용 중인 방 이름입니다.');
      } else if (e.toString().contains('invalid-argument')) {
        throw Exception('방 이름이 올바르지 않습니다.');
      } else if (e.toString().contains('자기 자신을 초대할 수 없습니다')) {
        throw Exception('자기 자신을 초대할 수 없습니다.');
      } else {
        throw Exception('방 생성에 실패했습니다. 잠시 후 다시 시도해주세요.');
      }
    }
  }

  /// 온라인 게임 방 목록 가져오기 (Stream)
  Stream<List<OnlineRoom>> getOnlineRooms() {
    if (!_isInitialized || _firestore == null) {
      return Stream.value([]);
    }

    return _firestore!.collection('online_rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final rooms = snapshot.docs
              .map((doc) => OnlineRoom.fromJson(doc.data()))
              .toList();
          
          // 방 상태 변화 디버그 로그
          for (final room in rooms) {
            if (room.isFull) {
              print('방이 가득 찼습니다: ${room.roomName} (hostId: ${room.hostId}, guestId: ${room.guestId})');
            }
          }
          
          return rooms;
        });
  }

  /// 온라인 게임 방 목록 가져오기 (Future)
  Future<List<Map<String, dynamic>>> getOnlineRoomsList() async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      final snapshot = await _firestore!.collection('online_rooms')
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt', descending: true)
          .limit(50) // 최대 50개 방만 가져오기
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('온라인 방 목록 가져오기 오류: $e');
      throw Exception('온라인 방 목록을 가져오는데 실패했습니다.');
    }
  }

  /// 온라인 게임 방 참가
  Future<OnlineRoom> joinOnlineRoom(String roomId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final userData = await getUserData(currentUser!.uid);
      final playerName = userData?['playerName'] ?? currentUser!.displayName ?? '플레이어';
      final email = userData?['email'] ?? currentUser!.email ?? '';
      final playerLevel = userData?['level'] ?? 1;

      final roomRef = _firestore!.collection('online_rooms').doc(roomId);
      
      // 트랜잭션으로 방 참가 처리
      await _firestore!.runTransaction((transaction) async {
        final roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists) {
          throw Exception('방을 찾을 수 없습니다.');
        }

        final room = OnlineRoom.fromJson(roomDoc.data()!);
        if (!room.canJoin) {
          throw Exception('방에 참가할 수 없습니다.');
        }

        final updatedRoom = room.copyWith(
          guestId: currentUser!.uid,
          guestName: playerName,
          guestEmail: email,
          guestLevel: playerLevel,
        );

        transaction.update(roomRef, updatedRoom.toJson());
        return updatedRoom;
      });

      print('온라인 게임 방 참가 완료: $roomId');
      
      // 업데이트된 방 정보 반환
      final updatedDoc = await roomRef.get();
      return OnlineRoom.fromJson(updatedDoc.data()!);
    } catch (e) {
      print('온라인 게임 방 참가 오류: $e');
      throw Exception('방 참가에 실패했습니다: ${e.toString()}');
    }
  }

  /// 온라인 게임 방 나가기
  Future<void> leaveOnlineRoom(String roomId) async {
    if (!_isInitialized) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (_currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final roomRef = _firestore!.collection('online_rooms').doc(roomId);
      final roomDoc = await roomRef.get();

      if (!roomDoc.exists) {
        // 방이 이미 삭제된 경우 (다른 플레이어가 이미 나간 경우)
        print('방이 이미 삭제되었습니다: $roomId');
        return;
      }

      final roomData = roomDoc.data()!;
      
      // 안전한 타입 캐스팅 적용 (OnlineRoom.toJson()과 일치하는 필드명 사용)
      final hostId = roomData['hostId']?.toString();
      final guestId = roomData['guestId']?.toString();
      final currentPlayerId = _currentUser!.uid;

      // hostId가 null이면 오류 처리
      if (hostId == null) {
        throw Exception('방 데이터가 손상되었습니다. 방을 다시 생성해주세요.');
      }

      // 방장이 나가는 경우 - 방과 모든 데이터 삭제
      if (currentPlayerId == hostId) {
        print('방장이 나가므로 방과 모든 데이터 삭제');
        
        // 서브컬렉션들 삭제
        final subcollections = ['game_state', 'card_actions', 'turn_changes', 'card_matches'];
        for (final subcollection in subcollections) {
          try {
            final subcollectionRef = roomRef.collection(subcollection);
            final subcollectionDocs = await subcollectionRef.get();
            
            // 배치 작업으로 모든 문서 삭제
            if (subcollectionDocs.docs.isNotEmpty) {
              final batch = _firestore!.batch();
              for (final doc in subcollectionDocs.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              print('서브컬렉션 삭제 완료: $subcollection');
            }
          } catch (e) {
            print('서브컬렉션 삭제 중 오류 ($subcollection): $e');
          }
        }

        // 방 문서 삭제
        await roomRef.delete();
        print('방 문서 삭제 완료');
      } else {
        // 게스트가 나가는 경우 - guest_id만 null로 설정
        await roomRef.update({'guestId': null});
        print('게스트 나가기 완료');
      }

      print('온라인 게임 방 나가기 완료: $roomId');
    } catch (e) {
      print('방 나가기 오류: $e');
      rethrow;
    }
  }

  /// 온라인 게임 방 상태 업데이트
  Future<void> updateRoomStatus(String roomId, RoomStatus status) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId).update({
        'status': status.toString().split('.').last,
        if (status == RoomStatus.playing) 'gameStartedAt': FieldValue.serverTimestamp(),
      });
      print('방 상태 업데이트 완료: $roomId -> $status');
    } catch (e) {
      print('방 상태 업데이트 오류: $e');
      throw Exception('방 상태 업데이트에 실패했습니다.');
    }
  }

  /// 특정 방 정보 가져오기
  Stream<OnlineRoom?> getRoomStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value(null);
    }

    return _firestore!.collection('online_rooms').doc(roomId)
        .snapshots()
        .map((doc) => doc.exists ? OnlineRoom.fromJson(doc.data()!) : null);
  }

  // ==================== 친구 시스템 ====================

  /// 친구 요청 보내기
  Future<void> sendFriendRequest(String friendEmail) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      // 친구 사용자 찾기
      final friendQuery = await _firestore!.collection('users')
          .where('email', isEqualTo: friendEmail)
          .limit(1)
          .get();

      if (friendQuery.docs.isEmpty) {
        throw Exception('해당 이메일의 사용자를 찾을 수 없습니다.');
      }

      final friendDoc = friendQuery.docs.first;
      final friendId = friendDoc.id;
      final friendData = friendDoc.data();
      final friendEmailFromData = friendData['email'] ?? '';

      if (friendId == currentUser!.uid) {
        throw Exception('자기 자신에게 친구 요청을 보낼 수 없습니다.');
      }

      // 이미 친구 관계가 있는지 확인
      final existingFriendQuery = await _firestore!.collection('friends')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('friendId', isEqualTo: friendId)
          .limit(1)
          .get();

      if (existingFriendQuery.docs.isNotEmpty) {
        throw Exception('이미 친구 요청을 보냈거나 친구 관계입니다.');
      }

      final userData = await getUserData(currentUser!.uid);
      final userName = userData?['playerName'] ?? currentUser!.displayName ?? '플레이어';
      final userEmail = userData?['email'] ?? currentUser!.email ?? '';

      final friendName = friendData['playerName'] ?? '플레이어';

      final friendDocId = _firestore!.collection('friends').doc().id;
      final friend = Friend(
        id: friendDocId,
        userId: currentUser!.uid,
        friendId: friendId,
        userName: userName,
        userEmail: userEmail,
        friendName: friendName,
        friendEmail: friendEmailFromData,
        status: FriendStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore!.collection('friends').doc(friendDocId).set(friend.toJson());
      print('친구 요청 전송 완료: $friendEmail');
    } catch (e) {
      print('친구 요청 전송 오류: $e');
      throw Exception('친구 요청 전송에 실패했습니다: ${e.toString()}');
    }
  }

  /// 친구 요청 수락
  Future<void> acceptFriendRequest(String friendId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      // 트랜잭션을 사용하여 양방향 친구 관계 생성
      await _firestore!.runTransaction((transaction) async {
        // 원본 친구 요청 문서 가져오기
        final friendDoc = await transaction.get(
          _firestore!.collection('friends').doc(friendId)
        );
        
        if (!friendDoc.exists) {
          throw Exception('친구 요청을 찾을 수 없습니다.');
        }

        final friendData = friendDoc.data()!;
        final requesterId = friendData['userId'] as String;
        final requesterName = friendData['userName'] as String;
        final requesterEmail = friendData['userEmail'] as String;
        
        // 현재 사용자 정보 가져오기
        final currentUserData = await getUserData(currentUser!.uid);
        final currentUserName = currentUserData?['playerName'] ?? currentUser!.displayName ?? '플레이어';
        final currentUserEmail = currentUserData?['email'] ?? currentUser!.email ?? '';

        // 1. 원본 요청을 accepted로 업데이트
        transaction.update(
          _firestore!.collection('friends').doc(friendId),
          {
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          }
        );

        // 2. 반대 방향 친구 관계 생성 (현재 사용자가 userId가 되는 문서)
        final reverseFriendId = _firestore!.collection('friends').doc().id;
        final reverseFriend = Friend(
          id: reverseFriendId,
          userId: currentUser!.uid,
          friendId: requesterId,
          userName: currentUserName,
          userEmail: currentUserEmail,
          friendName: requesterName,
          friendEmail: requesterEmail,
          status: FriendStatus.accepted,
          createdAt: DateTime.now(),
          acceptedAt: DateTime.now(),
        );

        transaction.set(
          _firestore!.collection('friends').doc(reverseFriendId),
          reverseFriend.toJson()
        );
      });

      print('친구 요청 수락 완료: $friendId');
    } catch (e) {
      print('친구 요청 수락 오류: $e');
      throw Exception('친구 요청 수락에 실패했습니다.');
    }
  }

  /// 친구 요청 거부
  Future<void> rejectFriendRequest(String friendId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      await _firestore!.collection('friends').doc(friendId).update({
        'status': 'rejected',
      });
      print('친구 요청 거부 완료: $friendId');
    } catch (e) {
      print('친구 요청 거부 오류: $e');
      throw Exception('친구 요청 거부에 실패했습니다.');
    }
  }

  /// 친구 목록 가져오기
  Stream<List<Friend>> getFriendsList() {
    if (!_isInitialized || _firestore == null || currentUser == null) {
      return Stream.value([]);
    }

    // 현재 사용자가 userId인 친구 관계와 friendId인 친구 관계를 모두 조회
    return _firestore!.collection('friends')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          final friends = <Friend>[];
          
          for (final doc in snapshot.docs) {
            final friend = Friend.fromJson(doc.data());
            
            // 현재 사용자와 관련된 친구 관계만 필터링
            if (friend.userId == currentUser!.uid || friend.friendId == currentUser!.uid) {
              friends.add(friend);
            }
          }
          
          return friends;
        });
  }

  /// 받은 친구 요청 목록 가져오기
  Stream<List<Friend>> getReceivedFriendRequests() {
    if (!_isInitialized || _firestore == null || currentUser == null) {
      return Stream.value([]);
    }

    return _firestore!.collection('friends')
        .where('friendId', isEqualTo: currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friend.fromJson(doc.data()))
            .toList());
  }

  /// 보낸 친구 요청 목록 가져오기
  Stream<List<Friend>> getSentFriendRequests() {
    if (!_isInitialized || _firestore == null || currentUser == null) {
      return Stream.value([]);
    }

    return _firestore!.collection('friends')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friend.fromJson(doc.data()))
            .toList());
  }

  // ==================== 게임 초대 시스템 ====================

  /// 친구에게 게임 초대 보내기
  Future<void> sendGameInvite(String friendId, String roomId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final userData = await getUserData(currentUser!.uid);
      final userName = userData?['playerName'] ?? currentUser!.displayName ?? '플레이어';

      await _firestore!.collection('game_invites').add({
        'fromUserId': currentUser!.uid,
        'fromUserName': userName,
        'toUserId': friendId,
        'roomId': roomId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('게임 초대 전송 완료: $friendId -> $roomId');
    } catch (e) {
      print('게임 초대 전송 오류: $e');
      throw Exception('게임 초대 전송에 실패했습니다.');
    }
  }

  /// 게임 초대 스트림 가져오기
  Stream<QuerySnapshot> getGameInvitesStream(String userId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.empty();
    }

    try {
      return _firestore!.collection('game_invites')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots();
    } catch (e) {
      print('게임 초대 스트림 오류: $e');
      // 인덱스 오류인 경우 빈 스트림 반환
      return Stream.empty();
    }
  }

  /// 게임 초대 수락
  Future<void> acceptGameInvite(String inviteId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('game_invites').doc(inviteId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      print('게임 초대 수락 완료: $inviteId');
    } catch (e) {
      print('게임 초대 수락 오류: $e');
      throw Exception('게임 초대 수락에 실패했습니다.');
    }
  }

  /// 게임 초대 거부
  Future<void> rejectGameInvite(String inviteId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('game_invites').doc(inviteId).update({
        'status': 'rejected',
      });
      print('게임 초대 거부 완료: $inviteId');
    } catch (e) {
      print('게임 초대 거부 오류: $e');
      throw Exception('게임 초대 거부에 실패했습니다.');
    }
  }

  /// 비밀번호 해시화
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 친구 삭제
  Future<void> removeFriend(String targetFriendId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      // 먼저 삭제할 친구 관계들을 찾기
      final friendsQuery = await _firestore!.collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();

      final friendsToDelete = <String>[];

      for (final doc in friendsQuery.docs) {
        final friendData = doc.data();
        final userId = friendData['userId'] as String;
        final friendId = friendData['friendId'] as String;

        // 현재 사용자와 대상 친구와의 관계인지 확인
        if ((userId == currentUser!.uid && friendId == targetFriendId) ||
            (friendId == currentUser!.uid && userId == targetFriendId)) {
          friendsToDelete.add(doc.id);
        }
      }

      // 트랜잭션을 사용하여 친구 관계 삭제
      if (friendsToDelete.isNotEmpty) {
        await _firestore!.runTransaction((transaction) async {
          for (final docId in friendsToDelete) {
            transaction.delete(_firestore!.collection('friends').doc(docId));
          }
        });
      }

      print('친구 삭제 완료: $targetFriendId');
    } catch (e) {
      print('친구 삭제 오류: $e');
      throw Exception('친구 삭제에 실패했습니다.');
    }
  }

  // ==================== 온라인 멀티플레이어 게임 동기화 ====================

  /// 게임 상태 스트림 가져오기
  Stream<Map<String, dynamic>?> getGameStateStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value(null);
    }

    return _firestore!.collection('online_rooms').doc(roomId)
        .collection('game_state')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// 게임 상태 업데이트
  Future<void> updateGameState(String roomId, Map<String, dynamic> gameState) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('game_state')
          .doc('current')
          .set(gameState, SetOptions(merge: true));
    } catch (e) {
      print('게임 상태 업데이트 오류: $e');
      throw Exception('게임 상태 업데이트에 실패했습니다.');
    }
  }

  /// 카드 액션 동기화
  Future<void> syncCardAction(String roomId, int cardIndex, bool isFlipped, String playerId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      print('Firebase가 초기화되지 않음 - 카드 액션 동기화 건너뜀');
      return;
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('card_actions')
          .add({
        'cardIndex': cardIndex,
        'isFlipped': isFlipped,
        'playerId': playerId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('카드 액션 동기화 완료: 카드 $cardIndex, 뒤집기: $isFlipped');
    } catch (e) {
      print('카드 액션 동기화 오류: $e');
      // 오류가 발생해도 게임 진행에 영향을 주지 않도록 예외를 던지지 않음
    }
  }

  /// 카드 액션 기록 (카드 뒤집기 시 사용)
  Future<void> recordCardAction(String roomId, String playerId, int cardIndex, String cardEmoji) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      print('Firebase가 초기화되지 않음 - 카드 액션 기록 건너뜀');
      return;
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('card_actions')
          .add({
        'cardIndex': cardIndex,
        'isFlipped': true, // 카드 뒤집기 액션
        'playerId': playerId,
        'cardEmoji': cardEmoji, // 카드 이모지 정보 추가
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('카드 액션 기록 완료: 플레이어=$playerId, 카드=$cardIndex, 이모지=$cardEmoji');
    } catch (e) {
      print('카드 액션 기록 오류: $e');
      // 오류가 발생해도 게임 진행에 영향을 주지 않도록 예외를 던지지 않음
    }
  }

  /// 카드 플립 동기화 (별칭)
  Future<void> syncCardFlip(String roomId, int cardIndex, bool isFlipped, String playerId) async {
    return syncCardAction(roomId, cardIndex, isFlipped, playerId);
  }

  /// 카드 액션 스트림 가져오기 - 개선된 버전
  Stream<List<Map<String, dynamic>>> getCardActionsStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value([]);
    }

    return _firestore!.collection('online_rooms').doc(roomId)
        .collection('card_actions')
        .orderBy('timestamp', descending: true) // 최신 순서로 정렬
        .limit(10) // 최근 10개 액션으로 증가
        .snapshots()
        .map((snapshot) {
          final actions = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // 문서 ID를 액션 ID로 사용
            return data;
          }).toList();
          return actions;
        });
  }

  /// 턴 변경 동기화 - 최적화된 버전
  Future<void> syncTurnChange(String roomId, String currentPlayerId, String nextPlayerId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      // 현재 시간을 밀리초로 기록
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('turn_changes')
          .add({
        'currentPlayerId': currentPlayerId,
        'nextPlayerId': nextPlayerId,
        'timestamp': timestamp, // 서버 타임스탬프 대신 클라이언트 타임스탬프 사용
        'clientTimestamp': FieldValue.serverTimestamp(), // 서버 타임스탬프도 함께 저장
      });
      
    } catch (e) {
      print('턴 변경 동기화 오류: $e');
      throw Exception('턴 변경 동기화에 실패했습니다.');
    }
  }

  /// 턴 변경 스트림 가져오기 - 개선된 버전
  Stream<Map<String, dynamic>?> getTurnChangeStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value(null);
    }

    return _firestore!.collection('online_rooms').doc(roomId)
        .collection('turn_changes')
        .orderBy('timestamp', descending: true) // 최신 순서로 정렬
        .limit(1) // 최신 턴 변경만 가져오기
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            data['id'] = snapshot.docs.first.id; // 문서 ID를 턴 변경 ID로 사용
            return data;
          }
          return null;
        });
  }

  /// 카드 매칭 동기화 - 최적화된 버전
  Future<void> syncCardMatch(String roomId, int cardIndex1, int cardIndex2, bool isMatched, String playerId, [int? score, int? combo, int? matchCount, int? failCount, int? maxCombo]) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      // 현재 시간을 밀리초로 기록
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final matchData = {
        'cardIndex1': cardIndex1,
        'cardIndex2': cardIndex2,
        'isMatched': isMatched,
        'playerId': playerId,
        'timestamp': timestamp, // 클라이언트 타임스탬프 사용
        'clientTimestamp': FieldValue.serverTimestamp(), // 서버 타임스탬프도 함께 저장
      };
      
      // 플레이어 상세 정보 추가
      if (score != null) {
        matchData['score'] = score;
      }
      if (combo != null) {
        matchData['combo'] = combo;
      }
      if (matchCount != null) {
        matchData['matchCount'] = matchCount;
      }
      if (failCount != null) {
        matchData['failCount'] = failCount;
      }
      if (maxCombo != null) {
        matchData['maxCombo'] = maxCombo;
      }
      
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('card_matches')
          .add(matchData);
      
      print('카드 매칭 동기화 완료: 플레이어=$playerId, 매칭=$isMatched, 점수=$score, 콤보=$combo');
      
    } catch (e) {
      print('카드 매칭 동기화 오류: $e');
      throw Exception('카드 매칭 동기화에 실패했습니다.');
    }
  }

  /// 카드 매칭 스트림 가져오기 - 개선된 버전
  Stream<List<Map<String, dynamic>>> getCardMatchesStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value([]);
    }

    return _firestore!.collection('online_rooms').doc(roomId)
        .collection('card_matches')
        .orderBy('timestamp', descending: true) // 최신 순서로 정렬
        .limit(10) // 최근 10개 매칭으로 증가
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // 문서 ID를 매칭 ID로 사용
            return data;
          }).toList();
          return matches;
        });
  }

  /// 게임 방의 카드 데이터를 Firestore에 저장
  Future<void> saveGameCards(String roomId, List<Map<String, dynamic>> cardsData) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firestore가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('game_state')
          .doc('cards')
          .set({
        'cards': cardsData,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('게임 카드 데이터 저장 완료: ${cardsData.length}개 카드');
    } catch (e) {
      print('게임 카드 데이터 저장 오류: $e');
      throw Exception('게임 카드 데이터 저장에 실패했습니다: $e');
    }
  }

  /// 게임 방의 카드 데이터를 Firestore에서 로드
  Future<List<CardModel>> loadGameCards(String roomId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return [];
    }

    try {
      final doc = await _firestore!.collection('online_rooms').doc(roomId)
          .collection('game_state')
          .doc('cards')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final cardsData = data['cards'] as List<dynamic>? ?? [];
        
        if (cardsData.isNotEmpty) {
          print('카드 데이터 로드 성공: ${cardsData.length}개 카드');
          return cardsData.map((cardData) {
            return CardModel(
              id: cardData['id'] ?? 0,
              emoji: cardData['emoji'] ?? '❓',
              name: cardData['name'], // name 필드 추가
              isFlipped: cardData['isFlipped'] ?? false,
              isMatched: cardData['isMatched'] ?? false,
            );
          }).toList();
        } else {
          print('카드 데이터가 비어있음');
          return [];
        }
      } else {
        print('카드 문서가 존재하지 않음');
        return [];
      }
    } catch (e) {
      print('게임 카드 데이터 로드 오류: $e');
      return [];
    }
  }

  /// 호스트가 카드를 저장했는지 확인
  Future<bool> hasHostSavedCards(String roomId) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      return false;
    }

    try {
      final doc = await _firestore!.collection('online_rooms').doc(roomId)
          .collection('game_state')
          .doc('cards')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final cardsData = data['cards'] as List<dynamic>? ?? [];
        final hasCards = cardsData.isNotEmpty;
        print('호스트 카드 저장 상태 확인: ${hasCards ? "저장됨" : "저장되지 않음"} (${cardsData.length}개)');
        return hasCards;
      }
      
      print('호스트 카드 저장 상태 확인: 문서 없음');
      return false;
    } catch (e) {
      print('호스트 카드 저장 상태 확인 오류: $e');
      return false;
    }
  }

  /// 게임 기록 저장
  Future<void> saveGameRecord(dynamic gameRecord) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      if (currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      final recordData = {
        'playerName': gameRecord.playerName,
        'score': gameRecord.score,
        'time': gameRecord.time,
        'date': gameRecord.date.toIso8601String(),
        'maxCombo': gameRecord.maxCombo,
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore!.collection('game_records').add(recordData);
      print('게임 기록 저장 완료: ${gameRecord.playerName} - ${gameRecord.score}점');
    } catch (e) {
      print('게임 기록 저장 오류: $e');
      throw Exception('게임 기록 저장에 실패했습니다.');
    }
  }

  /// 멀티플레이어 게임 기록 저장
  Future<void> saveMultiplayerGameRecord(dynamic multiplayerRecord) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      if (currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      final recordData = {
        'gameTitle': multiplayerRecord.gameTitle,
        'players': multiplayerRecord.players,
        'createdAt': multiplayerRecord.createdAt.toIso8601String(),
        'isCompleted': multiplayerRecord.isCompleted,
        'totalTime': multiplayerRecord.totalTime,
        'timeLeft': multiplayerRecord.timeLeft,
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email,
        'firebaseCreatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore!.collection('multiplayer_game_records').add(recordData);
      print('멀티플레이어 게임 기록 저장 완료: ${multiplayerRecord.gameTitle}');
    } catch (e) {
      print('멀티플레이어 게임 기록 저장 오류: $e');
      throw Exception('멀티플레이어 게임 기록 저장에 실패했습니다.');
    }
  }

  /// 게임 기록 목록 가져오기
  Future<List<Map<String, dynamic>>> getGameRecords() async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      final snapshot = await _firestore!.collection('game_records')
          .orderBy('createdAt', descending: true)
          .limit(100) // 최근 100개만 가져오기
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('게임 기록 목록 가져오기 오류: $e');
      throw Exception('게임 기록 목록을 가져오는데 실패했습니다.');
    }
  }

  /// 멀티플레이어 게임 기록 목록 가져오기
  Future<List<Map<String, dynamic>>> getMultiplayerGameRecords() async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      final snapshot = await _firestore!.collection('multiplayer_game_records')
          .orderBy('firebaseCreatedAt', descending: true)
          .limit(100) // 최근 100개만 가져오기
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('멀티플레이어 게임 기록 목록 가져오기 오류: $e');
      throw Exception('멀티플레이어 게임 기록 목록을 가져오는데 실패했습니다.');
    }
  }

  /// 개선된 이메일 중복체크 (유효한 임시 비밀번호로 회원가입 시도)
  Future<bool> checkEmailDuplicateImproved(String email) async {
    await _initialize();
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    final lowercasedEmail = email.toLowerCase();
    
    print('이메일 중복체크 (유효한 비밀번호 회원가입 시도 방식) 시작: $lowercasedEmail');

    try {
      // 'weak-password' 오류를 피하기 위해 유효한 길이의 임시 비밀번호를 사용합니다.
      final tempValidPassword = 'dummy-password-for-check';
      UserCredential credential = await _auth!.createUserWithEmailAndPassword(
        email: lowercasedEmail,
        password: tempValidPassword,
      );

      // 만약 위 코드가 성공하면 (이메일이 정말로 사용 가능했다는 의미),
      // 생성된 임시 계정을 즉시 삭제하고 '중복 아님'을 반환합니다.
      print('임시 계정 생성 성공 (중복 아님). 즉시 삭제합니다.');
      await credential.user?.delete();
      print('임시 계정 삭제 완료.');
      return false; // 중복 아님

    } catch (e) {
      final errorStr = e.toString();
      print('중복 체크 중 예외 발생: $errorStr');

      if (errorStr.contains('email-already-in-use')) {
        // 이메일이 이미 사용 중이라는 가장 확실한 신호입니다.
        print('결과: 중복된 이메일입니다.');
        return true;
      }
      
      if (errorStr.contains('invalid-email')) {
        throw Exception('올바르지 않은 이메일 형식입니다.');
      }
      
      // 'weak-password'는 이제 발생하지 않아야 하지만, 만약을 위해 처리합니다.
      if (errorStr.contains('weak-password')) {
        print('예상치 못한 weak-password 오류 발생. 이 경우 이메일은 사용 가능한 것으로 간주합니다.');
        return false;
      }

      // 그 외 다른 Firebase 관련 오류 (네트워크 등)
      throw Exception('이메일 확인 중 예상치 못한 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 게임 종료 이벤트를 기록
  Future<void> recordGameEndEvent(String roomId, Map<String, dynamic> gameEndData) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('game_events')
          .add({
        'type': 'game_end',
        'data': gameEndData,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('게임 종료 이벤트 기록 완료: $roomId');
    } catch (e) {
      print('게임 종료 이벤트 기록 오류: $e');
      throw Exception('게임 종료 이벤트 기록에 실패했습니다.');
    }
  }

  /// 게임 종료 이벤트 스트림 가져오기
  Stream<QuerySnapshot> getGameEventsStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.empty();
    }

    try {
      return _firestore!.collection('online_rooms').doc(roomId)
          .collection('game_events')
          .where('type', isEqualTo: 'game_end')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots();
    } catch (e) {
      print('게임 이벤트 스트림 오류: $e');
      // 인덱스 오류인 경우 빈 스트림 반환
      return Stream.empty();
    }
  }

  /// 플레이어 상태 스트림 가져오기
  Stream<Map<String, dynamic>> getPlayerStatesStream(String roomId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value({});
    }

    return _firestore!.collection('online_rooms').doc(roomId)
        .collection('player_states')
        .snapshots()
        .map((snapshot) {
          final states = <String, dynamic>{};
          for (final doc in snapshot.docs) {
            states[doc.id] = doc.data();
          }
          return states;
        });
  }

  /// 플레이어 상태 동기화
  Future<void> syncPlayerState(String roomId, String playerId, Map<String, dynamic> state) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      print('Firebase가 초기화되지 않음 - 플레이어 상태 동기화 건너뜀');
      return;
    }

    try {
      await _firestore!.collection('online_rooms').doc(roomId)
          .collection('player_states')
          .doc(playerId)
          .set({
        ...state,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('플레이어 상태 동기화 완료: $playerId');
    } catch (e) {
      print('플레이어 상태 동기화 오류: $e');
      // 오류가 발생해도 게임 진행에 영향을 주지 않도록 예외를 던지지 않음
      // throw Exception('플레이어 상태 동기화에 실패했습니다.');
    }
  }

  /// 받은 게임 초대 목록 가져오기
  Stream<List<Map<String, dynamic>>> getReceivedGameInvites() {
    if (!_isInitialized || _firestore == null || currentUser == null) {
      return Stream.value([]);
    }

    try {
      return _firestore!.collection('game_invites')
          .where('toUserId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
              .toList());
    } catch (e) {
      print('받은 게임 초대 목록 오류: $e');
      // 인덱스 오류인 경우 빈 리스트 반환
      return Stream.value([]);
    }
  }

  /// 다른 플레이어의 경험치와 레벨 업데이트 (보안상 Cloud Function을 통해 처리하는 것이 좋지만, 임시로 직접 업데이트)
  Future<void> updatePlayerExpAndLevel(String playerId, int addExp) async {
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    try {
      final userDoc = _firestore!.collection('users').doc(playerId);
      final snapshot = await userDoc.get();
      
      if (!snapshot.exists) {
        print('플레이어 데이터가 존재하지 않음: $playerId');
        return;
      }

      final userData = snapshot.data()!;
      int currentExp = (userData['exp'] ?? 0) as int;
      int newExp = currentExp + addExp;
      int newLevel = _calcLevel(newExp);

      await userDoc.update({
        'exp': newExp,
        'level': newLevel,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('플레이어 경험치/레벨 업데이트 완료: $playerId (경험치: $currentExp -> $newExp, 레벨: ${userData['level'] ?? 1} -> $newLevel)');
    } catch (e) {
      print('플레이어 경험치/레벨 업데이트 오류: $e');
      throw Exception('플레이어 경험치/레벨 업데이트에 실패했습니다.');
    }
  }

  /// 경험치를 레벨로 변환하는 함수
  int _calcLevel(int exp) {
    return (exp ~/ 1000).clamp(0, 98) + 1;
  }
}