import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/online_room.dart';
import '../models/multiplayer_game_record.dart';
import '../services/sound_service.dart';
import '../services/firebase_service.dart';

/// 온라인 멀티플레이어 메모리 카드 게임 화면
/// 2명의 플레이어가 온라인에서 실시간으로 게임을 진행
class OnlineMultiplayerGameScreen extends StatefulWidget {
  final OnlineRoom room;

  const OnlineMultiplayerGameScreen({
    super.key,
    required this.room,
  });

  @override
  _OnlineMultiplayerGameScreenState createState() => _OnlineMultiplayerGameScreenState();
}

class _OnlineMultiplayerGameScreenState extends State<OnlineMultiplayerGameScreen> {
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
  Timer? gameTimer;                       // 게임 타이머
  final SoundService soundService = SoundService.instance; // 사운드 관리
  final FirebaseService firebaseService = FirebaseService.instance; // Firebase 서비스
  
  // 플레이어 관련 변수
  int currentPlayerIndex = 0;             // 현재 플레이어 인덱스 (0: 호스트, 1: 게스트)
  late List<PlayerGameData> players;      // 플레이어 데이터 목록
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간
  String currentUserId = '';              // 현재 사용자 ID
  bool isHost = false;                    // 방장 여부
  bool isMyTurn = false;                  // 내 턴 여부

  @override
  void initState() {
    super.initState();
    _initPlayerInfo();
    _initPlayers();
    _initGame();
    _setupGameListener();
  }

  @override
  void dispose() {
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    super.dispose();
  }

  /// 플레이어 정보 초기화
  void _initPlayerInfo() {
    currentUserId = firebaseService.currentUser?.uid ?? '';
    isHost = widget.room.isHost(currentUserId);
    isMyTurn = isHost; // 방장이 먼저 시작
  }

  /// 플레이어 데이터 초기화
  void _initPlayers() {
    players = [
      PlayerGameData(
        name: widget.room.hostName,
        email: widget.room.hostEmail,
        scoreModel: ScoreModel(),
        maxCombo: 0,
        cardMatches: [],
        timeLeft: gameTimeSec,
        isCompleted: false,
      ),
      PlayerGameData(
        name: widget.room.guestName ?? '게스트',
        email: widget.room.guestEmail ?? '',
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

  /// 게임 상태 리스너 설정
  void _setupGameListener() {
    // Firebase에서 게임 상태 변화 감지
    firebaseService.getRoomStream(widget.room.id).listen((room) {
      if (room != null && mounted) {
        setState(() {
          // 게임 상태 업데이트
          if (room.status == RoomStatus.playing && !isGameRunning) {
            _startGame();
          } else if (room.status == RoomStatus.finished) {
            _endGame();
          }
        });
      }
    });
  }

  /// 게임 시작
  void _startGame() {
    setState(() {
      isGameRunning = true;
    });
    soundService.playBackgroundMusic();
  }

  /// 게임 종료
  void _endGame() {
    setState(() {
      isGameRunning = false;
    });
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    _saveGameRecord();
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
    // 게임이 진행 중이 아니거나 일시정지, 내 턴이 아니거나, 이미 뒤집힌/맞춘 카드, 같은 카드 두 번 클릭, 두 장 이미 선택된 경우 무시
    if (!isGameRunning || isTimerPaused || !isMyTurn) return;
    if (cards[index].isMatched || cards[index].isFlipped) return;
    if (firstSelectedIndex == index) return;
    if (firstSelectedIndex != null && secondSelectedIndex != null) return;

    // 즉시 카드 뒤집기 (반응성 향상)
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true);
    });

    // 사운드 재생
    Future.microtask(() {
      try {
        soundService.playCardFlipSound();
      } catch (e) {
        print('카드 뒤집기 사운드 재생 실패: $e');
      }
    });

    // 첫 번째 카드 선택
    if (firstSelectedIndex == null) {
      setState(() {
        firstSelectedIndex = index;
      });
    } else {
      // 두 번째 카드 선택
      setState(() {
        secondSelectedIndex = index;
      });

      // 카드 매칭 확인
      _checkCardMatch();
    }
  }

