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
    return InkWell(
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 카드의 높이를 기준으로 폰트와 아이콘 크기를 동적으로 계산
          final double cardHeight = constraints.maxHeight;
          final double cardWidth = constraints.maxWidth;
          final double iconSize = (cardHeight * 0.5).clamp(20.0, 80.0); // 아이콘 크기 조정
          final double fontSize = (cardHeight * 0.15).clamp(8.0, 20.0); // 폰트 크기 조정

          return Container(
            margin: const EdgeInsets.all(1), // 최소 마진
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4), // 작은 둥근 모서리
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
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
                child: card.isFlipped
                    ? Padding(
                        padding: const EdgeInsets.all(2.0), // 최소 패딩
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.emoji,
                              style: TextStyle(fontSize: iconSize),
                              textAlign: TextAlign.center,
                            ),
                            if (card.name != null && card.name!.isNotEmpty) ...[
                              SizedBox(height: cardHeight * 0.02),
                              Text(
                                card.name!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ],
                        ),
                      )
                    : Icon(
                        Icons.question_mark,
                        color: Colors.white,
                        size: iconSize,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}