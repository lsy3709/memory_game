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
                  ? _isImage
                      ? Image.asset(
                          card.emoji,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // 이미지 로드 실패 시 이모지로 대체
                            return _buildCardContent();
                          },
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
    );
  }

  /// 카드 내용 위젯 (국기와 이름)
  Widget _buildCardContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 국기 이모지
        Text(
          card.emoji,
          style: const TextStyle(
            fontSize: 24, // 국기 크기 조정
            fontWeight: FontWeight.bold,
          ),
        ),
        // 이름 (있는 경우에만 표시)
        if (card.name != null && card.name!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            card.name!,
            style: const TextStyle(
              fontSize: 8, // 이름 크기 (작게)
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}