/// 게임 기록을 저장하는 모델 클래스2
class GameRecord {
  final String id;           // 고유 식별자
  final String playerName;   // 플레이어 이름
  final String email;        // 이메일 (선택사항)
  final int score;           // 최종 점수
  final int matchCount;      // 매칭 성공 횟수
  final int failCount;       // 매칭 실패 횟수
  final int maxCombo;        // 최고 연속 매칭 기록
  final int timeLeft;        // 남은 시간 (초)
  final int totalTime;       // 총 게임 시간 (초)
  final DateTime createdAt;  // 기록 생성 시간
  final bool isCompleted;    // 게임 완료 여부

  GameRecord({
    required this.id,
    required this.playerName,
    this.email = '',
    required this.score,
    required this.matchCount,
    required this.failCount,
    required this.maxCombo,
    required this.timeLeft,
    required this.totalTime,
    required this.createdAt,
    required this.isCompleted,
  });

  /// JSON으로부터 GameRecord 객체 생성
  factory GameRecord.fromJson(Map<String, dynamic> json) {
    return GameRecord(
      id: json['id'] as String,
      playerName: json['playerName'] as String,
      email: json['email'] as String? ?? '',
      score: json['score'] as int,
      matchCount: json['matchCount'] as int,
      failCount: json['failCount'] as int,
      maxCombo: json['maxCombo'] as int,
      timeLeft: json['timeLeft'] as int,
      totalTime: json['totalTime'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isCompleted: json['isCompleted'] as bool,
    );
  }

  /// GameRecord 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerName': playerName,
      'email': email,
      'score': score,
      'matchCount': matchCount,
      'failCount': failCount,
      'maxCombo': maxCombo,
      'timeLeft': timeLeft,
      'totalTime': totalTime,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
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
} 