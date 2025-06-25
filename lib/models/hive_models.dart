import 'package:hive/hive.dart';

part 'hive_models.g.dart';

/// Hive를 위한 게임 기록 모델
@HiveType(typeId: 0)
class HiveGameRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String playerName;

  @HiveField(2)
  String email;

  @HiveField(3)
  int score;

  @HiveField(4)
  int matchCount;

  @HiveField(5)
  int failCount;

  @HiveField(6)
  int maxCombo;

  @HiveField(7)
  int timeLeft;

  @HiveField(8)
  int totalTime;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  bool isCompleted;

  @HiveField(11)
  GameType gameType; // 로컬/온라인 구분

  @HiveField(12)
  bool isSynced; // Firebase 동기화 여부

  HiveGameRecord({
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
    required this.gameType,
    this.isSynced = false,
  });

  /// 기존 GameRecord에서 HiveGameRecord 생성
  factory HiveGameRecord.fromGameRecord(dynamic gameRecord, GameType gameType) {
    return HiveGameRecord(
      id: gameRecord.id,
      playerName: gameRecord.playerName,
      email: gameRecord.email ?? '',
      score: gameRecord.score,
      matchCount: gameRecord.matchCount,
      failCount: gameRecord.failCount,
      maxCombo: gameRecord.maxCombo,
      timeLeft: gameRecord.timeLeft,
      totalTime: gameRecord.totalTime,
      createdAt: gameRecord.createdAt,
      isCompleted: gameRecord.isCompleted,
      gameType: gameType,
      isSynced: gameType == GameType.online, // 온라인은 이미 동기화됨
    );
  }

  /// JSON으로 변환 (Firebase 업로드용)
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
      'gameType': gameType.toString().split('.').last,
    };
  }

  /// 게임 완료 시간 계산
  int get gameTime => totalTime - timeLeft;

  /// 게임 완료 시간을 mm:ss 형식으로 반환
  String get formattedGameTime {
    final mins = gameTime ~/ 60;
    final secs = gameTime % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Hive를 위한 멀티플레이어 게임 기록 모델
@HiveType(typeId: 1)
class HiveMultiplayerGameRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String gameTitle;

  @HiveField(2)
  List<HivePlayerGameResult> players;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  int totalTime;

  @HiveField(6)
  int timeLeft;

  @HiveField(7)
  GameType gameType;

  @HiveField(8)
  bool isSynced;

  HiveMultiplayerGameRecord({
    required this.id,
    required this.gameTitle,
    required this.players,
    required this.createdAt,
    required this.isCompleted,
    required this.totalTime,
    required this.timeLeft,
    required this.gameType,
    this.isSynced = false,
  });

  /// 기존 MultiplayerGameRecord에서 HiveMultiplayerGameRecord 생성
  factory HiveMultiplayerGameRecord.fromMultiplayerGameRecord(
    dynamic multiplayerRecord, 
    GameType gameType
  ) {
    return HiveMultiplayerGameRecord(
      id: multiplayerRecord.id,
      gameTitle: multiplayerRecord.gameTitle,
      players: multiplayerRecord.players
          .map((player) => HivePlayerGameResult.fromPlayerGameResult(player))
          .toList(),
      createdAt: multiplayerRecord.createdAt,
      isCompleted: multiplayerRecord.isCompleted,
      totalTime: multiplayerRecord.totalTime,
      timeLeft: multiplayerRecord.timeLeft,
      gameType: gameType,
      isSynced: gameType == GameType.online,
    );
  }

  /// JSON으로 변환 (Firebase 업로드용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameTitle': gameTitle,
      'players': players.map((player) => player.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'totalTime': totalTime,
      'timeLeft': timeLeft,
      'gameType': gameType.toString().split('.').last,
    };
  }

  /// 승자 찾기
  HivePlayerGameResult? get winner {
    if (players.isEmpty) return null;
    
    final sortedPlayers = List<HivePlayerGameResult>.from(players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    
    if (sortedPlayers.length > 1 && 
        sortedPlayers[0].score == sortedPlayers[1].score) {
      final firstPlayerRate = sortedPlayers[0].matchRate;
      final secondPlayerRate = sortedPlayers[1].matchRate;
      
      if (firstPlayerRate == secondPlayerRate) {
        if (sortedPlayers[0].timeLeft == sortedPlayers[1].timeLeft) {
          return null; // 무승부
        }
        return sortedPlayers[0].timeLeft < sortedPlayers[1].timeLeft 
            ? sortedPlayers[0] 
            : sortedPlayers[1];
      }
      return firstPlayerRate > secondPlayerRate 
          ? sortedPlayers[0] 
          : sortedPlayers[1];
    }
    
    return sortedPlayers[0];
  }
}

/// Hive를 위한 플레이어 게임 결과 모델
@HiveType(typeId: 2)
class HivePlayerGameResult {
  @HiveField(0)
  String playerName;

  @HiveField(1)
  String email;

  @HiveField(2)
  int score;

