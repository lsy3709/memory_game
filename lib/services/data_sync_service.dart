import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hive_database_service.dart';
import 'firebase_service.dart';
import '../models/hive_models.dart';
import '../models/game_record.dart';
import '../models/multiplayer_game_record.dart';
import '../models/online_room.dart';

/// 데이터 동기화 서비스
/// Firebase와 Hive 간의 데이터 동기화를 관리
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  final HiveDatabaseService _hiveService = HiveDatabaseService();
  final FirebaseService _firebaseService = FirebaseService.instance;
  
  Timer? _syncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isAutoSyncEnabled = true;
  bool _isSyncing = false;

  /// 자동 동기화 활성화 여부
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;

  /// 현재 동기화 중인지 여부
  bool get isSyncing => _isSyncing;

  /// 서비스 초기화
  Future<void> initialize() async {
    // 네트워크 연결 상태 모니터링
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // 자동 동기화 설정 로드
    _isAutoSyncEnabled = await _loadAutoSyncSetting();

    print('데이터 동기화 서비스 초기화 완료');
  }

  /// 서비스 종료
  Future<void> dispose() async {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    print('데이터 동기화 서비스 종료');
  }

  /// 자동 동기화 설정 변경
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _isAutoSyncEnabled = enabled;
    await _saveAutoSyncSetting(enabled);
    
    if (enabled) {
      _startAutoSync();
    } else {
      _stopAutoSync();
    }
  }

  /// 자동 동기화 시작
  void _startAutoSync() {
    if (!_isAutoSyncEnabled) return;
    
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performAutoSync();
    });
    
    print('자동 동기화 시작 (5분 간격)');
  }

  /// 자동 동기화 중지
  void _stopAutoSync() {
    _syncTimer?.cancel();
    print('자동 동기화 중지');
  }

  /// 네트워크 연결 상태 변경 처리
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile) {
      print('네트워크 연결됨 - 동기화 시작');
      _performAutoSync();
    } else {
      print('네트워크 연결 끊김');
    }
  }

  /// 자동 동기화 수행
  Future<void> _performAutoSync() async {
    if (_isSyncing || !_isAutoSyncEnabled) return;
    
    try {
      _isSyncing = true;
      
      // Firebase 인증 상태 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Firebase 인증되지 않음 - 동기화 건너뜀');
        return;
      }

      // 양방향 동기화 수행
      await _performBidirectionalSync();
      
    } catch (e) {
      print('자동 동기화 오류: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 수동 동기화 수행
  Future<void> performManualSync() async {
    if (_isSyncing) {
      print('이미 동기화 중입니다.');
      return;
    }

    try {
      _isSyncing = true;
      
      // Firebase 인증 상태 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Firebase 인증이 필요합니다.');
      }

      // 양방향 동기화 수행
      await _performBidirectionalSync();
      
      print('수동 동기화 완료');
    } catch (e) {
      print('수동 동기화 오류: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// 양방향 동기화 수행
  Future<void> _performBidirectionalSync() async {
    print('양방향 동기화 시작...');

    // 1. 로컬 데이터를 Firebase에 업로드
    await _uploadLocalDataToFirebase();
    
    // 2. Firebase 데이터를 로컬로 다운로드
    await _downloadFirebaseDataToLocal();
    
    // 3. 온라인 방 데이터 동기화
    await _syncOnlineRooms();
    
    print('양방향 동기화 완료');
  }

  /// 로컬 데이터를 Firebase에 업로드
  Future<void> _uploadLocalDataToFirebase() async {
    try {
      // 동기화되지 않은 로컬 게임 기록 업로드
      final unsyncedRecords = _hiveService.getUnsyncedLocalRecords();
      for (final record in unsyncedRecords) {
        await _firebaseService.saveGameRecord(record.toJson());
        record.isSynced = true;
        // Hive 데이터베이스 서비스의 내부 박스에 직접 접근하지 않고 메서드 사용
        await _hiveService.saveLocalGameRecord(GameRecord.fromJson(record.toJson()));
        print('게임 기록 업로드 완료: ${record.id}');
      }

      // 동기화되지 않은 로컬 멀티플레이어 기록 업로드
      final unsyncedMultiplayerRecords = _hiveService.getUnsyncedLocalMultiplayerRecords();
      for (final record in unsyncedMultiplayerRecords) {
        await _firebaseService.saveMultiplayerGameRecord(record.toJson());
        record.isSynced = true;
        // Hive 데이터베이스 서비스의 내부 박스에 직접 접근하지 않고 메서드 사용
        await _hiveService.saveLocalMultiplayerRecord(MultiplayerGameRecord.fromJson(record.toJson()));
        print('멀티플레이어 기록 업로드 완료: ${record.id}');
      }

      print('로컬 데이터 Firebase 업로드 완료');
    } catch (e) {
      print('로컬 데이터 업로드 오류: $e');
      rethrow;
    }
  }

  /// Firebase 데이터를 로컬로 다운로드
  Future<void> _downloadFirebaseDataToLocal() async {
    try {
      // Firebase에서 게임 기록 가져오기
      final onlineRecords = await _firebaseService.getGameRecords();
      for (final recordData in onlineRecords) {
        final hiveRecord = HiveGameRecord.fromGameRecord(
          GameRecord.fromJson(recordData), 
          GameType.online
        );
        await _hiveService.saveOnlineGameRecord(GameRecord.fromJson(recordData));
      }

      // Firebase에서 멀티플레이어 기록 가져오기
      final onlineMultiplayerRecords = await _firebaseService.getMultiplayerGameRecords();
      for (final recordData in onlineMultiplayerRecords) {
        final hiveRecord = HiveMultiplayerGameRecord.fromMultiplayerGameRecord(
          MultiplayerGameRecord.fromJson(recordData), 
          GameType.online
        );
        await _hiveService.saveOnlineMultiplayerRecord(MultiplayerGameRecord.fromJson(recordData));
      }

      print('Firebase 데이터 로컬 다운로드 완료');
    } catch (e) {
      print('Firebase 데이터 다운로드 오류: $e');
      rethrow;
    }
  }

  /// 온라인 방 데이터 동기화
  Future<void> _syncOnlineRooms() async {
    try {
      // Firebase에서 온라인 방 목록 가져오기
      final onlineRooms = await _firebaseService.getOnlineRoomsList();
      
      // 기존 로컬 방 데이터 삭제 (Hive 서비스에서 처리)
      // await _hiveService._onlineRoomsBox.clear();
      
      // 새로운 방 데이터 저장
      for (final roomData in onlineRooms) {
        final hiveRoom = HiveOnlineRoom.fromOnlineRoom(
          OnlineRoom.fromJson(roomData)
        );
        await _hiveService.saveOnlineRoom(OnlineRoom.fromJson(roomData));
      }

      print('온라인 방 데이터 동기화 완료');
    } catch (e) {
      print('온라인 방 동기화 오류: $e');
      rethrow;
    }
  }

  /// 충돌 해결 (같은 ID의 데이터가 있을 때)
  Future<void> _resolveConflicts() async {
    // TODO: 충돌 해결 로직 구현
    // 1. 타임스탬프 비교
    // 2. 사용자 선택
    // 3. 자동 병합
  }

  /// 동기화 상태 확인
  Future<Map<String, dynamic>> getSyncStatus() async {
    final unsyncedLocalRecords = _hiveService.getUnsyncedLocalRecords();
    final unsyncedLocalMultiplayerRecords = _hiveService.getUnsyncedLocalMultiplayerRecords();
    
    return {
      'isAutoSyncEnabled': _isAutoSyncEnabled,
      'isSyncing': _isSyncing,
      'unsyncedGameRecords': unsyncedLocalRecords.length,
      'unsyncedMultiplayerRecords': unsyncedLocalMultiplayerRecords.length,
      'totalLocalRecords': _hiveService.getAllGameRecords().length,
      'totalLocalMultiplayerRecords': _hiveService.getAllMultiplayerRecords().length,
      'databaseSize': _hiveService.databaseSize,
    };
  }

  /// 특정 데이터 타입만 동기화
  Future<void> syncSpecificDataType(String dataType) async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;

      switch (dataType) {
        case 'game_records':
          await _uploadLocalDataToFirebase();
          await _downloadFirebaseDataToLocal();
          break;
        case 'multiplayer_records':
          await _uploadLocalDataToFirebase();
          await _downloadFirebaseDataToLocal();
          break;
        case 'online_rooms':
          await _syncOnlineRooms();
          break;
        default:
          throw Exception('알 수 없는 데이터 타입: $dataType');
      }

      print('$dataType 동기화 완료');
    } catch (e) {
      print('$dataType 동기화 오류: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// 동기화 히스토리 관리
  Future<void> _saveSyncHistory(String action, bool success, String? error) async {
    final syncHistory = {
      'timestamp': DateTime.now().toIso8601String(),
      'action': action,
      'success': success,
      'error': error,
    };

    // TODO: 동기화 히스토리를 로컬에 저장
    print('동기화 히스토리 저장: $syncHistory');
  }

  /// 자동 동기화 설정 저장
  Future<void> _saveAutoSyncSetting(bool enabled) async {
    // TODO: SharedPreferences에 설정 저장
    print('자동 동기화 설정 저장: $enabled');
  }

  /// 자동 동기화 설정 로드
  Future<bool> _loadAutoSyncSetting() async {
    // TODO: SharedPreferences에서 설정 로드
    return true; // 기본값
  }

  /// 동기화 일시 중지
  Future<void> pauseSync() async {
    _stopAutoSync();
    print('동기화 일시 중지');
  }

  /// 동기화 재개
  Future<void> resumeSync() async {
    if (_isAutoSyncEnabled) {
      _startAutoSync();
      print('동기화 재개');
    }
  }

  /// 동기화 강제 실행
  Future<void> forceSync() async {
    print('강제 동기화 시작...');
    await performManualSync();
  }
} 