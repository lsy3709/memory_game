import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/game_record.dart';
import '../models/player_stats.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import 'package:memory_game/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

/// 메모리 카드 게임의 메인 화면을 담당하는 StatefulWidget
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

/// 게임의 상태와 로직을 관리하는 State 클래스
class _GameScreenState extends State<GameScreen> {
  // 게임 설정 상수
  static const int rows = 8;              // 카드 그리드의 행 수
  static const int cols = 6;              // 카드 그리드의 열 수
  static const int numPairs = 24;         // 카드 쌍의 개수
  static const int totalCards = numPairs * 2; // 전체 카드 수
  static const int gameTimeSec = 15 * 60; // 게임 제한 시간(초 단위, 15분)

  // 게임 상태 변수
  List<CardModel> cards = [];
  int? firstSelectedIndex;
  int? secondSelectedIndex;
  bool isGameRunning = false;
  bool isTimerPaused = false;
  Timer? gameTimer;
  int timeLeft = 180; // 3분
  int maxCombo = 0;
  final SoundService soundService = SoundService.instance; // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final StorageService storageService = StorageService.instance; // 저장소 관리
  
  // 기록 관련 변수
  String currentPlayerName = '게스트';     // 현재 플레이어 이름
  String currentPlayerEmail = '';         // 현재 플레이어 이메일
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간

