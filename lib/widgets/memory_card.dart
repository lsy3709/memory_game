import 'package:flutter/material.dart';
import '../models/card_model.dart';

// MemoryCard 위젯: 메모리 게임의 개별 카드를 나타내는 StatelessWidget
class MemoryCard extends StatelessWidget {
  final CardModel card;           // 카드의 상태와 이미지를 담은 모델
  final VoidCallback? onTap;       // 카드 클릭 시 호출되는 콜백 함수
  final bool isEnabled;           // 카드가 클릭 가능한지 여부
  final double? cardWidth;        // 카드의 정확한 너비
  final double? cardHeight;       // 카드의 정확한 높이

  const MemoryCard({
    super.key,
    required this.card,
    this.onTap,
    this.isEnabled = true,
    this.cardWidth,
    this.cardHeight,
  });

  /// 카드 내용이 이미지인지 이모지인지 확인
  bool get _isImage => card.emoji.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: card.isMatched
              ? Colors.green.shade100
              : card.isFlipped
                  ? Colors.white
                  : Colors.blue.shade600,
          border: Border.all(
            color: card.isMatched ? Colors.green.shade400 : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: card.isFlipped
            ? _buildCardFace()
            : _buildCardBack(),
      ),
    );
  }

  Widget _buildCardFace() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          flex: 8,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  card.emoji,
                  style: const TextStyle(fontSize: 100), // 큰 기본값, FittedBox가 줄여줌
                ),
              ),
            ),
          ),
        ),
        if (card.name != null && card.name!.isNotEmpty)
          Expanded(
            flex: 2,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Text(
                    card.name!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20, // 큰 기본값, FittedBox가 줄여줌
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardBack() {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.question_mark, color: Colors.white, size: 100),
        ),
      ),
    );
  }
}