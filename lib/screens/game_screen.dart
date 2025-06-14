import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../services/sound_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game constants
  static const int rows = 8;              // 세로 8행
  static const int cols = 6;              // 가로 6열
  static const int numPairs = 24;
  static const int totalCards = numPairs * 2;
  static const int gameTimeSec = 15 * 60; // 15분

  // Game variables
  late List<CardModel> cards;
  int? firstSelectedIndex;
  int? secondSelectedIndex;
  int timeLeft = gameTimeSec;
  bool isGameRunning = false;
  bool isTimerPaused = false;
  late Timer gameTimer;
  final SoundService soundService = SoundService();

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    if (gameTimer.isActive) gameTimer.cancel();
    soundService.dispose();
    super.dispose();
  }

  void _initGame() {
    cards = [];
    _createCards();
    _setupTimer();
  }

  void _createCards() {
    cards.clear();
    for (int i = 0; i < numPairs; i++) {
      for (int j = 0; j < 2; j++) {
        cards.add(CardModel(
          id: i * 2 + j,
          pairId: i,
          imagePath: 'assets/flag_image/img${i + 1}.png',
        ));
      }
    }
    cards.shuffle();
  }

  void _setupTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isGameRunning && !isTimerPaused) {
        setState(() {
          if (timeLeft > 0) {
            timeLeft--;
          } else {
            _gameOver();
          }
        });
      }
    });
  }

  String _formatTime() {
    final mins = timeLeft ~/ 60;
    final secs = timeLeft % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _onCardTap(int index) {
    if (!isGameRunning || isTimerPaused) return;
    if (cards[index].isMatched || cards[index].isFlipped) return;
    if (firstSelectedIndex == index) return;
    if (firstSelectedIndex != null && secondSelectedIndex != null) return;

    soundService.playCardFlip();
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true);
      if (firstSelectedIndex == null) {
        firstSelectedIndex = index;
      } else {
        secondSelectedIndex = index;
        Future.microtask(_checkMatch);
      }
    });
  }

  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) return;
    final a = firstSelectedIndex!, b = secondSelectedIndex!;
    firstSelectedIndex = null;
    secondSelectedIndex = null;

    Future.delayed(const Duration(milliseconds: 700), () {
      setState(() {
        if (cards[a].pairId == cards[b].pairId) {
          soundService.playCardMatch();
          cards[a] = cards[a].copyWith(isMatched: true);
          cards[b] = cards[b].copyWith(isMatched: true);
          _checkGameEnd();
        } else {
          soundService.playCardMismatch();
          cards[a] = cards[a].copyWith(isFlipped: false);
          cards[b] = cards[b].copyWith(isFlipped: false);
        }
      });
    });
  }

  void _checkGameEnd() {
    if (cards.every((c) => c.isMatched)) {
      isGameRunning = false;
      gameTimer.cancel();
      soundService.stopBackgroundMusic();
      soundService.playGameWin();
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('축하합니다!'),
            content: const Text('모든 카드를 맞췄어요!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      });
    }
  }

  void _startGame() {
    if (isGameRunning && isTimerPaused) {
      setState(() => isTimerPaused = false);
      soundService.resumeBackgroundMusic();
      return;
    }
    soundService.playGameStart();
    setState(() {
      _createCards();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec;
      isGameRunning = true;
      isTimerPaused = false;
    });
    if (gameTimer.isActive) gameTimer.cancel();
    _setupTimer();
    soundService.startBackgroundMusic();
  }

  void _pauseGame() {
    if (!isGameRunning || isTimerPaused) return;
    setState(() => isTimerPaused = true);
    soundService.pauseBackgroundMusic();
  }

  void _resetGame() {
    soundService.playButtonSound();
    setState(() {
      _createCards();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
    });
    if (gameTimer.isActive) gameTimer.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  void _gameOver() {
    isGameRunning = false;
    gameTimer.cancel();
    soundService.stopBackgroundMusic();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('시간 초과!'),
        content: const Text('게임 오버'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모리 카드 게임'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 타이머 영역 패딩 축소
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            alignment: Alignment.center,
            child: Text(
              '남은 시간: ${_formatTime()}',
              style: const TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 카드 그리드: 화면에 딱 맞게, 스크롤 제거
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;
                  final gridHeight = constraints.maxHeight;
                  const spacing = 12.0;
                  final itemWidth =
                      (gridWidth - (cols - 1) * spacing) / cols;
                  final itemHeight =
                      (gridHeight - (rows - 1) * spacing) / rows;
                  final aspectRatio = itemWidth / itemHeight;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: totalCards,
                    itemBuilder: (context, index) {
                      return MemoryCard(
                        card: cards[index],
                        onTap: () => _onCardTap(index),
                        isEnabled: isGameRunning && !isTimerPaused,
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 버튼 영역 패딩 축소
          Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    soundService.playButtonSound();
                    _startGame();
                  },
                  child: Text(isGameRunning && isTimerPaused
                      ? '계속하기'
                      : '시작'),
                ),
                ElevatedButton(
                  onPressed: isGameRunning && !isTimerPaused
                      ? () {
                    soundService.playButtonSound();
                    _pauseGame();
                  }
                      : null,
                  child: const Text('멈춤'),
                ),
                ElevatedButton(
                  onPressed: _resetGame,
                  child: const Text('다시하기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
