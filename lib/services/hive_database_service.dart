import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/hive_models.dart';
import '../models/game_record.dart';
import '../models/multiplayer_game_record.dart';
import '../models/online_room.dart' as online_room;
import 'firebase_service.dart';

/// Hive 데이터베이스 서비스
/// 로컬 데이터 저장 및 Firebase 동기화 관리
class HiveDatabaseService {
  static final HiveDatabaseService _instance = HiveDatabaseService._internal();
  factory HiveDatabaseService() => _instance;
  HiveDatabaseService._internal();

  static const String _gameRecordsBoxName = 'game_records';
  static const String _multiplayerRecordsBoxName = 'multiplayer_records';
  static const String _onlineRoomsBoxName = 'online_rooms';
  static const String _syncStatusBoxName = 'sync_status';

  late Box<HiveGameRecord> _gameRecordsBox;
  late Box<HiveMultiplayerGameRecord> _multiplayerRecordsBox;
  late Box<HiveOnlineRoom> _onlineRoomsBox;
  late Box<String> _syncStatusBox;

  final Uuid _uuid = const Uuid();

  /// Hive 초기화
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Hive 어댑터 등록
    Hive.registerAdapter(HiveGameRecordAdapter());
    Hive.registerAdapter(HiveMultiplayerGameRecordAdapter());
    Hive.registerAdapter(HivePlayerGameResultAdapter());
    Hive.registerAdapter(HiveOnlineRoomAdapter());
    Hive.registerAdapter(GameTypeAdapter());
    Hive.registerAdapter(RoomStatusAdapter());

    // 박스 열기
    _gameRecordsBox = await Hive.openBox<HiveGameRecord>(_gameRecordsBoxName);
    _multiplayerRecordsBox = await Hive.openBox<HiveMultiplayerGameRecord>(_multiplayerRecordsBoxName);
    _onlineRoomsBox = await Hive.openBox<HiveOnlineRoom>(_onlineRoomsBoxName);
    _syncStatusBox = await Hive.openBox<String>(_syncStatusBoxName);

