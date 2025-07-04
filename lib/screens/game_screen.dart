import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  final String playerName;
  final String? email;

  const GameScreen({
    super.key,
    required this.playerName,
    this.email,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

/// 게임의 상태와 로직을 관리하는 State 클래스
class _GameScreenState extends State<GameScreen> {
  // 게임 설정 상수
  static const int rows = 8;              // 카드 그리드의 행 수
  static const int cols = 6;              // 카드 그리드의 열 수
  static const int numPairs = (rows * cols) ~/ 2;         // 카드 쌍의 개수
  static const int totalCards = numPairs * 2; // 전체 카드 수
  static const int gameTimeSec = 15 * 60; // 15분

  // 게임 상태 변수
  late List<CardModel> cards;
  int? firstSelectedIndex;
  int? secondSelectedIndex;
  bool isGameRunning = false;
  bool isTimerPaused = false;
  Timer? gameTimer;
  int timeLeft = gameTimeSec; // 5분
  int maxCombo = 0;
  final SoundService soundService = SoundService.instance; // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final StorageService storageService = StorageService.instance; // 저장소 관리
  
  // 기록 관련 변수
  String currentPlayerName = '게스트';     // 현재 플레이어 이름
  String currentPlayerEmail = '';         // 현재 플레이어 이메일
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간

  /// 게임 완료 여부
  bool gameCompleted = false;

  /// 현재 점수
  int get score => scoreModel.score;

  @override
  void initState() {
    super.initState();
    scoreModel = ScoreModel();
    _loadPlayerInfo();
    _initGame();
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
      soundService.stopBackgroundMusic();
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

  /// 이모지 가져오기 (국기로 변경)
  String _getEmoji(int index) {
    final flags = [
      '🇰🇷', '🇺🇸', '🇯🇵', '🇨🇳', '🇬🇧', '🇫🇷', '🇩🇪', '🇮🇹',
      '🇪🇸', '🇨🇦', '🇦🇺', '🇧🇷', '🇦🇷', '🇲🇽', '🇮🇳', '🇷🇺',
      '🇰🇵', '🇹🇭', '🇻🇳', '🇵🇭', '🇲🇾', '🇸🇬', '🇮🇩', '🇹🇼'
    ];
    return flags[index % flags.length];
  }

  /// 국기 한글 이름 가져오기
  String _getFlagName(int index) {
    final names = [
      '대한민국', '미국', '일본', '중국', '영국', '프랑스', '독일', '이탈리아',
      '스페인', '캐나다', '호주', '브라질', '아르헨티나', '멕시코', '인도', '러시아',
      '북한', '태국', '베트남', '필리핀', '말레이시아', '싱가포르', '인도네시아', '대만'
    ];
    return names[index % names.length];
  }

  /// 카드 생성 및 섞기
  void _createCards() {
    final List<String> cardValues = [
      '🇰🇷', '🇺🇸', '🇯🇵', '🇨🇳', '🇬🇧', '🇫🇷', '🇩🇪', '🇮🇹',
      '🇪🇸', '🇨🇦', '🇦🇺', '🇧🇷', '🇦🇷', '🇲🇽', '🇮🇳', '🇷🇺',
      '🇰🇵', '🇹🇭', '🇻🇳', '🇵🇭', '🇲🇾', '🇸🇬', '🇮🇩', '🇹🇼'
    ];
    final List<String> flagNames = [
      '대한민국', '미국', '일본', '중국', '영국', '프랑스', '독일', '이탈리아',
      '스페인', '캐나다', '호주', '브라질', '아르헨티나', '멕시코', '인도', '러시아',
      '북한', '태국', '베트남', '필리핀', '말레이시아', '싱가포르', '인도네시아', '대만'
    ];
    
    // 이모지와 이름을 함께 섞기
    final List<MapEntry<String, String>> cardPairs = [];
    for (int i = 0; i < cardValues.length; i++) {
      cardPairs.add(MapEntry(cardValues[i], flagNames[i]));
    }
    cardPairs.shuffle();
    
    List<CardModel> tempCards = [];
    for (int i = 0; i < numPairs; i++) {
      final emoji = cardPairs[i].key;
      final name = cardPairs[i].value;
      tempCards.add(CardModel(
        id: i,
        emoji: emoji,
        name: name,
        isMatched: false,
        isFlipped: false,
      ));
      tempCards.add(CardModel(
        id: i,
        emoji: emoji,
        name: name,
        isMatched: false,
        isFlipped: false,
      ));
    }
    tempCards.shuffle();
    cards = tempCards;
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
            _gameOver(byTimeout: true); // 시간 종료 시 게임 오버
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

    // 즉시 카드 뒤집기 (반응성 향상)
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true);
    });

    // 사운드는 비동기로 처리 (UI 블로킹 방지)
    Future.microtask(() {
      soundService.playCardFlipSound();
    });

    if (firstSelectedIndex == null) {
      firstSelectedIndex = index; // 첫 번째 카드 선택
    } else {
      secondSelectedIndex = index; // 두 번째 카드 선택
      Future.delayed(const Duration(milliseconds: 300), _checkMatch); // 매칭 검사 예약 (지연 시간 단축)
    }
  }

  /// 카드 매칭 확인
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) return;
    final a = firstSelectedIndex!, b = secondSelectedIndex!;
    firstSelectedIndex = null;
    secondSelectedIndex = null;

    if (mounted) {
      setState(() {
        if (cards[a].id == cards[b].id) {
          // 사운드는 비동기로 처리
          Future.microtask(() {
            soundService.playCardMatch();
          });
          cards[a] = cards[a].copyWith(isMatched: true);
          cards[b] = cards[b].copyWith(isMatched: true);
          scoreModel.addMatch();
          if (cards.every((c) => c.isMatched)) _gameOver();
        } else {
          // 사운드는 비동기로 처리
          Future.microtask(() {
            soundService.playCardMismatch();
          });
          scoreModel.addFailPenalty();
          cards[a] = cards[a].copyWith(isFlipped: false);
          cards[b] = cards[b].copyWith(isFlipped: false);
        }
      });
    }
  }

  /// 모든 카드가 매칭되었는지 확인 후 게임 종료 처리
  void _gameOver({bool byTimeout = false}) {
    isGameRunning = false;
    gameTimer?.cancel(); // 타이머 중지
    soundService.stopBackgroundMusic(); // 배경음악 중지

    final bool isCompleted = !byTimeout && cards.every((c) => c.isMatched);

    if (isCompleted) {
      soundService.playGameWin(); // 승리 사운드
    } else {
      soundService.playGameLose(); // 실패 사운드
    }
    
    // 게임 기록 저장
    _saveGameRecord(isCompleted);
    
    // 게임 결과 다이얼로그 표시
    _showGameResultDialog(isCompleted);
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
      print('게임 기록 저장 완료');

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

  /// 게임 결과 다이얼로그 표시
  void _showGameResultDialog(bool isCompleted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          isCompleted ? '🎉 축하합니다! 🎉' : '😭 아쉽네요 😭',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              isCompleted ? '모든 카드를 맞췄습니다!' : '시간이 초과되었습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
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
  }

  /// 게임 일시정지
  void _pauseGame() {
    soundService.playButtonClickSound();
    setState(() {
      isTimerPaused = true;
    });
    soundService.stopAllSounds();
  }

  /// 게임 재시작
  void _resumeGame() {
    soundService.playButtonClickSound();
    setState(() {
      isTimerPaused = false;
    });
    soundService.playBackgroundMusic();
  }

  /// 게임 시작
  void _initGame() {
    setState(() {
      _createCards();
      timeLeft = gameTimeSec;
      isGameRunning = true;
      isTimerPaused = false;
      scoreModel.reset();
      maxCombo = 0;
    });
    _setupTimer();
    soundService.playButtonClickSound(); // 게임 시작 사운드
    soundService.playBackgroundMusic();
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    soundService.playButtonClickSound();
    setState(() {
      _createCards();
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      maxCombo = 0;
      scoreModel.reset();
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('혼자 하기'),
        actions: [
          // 일시정지 버튼
          IconButton(
            icon: Icon(isTimerPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
            tooltip: isTimerPaused ? '계속하기' : '일시정지',
          ),
          // 재시작 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
            tooltip: '다시 시작',
          ),
          if (kDebugMode) ...[
            IconButton(
              icon: Icon(Icons.flash_on),
              onPressed: _debugAutoSolveAllPairs,
              tooltip: '자동 정답(디버그)',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 정보 패널
            _buildTopPanel(),
            // 반응형 카드 그리드
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight;

                  const double horizontalPadding = 4.0;
                  const double verticalPadding = 4.0;
                  const double horizontalSpacing = 2.0;
                  const double verticalSpacing = 2.0;

                  final double totalHorizontalGaps = (horizontalPadding * 2) + (horizontalSpacing * (cols - 1));
                  final double totalVerticalGaps = (verticalPadding * 2) + (verticalSpacing * (rows - 1));

                  final double cardWidth = (availableWidth - totalHorizontalGaps) / cols;
                  final double cardHeight = (availableHeight - totalVerticalGaps) / rows;

                  if (cardWidth <= 0 || cardHeight <= 0) {
                    return const Center(child: Text("레이아웃 계산 중..."));
                  }

                  final double cardAspectRatio = cardWidth / cardHeight;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: cardAspectRatio,
                        crossAxisSpacing: horizontalSpacing,
                        mainAxisSpacing: verticalSpacing,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return MemoryCard(
                          card: cards[index],
                          onTap: () => _onCardTap(index),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // 게임 시작 버튼 (플로팅)
      floatingActionButton: !isGameRunning
          ? FloatingActionButton.extended(
              onPressed: _initGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('게임 시작'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// 상단 정보 패널 위젯
  Widget _buildTopPanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn('점수', score.toString()),
              _buildInfoColumn('콤보', '${scoreModel.currentCombo} (최대: $maxCombo)'),
              _buildInfoColumn('남은 시간', _formatTime()),
            ],
          ),
        ),
      ),
    );
  }

  /// 정보 표시용 컬럼 위젯
  Widget _buildInfoColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// 게임 일시정지 및 재시작
  void _togglePause() {
    if (isGameRunning) {
      _pauseGame();
    } else {
      _resumeGame();
    }
  }

  /// 게임 재시작
  void _restartGame() {
    _resetGame();
  }

  Future<void> _debugAutoSolveAllPairs() async {
    if (cards.isEmpty) return;
    Map<int, List<int>> pairMap = {};
    for (int i = 0; i < cards.length; i++) {
      pairMap.putIfAbsent(cards[i].id, () => []).add(i);
    }
    for (var pair in pairMap.values) {
      if (pair.length == 2) {
        _onCardTap(pair[0]);
        await Future.delayed(const Duration(milliseconds: 200));
        _onCardTap(pair[1]);
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }
}