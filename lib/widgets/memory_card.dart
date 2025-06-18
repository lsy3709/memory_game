import 'package:flutter/material.dart';
import '../models/card_model.dart';

// MemoryCard 위젯: 메모리 게임의 개별 카드를 나타내는 StatelessWidget
class MemoryCard extends StatelessWidget {
  final CardModel card;           // 카드의 상태와 이미지를 담은 모델
  final VoidCallback onTap;       // 카드 클릭 시 호출되는 콜백 함수
  final bool isEnabled;           // 카드가 클릭 가능한지 여부

  const MemoryCard({
    super.key,
    required this.card,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    // 카드 전체를 GestureDetector로 감싸 터치 이벤트 처리
    return GestureDetector(
      // 카드가 활성화되어 있고, 이미 맞춘 카드가 아니면 onTap 실행
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // 애니메이션 지속 시간
        curve: Curves.easeInOut,                     // 애니메이션 곡선
        decoration: BoxDecoration(
          color: _getCardColor(),                    // 카드 배경색 결정
          borderRadius: BorderRadius.circular(8),    // 모서리 둥글게
          border: Border.all(
            color: _getBorderColor(),                // 테두리 색상 결정
            width: 3,                                // 테두리 두께
          ),
        ),
        child: _buildCardContent(),                  // 카드 내부 내용 위젯
      ),
    );
  }

  // 카드의 배경색 반환
  Color _getCardColor() {
    if (card.isMatched) {
      return Colors.white;                           // 맞춘 카드는 흰색
    } else if (card.isFlipped) {
      return Colors.white;                           // 뒤집힌 카드도 흰색
    } else {
      return Colors.lightBlue.shade100;              // 기본은 연한 파란색
    }
  }

  // 카드의 테두리 색상 반환
  Color _getBorderColor() {
    if (card.isMatched) {
      return Colors.green;                           // 맞춘 카드는 초록색
    } else if (card.isFlipped) {
      return Colors.red;                             // 뒤집힌 카드는 빨간색
    } else {
      return Colors.grey;                            // 기본은 회색
    }
  }

  // 카드 내부에 표시할 내용 반환
  Widget _buildCardContent() {
    if (card.isFlipped || card.isMatched) {
      // 뒤집혔거나 맞춘 카드면 이미지를 보여줌
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          card.imagePath,                            // 카드 이미지 경로
          fit: BoxFit.contain,
        ),
      );
    } else {
      // 아니면 물음표 아이콘 표시
      return const Center(
        child: Icon(
          Icons.question_mark,
          size: 40.0,
          color: Colors.blue,
        ),
      );
    }
  }
}