    print('Hive 데이터베이스 초기화 완료');
  }

  /// 박스 닫기
  Future<void> close() async {
    await _gameRecordsBox.close();
    await _multiplayerRecordsBox.close();
    await _onlineRoomsBox.close();
    await _syncStatusBox.close();
  }

  // ==================== 게임 기록 관리 ====================

  /// 로컬 게임 기록 저장
  Future<void> saveLocalGameRecord(GameRecord gameRecord) async {
    final hiveRecord = HiveGameRecord.fromGameRecord(gameRecord, GameType.local);
    await _gameRecordsBox.put(hiveRecord.id, hiveRecord);
    print('로컬 게임 기록 저장: ${hiveRecord.id}');
  }

  /// 온라인 게임 기록 저장 (Firebase에서 동기화)
  Future<void> saveOnlineGameRecord(GameRecord gameRecord) async {
    final hiveRecord = HiveGameRecord.fromGameRecord(gameRecord, GameType.online);
    await _gameRecordsBox.put(hiveRecord.id, hiveRecord);
    print('온라인 게임 기록 저장: ${hiveRecord.id}');
  }

  /// 모든 게임 기록 조회
  List<HiveGameRecord> getAllGameRecords() {
    return _gameRecordsBox.values.toList();
  }

  /// 특정 타입의 게임 기록 조회
  List<HiveGameRecord> getGameRecordsByType(GameType gameType) {
    return _gameRecordsBox.values
        .where((record) => record.gameType == gameType)
        .toList();
  }

  /// 특정 플레이어의 게임 기록 조회
  List<HiveGameRecord> getGameRecordsByPlayer(String playerName) {
    return _gameRecordsBox.values
        .where((record) => record.playerName == playerName)
        .toList();
  }

  /// 동기화되지 않은 로컬 게임 기록 조회
  List<HiveGameRecord> getUnsyncedLocalRecords() {
    return _gameRecordsBox.values
        .where((record) => record.gameType == GameType.local && !record.isSynced)
        .toList();
  }

  /// 게임 기록 삭제
  Future<void> deleteGameRecord(String id) async {
    await _gameRecordsBox.delete(id);
    print('게임 기록 삭제: $id');
  }

  // ==================== 멀티플레이어 기록 관리 ====================

  /// 로컬 멀티플레이어 기록 저장
  Future<void> saveLocalMultiplayerRecord(MultiplayerGameRecord record) async {
    final hiveRecord = HiveMultiplayerGameRecord.fromMultiplayerGameRecord(record, GameType.local);
    await _multiplayerRecordsBox.put(hiveRecord.id, hiveRecord);
    print('로컬 멀티플레이어 기록 저장: ${hiveRecord.id}');
  }

  /// 온라인 멀티플레이어 기록 저장
  Future<void> saveOnlineMultiplayerRecord(MultiplayerGameRecord record) async {
    final hiveRecord = HiveMultiplayerGameRecord.fromMultiplayerGameRecord(record, GameType.online);
    await _multiplayerRecordsBox.put(hiveRecord.id, hiveRecord);
    print('온라인 멀티플레이어 기록 저장: ${hiveRecord.id}');
  }

  /// 모든 멀티플레이어 기록 조회
  List<HiveMultiplayerGameRecord> getAllMultiplayerRecords() {
    return _multiplayerRecordsBox.values.toList();
  }

  /// 특정 타입의 멀티플레이어 기록 조회
  List<HiveMultiplayerGameRecord> getMultiplayerRecordsByType(GameType gameType) {
    return _multiplayerRecordsBox.values
        .where((record) => record.gameType == gameType)
        .toList();
  }

  /// 동기화되지 않은 로컬 멀티플레이어 기록 조회
  List<HiveMultiplayerGameRecord> getUnsyncedLocalMultiplayerRecords() {
    return _multiplayerRecordsBox.values
        .where((record) => record.gameType == GameType.local && !record.isSynced)
        .toList();
  }

  /// 멀티플레이어 기록 삭제
  Future<void> deleteMultiplayerRecord(String id) async {
    await _multiplayerRecordsBox.delete(id);
    print('멀티플레이어 기록 삭제: $id');
  }

  // ==================== 온라인 방 관리 ====================

  /// 온라인 방 저장
  Future<void> saveOnlineRoom(online_room.OnlineRoom room) async {
    final hiveRoom = HiveOnlineRoom.fromOnlineRoom(room);
    await _onlineRoomsBox.put(hiveRoom.id, hiveRoom);
    print('온라인 방 저장: ${hiveRoom.id}');
  }

  /// 모든 온라인 방 조회
  List<HiveOnlineRoom> getAllOnlineRooms() {
    return _onlineRoomsBox.values.toList();
  }

  /// 특정 상태의 온라인 방 조회
  List<HiveOnlineRoom> getOnlineRoomsByStatus(RoomStatus status) {
    return _onlineRoomsBox.values
        .where((room) => room.status == status)
        .toList();
  }

  /// 온라인 방 업데이트
  Future<void> updateOnlineRoom(HiveOnlineRoom room) async {
    await _onlineRoomsBox.put(room.id, room);
    print('온라인 방 업데이트: ${room.id}');
  }

  /// 온라인 방 삭제
  Future<void> deleteOnlineRoom(String id) async {
    await _onlineRoomsBox.delete(id);
    print('온라인 방 삭제: $id');
  }

  // ==================== Firebase 동기화 ====================

  /// 로컬 데이터를 Firebase에 동기화
  Future<void> syncLocalDataToFirebase() async {
    try {
      final firebaseService = FirebaseService.instance;
      
      // 동기화되지 않은 로컬 게임 기록 업로드
      final unsyncedRecords = getUnsyncedLocalRecords();
      for (final record in unsyncedRecords) {
        await firebaseService.saveGameRecord(record.toJson());
        record.isSynced = true;
        await _gameRecordsBox.put(record.id, record);
        print('게임 기록 동기화 완료: ${record.id}');
      }

      // 동기화되지 않은 로컬 멀티플레이어 기록 업로드
      final unsyncedMultiplayerRecords = getUnsyncedLocalMultiplayerRecords();
      for (final record in unsyncedMultiplayerRecords) {
        await firebaseService.saveMultiplayerGameRecord(record.toJson());
        record.isSynced = true;
        await _multiplayerRecordsBox.put(record.id, record);
        print('멀티플레이어 기록 동기화 완료: ${record.id}');
      }

      print('로컬 데이터 Firebase 동기화 완료');
    } catch (e) {
      print('Firebase 동기화 오류: $e');
      rethrow;
    }
  }

  /// Firebase 데이터를 로컬로 동기화
  Future<void> syncFirebaseDataToLocal() async {
    try {
      final firebaseService = FirebaseService.instance;
      
      // Firebase에서 게임 기록 가져오기
      final onlineRecords = await firebaseService.getGameRecords();
      for (final recordData in onlineRecords) {
        final hiveRecord = HiveGameRecord.fromGameRecord(
          GameRecord.fromJson(recordData), 
          GameType.online
        );
        await _gameRecordsBox.put(hiveRecord.id, hiveRecord);
      }

      // Firebase에서 멀티플레이어 기록 가져오기
      final onlineMultiplayerRecords = await firebaseService.getMultiplayerGameRecords();
      for (final recordData in onlineMultiplayerRecords) {
        final hiveRecord = HiveMultiplayerGameRecord.fromMultiplayerGameRecord(
          MultiplayerGameRecord.fromJson(recordData), 
          GameType.online
        );
        await _multiplayerRecordsBox.put(hiveRecord.id, hiveRecord);
      }

      print('Firebase 데이터 로컬 동기화 완료');
    } catch (e) {
      print('Firebase 데이터 동기화 오류: $e');
      rethrow;
    }
  }

  /// 온라인 방 데이터 동기화
  Future<void> syncOnlineRooms() async {
    try {
      final firebaseService = FirebaseService.instance;
      
      // Firebase에서 온라인 방 목록 가져오기
      final onlineRooms = await firebaseService.getOnlineRooms();
      
      // 기존 로컬 방 데이터 삭제
      await _onlineRoomsBox.clear();
      
      // 새로운 방 데이터 저장
      for (final roomData in onlineRooms) {
        final hiveRoom = HiveOnlineRoom.fromOnlineRoom(
          online_room.OnlineRoom.fromJson(roomData)
        );
        await _onlineRoomsBox.put(hiveRoom.id, hiveRoom);
      }

      print('온라인 방 데이터 동기화 완료');
    } catch (e) {
      print('온라인 방 동기화 오류: $e');
      rethrow;
    }
  }

  // ==================== 통계 및 분석 ====================

  /// 플레이어 통계 계산
  Map<String, dynamic> getPlayerStats(String playerName) {
    final playerRecords = getGameRecordsByPlayer(playerName);
    
    if (playerRecords.isEmpty) {
      return {
        'totalGames': 0,
        'completedGames': 0,
        'totalScore': 0,
        'averageScore': 0,
        'bestScore': 0,
        'totalTime': 0,
        'averageTime': 0,
        'bestTime': 0,
        'totalMatches': 0,
        'totalFails': 0,
        'matchRate': 0,
        'maxCombo': 0,
      };
    }

    final completedRecords = playerRecords.where((r) => r.isCompleted).toList();
    final totalScore = playerRecords.fold<int>(0, (sum, r) => sum + r.score);
    final totalTime = playerRecords.fold<int>(0, (sum, r) => sum + r.gameTime);
    final totalMatches = playerRecords.fold<int>(0, (sum, r) => sum + r.matchCount);
    final totalFails = playerRecords.fold<int>(0, (sum, r) => sum + r.failCount);
    final maxCombo = playerRecords.fold<int>(0, (max, r) => r.maxCombo > max ? r.maxCombo : max);

    return {
      'totalGames': playerRecords.length,
      'completedGames': completedRecords.length,
      'totalScore': totalScore,
      'averageScore': playerRecords.isNotEmpty ? totalScore / playerRecords.length : 0,
      'bestScore': playerRecords.fold<int>(0, (max, r) => r.score > max ? r.score : max),
      'totalTime': totalTime,
      'averageTime': playerRecords.isNotEmpty ? totalTime / playerRecords.length : 0,
      'bestTime': playerRecords.fold<int>(0, (max, r) => r.gameTime > max ? r.gameTime : max),
      'totalMatches': totalMatches,
      'totalFails': totalFails,
      'matchRate': (totalMatches + totalFails) > 0 ? (totalMatches / (totalMatches + totalFails)) * 100 : 0,
      'maxCombo': maxCombo,
    };
  }

  /// 전체 통계 계산
  Map<String, dynamic> getOverallStats() {
    final allRecords = getAllGameRecords();
    final localRecords = getGameRecordsByType(GameType.local);
    final onlineRecords = getGameRecordsByType(GameType.online);

    return {
      'totalGames': allRecords.length,
      'localGames': localRecords.length,
      'onlineGames': onlineRecords.length,
      'completedGames': allRecords.where((r) => r.isCompleted).length,
      'totalPlayers': allRecords.map((r) => r.playerName).toSet().length,
      'averageScore': allRecords.isNotEmpty ? allRecords.fold<int>(0, (sum, r) => sum + r.score) / allRecords.length : 0,
      'bestScore': allRecords.isNotEmpty ? allRecords.fold<int>(0, (max, r) => r.score > max ? r.score : max) : 0,
    };
  }

  // ==================== 데이터 관리 ====================

  /// 모든 데이터 삭제
  Future<void> clearAllData() async {
    await _gameRecordsBox.clear();
    await _multiplayerRecordsBox.clear();
    await _onlineRoomsBox.clear();
    await _syncStatusBox.clear();
    print('모든 로컬 데이터 삭제 완료');
  }

  /// 특정 타입의 데이터 삭제
  Future<void> clearDataByType(GameType gameType) async {
    final gameRecordsToDelete = getGameRecordsByType(gameType);
    final multiplayerRecordsToDelete = getMultiplayerRecordsByType(gameType);

    for (final record in gameRecordsToDelete) {
      await _gameRecordsBox.delete(record.id);
    }

    for (final record in multiplayerRecordsToDelete) {
      await _multiplayerRecordsBox.delete(record.id);
    }

    print('${gameType.toString().split('.').last} 타입 데이터 삭제 완료');
  }

  /// 데이터베이스 크기 확인
  int get databaseSize {
    return _gameRecordsBox.length + 
           _multiplayerRecordsBox.length + 
           _onlineRoomsBox.length;
  }
} 