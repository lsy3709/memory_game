/// 카드 정보를 나타내는 모델 클래스
class CardModel {
  /// 카드의 고유 ID
  final int id;

  /// 짝을 이루는 카드의 ID
  final int pairId;

  /// 카드 이미지 경로
  final String imagePath;

  /// 카드가 뒤집혀 있는지 여부
  bool isFlipped;

  /// 카드가 매칭되었는지 여부
  bool isMatched;

  /// CardModel 생성자
  CardModel({
    required this.id,
    required this.pairId,
    required this.imagePath,
    this.isFlipped = false,
    this.isMatched = false,
  });

  /// CardModel의 복사본을 생성하되, 일부 필드만 변경할 수 있음
  CardModel copyWith({
    int? id,
    int? pairId,
    String? imagePath,
    bool? isFlipped,
    bool? isMatched,
  }) {
    return CardModel(
      id: id ?? this.id,
      pairId: pairId ?? this.pairId,
      imagePath: imagePath ?? this.imagePath,
      isFlipped: isFlipped ?? this.isFlipped,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}