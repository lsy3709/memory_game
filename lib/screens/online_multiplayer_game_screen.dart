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
  
  // 실시간 동기화 관련 변수
  StreamSubscription? _cardActionsSubscription;
  StreamSubscription? _turnChangeSubscription;
  StreamSubscription? _cardMatchesSubscription;
  List<Map<String, dynamic>> recentCardActions = [];
  String? lastTurnChangePlayerId;

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
    // 카드 액션 리스너
    _cardActionsSubscription = firebaseService.getCardActionsStream(currentRoom.id)
        .listen((actions) {
      if (actions.isNotEmpty) {
        final latestAction = actions.first;
        final actionPlayerId = latestAction['playerId'] as String;
        
        // 다른 플레이어의 액션만 처리
        if (actionPlayerId != currentPlayerId) {
          final cardIndex = latestAction['cardIndex'] as int;
          final isFlipped = latestAction['isFlipped'] as bool;
          
          print('다른 플레이어 카드 액션 감지: 플레이어=$actionPlayerId, 카드=$cardIndex, 뒤집힘=$isFlipped');
          
          setState(() {
            if (cardIndex < cards.length) {
              cards[cardIndex].isFlipped = isFlipped;
            }
          });
        }
      }
    });

    // 카드 매칭 리스너
    _cardMatchesSubscription = firebaseService.getCardMatchesStream(currentRoom.id)
        .listen((matches) {
      if (matches.isNotEmpty) {
        final latestMatch = matches.first;
        final matchPlayerId = latestMatch['playerId'] as String;
        
        // 다른 플레이어의 매칭만 처리
        if (matchPlayerId != currentPlayerId) {
          final cardIndex1 = latestMatch['cardIndex1'] as int;
          final cardIndex2 = latestMatch['cardIndex2'] as int;
          final isMatched = latestMatch['isMatched'] as bool;
          
          print('다른 플레이어 매칭 감지: 플레이어=$matchPlayerId, 카드1=$cardIndex1, 카드2=$cardIndex2, 매칭=$isMatched');
          
          setState(() {
            if (cardIndex1 < cards.length && cardIndex2 < cards.length) {
              cards[cardIndex1].isMatched = isMatched;
              cards[cardIndex2].isMatched = isMatched;
              if (isMatched) {
                cards[cardIndex1].isFlipped = true;
                cards[cardIndex2].isFlipped = true;
              } else {
                // 매칭 실패 시 카드 뒤집기 해제
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    setState(() {
                      cards[cardIndex1].isFlipped = false;
                      cards[cardIndex2].isFlipped = false;
                    });
                  }
                });
              }
            }
          });
        }
      }
    });

    // 턴 변경 리스너
    _turnChangeSubscription = firebaseService.getTurnChangeStream(currentRoom.id)
        .listen((turnChange) {
      if (turnChange != null) {
        final nextPlayerId = turnChange['nextPlayerId'] as String;
        final changePlayerId = turnChange['currentPlayerId'] as String;
        
        print('턴 변경 감지: $changePlayerId -> $nextPlayerId');
        print('현재 플레이어: $currentPlayerId, 내 턴: ${nextPlayerId == currentPlayerId}');
        
        // 다른 플레이어의 턴 변경만 처리
        if (changePlayerId != currentPlayerId) {
          setState(() {
            isMyTurn = nextPlayerId == currentPlayerId;
          });
          
          print('턴 변경 완료: 내 턴 = $isMyTurn');
          
          // 턴 변경 시 선택된 카드 초기화
          if (isMyTurn) {
            firstSelectedIndex = null;
            secondSelectedIndex = null;
          }
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
    
    // 카드 쌍 생성 - 각 쌍에 고유한 ID 부여
    for (int i = 0; i < numPairs; i++) {
      final flagData = _getFlagWithName(i);
      
      // 첫 번째 카드
      tempCards.add(CardModel(
        id: i,
        emoji: flagData['flag']!,
        name: flagData['name'],
        isMatched: false,
        isFlipped: false,
      ));
      // 두 번째 카드 (같은 ID)
      tempCards.add(CardModel(
        id: i,
        emoji: flagData['flag']!,
        name: flagData['name'],
        isMatched: false,
        isFlipped: false,
      ));
    }
    
    // 카드 섞기
    tempCards.shuffle(Random());
    
    setState(() {
      cards = tempCards;
    });
    
    print('카드 생성 완료: ${cards.length}개 카드, ${numPairs}개 쌍');
    // 디버깅을 위해 카드 정보 출력
    for (int i = 0; i < cards.length; i++) {
      print('카드 $i: ID=${cards[i].id}, 국기=${cards[i].emoji}, 이름=${cards[i].name}');
    }
    
    // 방장인 경우 Firebase에 카드 데이터 저장
    if (currentRoom.isHost(currentPlayerId)) {
      _saveCardsToFirebase();
    }
  }

  /// Firebase에 카드 데이터 저장
  Future<void> _saveCardsToFirebase() async {
    try {
      // 카드 데이터에 순서 정보 추가
      final cardsData = cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        final cardData = card.toJson();
        cardData['orderIndex'] = index; // 순서 정보 추가
        return cardData;
      }).toList();
      
      await firebaseService.saveGameCards(currentRoom.id, cardsData);
      print('Firebase에 카드 데이터 저장 완료: ${cards.length}개 카드');
    } catch (e) {
      print('Firebase에 카드 데이터 저장 실패: $e');
    }
  }

  /// Firebase에서 카드 데이터 로드
  Future<void> _loadCardsFromFirebase() async {
    try {
      final loadedCardsData = await firebaseService.loadGameCards(currentRoom.id);
      if (loadedCardsData.isNotEmpty) {
        // 순서 정보에 따라 정렬
        loadedCardsData.sort((a, b) => (a['orderIndex'] ?? 0).compareTo(b['orderIndex'] ?? 0));
        
        final loadedCards = loadedCardsData.map((data) => CardModel.fromJson(data)).toList();
        
        setState(() {
          cards = loadedCards;
        });
        print('Firebase에서 카드 데이터 로드 완료: ${cards.length}개 카드');
      } else {
        print('Firebase에 저장된 카드 데이터가 없습니다. 새로 생성합니다.');
        _createCards();
      }
    } catch (e) {
      print('Firebase에서 카드 데이터 로드 실패: $e');
      _createCards();
    }
  }

  /// 이모지 가져오기 (국기로 변경)
  String _getFlagEmoji(int index) {
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

  /// 국기와 이름을 함께 가져오기
  Map<String, String> _getFlagWithName(int index) {
    return {
      'flag': _getFlagEmoji(index),
      'name': _getFlagName(index),
    };
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
    print('게임 시작 - 방장: ${currentRoom.isHost(currentPlayerId)}');
    
    // 방장이 아닌 경우 Firebase에서 카드 데이터 로드
    if (!currentRoom.isHost(currentPlayerId)) {
      _loadCardsFromFirebase();
    } else {
      // 방장인 경우 새로 카드 생성
      _createCards();
    }
    
    setState(() {
      isGameRunning = true;
      gameStartTime = DateTime.now();
      // 방장이 먼저 시작
      isMyTurn = currentRoom.isHost(currentPlayerId);
      firstSelectedIndex = null;
      secondSelectedIndex = null;
    });
    
    // 타이머 시작
    _startTimer();
    
    // Firebase에 게임 상태 업데이트
    _updateGameState();
    
    print('게임 시작됨 - 내 턴: $isMyTurn');
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
    
    // 실시간 동기화 - 카드 플립 정보 전송
    firebaseService.syncCardFlip(currentRoom.id, index, true, currentPlayerId);
  }

  /// 카드 매칭 확인
  void _checkMatch() {
    final firstCard = cards[firstSelectedIndex!];
    final secondCard = cards[secondSelectedIndex!];
    
    print('매칭 확인:');
    print('첫 번째 카드 (인덱스: $firstSelectedIndex): ID=${firstCard.id}, 이모지=${firstCard.emoji}');
    print('두 번째 카드 (인덱스: $secondSelectedIndex): ID=${secondCard.id}, 이모지=${secondCard.emoji}');
    print('매칭 결과: ${firstCard.id == secondCard.id}');
    
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
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    setState(() {
      cards[firstIndex].isMatched = true;
      cards[secondIndex].isMatched = true;
      
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
    
    // 실시간 동기화 - 매칭 성공 정보 전송
    firebaseService.syncCardMatch(
      currentRoom.id, 
      firstIndex, 
      secondIndex, 
      true, 
      currentPlayerId
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
    soundService.playMismatchSound();
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    print('매칭 실패 - 카드 뒤집기 해제: $firstIndex, $secondIndex');
    
    // 실시간 동기화 - 매칭 실패 정보 전송
    firebaseService.syncCardMatch(
      currentRoom.id, 
      firstIndex, 
      secondIndex, 
      false, 
      currentPlayerId
    );
    
    // 1초 후 카드 뒤집기 해제
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          cards[firstIndex].isFlipped = false;
          cards[secondIndex].isFlipped = false;
          firstSelectedIndex = null;
          secondSelectedIndex = null;
        });
        
        // 턴 변경
        _changeTurn();
      }
    });
  }

  /// 턴 변경
  void _changeTurn() {
    if (!mounted) return;
    
    // 현재 방에서 다음 플레이어 찾기
    final currentPlayerIndex = currentRoom.players.indexWhere((p) => p.id == currentPlayerId);
    if (currentPlayerIndex == -1) return;
    
    final nextPlayerIndex = (currentPlayerIndex + 1) % currentRoom.players.length;
    final nextPlayerId = currentRoom.players[nextPlayerIndex].id;
    
    print('턴 변경: $currentPlayerId -> $nextPlayerId');
    
    setState(() {
      isMyTurn = nextPlayerId == currentPlayerId;
    });
    
    // Firebase에 턴 변경 정보 전송
    firebaseService.syncTurnChange(currentRoom.id, currentPlayerId, nextPlayerId);
    
    print('턴 변경 완료: 내 턴 = $isMyTurn');
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

  /// Firebase에 게임 상태 업데이트
  void _updateGameState() {
    // 게임 상태 업데이트 로직 (필요시 구현)
    print('게임 상태 업데이트 완료');
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
            
            // 게임 시작 전 대기 화면 또는 카드 그리드
            Expanded(
              child: currentRoom.status == RoomStatus.waiting 
                  ? _buildWaitingScreen()
                  : _buildCardGrid(),
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
      padding: const EdgeInsets.all(8), // 패딩 줄임
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
              const SizedBox(width: 8), // 간격 줄임
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
          const SizedBox(height: 8), // 간격 줄임
          
          // 게임 상태 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 시간
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 패딩 줄임
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 14), // 크기 줄임
                    const SizedBox(width: 2), // 간격 줄임
                    Text(
                      '${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // 폰트 크기 줄임
                      ),
                    ),
                  ],
                ),
              ),
              
              // 턴 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 패딩 줄임
                decoration: BoxDecoration(
                  color: isMyTurn ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isMyTurn ? '내 턴' : '상대방 턴',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // 폰트 크기 줄임
                  ),
                ),
              ),
              
              // 최고 콤보
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 패딩 줄임
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on, color: Colors.yellow, size: 14), // 크기 줄임
                    const SizedBox(width: 2), // 간격 줄임
                    Text(
                      '콤보: $maxCombo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // 폰트 크기 줄임
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
      padding: const EdgeInsets.all(8), // 패딩 줄임
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8), // 반지름 줄임
        border: Border.all(
          color: isActive ? color : Colors.transparent,
          width: 1, // 테두리 두께 줄임
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12, // 폰트 크기 줄임
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2), // 간격 줄임
          Text(
            '점수: $score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10, // 폰트 크기 줄임
            ),
          ),
        ],
      ),
    );
  }

  /// 카드 그리드 위젯
  Widget _buildCardGrid() {
    // 화면 크기에 따라 카드 크기 조정
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 헤더와 컨트롤 영역을 제외한 사용 가능한 높이 계산 (더 정확한 계산)
    final availableHeight = screenHeight - 200; // 헤더 + 컨트롤 영역 줄임
    
    // 카드 크기 계산 (화면에 맞게 조정)
    final horizontalPadding = 16.0; // 좌우 패딩 줄임
    final cardSpacing = 4.0; // 카드 간격 더 줄임
    final availableWidth = screenWidth - horizontalPadding - (cols - 1) * cardSpacing;
    final cardWidth = availableWidth / cols;
    
    // 카드 높이 계산 (비율 고려)
    final cardHeight = cardWidth * 1.0; // 카드 비율 더 줄임
    
    // 전체 그리드 높이 계산
    final totalGridHeight = cardHeight * rows + (rows - 1) * cardSpacing;
    
    // 그리드가 화면을 벗어나지 않도록 조정
    final adjustedCardHeight = totalGridHeight > availableHeight 
        ? (availableHeight - (rows - 1) * cardSpacing) / rows 
        : cardHeight;
    
    return Container(
      padding: const EdgeInsets.all(8), // 패딩 줄임
      child: SizedBox(
        height: totalGridHeight > availableHeight ? totalGridHeight : availableHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // 스크롤 비활성화
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: cardWidth / adjustedCardHeight,
            crossAxisSpacing: cardSpacing,
            mainAxisSpacing: cardSpacing,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            return MemoryCard(
              card: cards[index],
              onTap: () => _onCardTap(index),
            );
          },
        ),
      ),
    );
  }

  /// 게임 컨트롤 위젯
  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.all(8), // 패딩 줄임
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showExitDialog(),
            icon: const Icon(Icons.exit_to_app, size: 16), // 아이콘 크기 줄임
            label: const Text('나가기', style: TextStyle(fontSize: 12)), // 폰트 크기 줄임
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 패딩 줄임
            ),
          ),
          if (currentRoom.status == RoomStatus.waiting && currentRoom.isHost(currentPlayerId) && currentRoom.isFull)
            ElevatedButton.icon(
              onPressed: _startGameAsHost,
              icon: const Icon(Icons.play_arrow, size: 16), // 아이콘 크기 줄임
              label: const Text('게임 시작', style: TextStyle(fontSize: 12)), // 폰트 크기 줄임
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 패딩 줄임
              ),
            ),
          if (currentRoom.status == RoomStatus.playing)
            ElevatedButton.icon(
              onPressed: isGameRunning ? null : _resetGame,
              icon: const Icon(Icons.refresh, size: 16), // 아이콘 크기 줄임
              label: const Text('다시 시작', style: TextStyle(fontSize: 12)), // 폰트 크기 줄임
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 패딩 줄임
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

  /// 대기 화면 위젯
  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            '게임 시작 대기 중...',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '상대방이 참가하면 게임이 시작됩니다.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // 방장만 시작 버튼 표시
          if (currentRoom.isHost(currentPlayerId) && currentRoom.isFull)
            ElevatedButton.icon(
              onPressed: _startGameAsHost,
              icon: const Icon(Icons.play_arrow),
              label: const Text('게임 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  /// 방장이 게임 시작
  Future<void> _startGameAsHost() async {
    try {
      await firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
      print('게임 시작 요청 완료');
    } catch (e) {
      print('게임 시작 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게임 시작에 실패했습니다: $e')),
        );
      }
    }
  }
} 