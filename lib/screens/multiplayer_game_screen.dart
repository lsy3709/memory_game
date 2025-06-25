import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/multiplayer_game_record.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/hive_database_service.dart';
import '../models/hive_models.dart';
import 'multiplayer_comparison_screen.dart';

/// 멀티플레이어 메모리 카드 게임 화면
/// 2명의 플레이어가 함께 게임을 진행
class MultiplayerGameScreen extends StatefulWidget {
  final String player1Name;
  final String player2Name;
  final String? player1Email;
  final String? player2Email;

  const MultiplayerGameScreen({
    super.key,
    required this.player1Name,
    required this.player2Name,
    this.player1Email,
    this.player2Email,
  });

  @override
  _MultiplayerGameScreenState createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  // 게임 설정 상수
  static const int rows = 8;              // 카드 그리드의 행 수
  static const int cols = 6;              // 카드 그리드의 열 수
  static const int numPairs = 24;         // 카드 쌍의 개수
  static const int totalCards = numPairs * 2; // 전체 카드 수
  static const int gameTimeSec = 15 * 60; // 15분

  // 게임 상태 변수
  late List<CardModel> cards;             // 카드 목록
  int? firstSelectedIndex;                // 첫 번째로 선택된 카드 인덱스
  int? secondSelectedIndex;               // 두 번째로 선택된 카드 인덱스
  int timeLeft = gameTimeSec;             // 15분
  bool isGameRunning = false;             // 게임 진행 여부
  bool isTimerPaused = false;             // 타이머 일시정지 여부
  Timer? gameTimer;                       // 게임 타이머 (nullable로 변경)
  final SoundService soundService = SoundService.instance; // 사운드 관리
  final StorageService storageService = StorageService.instance; // 저장소 관리
  final HiveDatabaseService hiveService = HiveDatabaseService(); // Hive 데이터베이스 서비스
  
  // 플레이어 관련 변수
  int currentPlayerIndex = 0;             // 현재 플레이어 인덱스 (0: 플레이어1, 1: 플레이어2)
  late List<PlayerGameData> players;      // 플레이어 데이터 목록
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간

  @override
  void initState() {
    super.initState();
    _initPlayers();
    _initGame();
  }

  @override
  void dispose() {
    if (gameTimer?.isActive == true) gameTimer?.cancel(); // 타이머 해제
    soundService.stopBackgroundMusic(); // 배경 음악만 정지
    super.dispose();
  }

  /// 플레이어 데이터 초기화
  void _initPlayers() {
    players = [
      PlayerGameData(
        name: widget.player1Name,
        email: widget.player1Email ?? '',
        scoreModel: ScoreModel(),
        maxCombo: 0,
        cardMatches: [],
        timeLeft: gameTimeSec,
        isCompleted: false,
      ),
      PlayerGameData(
        name: widget.player2Name,
        email: widget.player2Email ?? '',
        scoreModel: ScoreModel(),
        maxCombo: 0,
        cardMatches: [],
        timeLeft: gameTimeSec,
        isCompleted: false,
      ),
    ];
  }

  /// 게임 시작 시 카드 생성 및 타이머 설정
  void _initGame() {
    cards = [];
    _createCards();
    _setupTimer();
  }

