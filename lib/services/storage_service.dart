import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/game_record.dart';
import '../models/player_stats.dart';

/// 로컬 저장소 서비스 클래스
/// 게임 기록과 플레이어 통계를 로컬에 저장하고 관리
class StorageService {
  static const String _gameRecordsKey = 'game_records';
  static const String _playerStatsKey = 'player_stats';
  static const String _currentPlayerKey = 'current_player';
  
  final Uuid _uuid = const Uuid();
  
  /// 게임 기록 목록을 로컬에서 불러오기
  Future<List<GameRecord>> loadGameRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList(_gameRecordsKey) ?? [];
      
      return recordsJson
          .map((json) => GameRecord.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('게임 기록 로드 오류: $e');
      return [];
    }
  }

  /// 게임 기록을 로컬에 저장
  Future<void> saveGameRecord(GameRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await loadGameRecords();
      
      // 새 기록 추가
      records.add(record);
      
      // 최신 100개 기록만 유지
      if (records.length > 100) {
        records.removeRange(0, records.length - 100);
      }
      
      // JSON으로 변환하여 저장
      final recordsJson = records
          .map((record) => jsonEncode(record.toJson()))
          .toList();
      
      await prefs.setStringList(_gameRecordsKey, recordsJson);
    } catch (e) {
      print('게임 기록 저장 오류: $e');
    }
  }

  /// 플레이어 통계를 로컬에서 불러오기
  Future<PlayerStats?> loadPlayerStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_playerStatsKey);
      
      if (statsJson != null) {
        return PlayerStats.fromJson(jsonDecode(statsJson));
      }
      return null;
    } catch (e) {
      print('플레이어 통계 로드 오류: $e');
      return null;
    }
  }

  /// 플레이어 통계를 로컬에 저장
  Future<void> savePlayerStats(PlayerStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = jsonEncode(stats.toJson());
      await prefs.setString(_playerStatsKey, statsJson);
    } catch (e) {
      print('플레이어 통계 저장 오류: $e');
    }
  }

  /// 현재 플레이어 정보를 로컬에서 불러오기
  Future<Map<String, String>?> loadCurrentPlayer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playerJson = prefs.getString(_currentPlayerKey);
      
      if (playerJson != null) {
        return Map<String, String>.from(jsonDecode(playerJson));
      }
      return null;
    } catch (e) {
      print('현재 플레이어 정보 로드 오류: $e');
      return null;
    }
  }

  /// 현재 플레이어 정보를 로컬에 저장
  Future<void> saveCurrentPlayer(String playerName, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playerData = {
        'playerName': playerName,
        'email': email,
      };
      final playerJson = jsonEncode(playerData);
      await prefs.setString(_currentPlayerKey, playerJson);
    } catch (e) {
      print('현재 플레이어 정보 저장 오류: $e');
    }
  }

  /// 고유 ID 생성
  String generateId() {
    return _uuid.v4();
  }

  /// 게임 기록 삭제
  Future<void> deleteGameRecord(String recordId) async {
    try {
      final records = await loadGameRecords();
      records.removeWhere((record) => record.id == recordId);
      
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = records
          .map((record) => jsonEncode(record.toJson()))
          .toList();
      
      await prefs.setStringList(_gameRecordsKey, recordsJson);
    } catch (e) {
      print('게임 기록 삭제 오류: $e');
    }
  }

  /// 모든 게임 기록 삭제
  Future<void> clearAllGameRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gameRecordsKey);
    } catch (e) {
      print('모든 게임 기록 삭제 오류: $e');
    }
  }

  /// 플레이어 통계 삭제
  Future<void> clearPlayerStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_playerStatsKey);
      await prefs.remove(_currentPlayerKey);
    } catch (e) {
      print('플레이어 통계 삭제 오류: $e');
    }
  }

  /// 최고 점수 기록 가져오기
  Future<GameRecord?> getBestScoreRecord() async {
    try {
      final records = await loadGameRecords();
      if (records.isEmpty) return null;
      
      records.sort((a, b) => b.score.compareTo(a.score));
      return records.first;
    } catch (e) {
      print('최고 점수 기록 조회 오류: $e');
      return null;
    }
  }

  /// 최단 시간 기록 가져오기
  Future<GameRecord?> getBestTimeRecord() async {
    try {
      final records = await loadGameRecords();
      if (records.isEmpty) return null;
      
      // 완료된 게임만 필터링
      final completedRecords = records.where((r) => r.isCompleted).toList();
      if (completedRecords.isEmpty) return null;
      
      completedRecords.sort((a, b) => a.gameTime.compareTo(b.gameTime));
      return completedRecords.first;
    } catch (e) {
      print('최단 시간 기록 조회 오류: $e');
      return null;
    }
  }

  /// 최고 연속 매칭 기록 가져오기
  Future<GameRecord?> getBestComboRecord() async {
    try {
      final records = await loadGameRecords();
      if (records.isEmpty) return null;
      
      records.sort((a, b) => b.maxCombo.compareTo(a.maxCombo));
      return records.first;
    } catch (e) {
      print('최고 연속 매칭 기록 조회 오류: $e');
      return null;
    }
  }

  /// 랭킹 보드 데이터 가져오기 (상위 10개)
  Future<List<GameRecord>> getTopRankings({int limit = 10}) async {
    try {
      final records = await loadGameRecords();
      if (records.isEmpty) return [];
      
      // 점수순으로 정렬
      records.sort((a, b) => b.score.compareTo(a.score));
      
      // 상위 기록만 반환
      return records.take(limit).toList();
    } catch (e) {
      print('랭킹 보드 데이터 조회 오류: $e');
      return [];
    }
  }

  /// 최근 게임 기록 가져오기
  Future<List<GameRecord>> getRecentRecords({int limit = 10}) async {
    try {
      final records = await loadGameRecords();
      if (records.isEmpty) return [];
      
      // 시간순으로 정렬 (최신순)
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // 최근 기록만 반환
      return records.take(limit).toList();
    } catch (e) {
      print('최근 게임 기록 조회 오류: $e');
      return [];
    }
  }
} 