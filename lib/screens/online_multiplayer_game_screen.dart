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
  bool isProcessingCardSelection = false; // 카드 선택 처리 중 여부 (중복 클릭 방지)
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
  
  // 실시간 동기화 관련 변수
  StreamSubscription? _cardActionsSubscription;
  StreamSubscription? _turnChangeSubscription;
  StreamSubscription? _cardMatchesSubscription;
  List<Map<String, dynamic>> recentCardActions = [];
  String? lastTurnChangePlayerId;
  Map<String, int> lastProcessedTimestamps = {}; // 처리된 타임스탬프 추적

  /// 게임 완료 여부
  bool gameCompleted = false;

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
    _cardActionsSubscription?.cancel();
    _turnChangeSubscription?.cancel();
    _cardMatchesSubscription?.cancel();
    lastProcessedTimestamps.clear();
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
        
        // 상대방 정보 가져오기 - 방 정보에서 직접 가져오기
        if (currentRoom.isHost(currentPlayerId)) {
          // 방장인 경우 게스트 정보 가져오기
          opponentPlayerName = currentRoom.guestName ?? '대기 중...';
          opponentPlayerEmail = currentRoom.guestEmail ?? '';
        } else {
          // 게스트인 경우 방장 정보 가져오기
          opponentPlayerName = currentRoom.hostName;
          opponentPlayerEmail = currentRoom.hostEmail;
        }
        
        print('플레이어 정보 로드 완료:');
        print('현재 플레이어: $currentPlayerName (${currentRoom.isHost(currentPlayerId) ? '방장' : '게스트'})');
        print('상대방: $opponentPlayerName');
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
          
          // 상대방 정보 업데이트
          if (currentPlayerId.isNotEmpty) {
            if (room.isHost(currentPlayerId)) {
              opponentPlayerName = room.guestName ?? '대기 중...';
              opponentPlayerEmail = room.guestEmail ?? '';
            } else {
              opponentPlayerName = room.hostName;
              opponentPlayerEmail = room.hostEmail;
            }
          }
        });
        
        // 방 상태에 따른 처리
        if (room.status == RoomStatus.playing && !isGameRunning) {
          _startGame();
          _setupRealtimeSync();
        } else if (room.status == RoomStatus.finished || room.status == RoomStatus.cancelled) {
          _gameOver();
        }
      }
    });
  }

  /// 실시간 동기화 설정
  void _setupRealtimeSync() {
    // 타임스탬프 추적 초기화
    lastProcessedTimestamps.clear();
    
    // 카드 액션 리스너
    _cardActionsSubscription = firebaseService.getCardActionsStream(currentRoom.id)
        .listen((actions) {
      // 모든 액션을 시간순으로 처리 (최신부터)
      for (final action in actions) {
        final actionPlayerId = action['playerId'] as String;
        final actionTimestamp = action['timestamp'] as int? ?? 0;
        final actionId = action['id'] as String? ?? '';
        
        // 다른 플레이어의 액션만 처리
        if (actionPlayerId != currentPlayerId) {
          // 이미 처리된 액션인지 확인 (더 관대한 필터링)
          final actionKey = '${actionPlayerId}_${actionId}';
          final lastTimestamp = lastProcessedTimestamps[actionKey] ?? 0;
          
          // 타임스탬프가 이전보다 작거나 같으면 무시 (중복 방지)
          if (actionTimestamp <= lastTimestamp) {
            continue;
          }
          
          final cardIndex = action['cardIndex'] as int;
          final isFlipped = action['isFlipped'] as bool;
          
          // 카드 인덱스 유효성 확인
          if (cardIndex >= 0 && cardIndex < cards.length) {
            setState(() {
              cards[cardIndex].isFlipped = isFlipped;
            });
            
            // 처리된 타임스탬프 기록
            lastProcessedTimestamps[actionKey] = actionTimestamp;
          }
        }
      }
    });

    // 카드 매칭 리스너
    _cardMatchesSubscription = firebaseService.getCardMatchesStream(currentRoom.id)
        .listen((matches) {
      // 모든 매칭을 시간순으로 처리 (최신부터)
      for (final match in matches) {
        final matchPlayerId = match['playerId'] as String;
        final matchTimestamp = match['timestamp'] as int? ?? 0;
        final matchId = match['id'] as String? ?? '';
        
        // 다른 플레이어의 매칭만 처리
        if (matchPlayerId != currentPlayerId) {
          // 이미 처리된 매칭인지 확인 (더 관대한 필터링)
          final matchKey = '${matchPlayerId}_${matchId}';
          final lastTimestamp = lastProcessedTimestamps[matchKey] ?? 0;
          
          // 타임스탬프가 이전보다 작거나 같으면 무시 (중복 방지)
          if (matchTimestamp <= lastTimestamp) {
            continue;
          }
          
          final cardIndex1 = match['cardIndex1'] as int;
          final cardIndex2 = match['cardIndex2'] as int;
          final isMatched = match['isMatched'] as bool;
          final score = match['score'] as int? ?? 0;
          
          // 카드 인덱스 유효성 확인
          if (cardIndex1 >= 0 && cardIndex1 < cards.length && 
              cardIndex2 >= 0 && cardIndex2 < cards.length) {
            setState(() {
              cards[cardIndex1].isMatched = isMatched;
              cards[cardIndex2].isMatched = isMatched;
              if (isMatched) {
                cards[cardIndex1].isFlipped = true;
                cards[cardIndex2].isFlipped = true;
                
                // 상대방 점수 업데이트
                if (currentRoom.isHost(currentPlayerId)) {
                  opponentPlayerScore = score;
                } else {
                  opponentPlayerScore = score;
                }
              } else {
                // 매칭 실패 시 카드 뒤집기 해제
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    setState(() {
                      // 카드 인덱스 유효성 확인 후 뒤집기 해제
                      if (cardIndex1 < cards.length) {
                        cards[cardIndex1].isFlipped = false;
                      }
                      if (cardIndex2 < cards.length) {
                        cards[cardIndex2].isFlipped = false;
                      }
                    });
                  }
                });
              }
            });
            
            // 처리된 타임스탬프 기록
            lastProcessedTimestamps[matchKey] = matchTimestamp;
          }
        }
      }
    });

    // 턴 변경 리스너
    _turnChangeSubscription = firebaseService.getTurnChangeStream(currentRoom.id)
        .listen((turnChange) {
      if (turnChange != null) {
        final nextPlayerId = turnChange['nextPlayerId'] as String;
        final changePlayerId = turnChange['currentPlayerId'] as String;
        final turnTimestamp = turnChange['timestamp'] as int? ?? 0;
        final turnId = turnChange['id'] as String? ?? '';
        
        // 다른 플레이어의 턴 변경만 처리
        if (changePlayerId != currentPlayerId) {
          // 이미 처리된 턴 변경인지 확인 (더 관대한 필터링)
          final turnKey = '${changePlayerId}_${turnId}';
          final lastTimestamp = lastProcessedTimestamps[turnKey] ?? 0;
          
          // 타임스탬프가 이전보다 작거나 같으면 무시 (중복 방지)
          if (turnTimestamp <= lastTimestamp) {
            return;
          }
          
          setState(() {
            isMyTurn = nextPlayerId == currentPlayerId;
            
            // 내 턴이 시작될 때 선택된 카드 초기화
            if (isMyTurn) {
              firstSelectedIndex = null;
              secondSelectedIndex = null;
              isProcessingCardSelection = false;
            }
          });
          
          // 처리된 타임스탬프 기록
          lastProcessedTimestamps[turnKey] = turnTimestamp;
        }
      }
    });
  }

  /// 게임 초기화
  void _initGame() {
    _createCardsWithFixedSeed();
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  /// 고정된 시드로 카드 생성 (모든 플레이어가 동일한 카드 배치)
  void _createCardsWithFixedSeed() {
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
    
    // 방 ID를 시드로 사용하여 모든 플레이어가 동일한 카드 배치
    final seed = currentRoom.id.hashCode;
    final random = Random(seed);
    tempCards.shuffle(random);
    
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

  /// 타이머 시작
  void _startTimer() {
    _setupTimer();
  }

  /// 게임 시작
  void _startGame() {
    // 모든 플레이어가 동일한 시드로 카드 생성 (Firebase 로드 대신)
    _createCardsWithFixedSeed();
    
    // 방장이 먼저 시작하도록 턴 설정
    final shouldStartFirst = currentRoom.isHost(currentPlayerId);
    
    setState(() {
      isGameRunning = true;
      gameStartTime = DateTime.now();
      isMyTurn = shouldStartFirst;
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      isProcessingCardSelection = false;
    });
    
    // 타임스탬프 추적 초기화
    lastProcessedTimestamps.clear();
    
    // 타이머 시작
    _startTimer();
    
    // 게임 시작 사운드
    soundService.playGameStart();
    
    // Firebase에 게임 상태 업데이트
    _updateGameState();
  }

  /// 카드 선택 처리
  void _onCardTap(int index) {
    if (!mounted || !isGameRunning || isProcessingCardSelection) {
      return;
    }
    
    // 내 턴인지 확인
    if (!isMyTurn) {
      return;
    }
    
    // 이미 선택된 카드인지 확인
    if (firstSelectedIndex == index || secondSelectedIndex == index) {
      return;
    }
    
    // 이미 매칭된 카드인지 확인
    if (cards[index].isMatched) {
      return;
    }
    
    setState(() {
      isProcessingCardSelection = true;
    });
    
    // 카드 뒤집기 사운드
    soundService.playCardFlip();
    
    // 카드 뒤집기
    setState(() {
      cards[index].isFlipped = true;
    });
    
    // 실시간 동기화 - 카드 뒤집기 정보 전송 (약간의 지연 후)
    Future.delayed(const Duration(milliseconds: 50), () {
      firebaseService.syncCardFlip(currentRoom.id, index, true, currentPlayerId);
    });
    
    // 첫 번째 카드 선택
    if (firstSelectedIndex == null) {
      setState(() {
        firstSelectedIndex = index;
        isProcessingCardSelection = false;
      });
    }
    // 두 번째 카드 선택
    else if (secondSelectedIndex == null) {
      setState(() {
        secondSelectedIndex = index;
      });
      
      // 매칭 확인 (약간의 지연 후)
      Future.delayed(const Duration(milliseconds: 100), () {
        _checkMatch();
      });
    }
  }

  /// 매칭 확인
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) {
      return;
    }
    
    final firstCard = cards[firstSelectedIndex!];
    final secondCard = cards[secondSelectedIndex!];
    
    // 매칭 확인
    final isMatch = firstCard.id == secondCard.id;
    
    if (isMatch) {
      _handleMatchSuccess();
    } else {
      _handleMatchFailure();
    }
  }

  /// 매칭 성공 처리
  void _handleMatchSuccess() {
    soundService.playCardMatch(); // 카드 매치 성공 사운드
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    setState(() {
      // 카드 매칭 상태 설정
      cards[firstIndex].isMatched = true;
      cards[secondIndex].isMatched = true;
      cards[firstIndex].isFlipped = true;
      cards[secondIndex].isFlipped = true;
      
      // 점수 증가
      currentPlayerScore += 10;
      scoreModel.addScore(10);
      
      // 연속 매칭 기록 업데이트
      final currentCombo = scoreModel.currentCombo;
      if (currentCombo > maxCombo) {
        maxCombo = currentCombo;
      }
      
      // 선택 상태 초기화
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      isProcessingCardSelection = false;
    });
    
    // 실시간 동기화 - 매칭 성공 정보 전송 (점수 포함)
    firebaseService.syncCardMatch(
      currentRoom.id, 
      firstIndex, 
      secondIndex, 
      true, 
      currentPlayerId,
      currentPlayerScore, // 점수 정보 추가
    );
    
    // 매칭 성공 시에도 턴 변경 (연속 매칭이 아닌 경우)
    if (scoreModel.currentCombo == 0) {
      _changeTurn();
    }
    
    // 게임 완료 확인
    _checkGameCompletion();
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    soundService.playCardMismatch(); // 카드 매치 실패 사운드
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    // 실시간 동기화 - 매칭 실패 정보 전송
    firebaseService.syncCardMatch(
      currentRoom.id, 
      firstIndex, 
      secondIndex, 
      false, 
      currentPlayerId
    );
    
    // 즉시 선택 상태 초기화
    setState(() {
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      isProcessingCardSelection = false;
    });
    
    // 1초 후 카드 뒤집기 해제
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          // 카드 인덱스 유효성 확인 후 뒤집기 해제
          if (firstIndex < cards.length) {
            cards[firstIndex].isFlipped = false;
          }
          if (secondIndex < cards.length) {
            cards[secondIndex].isFlipped = false;
          }
        });
        
        // 턴 변경
        _changeTurn();
      }
    });
  }

  /// 턴 변경
  void _changeTurn() {
    if (!mounted) return;
    
    // 다음 플레이어 ID 결정
    String nextPlayerId;
    if (currentRoom.isHost(currentPlayerId)) {
      // 방장인 경우 게스트로 턴 변경
      nextPlayerId = currentRoom.guestId ?? currentRoom.hostId;
    } else {
      // 게스트인 경우 방장으로 턴 변경
      nextPlayerId = currentRoom.hostId;
    }
    
    // 다음 플레이어가 유효한지 확인
    if (nextPlayerId.isEmpty) {
      return;
    }
    
    // 로컬 상태 먼저 업데이트
    setState(() {
      isMyTurn = nextPlayerId == currentPlayerId;
    });
    
    // Firebase에 턴 변경 정보 전송
    firebaseService.syncTurnChange(currentRoom.id, currentPlayerId, nextPlayerId);
  }

  /// 게임 완료 확인
  void _checkGameCompletion() {
    final matchedCards = cards.where((card) => card.isMatched).length;
    final totalCards = cards.length;
    
    if (matchedCards == totalCards) {
      // 게임 승리 사운드 (박수 효과음 포함)
      soundService.playGameWin();
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
      _createCardsWithFixedSeed();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      isProcessingCardSelection = false;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      maxCombo = 0;
      currentPlayerScore = 0;
      opponentPlayerScore = 0;
      scoreModel.reset();
    });
    
    // 타임스탬프 추적 초기화
    lastProcessedTimestamps.clear();
    
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  /// Firebase에 게임 상태 업데이트
  void _updateGameState() {
    // 게임 시작 상태를 Firebase에 업데이트
    if (currentRoom.isHost(currentPlayerId)) {
      firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.roomName),
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
            // 반응형 카드 그리드
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double screenWidth = constraints.maxWidth;
                  const double spacing = 4.0;
                  final double itemWidth = (screenWidth - (spacing * (cols + 1))) / cols;
                  final double itemHeight = itemWidth * 1.4;
                  final double childAspectRatio = itemWidth / itemHeight;

                  return GridView.builder(
                    padding: const EdgeInsets.all(spacing),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: totalCards,
                    itemBuilder: (context, index) {
                      return MemoryCard(
                        card: cards[index],
                        onTap: () => _onCardTap(index),
                      );
                    },
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
    // 플레이어 정보가 아직 로드되지 않았으면 빈 컨테이너 반환
    if (players.isEmpty) {
      return const SizedBox(height: 60);
    }
    
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
                  _buildPlayerScore(players[0]),
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
                  _buildPlayerScore(players[1]),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '현재 턴: ${players[currentPlayerIndex].playerName}',
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

  Widget _buildPlayerScore(Player player) {
    bool isCurrentTurn = players[currentPlayerIndex].id == player.id;
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
            player.playerName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '점수: ${player.score}',
            style: const TextStyle(fontSize: 14),
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

  /// 게임 리셋
  void _restartGame() {
    _resetGame();
  }

  /// 타이머 일시정지
  void _togglePause() {
    setState(() {
      isTimerPaused = !isTimerPaused;
    });
  }
} 