  /// 카드 쌍을 생성하고 셔플
  void _createCards() {
    final List<CardModel> tempCards = [];
    
    // 카드 쌍 생성
    for (int i = 0; i < numPairs; i++) {
      tempCards.add(CardModel(
        id: i,
        emoji: _getEmoji(i),
        name: _getFlagName(i),
        isMatched: false,
        isFlipped: false,
      ));
      tempCards.add(CardModel(
        id: i,
        emoji: _getEmoji(i),
        name: _getFlagName(i),
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

  /// 1초마다 남은 시간을 감소시키는 타이머 설정
  void _setupTimer() {
    // 기존 타이머가 있다면 취소
    if (gameTimer?.isActive == true) {
      gameTimer?.cancel();
    }
    
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isGameRunning && !isTimerPaused) {
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

    // 즉시 카드 뒤집기 (반응성 향상)
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true);
    });

    // 사운드는 비동기로 처리하되, 오류가 발생해도 게임 진행에 영향 없도록
    Future.microtask(() {
      try {
        soundService.playCardFlipSound();
      } catch (e) {
        print('카드 뒤집기 사운드 재생 실패: $e');
      }
    });

    if (firstSelectedIndex == null) {
      firstSelectedIndex = index; // 첫 번째 카드 선택
    } else {
      secondSelectedIndex = index; // 두 번째 카드 선택
      Future.delayed(const Duration(milliseconds: 300), _checkMatch); // 매칭 검사 예약 (지연 시간 단축)
    }
  }

  /// 두 카드가 매칭되는지 검사
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) return;
    final a = firstSelectedIndex!, b = secondSelectedIndex!;
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          if (cards[a].id == cards[b].id) {
            // 사운드는 비동기로 처리하되, 오류가 발생해도 게임 진행에 영향 없도록
            Future.microtask(() {
              try {
                soundService.playCardMatch();
              } catch (e) {
                print('카드 매칭 사운드 재생 실패: $e');
              }
            });
            cards[a] = cards[a].copyWith(isMatched: true);
            cards[b] = cards[b].copyWith(isMatched: true);
            players[currentPlayerIndex].scoreModel.addMatchScore();
            
            if (players[currentPlayerIndex].scoreModel.currentCombo > players[currentPlayerIndex].maxCombo) {
              players[currentPlayerIndex].maxCombo = players[currentPlayerIndex].scoreModel.currentCombo;
            }
            
            // 매칭된 카드 정보를 현재 플레이어에게만 추가
            final cardMatch = CardMatch(
              pairId: cards[a].id,
              emoji: cards[a].emoji,
              matchedAt: DateTime.now(),
            );
            players[currentPlayerIndex].cardMatches.add(cardMatch);
            
            _checkGameEnd();
          } else {
            // 사운드는 비동기로 처리하되, 오류가 발생해도 게임 진행에 영향 없도록
            Future.microtask(() {
              try {
                soundService.playCardMismatch();
              } catch (e) {
                print('카드 매칭 실패 사운드 재생 실패: $e');
              }
            });
            cards[a] = cards[a].copyWith(isFlipped: false);
            cards[b] = cards[b].copyWith(isFlipped: false);
            players[currentPlayerIndex].scoreModel.addFailPenalty();
            
            _switchPlayer();
          }
        });
      }
    });
  }

  /// 플레이어 턴 변경
  void _switchPlayer() {
    setState(() {
      currentPlayerIndex = (currentPlayerIndex + 1) % 2;
    });
  }

  /// 모든 카드가 매칭되었는지 확인 후 게임 종료 처리
  void _checkGameEnd() {
    if (cards.every((c) => c.isMatched)) {
      isGameRunning = false;
      gameTimer?.cancel(); // 타이머 중지
      soundService.stopBackgroundMusic(); // 배경음악 중지
      soundService.playGameWin(); // 승리 사운드
      
      // 플레이어들의 게임 완료 시간 설정
      final gameEndTime = DateTime.now();
      final totalGameTime = gameEndTime.difference(gameStartTime).inSeconds;
      
      for (int i = 0; i < players.length; i++) {
        players[i].isCompleted = true;
        players[i].timeLeft = totalGameTime;
      }
      
      // 게임 기록 저장
      _saveMultiplayerGameRecord(true);
      
      // 0.5초 후 결과 다이얼로그 표시
      Future.delayed(const Duration(milliseconds: 500), () {
        _showGameResult();
      });
    }
  }

  /// 멀티플레이어 게임 기록 저장
  Future<void> _saveMultiplayerGameRecord(bool isCompleted) async {
    try {
      final playerResults = players.map((playerData) => PlayerGameResult(
        playerName: playerData.name,
        email: playerData.email,
        score: playerData.scoreModel.score,
        matchCount: playerData.scoreModel.matchCount,
        failCount: playerData.scoreModel.failCount,
        maxCombo: playerData.maxCombo,
        timeLeft: timeLeft,
        isWinner: false, // 승자 판정은 나중에
      )).toList();

      final multiplayerRecord = MultiplayerGameRecord(
        id: storageService.generateId(),
        gameTitle: '${widget.player1Name} vs ${widget.player2Name}',
        players: playerResults,
        createdAt: DateTime.now(),
        isCompleted: isCompleted,
        totalTime: gameTimeSec - timeLeft,
        timeLeft: timeLeft,
      );

      // Hive 데이터베이스에 로컬 멀티플레이어 게임 기록 저장
      await hiveService.saveLocalMultiplayerRecord(multiplayerRecord);
      print('Hive 데이터베이스에 로컬 멀티플레이어 게임 기록 저장 완료');

      // 기존 SharedPreferences 저장소에도 저장 (호환성 유지)
      print('멀티플레이어 게임 기록 저장: ${multiplayerRecord.toJson()}');
    } catch (e) {
      print('멀티플레이어 게임 기록 저장 오류: $e');
    }
  }

  /// 게임 결과 다이얼로그 표시
  void _showGameResult() {
    final winner = _getWinner();
    final isDraw = winner == null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isDraw ? Icons.emoji_events : Icons.emoji_events,
              color: isDraw ? Colors.grey : Colors.amber,
            ),
            const SizedBox(width: 8),
            Text(
              isDraw ? '무승부!' : '${winner!.name} 승리!',
              style: TextStyle(
                color: isDraw ? Colors.grey : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 플레이어 1 결과
            _buildPlayerResultCard(players[0], 0),
            const SizedBox(height: 16),
            // 플레이어 2 결과
            _buildPlayerResultCard(players[1], 1),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '게임 정보',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('총 게임 시간: ${_formatTime()}'),
                  Text('총 카드 쌍: ${numPairs}쌍'),
                  Text('완료된 매칭: ${cards.where((c) => c.isMatched).length ~/ 2}쌍'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDetailedComparison();
            },
            child: const Text('상세 비교'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 플레이어 결과 카드 위젯 생성
  Widget _buildPlayerResultCard(PlayerGameData player, int playerIndex) {
    final isWinner = _getWinner()?.name == player.name;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isWinner ? Colors.green : Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                player.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isWinner ? Colors.green : Colors.black,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 8),
                const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '점수: ${player.scoreModel.score}점',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '매칭: ${player.scoreModel.matchCount}성공 / ${player.scoreModel.failCount}실패',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '최고 콤보: ${player.maxCombo}회',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              if (isWinner) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '승리!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 승자 찾기
  PlayerGameData? _getWinner() {
    final player1 = players[0];
    final player2 = players[1];
    
    if (player1.scoreModel.score > player2.scoreModel.score) {
      return player1;
    } else if (player2.scoreModel.score > player1.scoreModel.score) {
      return player2;
    } else {
      // 점수가 같으면 매칭 성공률로 비교
      final rate1 = player1.scoreModel.matchCount / (player1.scoreModel.matchCount + player1.scoreModel.failCount);
      final rate2 = player2.scoreModel.matchCount / (player2.scoreModel.matchCount + player2.scoreModel.failCount);
      
      if (rate1 > rate2) return player1;
      if (rate2 > rate1) return player2;
      
      // 매칭 성공률도 같으면 무승부
      return null;
    }
  }

  /// 상세 비교 화면 표시
  void _showDetailedComparison() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultiplayerComparisonScreen(
          player1: players[0],
          player2: players[1],
          gameTime: gameTimeSec - timeLeft,
        ),
      ),
    );
  }

  /// 게임 시작 또는 일시정지 해제
  void _startGame() {
    setState(() {
      _createCards();
      timeLeft = gameTimeSec;
      isGameRunning = true;
      isTimerPaused = false;
      players[0].scoreModel.reset();
      players[1].scoreModel.reset();
      players[0].maxCombo = 0;
      players[1].maxCombo = 0;
    });
    _setupTimer();
    soundService.playButtonClickSound(); // 게임 시작 사운드
    soundService.playBackgroundMusic();
  }

  /// 게임 일시정지
  void _pauseGame() {
    setState(() {
      isTimerPaused = true;
    });
    soundService.stopAllSounds();
  }

  /// 게임 재시작
  void _resumeGame() {
    setState(() {
      isTimerPaused = false;
    });
    soundService.playBackgroundMusic();
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    setState(() {
      _createCards();
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      players[0].maxCombo = 0;
      players[1].maxCombo = 0;
      players[0].scoreModel.reset();
      players[1].scoreModel.reset();
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  /// 시간 초과 시 게임 오버 처리
  void _gameOver() {
    isGameRunning = false;
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    
    // 게임 기록 저장 (미완료)
    _saveMultiplayerGameRecord(false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.timer_off, color: Colors.red),
            const SizedBox(width: 8),
            const Text(
              '시간 초과!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '게임 오버',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 플레이어 1 결과
            _buildPlayerResultCard(players[0], 0),
            const SizedBox(height: 16),
            // 플레이어 2 결과
            _buildPlayerResultCard(players[1], 1),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '게임 정보',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('총 게임 시간: ${_formatTime()}'),
                  Text('총 카드 쌍: ${numPairs}쌍'),
                  Text('완료된 매칭: ${cards.where((c) => c.isMatched).length ~/ 2}쌍'),
                  const Text(
                    '시간 초과로 게임이 종료되었습니다.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDetailedComparison();
            },
            child: const Text('상세 비교'),
          ),
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
        title: Text('멀티플레이어: ${widget.player1Name} vs ${widget.player2Name}'),
        actions: [
          IconButton(
            icon: Icon(isTimerPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
            tooltip: isTimerPaused ? '계속하기' : '일시정지',
          ),
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
            // 상단 정보 패널 (점수판)
            _buildScorePanel(),
            // Game Board
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
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('게임 시작'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// 상단 점수판 위젯
  Widget _buildScorePanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerScore(players[0], widget.player1Name),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('남은 시간', style: TextStyle(fontSize: 14)),
                      Text(
                        _formatTime(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  _buildPlayerScore(players[1], widget.player2Name),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '현재 턴: ${currentPlayerIndex == 0 ? widget.player1Name : widget.player2Name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerScore(PlayerGameData player, String name) {
    bool isCurrentTurn = players[currentPlayerIndex] == player;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentTurn ? Colors.blue.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrentTurn ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '점수: ${player.scoreModel.score}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '매칭: ${player.scoreModel.matchCount}',
            style: const TextStyle(fontSize: 12, color: Colors.green),
          ),
          Text(
            '실패: ${player.scoreModel.failCount}',
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
          Text(
            '콤보: ${player.scoreModel.currentCombo}',
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ],
      ),
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