  @override
  void initState() {
    super.initState();
    scoreModel = ScoreModel();
    _loadPlayerInfo();
    _createCards();
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  @override
  void dispose() {
    // 타이머 정리
    try {
      if (gameTimer?.isActive == true) {
        gameTimer?.cancel();
        print('로컬 게임 타이머 정리 완료');
      }
    } catch (e) {
      print('로컬 타이머 정리 오류: $e');
    }
    
    // 사운드 리소스 해제
    try {
      soundService.dispose();
      print('로컬 사운드 서비스 정리 완료');
    } catch (e) {
      print('로컬 사운드 서비스 정리 오류: $e');
    }
    
    // 상태 변수 초기화
    isGameRunning = false;
    isTimerPaused = false;
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    print('GameScreen dispose 완료');
    super.dispose();
  }

  /// 플레이어 정보 로드
  Future<void> _loadPlayerInfo() async {
    try {
      final playerInfo = await storageService.loadCurrentPlayer();
      if (playerInfo != null) {
        setState(() {
          currentPlayerName = playerInfo['playerName'] ?? '게스트';
          currentPlayerEmail = playerInfo['email'] ?? '';
        });
      }
    } catch (e) {
      print('플레이어 정보 로드 오류: $e');
    }
  }

  /// 카드 생성 및 섞기
  void _createCards() {
    final List<CardModel> tempCards = [];
    
    // 카드 쌍 생성
    for (int i = 0; i < numPairs; i++) {
      tempCards.add(CardModel(
        id: i,
        emoji: _getEmoji(i),
        isMatched: false,
        isFlipped: false,
      ));
      tempCards.add(CardModel(
        id: i,
        emoji: _getEmoji(i),
        isMatched: false,
        isFlipped: false,
      ));
    }
    
    // 카드 섞기
    tempCards.shuffle(Random());
    
    setState(() {
      cards = tempCards;
    });
  }

  /// 1초마다 남은 시간을 감소시키는 타이머 설정
  void _setupTimer() {
    // 기존 타이머가 있다면 취소
    if (gameTimer?.isActive == true) {
      gameTimer?.cancel();
    }
    
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // mounted 상태 확인 후 setState 호출
      if (mounted && isGameRunning && !isTimerPaused) {
        setState(() {
          if (timeLeft > 0) {
            timeLeft--; // 남은 시간 감소
          } else {
            _gameOver(); // 시간 종료 시 게임 오버
          }
        });
      }
    });
  }

  /// 남은 시간을 mm:ss 형식으로 반환
  String _formatTime() {
    final mins = timeLeft ~/ 60;
    final secs = timeLeft % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 카드가 터치되었을 때 처리
  void _onCardTap(int index) {
    // 게임이 진행 중이 아니거나 일시정지, 이미 뒤집힌/맞춘 카드, 같은 카드 두 번 클릭, 두 장 이미 선택된 경우 무시
    if (!isGameRunning || isTimerPaused) return;
    if (cards[index].isMatched || cards[index].isFlipped) return;
    if (firstSelectedIndex == index) return;
    if (firstSelectedIndex != null && secondSelectedIndex != null) return;

    soundService.playCardFlip(); // 카드 뒤집기 사운드
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true); // 카드 뒤집기
      if (firstSelectedIndex == null) {
        firstSelectedIndex = index; // 첫 번째 카드 선택
      } else {
        secondSelectedIndex = index; // 두 번째 카드 선택
        Future.microtask(_checkMatch); // 매칭 검사 예약
      }
    });
  }

  /// 카드 매칭 확인
  void _checkMatch() {
    final firstCard = cards[firstSelectedIndex!];
    final secondCard = cards[secondSelectedIndex!];
    
    if (firstCard.id == secondCard.id) {
      // 매칭 성공
      _handleMatchSuccess();
    } else {
      // 매칭 실패
      _handleMatchFailure();
    }
  }

  /// 매칭 성공 처리
  void _handleMatchSuccess() {
    soundService.playMatchSound();
    
    setState(() {
      cards[firstSelectedIndex!].isMatched = true;
      cards[secondSelectedIndex!].isMatched = true;
      
      // 점수 증가
      scoreModel.addMatch();
      
      // 연속 매칭 기록 업데이트
      if (scoreModel.currentCombo > maxCombo) {
        maxCombo = scoreModel.currentCombo;
      }
    });
    
    // 선택된 카드 초기화
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    // 게임 완료 확인
    _checkGameCompletion();
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    soundService.playMismatchSound();
    
    setState(() {
      // 실패 횟수 증가
      scoreModel.addFail();
    });
    
    // 1초 후 카드 뒤집기
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          cards[firstSelectedIndex!].isFlipped = false;
          cards[secondSelectedIndex!].isFlipped = false;
          firstSelectedIndex = null;
          secondSelectedIndex = null;
        });
      }
    });
  }

  /// 모든 카드가 매칭되었는지 확인 후 게임 종료 처리
  void _checkGameCompletion() {
    if (cards.every((c) => c.isMatched)) {
      isGameRunning = false;
      gameTimer?.cancel(); // 타이머 중지
      soundService.stopBackgroundMusic(); // 배경음악 중지
      soundService.playGameWin(); // 승리 사운드
      
      // 게임 기록 저장
      _saveGameRecord(true);
      
      // 0.5초 후 축하 다이얼로그 표시
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('축하합니다!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('모든 카드를 맞췄어요!'),
                const SizedBox(height: 8),
                Text('최종 점수: ${scoreModel.score}점'),
                Text('최고 연속 매칭: ${maxCombo}회'),
                Text('완료 시간: ${_formatTime()}'),
              ],
            ),
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

  /// 게임 기록 저장
  Future<void> _saveGameRecord(bool isCompleted) async {
    try {
      final gameRecord = GameRecord(
        id: storageService.generateId(),
        playerName: currentPlayerName,
        email: currentPlayerEmail,
        score: scoreModel.score,
        matchCount: scoreModel.matchCount,
        failCount: scoreModel.failCount,
        maxCombo: maxCombo,
        timeLeft: timeLeft,
        totalTime: gameTimeSec,
        createdAt: DateTime.now(),
        isCompleted: isCompleted,
      );

      // 게임 기록 저장
      await storageService.saveGameRecord(gameRecord);

      // 플레이어 통계 업데이트 (등록된 플레이어인 경우)
      if (currentPlayerEmail.isNotEmpty) {
        final playerStats = await storageService.loadPlayerStats();
        if (playerStats != null) {
          final updatedStats = playerStats.updateWithGameResult(
            score: scoreModel.score,
            gameTime: gameTimeSec - timeLeft,
            maxCombo: maxCombo,
            matchCount: scoreModel.matchCount,
            failCount: scoreModel.failCount,
            isWin: isCompleted,
          );
          await storageService.savePlayerStats(updatedStats);
        }
      }
    } catch (e) {
      print('게임 기록 저장 오류: $e');
    }
  }

  /// 이모지 가져오기
  String _getEmoji(int index) {
    final emojis = [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
      '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔',
      '🐧', '🐦', '🐤', '🦆', '🦅', '🦉', '🦇', '🐺'
    ];
    return emojis[index % emojis.length];
  }

  /// 게임 결과 다이얼로그 표시
  void _showGameResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('게임 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('모든 카드를 맞췄어요!'),
            const SizedBox(height: 8),
            Text('최종 점수: ${scoreModel.score}점'),
            Text('최고 연속 매칭: ${maxCombo}회'),
            Text('완료 시간: ${_formatTime()}'),
            if (scoreModel.score > 0)
              const Text('새로운 최고 점수!', style: TextStyle(color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 게임 일시정지
  void _pauseGame() {
    setState(() {
      isTimerPaused = true;
    });
    soundService.stopAllSounds();
  }

  /// 게임 재개
  void _resumeGame() {
    setState(() {
      isTimerPaused = false;
    });
    soundService.playBackgroundMusic();
  }

  /// 게임 시작
  void _startGame() {
    soundService.playGameStartSound();
    setState(() {
      _createCards();
      timeLeft = 180;
      isGameRunning = true;
      isTimerPaused = false;
      scoreModel.reset();
      maxCombo = 0;
    });
    soundService.playBackgroundMusic();
  }

  /// 게임 일시정지/재개 토글
  void _togglePause() {
    if (isTimerPaused) {
      _resumeGame();
    } else {
      _pauseGame();
    }
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    soundService.playButtonClickSound();
    setState(() {
      _createCards();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      maxCombo = 0; // 최고 연속 매칭 기록 초기화
      scoreModel.reset(); // 점수 초기화
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  /// 시간 초과 시 게임 오버 처리
  void _gameOver() {
    setState(() {
      isGameRunning = false;
    });
    
    soundService.stopAllSounds();
    soundService.playGameOverSound();
    
    // 게임 기록 저장
    _saveGameRecord(false);
    
    // 게임 결과 다이얼로그 표시
    _showGameResultDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모리 카드 게임'),
        centerTitle: true,
        actions: [
          // 랭킹 보드 버튼
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.of(context).pushNamed('/ranking');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 게임 정보 영역
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 시간 표시
                Text(
                  '남은 시간: ${_formatTime()}',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 점수 표시
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '점수: ${scoreModel.score}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (scoreModel.currentCombo > 1)
                      Text(
                        '${scoreModel.currentCombo}콤보!',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (maxCombo > 0)
                      Text(
                        '최고 콤보: $maxCombo',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 카드 그리드 영역
          // 화면의 남은 공간을 모두 차지하도록 Expanded로 감쌈
          Expanded(
            child: Padding(
              // 좌우에 16픽셀씩 여백 추가
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LayoutBuilder(
                // LayoutBuilder로 실제 그리드 영역의 크기 계산
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;   // 가용 너비
                  final gridHeight = constraints.maxHeight; // 가용 높이
                  const spacing = 12.0;                     // 카드 사이 간격
                  // 각 카드의 가로/세로 크기 계산
                  final itemWidth =
                      (gridWidth - (cols - 1) * spacing) / cols;
                  final itemHeight =
                      (gridHeight - (rows - 1) * spacing) / rows;
                  final aspectRatio = itemWidth / itemHeight; // 카드 비율

                  // 그리드 형태로 카드 목록을 표시
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(), // 스크롤 비활성화
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,                // 열 개수 지정
                      childAspectRatio: aspectRatio,        // 카드 비율 적용
                      crossAxisSpacing: spacing,            // 열 간격
                      mainAxisSpacing: spacing,             // 행 간격
                    ),
                    itemCount: totalCards,                  // 전체 카드 개수
                    itemBuilder: (context, index) {
                      // 각 카드에 대한 위젯 생성
                      return MemoryCard(
                        card: cards[index],                 // 카드 데이터 전달
                        onTap: () => _onCardTap(index),     // 카드 터치 시 콜백
                        isEnabled: isGameRunning && !isTimerPaused, // 활성화 여부
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 하단 버튼 영역
          Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 시작/계속하기 버튼
                ElevatedButton(
                  onPressed: () {
                    soundService.playButtonClickSound();
                    _startGame();
                  },
                  child: Text(isGameRunning && isTimerPaused
                      ? '계속하기'
                      : '시작'),
                ),
                // 멈춤 버튼
                ElevatedButton(
                  onPressed: isGameRunning && !isTimerPaused
                      ? () {
                    soundService.playButtonClickSound();
                    _togglePause();
                  }
                      : null,
                  child: const Text('멈춤'),
                ),
                // 다시하기 버튼
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