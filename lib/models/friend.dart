import 'package:cloud_firestore/cloud_firestore.dart';

/// 친구 관계 모델
class Friend {
  final String id;                    // 친구 관계 고유 ID
  final String userId;                // 사용자 ID
  final String friendId;              // 친구 ID
  final String userName;              // 사용자 이름
  final String userEmail;             // 사용자 이메일
  final String friendName;            // 친구 이름
  final String friendEmail;           // 친구 이메일
  final FriendStatus status;          // 친구 상태
  final DateTime createdAt;           // 친구 요청 시간
  final DateTime? acceptedAt;         // 친구 수락 시간
  final DateTime? lastGameAt;         // 마지막 게임 시간

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.userName,
    required this.userEmail,
    required this.friendName,
    required this.friendEmail,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.lastGameAt,
  });

  /// JSON으로부터 Friend 객체 생성
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      userId: json['userId'] as String,
      friendId: json['friendId'] as String,
      userName: json['userName'] as String,
      userEmail: json['userEmail'] as String,
      friendName: json['friendName'] as String,
      friendEmail: json['friendEmail'] as String,
      status: FriendStatus.values.firstWhere(
        (e) => e.toString() == 'FriendStatus.${json['status']}',
        orElse: () => FriendStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      acceptedAt: json['acceptedAt'] != null 
          ? (json['acceptedAt'] as Timestamp).toDate() 
          : null,
      lastGameAt: json['lastGameAt'] != null 
          ? (json['lastGameAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Friend 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'userName': userName,
      'userEmail': userEmail,
      'friendName': friendName,
      'friendEmail': friendEmail,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'lastGameAt': lastGameAt != null ? Timestamp.fromDate(lastGameAt!) : null,
    };
  }

  /// 친구 요청을 보낸 사람인지 확인
  bool isRequester(String currentUserId) => userId == currentUserId;

  /// 친구 요청을 받은 사람인지 확인
  bool isReceiver(String currentUserId) => friendId == currentUserId;

  /// 상대방 정보 가져오기
  String getOtherUserName(String currentUserId) {
    if (isRequester(currentUserId)) {
      return friendName;
    } else if (isReceiver(currentUserId)) {
      return userName;
    }
    return '';
  }

  /// 상대방 이메일 가져오기
  String getOtherUserEmail(String currentUserId) {
    if (isRequester(currentUserId)) {
      return friendEmail;
    } else if (isReceiver(currentUserId)) {
      return userEmail;
    }
    return '';
  }

  /// 상대방 ID 가져오기
  String getOtherUserId(String currentUserId) {
    if (isRequester(currentUserId)) {
      return friendId;
    } else if (isReceiver(currentUserId)) {
      return userId;
    }
    return '';
  }

  /// 친구 관계가 활성화되었는지 확인
  bool get isActive => status == FriendStatus.accepted;

  /// 친구 요청 대기 중인지 확인
  bool get isPending => status == FriendStatus.pending;

  /// 친구 요청이 거부되었는지 확인
  bool get isRejected => status == FriendStatus.rejected;

  /// Friend 복사본 생성 (상태 변경용)
  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? userName,
    String? userEmail,
    String? friendName,
    String? friendEmail,
    FriendStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? lastGameAt,
  }) {
    return Friend(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      friendName: friendName ?? this.friendName,
      friendEmail: friendEmail ?? this.friendEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      lastGameAt: lastGameAt ?? this.lastGameAt,
    );
  }
}

/// 친구 상태 열거형
enum FriendStatus {
  pending,    // 친구 요청 대기 중
  accepted,   // 친구 요청 수락됨
  rejected,   // 친구 요청 거부됨
  blocked,    // 차단됨
} 