  @HiveField(3)
  int matchCount;

  @HiveField(4)
  int failCount;

  @HiveField(5)
  int maxCombo;

  @HiveField(6)
  int timeLeft;

  @HiveField(7)
  bool isWinner;

  HivePlayerGameResult({
    required this.playerName,
    this.email = '',
    required this.score,
    required this.matchCount,
    required this.failCount,
    required this.maxCombo,
    required this.timeLeft,
    this.isWinner = false,
  });

  /// 기존 PlayerGameResult에서 HivePlayerGameResult 생성
  factory HivePlayerGameResult.fromPlayerGameResult(dynamic playerResult) {
    return HivePlayerGameResult(
      playerName: playerResult.playerName,
      email: playerResult.email ?? '',
      score: playerResult.score,
      matchCount: playerResult.matchCount,
      failCount: playerResult.failCount,
      maxCombo: playerResult.maxCombo,
      timeLeft: playerResult.timeLeft,
      isWinner: playerResult.isWinner ?? false,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'email': email,
      'score': score,
      'matchCount': matchCount,
      'failCount': failCount,
      'maxCombo': maxCombo,
      'timeLeft': timeLeft,
      'isWinner': isWinner,
    };
  }

  /// 매칭 성공률 계산
  double get matchRate {
    final totalAttempts = matchCount + failCount;
    if (totalAttempts == 0) return 0.0;
    return (matchCount / totalAttempts) * 100;
  }
}

/// Hive를 위한 온라인 방 모델
@HiveType(typeId: 3)
class HiveOnlineRoom extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String roomName;

  @HiveField(2)
  String hostId;

  @HiveField(3)
  String hostName;

  @HiveField(4)
  String hostEmail;

  @HiveField(5)
  int hostLevel;

  @HiveField(6)
  String? guestId;

  @HiveField(7)
  String? guestName;

  @HiveField(8)
  String? guestEmail;

  @HiveField(9)
  int? guestLevel;

  @HiveField(10)
  RoomStatus status;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime? gameStartedAt;

  @HiveField(13)
  int maxPlayers;

  @HiveField(14)
  bool isPrivate;

  @HiveField(15)
  String? password;

  @HiveField(16)
  bool isSynced;

  HiveOnlineRoom({
    required this.id,
    required this.roomName,
    required this.hostId,
    required this.hostName,
    required this.hostEmail,
    this.hostLevel = 1,
    this.guestId,
    this.guestName,
    this.guestEmail,
    this.guestLevel,
    required this.status,
    required this.createdAt,
    this.gameStartedAt,
    this.maxPlayers = 2,
    this.isPrivate = false,
    this.password,
    this.isSynced = false,
  });

  /// 기존 OnlineRoom에서 HiveOnlineRoom 생성
  factory HiveOnlineRoom.fromOnlineRoom(dynamic onlineRoom) {
    return HiveOnlineRoom(
      id: onlineRoom.id,
      roomName: onlineRoom.roomName,
      hostId: onlineRoom.hostId,
      hostName: onlineRoom.hostName,
      hostEmail: onlineRoom.hostEmail,
      hostLevel: onlineRoom.hostLevel ?? 1,
      guestId: onlineRoom.guestId,
      guestName: onlineRoom.guestName,
      guestEmail: onlineRoom.guestEmail,
      guestLevel: onlineRoom.guestLevel,
      status: onlineRoom.status,
      createdAt: onlineRoom.createdAt,
      gameStartedAt: onlineRoom.gameStartedAt,
      maxPlayers: onlineRoom.maxPlayers ?? 2,
      isPrivate: onlineRoom.isPrivate ?? false,
      password: onlineRoom.password,
      isSynced: true, // 온라인 데이터는 이미 동기화됨
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomName': roomName,
      'hostId': hostId,
      'hostName': hostName,
      'hostEmail': hostEmail,
      'hostLevel': hostLevel,
      'guestId': guestId,
      'guestName': guestName,
      'guestEmail': guestEmail,
      'guestLevel': guestLevel,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'gameStartedAt': gameStartedAt?.toIso8601String(),
      'maxPlayers': maxPlayers,
      'isPrivate': isPrivate,
      'password': password,
    };
  }

  /// 방이 가득 찼는지 확인
  bool get isFull => guestId != null;

  /// 방에 참가 가능한지 확인
  bool get canJoin => status == RoomStatus.waiting && !isFull;
}

/// 게임 타입 열거형
@HiveType(typeId: 4)
enum GameType {
  @HiveField(0)
  local,    // 로컬 게임
  @HiveField(1)
  online,   // 온라인 게임
}

/// 방 상태 열거형
@HiveType(typeId: 5)
enum RoomStatus {
  @HiveField(0)
  waiting,    // 대기 중
  @HiveField(1)
  ready,      // 준비 완료
  @HiveField(2)
  playing,    // 게임 진행 중
  @HiveField(3)
  finished,   // 게임 완료
  @HiveField(4)
  cancelled,  // 게임 취소
} 