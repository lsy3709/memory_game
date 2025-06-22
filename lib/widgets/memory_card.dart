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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 제공된 크기 또는 제약 조건에서 크기 가져오기
          final double actualCardWidth = cardWidth ?? constraints.maxWidth;
          final double actualCardHeight = cardHeight ?? constraints.maxHeight;
          
          // 카드 크기에 따른 요소 크기 계산
          final double iconSize = (actualCardHeight * 0.35).clamp(12.0, 32.0);
          final double fontSize = (actualCardHeight * 0.10).clamp(6.0, 10.0);
          final double padding = (actualCardHeight * 0.05).clamp(1.0, 4.0);
          final double borderRadius = (actualCardHeight * 0.08).clamp(2.0, 6.0);

          return Container(
            width: actualCardWidth,
            height: actualCardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                color: card.isMatched
                    ? Colors.green.shade100
                    : card.isFlipped
                    ? Colors.white
                    : Colors.blue.shade600,
                border: card.isMatched
                    ? Border.all(color: Colors.green, width: 1)
                    : null,
              ),
              child: Center(
                child: card.isFlipped
                    ? Padding(
                        padding: EdgeInsets.all(padding),
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
                              SizedBox(height: actualCardHeight * 0.02),
                              Flexible(
                                child: Text(
                                  card.name!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
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