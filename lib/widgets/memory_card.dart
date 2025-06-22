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
          final double iconSize = (cardHeight * 0.4).clamp(20.0, 60.0); // 아이콘 크기 제한
          final double fontSize = (cardHeight * 0.12).clamp(8.0, 16.0); // 폰트 크기 제한

          return Container(
            margin: const EdgeInsets.all(2),
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
                child: card.isFlipped
                    ? Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                card.emoji,
                                style: TextStyle(fontSize: iconSize),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (card.name != null && card.name!.isNotEmpty) ...[
                              SizedBox(height: cardHeight * 0.02),
                              Flexible(
                                child: Text(
                                  card.name!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
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