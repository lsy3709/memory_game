/// 카드 정보를 나타내는 모델 클래스
class CardModel {
  /// 카드의 고유 ID
  final int id;

  /// 카드의 이모지
  final String emoji;

  /// 카드의 이름 (국기 이름 등)
  final String? name;

  /// 카드가 뒤집혀 있는지 여부
  bool isFlipped;

  /// 카드가 매칭되었는지 여부
  bool isMatched;

  /// 카드가 활성화되었는지 여부
  bool isEnabled;

  /// CardModel 생성자
  CardModel({
    required this.id,
    required this.emoji,
    this.name,
    this.isFlipped = false,
    this.isMatched = false,
    this.isEnabled = true,
  });

  /// 카드 뒤집기
  void flip() {
    if (!isMatched && isEnabled) {
      isFlipped = !isFlipped;
    }
  }

  /// 카드 매치 설정
  void setMatched(bool matched) {
    isMatched = matched;
    if (matched) {
      isFlipped = true;
    }
  }

  /// 카드 비활성화
  void setEnabled(bool enabled) {
    isEnabled = enabled;
  }

  /// CardModel의 복사본을 생성하되, 일부 필드만 변경할 수 있음
  CardModel copyWith({
    int? id,
    String? emoji,
    String? name,
    bool? isFlipped,
    bool? isMatched,
    bool? isEnabled,
  }) {
    return CardModel(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      isFlipped: isFlipped ?? this.isFlipped,
      isMatched: isMatched ?? this.isMatched,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'name': name,
      'isFlipped': isFlipped,
      'isMatched': isMatched,
      'isEnabled': isEnabled,
    };
  }

  /// JSON에서 생성
  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] ?? 0,
      emoji: json['emoji'] ?? '❓',
      name: json['name'],
      isFlipped: json['isFlipped'] ?? false,
      isMatched: json['isMatched'] ?? false,
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CardModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}