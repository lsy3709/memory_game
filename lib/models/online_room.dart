import 'package:cloud_firestore/cloud_firestore.dart';

/// 온라인 멀티플레이어 게임 방 모델
class OnlineRoom {
  final String id;                    // 방 고유 ID
  final String roomName;              // 방 이름
  final String hostId;                // 방장 ID
  final String hostName;              // 방장 이름
  final String hostEmail;             // 방장 이메일
  final String? guestId;              // 게스트 ID (참가자)
  final String? guestName;            // 게스트 이름
  final String? guestEmail;           // 게스트 이메일
  final RoomStatus status;            // 방 상태
  final DateTime createdAt;           // 생성 시간
  final DateTime? gameStartedAt;      // 게임 시작 시간
  final int maxPlayers;               // 최대 플레이어 수
  final bool isPrivate;               // 비공개 방 여부
  final String? password;             // 비밀번호 (비공개 방인 경우)

  OnlineRoom({
    required this.id,
    required this.roomName,
    required this.hostId,
    required this.hostName,
    required this.hostEmail,
    this.guestId,
    this.guestName,
    this.guestEmail,
    required this.status,
    required this.createdAt,
    this.gameStartedAt,
    this.maxPlayers = 2,
    this.isPrivate = false,
    this.password,
  });

  /// JSON으로부터 OnlineRoom 객체 생성
  factory OnlineRoom.fromJson(Map<String, dynamic> json) {
    return OnlineRoom(
      id: json['id'] as String,
      roomName: json['roomName'] as String,
      hostId: json['hostId'] as String,
      hostName: json['hostName'] as String,
      hostEmail: json['hostEmail'] as String,
      guestId: json['guestId'] as String?,
      guestName: json['guestName'] as String?,
      guestEmail: json['guestEmail'] as String?,
      status: RoomStatus.values.firstWhere(
        (e) => e.toString() == 'RoomStatus.${json['status']}',
        orElse: () => RoomStatus.waiting,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      gameStartedAt: json['gameStartedAt'] != null 
          ? (json['gameStartedAt'] as Timestamp).toDate() 
          : null,
      maxPlayers: json['maxPlayers'] as int? ?? 2,
      isPrivate: json['isPrivate'] as bool? ?? false,
      password: json['password'] as String?,
    );
  }

  /// OnlineRoom 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomName': roomName,
      'hostId': hostId,
      'hostName': hostName,
      'hostEmail': hostEmail,
      'guestId': guestId,
      'guestName': guestName,
      'guestEmail': guestEmail,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'gameStartedAt': gameStartedAt != null ? Timestamp.fromDate(gameStartedAt!) : null,
      'maxPlayers': maxPlayers,
      'isPrivate': isPrivate,
      'password': password,
    };
  }

  /// 방이 가득 찼는지 확인
  bool get isFull => guestId != null;

  /// 방에 참가 가능한지 확인
  bool get canJoin => status == RoomStatus.waiting && !isFull;

  /// 방장인지 확인
  bool isHost(String userId) => hostId == userId;

  /// 게스트인지 확인
  bool isGuest(String userId) => guestId == userId;

  /// 방에 참가 중인지 확인
  bool isInRoom(String userId) => isHost(userId) || isGuest(userId);

  /// 다른 플레이어 정보 가져오기
  String? getOtherPlayerName(String currentUserId) {
    if (isHost(currentUserId)) {
      return guestName;
    } else if (isGuest(currentUserId)) {
      return hostName;
    }
    return null;
  }

  /// 다른 플레이어 이메일 가져오기
  String? getOtherPlayerEmail(String currentUserId) {
    if (isHost(currentUserId)) {
      return guestEmail;
    } else if (isGuest(currentUserId)) {
      return hostEmail;
    }
    return null;
  }

  /// 방 복사본 생성 (상태 변경용)
  OnlineRoom copyWith({
    String? id,
    String? roomName,
    String? hostId,
    String? hostName,
    String? hostEmail,
    String? guestId,
    String? guestName,
    String? guestEmail,
    RoomStatus? status,
    DateTime? createdAt,
    DateTime? gameStartedAt,
    int? maxPlayers,
    bool? isPrivate,
    String? password,
  }) {
    return OnlineRoom(
      id: id ?? this.id,
      roomName: roomName ?? this.roomName,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostEmail: hostEmail ?? this.hostEmail,
      guestId: guestId ?? this.guestId,
      guestName: guestName ?? this.guestName,
      guestEmail: guestEmail ?? this.guestEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      gameStartedAt: gameStartedAt ?? this.gameStartedAt,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isPrivate: isPrivate ?? this.isPrivate,
      password: password ?? this.password,
    );
  }
}

/// 방 상태 열거형
enum RoomStatus {
  waiting,    // 대기 중 (플레이어 모집)
  playing,    // 게임 진행 중
  finished,   // 게임 완료
  cancelled,  // 게임 취소
} 