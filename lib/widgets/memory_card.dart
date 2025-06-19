import 'package:flutter/material.dart';
import '../models/card_model.dart';

// MemoryCard 위젯: 메모리 게임의 개별 카드를 나타내는 StatelessWidget
class MemoryCard extends StatelessWidget {
  final CardModel card;           // 카드의 상태와 이미지를 담은 모델
  final VoidCallback? onTap;       // 카드 클릭 시 호출되는 콜백 함수
  final bool isEnabled;           // 카드가 클릭 가능한지 여부

  const MemoryCard({
    super.key,
    required this.card,
    this.onTap,
    this.isEnabled = true,
  });

  /// 카드 내용이 이미지인지 이모지인지 확인
  bool get _isImage => card.emoji.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: card.isMatched
                ? Colors.green.shade100
                : card.isFlipped
                ? Colors.white
                : Colors.blue.shade600,
            border: card.isMatched
                ? Border.all(color: Colors.green, width: 2)
                : null,
          ),
          child: Center(
            // FittedBox로 셀 크기에 맞춰 내부를 축소
            child: FittedBox(
              fit: BoxFit.contain,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: card.isFlipped || card.isMatched ? 1.0 : 0.0,
                child: (card.isFlipped || card.isMatched)
                    ? _isImage
                    ? Image.asset(
                  card.emoji,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, e, st) => _buildCardContent(),
                )
                    : _buildCardContent()
                    : const Text(
                  '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          card.emoji,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (card.name != null && card.name!.isNotEmpty) ...[
          const SizedBox(height: 2),
          // Flexible로 텍스트가 너무 길면 말줄임 처리
          Flexible(
            child: Text(
              card.name!,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}