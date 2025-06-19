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
          final score = latestMatch['score'] as int? ?? 0;
          
          print('다른 플레이어 매칭 감지: 플레이어=$matchPlayerId, 카드1=$cardIndex1, 카드2=$cardIndex2, 매칭=$isMatched, 점수=$score');
          
          setState(() {
            if (cardIndex1 < cards.length && cardIndex2 < cards.length) {
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
    
    // 방 ID를 시드로 사용하여 카드 섞기 (모든 플레이어가 동일한 순서)
    final roomIdHash = currentRoom.id.hashCode;
    final random = Random(roomIdHash);
    
    // Fisher-Yates 셔플 알고리즘 사용
    for (int i = tempCards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = tempCards[i];
      tempCards[i] = tempCards[j];
      tempCards[j] = temp;
    }
    
    setState(() {
      cards = tempCards;
    });
    
    print('카드 생성 완료: ${cards.length}개 카드, ${numPairs}개 쌍');
    print('방 ID 시드: $roomIdHash');
    // 디버깅을 위해 카드 정보 출력
    for (int i = 0; i < cards.length; i++) {
      print('카드 $i: ID=${cards[i].id}, 국기=${cards[i].emoji}, 이름=${cards[i].name}');
    }
    
    // 방장인 경우 Firebase에 카드 데이터 저장 (백업용)
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
      
      print('Firebase에 저장할 카드 데이터:');
      for (int i = 0; i < cardsData.length; i++) {
        print('  인덱스 $i: ID=${cardsData[i]['id']}, 국기=${cardsData[i]['emoji']}, 이름=${cardsData[i]['name']}');
      }
      
      await firebaseService.saveGameCards(currentRoom.id, cardsData);
      print('Firebase에 카드 데이터 저장 완료: ${cards.length}개 카드');
    } catch (e) {
      print('Firebase에 카드 데이터 저장 실패: $e');
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
    
    // 모든 플레이어가 동일한 시드로 카드 생성 (Firebase 로드 대신)
    _createCards();
    
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

  /// 턴 변경
  void _changeTurn() {
    if (!mounted) return;
    
    print('=== 턴 변경 시작 ===');
    print('현재 플레이어 ID: $currentPlayerId');
    print('방장 ID: ${currentRoom.hostId}');
    print('게스트 ID: ${currentRoom.guestId}');
    print('현재 내 턴: $isMyTurn');
    
    // 현재 플레이어가 방장인지 게스트인지 확인
    final isCurrentPlayerHost = currentRoom.isHost(currentPlayerId);
    
    // 다음 플레이어 ID 결정
    String nextPlayerId;
    if (isCurrentPlayerHost) {
      // 방장인 경우 게스트로 턴 변경
      nextPlayerId = currentRoom.guestId ?? currentRoom.hostId;
      print('방장 -> 게스트 턴 변경: $nextPlayerId');
    } else {
      // 게스트인 경우 방장으로 턴 변경
      nextPlayerId = currentRoom.hostId;
      print('게스트 -> 방장 턴 변경: $nextPlayerId');
    }
    
    print('턴 변경: $currentPlayerId -> $nextPlayerId');
    print('다음 턴이 내 턴인가: ${nextPlayerId == currentPlayerId}');
    
    // 로컬 상태 업데이트
    setState(() {
      isMyTurn = nextPlayerId == currentPlayerId;
    });
    
    print('로컬 턴 상태 업데이트: 내 턴 = $isMyTurn');
    
    // Firebase에 턴 변경 정보 전송
    firebaseService.syncTurnChange(currentRoom.id, currentPlayerId, nextPlayerId);
    
    print('Firebase 턴 변경 정보 전송 완료');
    print('=== 턴 변경 완료 ===');
  }

  /// 매칭 성공 처리
  void _handleMatchSuccess() {
    soundService.playMatchSound();
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    print('매칭 성공 처리 시작');
    print('현재 콤보: ${scoreModel.currentCombo}');
    
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
    
    // 실시간 동기화 - 매칭 성공 정보 전송 (점수 포함)
    firebaseService.syncCardMatch(
      currentRoom.id, 
      firstIndex, 
      secondIndex, 
      true, 
      currentPlayerId,
      currentPlayerScore, // 점수 정보 추가
    );
    
    print('매칭 성공 후 콤보: ${scoreModel.currentCombo}');
    
    // 매칭 성공 시에도 턴 변경 (연속 매칭이 아닌 경우)
    if (scoreModel.currentCombo == 0) {
      print('콤보가 0이므로 턴 변경 실행');
      _changeTurn();
    } else {
      print('콤보가 ${scoreModel.currentCombo}이므로 턴 유지');
    }
    
    // 게임 완료 확인
    _checkGameCompletion();
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    soundService.playMismatchSound();
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    print('매칭 실패 처리 시작');
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
        print('매칭 실패 후 카드 뒤집기 해제 및 턴 변경');
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
    // 게임 시작 상태를 Firebase에 업데이트
    if (currentRoom.isHost(currentPlayerId)) {
      firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
      print('게임 시작 상태를 Firebase에 업데이트 완료');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 레이아웃 계산 - 더 효율적인 공간 활용
    final headerHeight = 60.0; // 헤더 높이 줄임
    final controlHeight = 60.0; // 컨트롤 영역 높이 줄임
    final padding = 16.0; // 패딩 줄임
    final availableHeight = screenHeight - headerHeight - controlHeight - padding;
    
    // 카드 개수에 따른 그리드 계산
    final totalCards = cards.length;
    int gridColumns;
    int gridRows;
    
    // 화면 비율과 카드 개수를 고려한 그리드 계산
    final aspectRatio = screenWidth / screenHeight;
    
    if (screenWidth < 400) {
      // 작은 화면 (세로 모드)
      gridColumns = 4;
      gridRows = (totalCards / gridColumns).ceil();
    } else if (screenWidth < 600) {
      // 중간 화면
      if (aspectRatio < 1.0) {
        // 세로 모드
        gridColumns = 5;
        gridRows = (totalCards / gridColumns).ceil();
      } else {
        // 가로 모드
        gridColumns = 6;
        gridRows = (totalCards / gridColumns).ceil();
      }
    } else {
      // 큰 화면 (가로 모드)
      if (aspectRatio > 1.5) {
        // 매우 넓은 화면
        gridColumns = 8;
        gridRows = (totalCards / gridColumns).ceil();
      } else {
        // 일반적인 가로 모드
        gridColumns = 6;
        gridRows = (totalCards / gridColumns).ceil();
      }
    }
    
    // 카드 간격 최소화
    final cardSpacing = 2.0; // 간격을 2px로 줄임
    final availableGridWidth = screenWidth - padding - (gridColumns - 1) * cardSpacing;
    final availableGridHeight = availableHeight - (gridRows - 1) * cardSpacing;
    
    // 카드 크기 계산 - 가용 공간에 맞춰 조정
    final cardWidth = availableGridWidth / gridColumns;
    final cardHeight = availableGridHeight / gridRows;
    
    // 카드 크기 제한 (더 작게 조정)
    final cardSize = cardWidth.clamp(35.0, 70.0);
    
    // 그리드가 화면을 벗어나지 않도록 강제 조정
    final actualGridHeight = (cardSize * gridRows) + ((gridRows - 1) * cardSpacing);
    final finalCardSize = actualGridHeight > availableHeight 
        ? (availableHeight - (gridRows - 1) * cardSpacing) / gridRows
        : cardSize;
    
    print('레이아웃 정보:');
    print('화면 크기: ${screenWidth}x${screenHeight}');
    print('가용 높이: $availableHeight');
    print('그리드: ${gridColumns}x${gridRows}');
    print('카드 크기: ${finalCardSize.toStringAsFixed(1)}px');
    print('실제 그리드 높이: ${actualGridHeight.toStringAsFixed(1)}px');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 멀티플레이어 게임'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (isGameRunning)
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
              // 게임 정보 헤더 (고정 높이)
              Container(
                height: headerHeight,
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 현재 플레이어 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isMyTurn ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentPlayerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '점수: $currentPlayerScore',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 상대방 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: !isMyTurn ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              opponentPlayerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '점수: $opponentPlayerScore',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 게임 시작 버튼 (방장만, 게임 시작 전에만)
              if (!isGameRunning && currentRoom.isHost(currentPlayerId))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('게임 시작'),
                  ),
                ),
              
              // 대기 메시지 (게스트만, 게임 시작 전에만)
              if (!isGameRunning && !currentRoom.isHost(currentPlayerId))
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    '방장이 게임을 시작할 때까지 기다려주세요...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // 카드 그리드 (고정 크기, 스크롤 없음)
              if (isGameRunning)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // 스크롤 비활성화
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: cardSpacing,
                        mainAxisSpacing: cardSpacing,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: finalCardSize,
                          height: finalCardSize,
                          child: MemoryCard(
                            card: cards[index],
                            onTap: () => _onCardTap(index),
                            isEnabled: isMyTurn && isGameRunning,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              // 게임 완료 메시지
              if (!isGameRunning && gameCompleted)
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        '게임 완료!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '최고 연속 매칭: $maxCombo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 게임 컨트롤 (고정 높이)
              Container(
                height: controlHeight,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('방 나가기'),
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