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

  @override
  Widget build(BuildContext context) {
    // 카드 전체를 GestureDetector로 감싸 터치 이벤트 처리
    return GestureDetector(
      // 카드가 활성화되어 있고, 이미 맞춘 카드가 아니면 onTap 실행
      onTap: isEnabled && card.isEnabled ? onTap : null,
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
          duration: const Duration(milliseconds: 300), // 애니메이션 지속 시간
          curve: Curves.easeInOut,                     // 애니메이션 곡선
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
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: card.isFlipped || card.isMatched ? 1.0 : 0.0,
              child: card.isMatched || card.isFlipped
                  ? Text(
                      card.emoji,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    )
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
    );
  }
}