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
        email: widget.player1Email,
        scoreModel: ScoreModel(),
        maxCombo: 0,
        cardMatches: [],
        timeLeft: gameTimeSec,
        isCompleted: false,
      ),
      PlayerGameData(
        name: widget.player2Name,
        email: widget.player2Email,
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
    cards.clear(); // 기존 카드 리스트 초기화
    
    // 카드 쌍의 개수만큼 반복
    for (int i = 0; i < numPairs; i++) {
      // 각 쌍마다 두 장의 카드를 생성
      for (int j = 0; j < 2; j++) {
        cards.add(CardModel(
          id: i, // 쌍 id
          emoji: _getEmoji(i), // 이모지
          isMatched: false,
          isFlipped: false,
        ));
      }
    }
    cards.shuffle(); // 카드 순서 섞기
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
            currentPlayer.scoreModel.addMatchScore(); // 매칭 성공 시 점수 추가
            
            // 최고 연속 매칭 기록 업데이트
            if (currentPlayer.scoreModel.currentCombo > currentPlayer.maxCombo) {
              currentPlayer.maxCombo = currentPlayer.scoreModel.currentCombo;
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
        players[i].gameTime = totalGameTime;
        players[i].isCompleted = true;
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
          Text('점수: ${player.scoreModel.score}점'),
          Text('매칭: ${player.scoreModel.matchCount}성공 / ${player.scoreModel.failCount}실패'),
          Text('최고 콤보: ${player.maxCombo}회'),
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
    final currentPlayer = players[currentPlayerIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('멀티플레이어 게임'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 플레이어 정보 영역
          Container(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.01, 
              horizontal: screenWidth * 0.04
            ),
            child: Row(
              children: [
                // 플레이어 1 정보
                Expanded(
                  child: _buildPlayerInfoCard(players[0], 0),
                ),
                SizedBox(width: screenWidth * 0.04),
                // 플레이어 2 정보
                Expanded(
                  child: _buildPlayerInfoCard(players[1], 1),
                ),
              ],
            ),
          ),

          // 게임 정보 영역
          Container(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.01, 
              horizontal: screenWidth * 0.04
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 시간 표시
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      '남은 시간: ${_formatTime()}',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                // 현재 플레이어 표시
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentPlayerIndex == 0 ? Colors.blue : Colors.green,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.white,
                          size: screenWidth * 0.04,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${currentPlayer.name} 턴',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 카드 그리드 영역
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;
                  final gridHeight = constraints.maxHeight;
                  final spacing = screenWidth * 0.02; // 반응형 간격
                  final itemWidth = (gridWidth - (cols - 1) * spacing) / cols;
                  final itemHeight = (gridHeight - (rows - 1) * spacing) / rows;
                  final aspectRatio = itemWidth / itemHeight;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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

          // 하단 버튼 영역
          Container(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.02, 
              horizontal: screenWidth * 0.04
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 시작/계속하기 버튼
                Expanded(
                  child: Container(
                    height: screenHeight * 0.06,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        soundService.playButtonSound();
                        _startGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isGameRunning && isTimerPaused ? '계속하기' : '시작',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // 멈춤 버튼
                Expanded(
                  child: Container(
                    height: screenHeight * 0.06,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: isGameRunning && !isTimerPaused
                          ? () {
                        soundService.playButtonSound();
                        _pauseGame();
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        '멈춤',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // 다시하기 버튼
                Expanded(
                  child: Container(
                    height: screenHeight * 0.06,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: _resetGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        '다시하기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 플레이어 정보 카드 위젯 생성
  Widget _buildPlayerInfoCard(PlayerGameData player, int playerIndex) {
    final isCurrentPlayer = currentPlayerIndex == playerIndex;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
            ? (playerIndex == 0 ? Colors.blue.withOpacity(0.15) : Colors.green.withOpacity(0.15))
            : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isCurrentPlayer 
              ? (playerIndex == 0 ? Colors.blue : Colors.green)
              : Colors.grey,
          width: isCurrentPlayer ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isCurrentPlayer ? [
          BoxShadow(
            color: (playerIndex == 0 ? Colors.blue : Colors.green).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          // 플레이어 이름
          Text(
            player.name,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: isCurrentPlayer 
                  ? (playerIndex == 0 ? Colors.blue : Colors.green)
                  : Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: screenWidth * 0.01),
          // 점수
          Text(
            '${player.scoreModel.score}점',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          // 콤보 표시
          if (player.scoreModel.currentCombo > 1) ...[
            SizedBox(height: screenWidth * 0.005),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${player.scoreModel.currentCombo}콤보!',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.025,
                ),
              ),
            ),
          ],
          // 최고 콤보 표시
          if (player.maxCombo > 0) ...[
            SizedBox(height: screenWidth * 0.005),
            Text(
              '최고: ${player.maxCombo}',
              style: TextStyle(
                color: Colors.red,
                fontSize: screenWidth * 0.025,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 
