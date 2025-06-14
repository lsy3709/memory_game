class CardModel {
  final int id;
  final int pairId;
  final String imagePath;
  bool isFlipped;
  bool isMatched;

  CardModel({
    required this.id,
    required this.pairId,
    required this.imagePath,
    this.isFlipped = false,
    this.isMatched = false,
  });

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