  /// 카드 매칭 확인
  void _checkCardMatch() {
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
    // 매칭된 카드 표시
    setState(() {
      cards[firstSelectedIndex!] = cards[firstSelectedIndex!].copyWith(isMatched: true);
      cards[secondSelectedIndex!] = cards[secondSelectedIndex!].copyWith(isMatched: true);
    });

    // 현재 플레이어 점수 증가
    players[currentPlayerIndex].scoreModel.addScore(10);
    players[currentPlayerIndex].cardMatches.add(firstSelectedIndex!);
    players[currentPlayerIndex].cardMatches.add(secondSelectedIndex!);

    // 연속 매칭 기록 업데이트
    players[currentPlayerIndex].maxCombo = max(players[currentPlayerIndex].maxCombo, 1);

    // 성공 사운드 재생
    Future.microtask(() {
      try {
        soundService.playMatchSuccessSound();
      } catch (e) {
        print('매칭 성공 사운드 재생 실패: $e');
      }
    });

    // 선택 초기화
    firstSelectedIndex = null;
    secondSelectedIndex = null;

    // 게임 완료 확인
    _checkGameCompletion();
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    // 잠시 후 카드 다시 뒤집기
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          cards[firstSelectedIndex!] = cards[firstSelectedIndex!].copyWith(isFlipped: false);
          cards[secondSelectedIndex!] = cards[secondSelectedIndex!].copyWith(isFlipped: false);
        });

        // 선택 초기화
        firstSelectedIndex = null;
        secondSelectedIndex = null;

        // 턴 변경
        _switchTurn();
      }
    });

    // 실패 사운드 재생
    Future.microtask(() {
      try {
        soundService.playMatchFailureSound();
      } catch (e) {
        print('매칭 실패 사운드 재생 실패: $e');
      }
    });
  }

  /// 턴 변경
  void _switchTurn() {
    setState(() {
      currentPlayerIndex = (currentPlayerIndex + 1) % 2;
      isMyTurn = (currentPlayerIndex == 0 && isHost) || (currentPlayerIndex == 1 && !isHost);
    });

    // Firebase에 턴 변경 알림
    final currentPlayerId = currentPlayerIndex == 0 ? widget.room.hostId : widget.room.guestId ?? '';
    final nextPlayerId = currentPlayerIndex == 0 ? widget.room.guestId ?? '' : widget.room.hostId;
    firebaseService.syncTurnChange(widget.room.id, currentPlayerId, nextPlayerId);
  }

  /// 게임 완료 확인
  void _checkGameCompletion() {
    final matchedCards = cards.where((card) => card.isMatched).length;
    if (matchedCards == totalCards) {
      _gameCompleted();
    }
  }

  /// 게임 완료 처리
  void _gameCompleted() {
    isGameRunning = false;
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();

    // 게임 기록 저장
    _saveGameRecord();

    // 완료 다이얼로그 표시
    _showGameCompletionDialog();
  }

  /// 시간 초과 시 게임 오버 처리
  void _gameOver() {
    isGameRunning = false;
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();

    // 게임 기록 저장 (미완료)
    _saveGameRecord();

    // 게임 오버 다이얼로그 표시
    _showGameOverDialog();
  }

  /// 게임 기록 저장
  void _saveGameRecord() {
    try {
      // 플레이어 결과 생성
      final player1Result = PlayerGameResult(
        playerName: players[0].name,
        email: players[0].email,
        score: players[0].scoreModel.score,
        matchCount: players[0].cardMatches.length ~/ 2, // 매칭된 카드 쌍의 수
        failCount: players[0].scoreModel.failCount,
        maxCombo: players[0].maxCombo,
        timeLeft: timeLeft,
        isWinner: players[0].scoreModel.score > players[1].scoreModel.score,
      );

      final player2Result = PlayerGameResult(
        playerName: players[1].name,
        email: players[1].email,
        score: players[1].scoreModel.score,
        matchCount: players[1].cardMatches.length ~/ 2, // 매칭된 카드 쌍의 수
        failCount: players[1].scoreModel.failCount,
        maxCombo: players[1].maxCombo,
        timeLeft: timeLeft,
        isWinner: players[1].scoreModel.score > players[0].scoreModel.score,
      );

      final record = MultiplayerGameRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        gameTitle: widget.room.roomName,
        players: [player1Result, player2Result],
        createdAt: DateTime.now(),
        isCompleted: true,
        totalTime: gameTimeSec,
        timeLeft: timeLeft,
      );

      // Firebase에 기록 저장
      firebaseService.saveOnlineMultiplayerGameRecord(record);
    } catch (e) {
      print('게임 기록 저장 실패: $e');
    }
  }

  /// 게임 완료 다이얼로그 표시
  void _showGameCompletionDialog() {
    final winner = players[0].scoreModel.score > players[1].scoreModel.score 
        ? players[0] 
        : players[1];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('게임 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('승자: ${winner.name}'),
            const SizedBox(height: 16),
            Text('${players[0].name}: ${players[0].scoreModel.score}점'),
            Text('${players[1].name}: ${players[1].scoreModel.score}점'),
            const SizedBox(height: 16),
            Text('총 시간: ${_formatTime()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // 게임 완료 결과 반환
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 게임 오버 다이얼로그 표시
  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('시간 초과!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('게임 시간이 종료되었습니다.'),
            const SizedBox(height: 16),
            Text('${players[0].name}: ${players[0].scoreModel.score}점'),
            Text('${players[1].name}: ${players[1].scoreModel.score}점'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // 게임 완료 결과 반환
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 일시정지/재개 토글
  void _togglePause() {
    if (!isGameRunning) return;
    
    setState(() {
      isTimerPaused = !isTimerPaused;
    });
  }

  /// 게임 재시작
  void _restartGame() {
    setState(() {
      _createCards();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      players[0].maxCombo = 0;
      players[1].maxCombo = 0;
      players[0].scoreModel.reset();
      players[1].scoreModel.reset();
      players[0].cardMatches.clear();
      players[1].cardMatches.clear();
    });
    
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  /// 점수 패널 위젯 생성
  Widget _buildScorePanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        children: [
          // 현재 플레이어 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 플레이어: ${players[currentPlayerIndex].name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '점수: ${players[currentPlayerIndex].scoreModel.score}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '최고 연속: ${players[currentPlayerIndex].maxCombo}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          // 시간 표시
          Column(
            children: [
              const Text(
                '남은 시간',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                _formatTime(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('온라인 멀티플레이어: ${widget.room.roomName}'),
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

                  return Container(
                    padding: const EdgeInsets.all(horizontalPadding),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: cardWidth / cardHeight,
                        crossAxisSpacing: horizontalSpacing,
                        mainAxisSpacing: verticalSpacing,
                      ),
                      itemCount: totalCards,
                      itemBuilder: (context, index) {
                        return MemoryCard(
                          card: cards[index],
                          onTap: () => _onCardTap(index),
                          isEnabled: isMyTurn,
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
    );
  }
}

/// 플레이어 게임 데이터 클래스
class PlayerGameData {
  final String name;
  final String email;
  final ScoreModel scoreModel;
  int maxCombo;
  final List<int> cardMatches;
  int timeLeft;
  bool isCompleted;

  PlayerGameData({
    required this.name,
    required this.email,
    required this.scoreModel,
    required this.maxCombo,
    required this.cardMatches,
    required this.timeLeft,
    required this.isCompleted,
  });
}