import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/multiplayer_game_record.dart';
import '../models/online_room.dart';
import '../services/sound_service.dart';
import '../services/firebase_service.dart';

/// 온라인 멀티플레이어 메모리 카드 게임 화면
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
  Timer? gameTimer;                       // 게임 타이머 (nullable로 변경)
  final SoundService soundService = SoundService.instance; // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final FirebaseService firebaseService = FirebaseService.instance; // Firebase 서비스
  
  // 온라인 멀티플레이어 관련 변수
  late OnlineRoom currentRoom;            // 현재 방 정보
  String currentPlayerId = '';            // 현재 플레이어 ID
  String currentPlayerName = '';          // 현재 플레이어 이름
  String opponentPlayerName = '';         // 상대방 플레이어 이름
  String opponentPlayerEmail = '';        // 상대방 플레이어 이메일
  bool isMyTurn = false;                  // 내 턴인지 여부
  int currentPlayerScore = 0;             // 현재 플레이어 점수
  int opponentPlayerScore = 0;            // 상대방 플레이어 점수
  int maxCombo = 0;                       // 최고 연속 매칭 기록
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간

  @override
  void initState() {
    super.initState();
    currentRoom = widget.room;
    scoreModel = ScoreModel();
    _loadPlayerInfo();
    _initGame();
    _setupRoomListener();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    super.dispose();
  }

  /// 플레이어 정보 로드
  Future<void> _loadPlayerInfo() async {
    try {
      final user = firebaseService.currentUser;
      if (user != null) {
        currentPlayerId = user.uid;
        final userData = await firebaseService.getUserData(user.uid);
        currentPlayerName = userData?['playerName'] ?? user.displayName ?? '플레이어';
        
        // 상대방 정보 가져오기
        opponentPlayerName = currentRoom.getOtherPlayerName(currentPlayerId) ?? '상대방';
        opponentPlayerEmail = currentRoom.getOtherPlayerEmail(currentPlayerId) ?? '';
        
        // 방장이 먼저 시작
        isMyTurn = currentRoom.isHost(currentPlayerId);
      }
    } catch (e) {
      print('플레이어 정보 로드 오류: $e');
    }
  }

  /// 방 상태 리스너 설정
  void _setupRoomListener() {
    firebaseService.getRoomStream(currentRoom.id).listen((room) {
      if (room != null) {
        setState(() {
          currentRoom = room;
        });
        
        // 방 상태에 따른 처리
        if (room.status == RoomStatus.playing && !isGameRunning) {
          _startGame();
        } else if (room.status == RoomStatus.finished || room.status == RoomStatus.cancelled) {
          _gameOver();
        }
      }
    });
  }

  /// 게임 초기화
  void _initGame() {
    _createCards();
    _setupTimer();
    soundService.playBackgroundMusic();
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

  /// 게임 시작
  void _startGame() {
    setState(() {
      isGameRunning = true;
      gameStartTime = DateTime.now();
    });
    
    soundService.playGameStartSound();
  }

  /// 카드 선택 처리
  void _onCardTap(int index) {
    if (!isGameRunning || !isMyTurn || isTimerPaused) return;
    
    final card = cards[index];
    if (card.isMatched || card.isFlipped) return;
    
    soundService.playCardFlipSound();
    
    setState(() {
      card.isFlipped = true;
      
      if (firstSelectedIndex == null) {
        firstSelectedIndex = index;
      } else if (secondSelectedIndex == null && firstSelectedIndex != index) {
        secondSelectedIndex = index;
        _checkMatch();
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
      currentPlayerScore += 10;
      scoreModel.addScore(10);
      
      // 연속 매칭 기록 업데이트
      final currentCombo = scoreModel.currentCombo;
      if (currentCombo > maxCombo) {
        maxCombo = currentCombo;
      }
      
      firstSelectedIndex = null;
      secondSelectedIndex = null;
    });
    
    // 게임 완료 확인
    _checkGameCompletion();
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    soundService.playMismatchSound();
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          cards[firstSelectedIndex!].isFlipped = false;
          cards[secondSelectedIndex!].isFlipped = false;
          
          firstSelectedIndex = null;
          secondSelectedIndex = null;
          
          // 턴 변경
          isMyTurn = false;
        });
        
        // 상대방 턴으로 변경 (실제로는 Firebase를 통해 동기화)
        _switchTurn();
      }
    });
  }

  /// 턴 변경
  void _switchTurn() {
    // Firebase를 통해 턴 변경 정보를 상대방에게 전송
    // TODO: 실시간 턴 동기화 구현
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isMyTurn = true;
        });
      }
    });
  }

  /// 게임 완료 확인
  void _checkGameCompletion() {
    final matchedCards = cards.where((card) => card.isMatched).length;
    if (matchedCards == totalCards) {
      _gameOver();
    }
  }

  /// 게임 오버 처리
  void _gameOver() {
    isGameRunning = false;
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    
    // 온라인 멀티플레이어 게임 기록 저장
    _saveOnlineMultiplayerGameRecord();
    
    if (mounted) {
      _showGameOverDialog();
    }
  }

  /// 온라인 멀티플레이어 게임 기록 저장
  Future<void> _saveOnlineMultiplayerGameRecord() async {
    try {
      final totalTime = DateTime.now().difference(gameStartTime).inSeconds;
      
      final record = MultiplayerGameRecord(
        id: '',
        gameTitle: currentRoom.roomName,
        players: [
          PlayerGameResult(
            playerName: currentPlayerName,
            email: firebaseService.currentUser?.email ?? '',
            score: currentPlayerScore,
            matchCount: scoreModel.matchCount,
            failCount: scoreModel.failCount,
            maxCombo: maxCombo,
            timeLeft: timeLeft,
          ),
          PlayerGameResult(
            playerName: opponentPlayerName,
            email: opponentPlayerEmail,
            score: opponentPlayerScore,
            matchCount: 0, // TODO: 상대방 정보 동기화
            failCount: 0,
            maxCombo: 0,
            timeLeft: timeLeft,
          ),
        ],
        createdAt: DateTime.now(),
        isCompleted: true,
        totalTime: totalTime,
        timeLeft: timeLeft,
      );
      
      await firebaseService.saveOnlineMultiplayerGameRecord(record);
    } catch (e) {
      print('온라인 멀티플레이어 게임 기록 저장 오류: $e');
    }
  }

  /// 게임 오버 다이얼로그 표시
  void _showGameOverDialog() {
    final winner = currentPlayerScore > opponentPlayerScore 
        ? currentPlayerName 
        : opponentPlayerName;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('게임 종료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('승자: $winner'),
            const SizedBox(height: 16),
            Text('내 점수: $currentPlayerScore'),
            Text('상대방 점수: $opponentPlayerScore'),
            const SizedBox(height: 16),
            Text('최고 콤보: $maxCombo'),
            Text('남은 시간: ${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 방 목록으로 돌아가기
            },
            child: const Text('방 목록으로'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('다시 시작'),
          ),
        ],
      ),
    );
  }

  /// 게임 리셋
  void _resetGame() {
    setState(() {
      _createCards();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      maxCombo = 0;
      currentPlayerScore = 0;
      opponentPlayerScore = 0;
      scoreModel.reset();
    });
    
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentRoom.roomName),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _showExitDialog(),
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
        child: Column(
          children: [
            // 게임 정보 헤더
            _buildGameHeader(),
            
            // 카드 그리드
            Expanded(
              child: _buildCardGrid(),
            ),
            
            // 게임 컨트롤
            _buildGameControls(),
          ],
        ),
      ),
    );
  }

  /// 게임 정보 헤더 위젯
  Widget _buildGameHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 플레이어 정보
          Row(
            children: [
              Expanded(
                child: _buildPlayerInfo(
                  currentPlayerName,
                  currentPlayerScore,
                  isMyTurn,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPlayerInfo(
                  opponentPlayerName,
                  opponentPlayerScore,
                  !isMyTurn,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 게임 상태 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 시간
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 턴 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isMyTurn ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isMyTurn ? '내 턴' : '상대방 턴',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // 최고 콤보
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on, color: Colors.yellow, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '콤보: $maxCombo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 플레이어 정보 위젯
  Widget _buildPlayerInfo(String name, int score, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '점수: $score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 카드 그리드 위젯
  Widget _buildCardGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return MemoryCard(
          card: cards[index],
          onTap: () => _onCardTap(index),
        );
      },
    );
  }

  /// 게임 컨트롤 위젯
  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showExitDialog(),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('나가기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: isGameRunning ? null : _resetGame,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 나가기 확인 다이얼로그
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방 나가기'),
        content: const Text('정말로 방을 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await firebaseService.leaveOnlineRoom(currentRoom.id);
                if (mounted) {
                  Navigator.of(context).pop(); // 방 목록으로 돌아가기
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('방 나가기에 실패했습니다: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }
} 