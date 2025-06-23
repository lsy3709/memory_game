import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flip_card/flip_card_controller.dart';
import '../models/card_model.dart';

// MemoryCard 위젯: 메모리 게임의 개별 카드를 나타내는 StatelessWidget
class MemoryCard extends StatelessWidget {
  final CardModel card;           // 카드의 상태와 이미지를 담은 모델
  final VoidCallback onTap;        // 카드 클릭 시 호출되는 콜백 함수
  final FlipCardController? controller; // 컨트롤러를 옵셔널로 받음
  final bool isEnabled;           // 카드가 클릭 가능한지 여부
  final double? cardWidth;        // 카드의 정확한 너비
  final double? cardHeight;       // 카드의 정확한 높이

  const MemoryCard({
    super.key,
    required this.card,
    required this.onTap,
    this.controller, // 생성자에 컨트롤러 추가
    this.isEnabled = true,
    this.cardWidth,
    this.cardHeight,
  });

  /// 카드 내용이 이미지인지 이모지인지 확인
  bool get _isImage => card.emoji.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return FlipCard(
      key: key, // FlipCard 위젯은 자체 key를 사용하므로 전달받은 key를 사용
      controller: controller, // 전달받은 컨트롤러 사용
      flipOnTouch: false, // 탭으로 뒤집는 기능은 비활성화
      front: _buildCardContent(context, true), // 카드 앞면
      back: _buildCardContent(context, false), // 카드 뒷면
    );
  }

  Widget _buildCardContent(BuildContext context, bool isFront) {
    // isFront가 true이면 카드 뒷면(물음표)을, false이면 카드 앞면(이모지)을 보여줌
    // FlipCard의 front/back과 우리 로직의 isFlipped 상태를 맞추기 위함
    final content = isFront ? '❓' : card.emoji;
    final backgroundColor = isFront ? Colors.blue.shade400 : Colors.white;
    final cardName = card.name;

    return GestureDetector(
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: card.isMatched ? Colors.grey.shade300 : backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: card.isMatched ? Colors.grey.shade500 : Colors.blue.shade600,
            width: 2,
          ),
          boxShadow: [
            if (!card.isMatched)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
          ],
        ),
        child: Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      content,
                      style: const TextStyle(fontSize: 32.0),
                    ),
                  ),
                ),
              ),
              if (!isFront && cardName != null && cardName.isNotEmpty) ...[
                Expanded(
                  flex: 1,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        cardName,
                        style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}