import 'package:flutter/material.dart';
import '../models/card_model.dart';

class MemoryCard extends StatelessWidget {
  final CardModel card;
  final VoidCallback onTap;
  final bool isEnabled;

  const MemoryCard({
    super.key,
    required this.card,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled && !card.isMatched ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getBorderColor(),
            width: 3,
          ),
        ),
        child: _buildCardContent(),
      ),
    );
  }

  Color _getCardColor() {
    if (card.isMatched) {
      return Colors.white;
    } else if (card.isFlipped) {
      return Colors.white;
    } else {
      return Colors.lightBlue.shade100;
    }
  }

  Color _getBorderColor() {
    if (card.isMatched) {
      return Colors.green;
    } else if (card.isFlipped) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildCardContent() {
    if (card.isFlipped || card.isMatched) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          card.imagePath,
          fit: BoxFit.contain,
        ),
      );
    } else {
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