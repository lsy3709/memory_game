import 'package:flutter/material.dart';
import '../models/card_model.dart';

/// 메모리 카드를 표시하는 위젯
class MemoryCard extends StatelessWidget {
  final CardModel card;
  final VoidCallback onTap;
  final bool isEnabled;

  const MemoryCard({
    super.key,
    required this.card,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: card.isMatched 
              ? Colors.grey.shade300 
              : card.isFlipped 
                  ? Colors.white 
                  : Colors.blue.shade400,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: card.isMatched 
                ? Colors.grey.shade500 
                : card.isFlipped 
                    ? Colors.blue.shade600 
                    : Colors.blue.shade600,
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
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            child: card.isFlipped
                ? _buildCardFace()
                : _buildCardBack(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  card.emoji,
                  style: const TextStyle(fontSize: 32.0),
                ),
              ),
            ),
          ),
        ),
        if (card.name != null && card.name!.isNotEmpty) ...[
          Expanded(
            flex: 1,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Text(
                    card.name!,
                    style: const TextStyle(
                      fontSize: 12.0, 
                      fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildCardBack() {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '❓',
            style: const TextStyle(fontSize: 32.0, color: Colors.white),
          ),
        ),
      ),
    );
  }
}