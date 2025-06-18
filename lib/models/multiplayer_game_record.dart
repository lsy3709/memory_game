import '../models/score_model.dart';

/// 멀티플레이어 게임 기록을 저장하는 모델 클래스
class MultiplayerGameRecord {
  final String id;                    // 고유 식별자
  final String gameTitle;             // 게임 제목
  final List<PlayerGameResult> players; // 플레이어들의 게임 결과
  final DateTime createdAt;           // 게임 생성 시간
  final bool isCompleted;             // 게임 완료 여부
  final int totalTime;                // 총 게임 시간 (초)
  final int timeLeft;                 // 남은 시간 (초)

  MultiplayerGameRecord({
    required this.id,
    required this.gameTitle,
    required this.players,
    required this.createdAt,
    required this.isCompleted,
    required this.totalTime,
    required this.timeLeft,
  });

  /// JSON으로부터 MultiplayerGameRecord 객체 생성
  factory MultiplayerGameRecord.fromJson(Map<String, dynamic> json) {
    return MultiplayerGameRecord(
      id: json['id'] as String,
      gameTitle: json['gameTitle'] as String,
      players: (json['players'] as List)
          .map((playerJson) => PlayerGameResult.fromJson(playerJson))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isCompleted: json['isCompleted'] as bool,
      totalTime: json['totalTime'] as int,
      timeLeft: json['timeLeft'] as int,
    );
  }

  /// MultiplayerGameRecord 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameTitle': gameTitle,
      'players': players.map((player) => player.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'totalTime': totalTime,
      'timeLeft': timeLeft,
    };
  }

  /// 게임 완료 시간 계산 (초 단위)
  int get gameTime => totalTime - timeLeft;

  /// 게임 완료 시간을 mm:ss 형식으로 반환
  String get formattedGameTime {
    final mins = gameTime ~/ 60;
    final secs = gameTime % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 기록 생성 시간을 포맷된 문자열로 반환
  String get formattedCreatedAt {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
           '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// 승자 찾기
  PlayerGameResult? get winner {
    if (players.isEmpty) return null;
    
    // 점수순으로 정렬
    final sortedPlayers = List<PlayerGameResult>.from(players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    
    // 최고 점수가 같으면 매칭 성공률로 비교
    if (sortedPlayers.length > 1 && 
        sortedPlayers[0].score == sortedPlayers[1].score) {
      final firstPlayerRate = sortedPlayers[0].matchRate;
      final secondPlayerRate = sortedPlayers[1].matchRate;
      
      if (firstPlayerRate == secondPlayerRate) {
        // 매칭 성공률도 같으면 완료 시간으로 비교
        if (sortedPlayers[0].gameTime == sortedPlayers[1].gameTime) {
          return null; // 무승부
        }
        return sortedPlayers[0].gameTime < sortedPlayers[1].gameTime 
            ? sortedPlayers[0] 
            : sortedPlayers[1];
      }
      return firstPlayerRate > secondPlayerRate 
          ? sortedPlayers[0] 
          : sortedPlayers[1];
    }
    
    return sortedPlayers[0];
  }

  /// 무승부 여부 확인
  bool get isDraw {
    final winner = this.winner;
    if (winner == null) return true;
    
    // 동점자가 있는지 확인
    final maxScore = winner.score;
    final playersWithMaxScore = players.where((p) => p.score == maxScore).length;
    
    return playersWithMaxScore > 1;
  }
}

/// 개별 플레이어의 게임 결과를 저장하는 클래스
class PlayerGameResult {
  final String playerName;        // 플레이어 이름
  final String email;             // 플레이어 이메일 (선택사항)
  final int score;                // 최종 점수
  final int matchCount;           // 매칭 성공 횟수
  final int failCount;            // 매칭 실패 횟수
  final int maxCombo;             // 최고 연속 매칭 기록
  final int gameTime;             // 게임 완료 시간 (초)
  final List<CardMatch> cardMatches; // 매칭된 카드 목록
  final bool isCompleted;         // 게임 완료 여부

  PlayerGameResult({
    required this.playerName,
    this.email = '',
    required this.score,
    required this.matchCount,
    required this.failCount,
    required this.maxCombo,
    required this.gameTime,
    required this.cardMatches,
    required this.isCompleted,
  });

  /// JSON으로부터 PlayerGameResult 객체 생성
  factory PlayerGameResult.fromJson(Map<String, dynamic> json) {
    return PlayerGameResult(
      playerName: json['playerName'] as String,
      email: json['email'] as String? ?? '',
      score: json['score'] as int,
      matchCount: json['matchCount'] as int,
      failCount: json['failCount'] as int,
      maxCombo: json['maxCombo'] as int,
      gameTime: json['gameTime'] as int,
      cardMatches: (json['cardMatches'] as List?)
          ?.map((matchJson) => CardMatch.fromJson(matchJson))
          .toList() ?? [],
      isCompleted: json['isCompleted'] as bool,
    );
  }

  /// PlayerGameResult 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'email': email,
      'score': score,
      'matchCount': matchCount,
      'failCount': failCount,
      'maxCombo': maxCombo,
      'gameTime': gameTime,
      'cardMatches': cardMatches.map((match) => match.toJson()).toList(),
      'isCompleted': isCompleted,
    };
  }

  /// 매칭 성공률 계산
  double get matchRate {
    final totalAttempts = matchCount + failCount;
    if (totalAttempts == 0) return 0.0;
    return (matchCount / totalAttempts) * 100;
  }

  /// 게임 완료 시간을 mm:ss 형식으로 반환
  String get formattedGameTime {
    final mins = gameTime ~/ 60;
    final secs = gameTime % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// 카드 매칭 정보를 저장하는 클래스
class CardMatch {
  final int pairId;               // 카드 쌍 ID
  final String imagePath;         // 카드 이미지 경로
  final DateTime matchedAt;       // 매칭된 시간
  final int matchNumber;          // 몇 번째 매칭인지

  CardMatch({
    required this.pairId,
    required this.imagePath,
    required this.matchedAt,
    required this.matchNumber,
  });

  /// JSON으로부터 CardMatch 객체 생성
  factory CardMatch.fromJson(Map<String, dynamic> json) {
    return CardMatch(
      pairId: json['pairId'] as int,
      imagePath: json['imagePath'] as String,
      matchedAt: DateTime.parse(json['matchedAt'] as String),
      matchNumber: json['matchNumber'] as int,
    );
  }

  /// CardMatch 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'pairId': pairId,
      'imagePath': imagePath,
      'matchedAt': matchedAt.toIso8601String(),
      'matchNumber': matchNumber,
    };
  }

  /// 매칭 시간을 포맷된 문자열로 반환
  String get formattedMatchedAt {
    return '${matchedAt.hour.toString().padLeft(2, '0')}:${matchedAt.minute.toString().padLeft(2, '0')}:${matchedAt.second.toString().padLeft(2, '0')}';
  }
}

/// 플레이어 게임 데이터 클래스 (멀티플레이어 게임 화면에서 사용)
class PlayerGameData {
  String name;
  String email;
  ScoreModel scoreModel;
  int maxCombo;
  List<CardMatch> cardMatches;
  int gameTime;
  bool isCompleted;

  PlayerGameData({
    required this.name,
    required this.email,
    required this.scoreModel,
    required this.maxCombo,
    required this.cardMatches,
    required this.gameTime,
    required this.isCompleted,
  });
} 