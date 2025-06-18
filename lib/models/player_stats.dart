/// 플레이어의 통계 정보를 저장하는 모델 클래스
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerStats {
  final String id;              // 고유 식별자
  final String playerName;      // 플레이어 이름
  final String email;           // 이메일
  final int bestScore;          // 최고 점수
  final int bestTime;           // 최단 시간 (초)
  final int maxCombo;           // 최고 연속 매칭 기록
  final int totalGames;         // 총 게임 수
  final int totalWins;          // 총 승리 수
  final int totalMatches;       // 총 매칭 성공 수
  final int totalFails;         // 총 매칭 실패 수
  final int totalMatchCount;    // 총 매칭 시도 수 (성공 + 실패)
  final int totalFailCount;     // 총 실패 수
  final DateTime lastPlayed;    // 마지막 플레이 시간
  final DateTime createdAt;     // 계정 생성 시간

  PlayerStats({
    required this.id,
    required this.playerName,
    required this.email,
    this.bestScore = 0,
    this.bestTime = 0,
    this.maxCombo = 0,
    this.totalGames = 0,
    this.totalWins = 0,
    this.totalMatches = 0,
    this.totalFails = 0,
    this.totalMatchCount = 0,
    this.totalFailCount = 0,
    required this.lastPlayed,
    required this.createdAt,
  });

  /// JSON으로부터 PlayerStats 객체 생성
  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      id: json['id'] as String,
      playerName: json['playerName'] as String,
      email: json['email'] as String,
      bestScore: json['bestScore'] as int? ?? 0,
      bestTime: json['bestTime'] as int? ?? 0,
      maxCombo: json['maxCombo'] as int? ?? 0,
      totalGames: json['totalGames'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      totalMatches: json['totalMatches'] as int? ?? 0,
      totalFails: json['totalFails'] as int? ?? 0,
      totalMatchCount: json['totalMatchCount'] as int? ?? 0,
      totalFailCount: json['totalFailCount'] as int? ?? 0,
      lastPlayed: DateTime.parse(json['lastPlayed'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Map으로부터 PlayerStats 객체 생성 (Firestore용)
  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      id: map['id'] as String? ?? '',
      playerName: map['playerName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      bestScore: map['bestScore'] as int? ?? 0,
      bestTime: map['bestTime'] as int? ?? 0,
      maxCombo: map['maxCombo'] as int? ?? 0,
      totalGames: map['totalGames'] as int? ?? 0,
      totalWins: map['totalWins'] as int? ?? 0,
      totalMatches: map['totalMatches'] as int? ?? 0,
      totalFails: map['totalFails'] as int? ?? 0,
      totalMatchCount: map['totalMatchCount'] as int? ?? 0,
      totalFailCount: map['totalFailCount'] as int? ?? 0,
      lastPlayed: map['lastPlayed'] != null 
          ? (map['lastPlayed'] is Timestamp 
              ? (map['lastPlayed'] as Timestamp).toDate()
              : DateTime.parse(map['lastPlayed'] as String))
          : DateTime.now(),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'] as String))
          : DateTime.now(),
    );
  }

  /// PlayerStats 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerName': playerName,
      'email': email,
      'bestScore': bestScore,
      'bestTime': bestTime,
      'maxCombo': maxCombo,
      'totalGames': totalGames,
      'totalWins': totalWins,
      'totalMatches': totalMatches,
      'totalFails': totalFails,
      'totalMatchCount': totalMatchCount,
      'totalFailCount': totalFailCount,
      'lastPlayed': lastPlayed.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 승률 계산
  double get winRate {
    if (totalGames == 0) return 0.0;
    return (totalWins / totalGames) * 100;
  }

  /// 평균 매칭 성공률 계산
  double get matchRate {
    final totalAttempts = totalMatches + totalFails;
    if (totalAttempts == 0) return 0.0;
    return (totalMatches / totalAttempts) * 100;
  }

  /// 최단 시간을 mm:ss 형식으로 반환
  String get formattedBestTime {
    if (bestTime == 0) return '--:--';
    final mins = bestTime ~/ 60;
    final secs = bestTime % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 마지막 플레이 시간을 포맷된 문자열로 반환
  String get formattedLastPlayed {
    return '${lastPlayed.year}-${lastPlayed.month.toString().padLeft(2, '0')}-${lastPlayed.day.toString().padLeft(2, '0')} '
           '${lastPlayed.hour.toString().padLeft(2, '0')}:${lastPlayed.minute.toString().padLeft(2, '0')}';
  }

  /// 계정 생성 시간을 포맷된 문자열로 반환
  String get formattedCreatedAt {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
           '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// 게임 결과에 따라 통계 업데이트
  PlayerStats updateWithGameResult({
    required int score,
    required int gameTime,
    required int maxCombo,
    required int matchCount,
    required int failCount,
    required bool isWin,
  }) {
    return PlayerStats(
      id: id,
      playerName: playerName,
      email: email,
      bestScore: score > bestScore ? score : bestScore,
      bestTime: (bestTime == 0 || gameTime < bestTime) ? gameTime : bestTime,
      maxCombo: maxCombo > this.maxCombo ? maxCombo : this.maxCombo,
      totalGames: totalGames + 1,
      totalWins: isWin ? totalWins + 1 : totalWins,
      totalMatches: totalMatches + matchCount,
      totalFails: totalFails + failCount,
      totalMatchCount: totalMatchCount + matchCount,
      totalFailCount: totalFailCount + failCount,
      lastPlayed: DateTime.now(),
      createdAt: createdAt,
    );
  }
} 