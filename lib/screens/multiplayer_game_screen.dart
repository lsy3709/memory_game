import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/multiplayer_game_record.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
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
  static const int gameTimeSec = 15 * 60; // 게임 제한 시간(초 단위, 15분)

  // 게임 상태 변수
  late List<CardModel> cards;             // 카드 목록
  int? firstSelectedIndex;                // 첫 번째로 선택된 카드 인덱스
  int? secondSelectedIndex;               // 두 번째로 선택된 카드 인덱스
  int timeLeft = gameTimeSec;             // 남은 시간(초)
  bool isGameRunning = false;             // 게임 진행 여부
  bool isTimerPaused = false;             // 타이머 일시정지 여부
  Timer? gameTimer;                       // 게임 타이머 (nullable로 변경)
  final SoundService soundService = SoundService.instance; // 사운드 관리
  final StorageService storageService = StorageService.instance; // 저장소 관리
  
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
    soundService.dispose(); // 사운드 리소스 해제
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

  /// 두 카드가 매칭되는지 검사
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) return;
    final a = firstSelectedIndex!, b = secondSelectedIndex!;
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    // 0.7초 후 매칭 결과 처리(뒤집힌 카드 보여주기)
    Future.delayed(const Duration(milliseconds: 700), () {
      // mounted 상태 확인 후 setState 호출
      if (mounted) {
        setState(() {
          if (cards[a].id == cards[b].id) {
            soundService.playCardMatch();
            cards[a] = cards[a].copyWith(isMatched: true);
            cards[b] = cards[b].copyWith(isMatched: true);
            players[currentPlayerIndex].scoreModel.addMatchScore(); // 매칭 성공 시 점수 추가
            
            // 최고 연속 매칭 기록 업데이트
            if (players[currentPlayerIndex].scoreModel.currentCombo > players[currentPlayerIndex].maxCombo) {
              players[currentPlayerIndex].maxCombo = players[currentPlayerIndex].scoreModel.currentCombo;
            }
            
            // 매칭된 카드 정보 추가
            final cardMatch = CardMatch(
              pairId: cards[a].id,
              emoji: cards[a].emoji,
              matchedAt: DateTime.now(),
            );
            
            _checkGameEnd();
          } else {
            soundService.playCardMismatch();
            cards[a] = cards[a].copyWith(isFlipped: false);
            cards[b] = cards[b].copyWith(isFlipped: false);
            players[currentPlayerIndex].scoreModel.addFailPenalty(); // 매칭 실패 시 패널티
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

      // 멀티플레이어 게임 기록 저장 (간단한 구현)
      // 실제로는 storageService에 멀티플레이어 기록 저장 메서드 추가 필요
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
        title: Text(isDraw ? '무승부!' : '${winner!.name} 승리!'),
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
            Text('게임 시간: ${_formatTime()}'),
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
          const SizedBox(height: 4),
          Text(
            '점수: ${players[1].scoreModel.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
          Text('매칭: ${players[1].scoreModel.matchCount}성공 / ${players[1].scoreModel.failCount}실패'),
          Text('최고 콤보: ${players[1].maxCombo}회'),
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
    // 일시정지 상태에서 계속하기
    if (isGameRunning && isTimerPaused) {
      setState(() => isTimerPaused = false);
      soundService.resumeBackgroundMusic();
      return;
    }
    
    soundService.playGameStart(); // 게임 시작 사운드
    setState(() {
      _createCards(); // 카드 새로 생성
      _initPlayers(); // 플레이어 데이터 초기화
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      currentPlayerIndex = 0; // 첫 번째 플레이어부터 시작
      timeLeft = gameTimeSec; // 시간 초기화
      isGameRunning = true;
      isTimerPaused = false;
      gameStartTime = DateTime.now(); // 게임 시작 시간 기록
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel(); // 기존 타이머 중지
    _setupTimer(); // 타이머 재설정
    soundService.startBackgroundMusic(); // 배경음악 시작
  }

  /// 게임 일시정지
  void _pauseGame() {
    if (!isGameRunning || isTimerPaused) return;
    setState(() => isTimerPaused = true);
    soundService.pauseBackgroundMusic(); // 배경음악 일시정지
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    soundService.playButtonSound();
    setState(() {
      _createCards();
      _initPlayers();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      currentPlayerIndex = 0;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
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
        title: const Text('시간 초과!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('게임 오버'),
            const SizedBox(height: 8),
            Text('${players[0].name}: ${players[0].scoreModel.score}점'),
            Text('${players[1].name}: ${players[1].scoreModel.score}점'),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 화면 크기에 따라 카드 크기와 그리드 열 수 조절
    int gridColumns;
    double cardSize;
    double cardSpacing;
    
    if (screenWidth < 400) {
      // 작은 화면 (세로 모드)
      gridColumns = 4;
      cardSize = (screenWidth - 40) / 4 - 8;
      cardSpacing = 4;
    } else if (screenWidth < 600) {
      // 중간 화면
      gridColumns = 5;
      cardSize = (screenWidth - 50) / 5 - 8;
      cardSpacing = 6;
    } else {
      // 큰 화면 (가로 모드)
      gridColumns = 6;
      cardSize = (screenWidth - 60) / 6 - 8;
      cardSpacing = 8;
    }
    
    // 카드 크기 최소/최대 제한
    cardSize = cardSize.clamp(60.0, 120.0);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('멀티플레이어 게임'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 게임 정보 헤더
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 플레이어 1 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: currentPlayerIndex == 0 ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.player1Name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '점수: ${players[0].scoreModel.score}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 플레이어 2 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: currentPlayerIndex == 1 ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.player2Name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '점수: ${players[1].scoreModel.score}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 카드 그리드
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumns,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: cardSpacing,
                      mainAxisSpacing: cardSpacing,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: cardSize,
                        height: cardSize,
                        child: MemoryCard(
                          card: cards[index],
                          onTap: () => _onCardTap(index),
                          isEnabled: isGameRunning,
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // 게임 완료 메시지
              if (!isGameRunning && players[0].isCompleted && players[1].isCompleted)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '게임 완료!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '승자: ${players[0].scoreModel.score > players[1].scoreModel.score ? widget.player1Name : widget.player2Name}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 게임 컨트롤
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _resetGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('다시 시작'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('나가기'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
