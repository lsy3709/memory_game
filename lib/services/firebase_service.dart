import 'dart:convert';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_record.dart';
import '../models/multiplayer_game_record.dart';
import '../models/player_stats.dart';
import '../models/online_room.dart';
import '../models/friend.dart';
import 'package:crypto/crypto.dart';
import 'dart:async';

/// Firebase 서비스를 관리하는 클래스
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  bool _isInitialized = false;
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  User? _currentUser;

  /// Firebase 초기화
  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;

    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _currentUser = _auth!.currentUser;
      _isInitialized = true;
      
      print('Firebase 초기화 성공');
      return true;
    } catch (e) {
      print('Firebase 초기화 실패: $e');
      return false;
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
      // 로그인 시도
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
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
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _currentUser = credential.user;
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

      final roomId = _firestore!.collection('online_rooms').doc().id;
      final room = OnlineRoom(
        id: roomId,
        roomName: roomName,
        hostId: currentUser!.uid,
        hostName: playerName,
        hostEmail: email,
        status: RoomStatus.waiting,
        createdAt: DateTime.now(),
        isPrivate: isPrivate,
        password: password,
      );

      await _firestore!.collection('online_rooms').doc(roomId).set(room.toJson());
      print('온라인 게임 방 생성 완료: $roomName');
      return room;
    } catch (e) {
      print('온라인 게임 방 생성 오류: $e');
      throw Exception('게임 방 생성에 실패했습니다.');
    }
  }

  /// 온라인 게임 방 목록 가져오기
  Stream<List<OnlineRoom>> getOnlineRooms() {
    if (!_isInitialized || _firestore == null) {
      return Stream.value([]);
    }

    return _firestore!.collection('online_rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OnlineRoom.fromJson(doc.data()))
            .toList());
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
    await _initialize();
    if (!_isInitialized || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final roomRef = _firestore!.collection('online_rooms').doc(roomId);
      
      await _firestore!.runTransaction((transaction) async {
        final roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists) {
          return;
        }

        final room = OnlineRoom.fromJson(roomDoc.data()!);
        
        if (room.isHost(currentUser!.uid)) {
          // 방장이 나가면 방 삭제
          transaction.delete(roomRef);
        } else if (room.isGuest(currentUser!.uid)) {
          // 게스트가 나가면 게스트 정보만 제거
          final updatedRoom = room.copyWith(
            guestId: null,
            guestName: null,
            guestEmail: null,
          );
          transaction.update(roomRef, updatedRoom.toJson());
        }
      });

      print('온라인 게임 방 나가기 완료: $roomId');
    } catch (e) {
      print('온라인 게임 방 나가기 오류: $e');
      throw Exception('방 나가기에 실패했습니다.');
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

  /// 받은 게임 초대 목록 가져오기
  Stream<List<Map<String, dynamic>>> getReceivedGameInvites() {
    if (!_isInitialized || _firestore == null || currentUser == null) {
      return Stream.value([]);
    }

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
      // 트랜잭션을 사용하여 양방향 친구 관계 모두 삭제
      await _firestore!.runTransaction((transaction) async {
        // 현재 사용자와 관련된 모든 친구 관계 찾기
        final friendsQuery = await transaction.get(
          _firestore!.collection('friends')
              .where('status', isEqualTo: 'accepted')
        );

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

        // 모든 관련 친구 관계 삭제
        for (final docId in friendsToDelete) {
          transaction.delete(_firestore!.collection('friends').doc(docId));
        }
      });

      print('친구 삭제 완료: $targetFriendId');
    } catch (e) {
      print('친구 삭제 오류: $e');
      throw Exception('친구 삭제에 실패했습니다.');
    }
  }
}