import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/game_record.dart';
import '../models/multiplayer_game_record.dart';
import '../models/online_room.dart';
import '../services/sound_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

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
  final StorageService storageService = StorageService.instance; // 로컬 저장 서비스
  
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
  
  // 실시간 동기화 관련 변수들
  StreamSubscription<List<Map<String, dynamic>>>? _cardActionsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _cardMatchesSubscription;
  StreamSubscription<Map<String, dynamic>?>? _turnChangeSubscription;
  StreamSubscription<Map<String, dynamic>?>? _gameStateSubscription;
  String? lastTurnChangePlayerId;
  
  // 처리된 액션 추적을 위한 변수들
  Set<String> _processedCardActions = {};
  Set<String> _processedCardMatches = {};

  /// 게임 완료 여부
  bool gameCompleted = false;

  /// 현재 점수
  int get score => scoreModel.score;

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
    _gameStateSubscription?.cancel();
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
    print('=== 실시간 동기화 설정 시작 ===');
    
    // 게임 상태 리스너
    _gameStateSubscription = firebaseService.getGameStateStream(currentRoom.id)
        .listen((gameState) {
      if (gameState != null) {
        final isGameRunningState = gameState['isGameRunning'] as bool? ?? false;
        final currentTurn = gameState['currentTurn'] as String? ?? '';
        
        print('게임 상태 변경 감지: 진행중=$isGameRunningState, 현재 턴=$currentTurn');
        
        if (isGameRunningState && !isGameRunning) {
          // 게임이 시작되었을 때
          print('게임 시작 감지됨');
          setState(() {
            isGameRunning = true;
            isMyTurn = currentTurn == currentPlayerId;
            gameStartTime = DateTime.now();
            firstSelectedIndex = null;
            secondSelectedIndex = null;
            lastTurnChangePlayerId = null; // 턴 변경 중복 방지 변수 초기화
          });
          
          // 타이머 시작
          _startTimer();
          
          print('게임 시작 상태 동기화 완료: 내 턴 = $isMyTurn');
        } else if (!isGameRunningState && isGameRunning) {
          // 게임이 종료되었을 때
          print('게임 종료 감지됨');
          setState(() {
            isGameRunning = false;
            isMyTurn = false;
          });
          
          // 타이머 정지
          _stopTimer();
        } else if (isGameRunningState && isGameRunning) {
          // 턴 상태만 업데이트
          final newIsMyTurn = currentTurn == currentPlayerId;
          if (newIsMyTurn != isMyTurn) {
            print('턴 상태 변경: $isMyTurn -> $newIsMyTurn');
            setState(() {
              isMyTurn = newIsMyTurn;
            });
          }
        }
      }
    });

    // 카드 액션 리스너
    _cardActionsSubscription = firebaseService.getCardActionsStream(currentRoom.id)
        .listen((actions) {
      if (actions.isNotEmpty) {
        print('카드 액션 스트림 수신: ${actions.length}개 액션');
        
        // 모든 액션을 처리 (순차 처리)
        for (final action in actions) {
          final actionPlayerId = action['playerId'] as String;
          final cardIndex = action['cardIndex'] as int;
          final isFlipped = action['isFlipped'] as bool;
          final timestamp = action['timestamp'] as int? ?? 0;
          
          // 액션 고유 ID 생성 (중복 처리 방지)
          final actionId = '${actionPlayerId}_${cardIndex}_${timestamp}';
          
          if (_processedCardActions.contains(actionId)) {
            print('이미 처리된 액션 무시: $actionId');
            continue;
          }
          
          print('액션 처리: 플레이어=$actionPlayerId, 카드=$cardIndex, 뒤집힘=$isFlipped');
          
          // 다른 플레이어의 액션만 처리
          if (actionPlayerId != currentPlayerId) {
            print('다른 플레이어 카드 액션 처리: 플레이어=$actionPlayerId, 카드=$cardIndex, 뒤집힘=$isFlipped');
            
            setState(() {
              if (cardIndex < cards.length) {
                cards[cardIndex].isFlipped = isFlipped;
                print('카드 $cardIndex 뒤집기 상태 업데이트: $isFlipped');
              } else {
                print('잘못된 카드 인덱스: $cardIndex (총 ${cards.length}개 카드)');
              }
            });
          } else {
            print('내가 보낸 카드 액션이므로 무시');
          }
          
          // 처리된 액션으로 표시
          _processedCardActions.add(actionId);
          
          // 오래된 액션 ID 정리 (메모리 관리)
          if (_processedCardActions.length > 100) {
            _processedCardActions.clear();
          }
        }
      }
    });

    // 카드 매칭 리스너
    _cardMatchesSubscription = firebaseService.getCardMatchesStream(currentRoom.id)
        .listen((matches) {
      if (matches.isNotEmpty) {
        print('카드 매칭 스트림 수신: ${matches.length}개 매칭');
        
        // 모든 매칭을 처리 (순차 처리)
        for (final match in matches) {
          final matchPlayerId = match['playerId'] as String;
          final cardIndex1 = match['cardIndex1'] as int;
          final cardIndex2 = match['cardIndex2'] as int;
          final isMatched = match['isMatched'] as bool;
          final score = match['score'] as int? ?? 0;
          final timestamp = match['timestamp'] as int? ?? 0;
          
          // 매칭 고유 ID 생성 (중복 처리 방지)
          final matchId = '${matchPlayerId}_${cardIndex1}_${cardIndex2}_${timestamp}';
          
          if (_processedCardMatches.contains(matchId)) {
            print('이미 처리된 매칭 무시: $matchId');
            continue;
          }
          
          print('매칭 처리: 플레이어=$matchPlayerId, 카드1=$cardIndex1, 카드2=$cardIndex2, 매칭=$isMatched, 점수=$score');
          
          // 다른 플레이어의 매칭만 처리
          if (matchPlayerId != currentPlayerId) {
            print('다른 플레이어 매칭 처리: 플레이어=$matchPlayerId, 카드1=$cardIndex1, 카드2=$cardIndex2, 매칭=$isMatched, 점수=$score');
            
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
                  print('매칭 성공 - 상대방 점수 업데이트: $opponentPlayerScore');
                } else {
                  // 매칭 실패 시 카드 뒤집기 해제
                  print('매칭 실패 - 1초 후 카드 뒤집기 해제 예정');
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      setState(() {
                        cards[cardIndex1].isFlipped = false;
                        cards[cardIndex2].isFlipped = false;
                        firstSelectedIndex = null;
                        secondSelectedIndex = null;
                      });
                    }
                  });
                }
              } else {
                print('잘못된 카드 인덱스: $cardIndex1, $cardIndex2 (총 ${cards.length}개 카드)');
              }
            });
          } else {
            print('내가 보낸 매칭이므로 무시');
          }
          
          // 처리된 매칭으로 표시
          _processedCardMatches.add(matchId);
          
          // 오래된 매칭 ID 정리 (메모리 관리)
          if (_processedCardMatches.length > 50) {
            _processedCardMatches.clear();
          }
        }
      }
    });

    // 턴 변경 리스너 - 완전히 개선된 버전
    _turnChangeSubscription = firebaseService.getTurnChangeStream(currentRoom.id)
        .listen((turnChange) {
      if (turnChange != null) {
        final nextPlayerId = turnChange['nextPlayerId'] as String;
        final changePlayerId = turnChange['currentPlayerId'] as String;
        
        // Timestamp 타입 안전하게 처리
        int timestamp;
        try {
          final timestampData = turnChange['timestamp'];
          if (timestampData is Timestamp) {
            timestamp = timestampData.millisecondsSinceEpoch;
          } else if (timestampData is int) {
            timestamp = timestampData;
          } else {
            timestamp = DateTime.now().millisecondsSinceEpoch;
          }
        } catch (e) {
          print('타임스탬프 처리 오류: $e');
          timestamp = DateTime.now().millisecondsSinceEpoch;
        }
        
        print('턴 변경 스트림 수신: $changePlayerId -> $nextPlayerId (시간: $timestamp)');
        print('현재 플레이어: $currentPlayerId, 내 턴: ${nextPlayerId == currentPlayerId}');
        
        // 다른 플레이어의 턴 변경만 처리
        if (changePlayerId != currentPlayerId) {
          print('다른 플레이어의 턴 변경 처리 중...');
          
          // 중복 턴 변경 방지 - 더 유연한 검증 (시간 제한 완화)
          if (lastTurnChangePlayerId == changePlayerId && 
              DateTime.now().millisecondsSinceEpoch - timestamp < 500) {
            print('중복 턴 변경 무시: $changePlayerId (0.5초 이내)');
            return;
          }
          
          setState(() {
            isMyTurn = nextPlayerId == currentPlayerId;
            lastTurnChangePlayerId = changePlayerId;
          });
          
          print('턴 변경 완료: 내 턴 = $isMyTurn');
          
          // 턴 변경 시 선택된 카드 초기화
          if (isMyTurn) {
            print('내 턴이므로 선택된 카드 초기화');
            firstSelectedIndex = null;
            secondSelectedIndex = null;
          }
          
          // 턴 변경 후 일정 시간 후에 lastTurnChangePlayerId 초기화 (시간 단축)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && lastTurnChangePlayerId == changePlayerId) {
              print('턴 변경 중복 방지 변수 초기화');
              lastTurnChangePlayerId = null;
            }
          });
        } else {
          print('내가 보낸 턴 변경이므로 무시');
        }
      }
    });
    
    print('=== 실시간 동기화 설정 완료 ===');
  }

  /// 게임 초기화
  void _initGame() async {
    await _createCards();
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  /// 카드 생성 및 섞기 - 개선된 버전
  void _createCards() async {
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
    
    // 방장인 경우 카드 순서를 결정하고 Firebase에 저장
    if (currentRoom.isHost(currentPlayerId)) {
      // 방 ID를 시드로 사용하여 카드 섞기
      final roomIdHash = currentRoom.id.hashCode;
      final random = Random(roomIdHash);
      
      // Fisher-Yates 셔플 알고리즘 사용
      for (int i = tempCards.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = tempCards[i];
        tempCards[i] = tempCards[j];
        tempCards[j] = temp;
      }
      
      // Firebase에 카드 순서 저장
      await _saveCardsToFirebase(tempCards);
    } else {
      // 게스트인 경우 Firebase에서 카드 순서를 가져옴
      try {
        final cardsData = await firebaseService.loadGameCards(currentRoom.id);
        if (cardsData.isNotEmpty) {
          // Firebase에서 가져온 순서로 카드 재구성
          final orderedCards = List<CardModel>.filled(tempCards.length, tempCards[0]);
          
          for (int i = 0; i < cardsData.length && i < tempCards.length; i++) {
            final cardData = cardsData[i];
            final originalIndex = cardData['orderIndex'] as int? ?? i;
            final cardId = cardData['id'] as int? ?? i ~/ 2;
            final flagData = _getFlagWithName(cardId);
            
            orderedCards[originalIndex] = CardModel(
              id: cardId,
              emoji: flagData['flag']!,
              name: flagData['name'],
              isMatched: false,
              isFlipped: false,
            );
          }
          
          tempCards.clear();
          tempCards.addAll(orderedCards);
          print('Firebase에서 카드 순서 로드 완료');
        } else {
          // Firebase에 데이터가 없으면 기본 순서 사용
          print('Firebase에 카드 데이터가 없어 기본 순서 사용');
        }
      } catch (e) {
        print('Firebase에서 카드 순서 로드 실패: $e');
        // 오류 발생 시 기본 순서 사용
      }
    }
    
    setState(() {
      cards = tempCards;
    });
    
    print('카드 생성 완료: ${cards.length}개 카드, ${numPairs}개 쌍');
    // 디버깅을 위해 카드 정보 출력
    for (int i = 0; i < cards.length; i++) {
      print('카드 $i: ID=${cards[i].id}, 국기=${cards[i].emoji}, 이름=${cards[i].name}');
    }
  }

  /// Firebase에 카드 데이터 저장 - 개선된 버전
  Future<void> _saveCardsToFirebase(List<CardModel> cardsToSave) async {
    try {
      // 카드 데이터에 순서 정보 추가
      final cardsData = cardsToSave.asMap().entries.map((entry) {
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
      print('Firebase에 카드 데이터 저장 완료: ${cardsToSave.length}개 카드');
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

  /// 타이머 정지
  void _stopTimer() {
    print('타이머 정지');
    gameTimer?.cancel();
    gameTimer = null;
  }

  /// 게임 시작
  void _startGame() {
    if (!currentRoom.isHost(currentPlayerId)) {
      print('방장이 아니므로 게임 시작 불가');
      return;
    }

    print('=== 게임 시작 ===');
    print('방장 ID: ${currentRoom.hostId}');
    print('게스트 ID: ${currentRoom.guestId}');
    print('현재 플레이어 ID: $currentPlayerId');

    setState(() {
      isGameRunning = true;
      isMyTurn = true; // 방장이 먼저 시작
      gameStartTime = DateTime.now();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      lastTurnChangePlayerId = null; // 턴 변경 중복 방지 변수 초기화
    });

    print('게임 상태 설정 완료: 내 턴 = $isMyTurn, 게임 진행 = $isGameRunning');

    // 타이머 시작
    _startTimer();

    // Firebase에 게임 시작 상태 동기화
    try {
      firebaseService.updateGameState(currentRoom.id, {
        'isGameRunning': true,
        'startTime': FieldValue.serverTimestamp(),
        'currentTurn': currentRoom.hostId, // 방장이 첫 턴
      });
      print('게임 시작 Firebase 동기화 완료');
    } catch (e) {
      print('게임 시작 Firebase 동기화 실패: $e');
    }

    print('=== 게임 시작 완료 ===');
  }

  /// 카드 선택 처리 - 개선된 버전
  void _onCardTap(int index) {
    if (!isMyTurn || !isGameRunning) {
      print('카드 선택 무시: 내 턴=$isMyTurn, 게임 진행=$isGameRunning');
      return;
    }

    if (cards[index].isMatched || cards[index].isFlipped) {
      print('카드 선택 무시: 이미 매칭됨 또는 뒤집힘');
      return;
    }

    print('=== 카드 선택 처리 시작 ===');
    print('선택된 카드 인덱스: $index');
    print('첫 번째 선택: $firstSelectedIndex');
    print('두 번째 선택: $secondSelectedIndex');

    setState(() {
      cards[index].isFlipped = true;
    });

    // Firebase에 카드 뒤집기 동기화
    try {
      firebaseService.syncCardFlip(currentRoom.id, index, true, currentPlayerId);
      print('카드 뒤집기 Firebase 동기화 완료');
    } catch (e) {
      print('카드 뒤집기 Firebase 동기화 실패: $e');
    }

    if (firstSelectedIndex == null) {
      // 첫 번째 카드 선택
      print('첫 번째 카드 선택');
      firstSelectedIndex = index;
    } else if (secondSelectedIndex == null && firstSelectedIndex != index) {
      // 두 번째 카드 선택 (첫 번째와 다른 카드)
      print('두 번째 카드 선택');
      secondSelectedIndex = index;
      
      // 매칭 확인
      _checkMatch();
    } else {
      // 같은 카드를 다시 선택한 경우
      print('같은 카드를 다시 선택함');
      setState(() {
        cards[index].isFlipped = false;
      });
      
      // Firebase에 카드 뒤집기 해제 동기화
      try {
        firebaseService.syncCardFlip(currentRoom.id, index, false, currentPlayerId);
        print('카드 뒤집기 해제 Firebase 동기화 완료');
      } catch (e) {
        print('카드 뒤집기 해제 Firebase 동기화 실패: $e');
      }
    }

    print('=== 카드 선택 처리 완료 ===');
  }

  /// 매칭 확인 - 개선된 버전
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) {
      print('매칭 확인 불가: 선택된 카드가 부족함');
      return;
    }

    print('=== 매칭 확인 시작 ===');
    print('첫 번째 카드: $firstSelectedIndex (${cards[firstSelectedIndex!].emoji})');
    print('두 번째 카드: $secondSelectedIndex (${cards[secondSelectedIndex!].emoji})');

    final firstCard = cards[firstSelectedIndex!];
    final secondCard = cards[secondSelectedIndex!];

    // 매칭 확인
    final isMatch = firstCard.id == secondCard.id;
    print('매칭 결과: $isMatch');

    if (isMatch) {
      // 매칭 성공
      print('매칭 성공!');
      soundService.playMatchSound();
      
      setState(() {
        firstCard.isMatched = true;
        secondCard.isMatched = true;
        firstCard.isFlipped = true;
        secondCard.isFlipped = true;
      });

      // 점수 계산
      scoreModel.addScore(10);
      currentPlayerScore = scoreModel.score;
      print('점수 업데이트: $currentPlayerScore');

      // Firebase에 매칭 성공 동기화
      try {
        firebaseService.syncCardMatch(
          currentRoom.id,
          firstSelectedIndex!,
          secondSelectedIndex!,
          true,
          currentPlayerId,
          currentPlayerScore,
        );
        print('매칭 성공 Firebase 동기화 완료');
      } catch (e) {
        print('매칭 성공 Firebase 동기화 실패: $e');
      }

      // 선택된 카드 초기화
      firstSelectedIndex = null;
      secondSelectedIndex = null;

      // 게임 완료 확인
      _checkGameCompletion();

      // 매칭 성공 시에도 턴 변경 (연속 매칭이 아닌 경우)
      if (scoreModel.currentCombo == 0) {
        print('콤보가 0이므로 턴 변경 실행');
        // 약간의 지연을 두고 턴 변경
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && isGameRunning) {
            print('매칭 성공 후 턴 변경 실행');
            _changeTurn();
          }
        });
      } else {
        print('콤보가 ${scoreModel.currentCombo}이므로 턴 유지');
      }
    } else {
      // 매칭 실패
      print('매칭 실패');
      soundService.playMismatchSound();

      // Firebase에 매칭 실패 동기화
      try {
        firebaseService.syncCardMatch(
          currentRoom.id,
          firstSelectedIndex!,
          secondSelectedIndex!,
          false,
          currentPlayerId,
          currentPlayerScore,
        );
        print('매칭 실패 Firebase 동기화 완료');
      } catch (e) {
        print('매칭 실패 Firebase 동기화 실패: $e');
      }

      // 1초 후 카드 뒤집기 해제
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          print('매칭 실패 후 카드 뒤집기 해제');
          setState(() {
            cards[firstSelectedIndex!].isFlipped = false;
            cards[secondSelectedIndex!].isFlipped = false;
            firstSelectedIndex = null;
            secondSelectedIndex = null;
          });
        }
      });

      // 턴 변경 - 약간의 지연을 두고 실행
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && isGameRunning) {
          print('매칭 실패 후 턴 변경 실행');
          _changeTurn();
        }
      });
    }

    print('=== 매칭 확인 완료 ===');
  }

  /// 게임 오버 처리
  void _gameOver() {
    print('게임 오버 처리 시작');
    isGameRunning = false;
    gameCompleted = true;
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
  Future<void> _updateGameState() async {
    try {
      await firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
      print('Firebase 게임 상태 업데이트 완료');
    } catch (e) {
      print('Firebase 게임 상태 업데이트 실패: $e');
    }
  }

  /// 턴 변경 - 완전히 개선된 버전
  void _changeTurn() {
    if (!mounted) {
      print('컴포넌트가 마운트되지 않아 턴 변경 취소');
      return;
    }
    
    // 게임이 진행 중이 아닌 경우 턴 변경 취소
    if (!isGameRunning) {
      print('게임이 진행 중이 아니므로 턴 변경 취소');
      return;
    }
    
    print('=== 턴 변경 시작 ===');
    print('현재 플레이어 ID: $currentPlayerId');
    print('방장 ID: ${currentRoom.hostId}');
    print('게스트 ID: ${currentRoom.guestId}');
    print('현재 내 턴: $isMyTurn');
    print('게임 진행 상태: $isGameRunning');
    
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
    
    // 다음 플레이어가 유효한지 확인
    if (nextPlayerId.isEmpty) {
      print('다음 플레이어 ID가 비어있어 턴 변경 취소');
      return;
    }
    
    print('턴 변경: $currentPlayerId -> $nextPlayerId');
    print('다음 턴이 내 턴인가: ${nextPlayerId == currentPlayerId}');
    
    // 로컬 상태 업데이트
    setState(() {
      isMyTurn = nextPlayerId == currentPlayerId;
    });
    
    print('로컬 턴 상태 업데이트: 내 턴 = $isMyTurn');
    
    // Firebase에 턴 변경 정보 전송 (타임스탬프 포함)
    try {
      firebaseService.syncTurnChange(currentRoom.id, currentPlayerId, nextPlayerId);
      print('Firebase 턴 변경 정보 전송 완료');
      
      // 게임 상태도 함께 업데이트
      firebaseService.updateGameState(currentRoom.id, {
        'currentTurn': nextPlayerId,
        'lastTurnChange': FieldValue.serverTimestamp(),
      });
      print('Firebase 게임 상태 업데이트 완료');
    } catch (e) {
      print('Firebase 턴 변경 정보 전송 실패: $e');
      // 전송 실패 시에도 로컬 상태는 유지
    }
    
    print('=== 턴 변경 완료 ===');
  }

  /// 방 나가기 처리
  Future<void> _leaveRoom() async {
    print('=== 방 나가기 시작 ===');
    print('현재 플레이어 ID: $currentPlayerId');
    print('방장 ID: ${currentRoom.hostId}');
    print('게스트 ID: ${currentRoom.guestId}');
    
    try {
      // 게임 타이머 정지
      _stopTimer();
      
      // 실시간 동기화 구독 해제
      _cardActionsSubscription?.cancel();
      _turnChangeSubscription?.cancel();
      _cardMatchesSubscription?.cancel();
      _gameStateSubscription?.cancel();
      
      // Firebase에서 방 나가기 처리
      await firebaseService.leaveOnlineRoom(currentRoom.id);
      
      print('Firebase 방 나가기 완료');
      
      // 방장인 경우 게임 상태도 정리
      if (currentRoom.isHost(currentPlayerId)) {
        try {
          await firebaseService.updateGameState(currentRoom.id, {
            'isGameRunning': false,
            'gameEndedAt': FieldValue.serverTimestamp(),
            'endedBy': 'host_left',
          });
          print('게임 상태 정리 완료');
        } catch (e) {
          print('게임 상태 정리 실패: $e');
        }
      }
      
      if (mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentRoom.isHost(currentPlayerId) 
                ? '방이 삭제되었습니다.' 
                : '방을 나갔습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 방 목록 화면으로 돌아가기
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/online-room-list',
          (route) => false,
        );
      }
    } catch (e) {
      print('방 나가기 오류: $e');
      
      if (mounted) {
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('방 나가기에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        
        // 오류가 발생해도 화면은 나가기
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/online-room-list',
          (route) => false,
        );
      }
    }
    
    print('=== 방 나가기 완료 ===');
  }

  /// 방 나가기 확인 다이얼로그
  void _showLeaveRoomDialog() {
    final isHost = currentRoom.isHost(currentPlayerId);
    final title = isHost ? '방 삭제' : '방 나가기';
    final content = isHost 
        ? '방을 삭제하시겠습니까?\n다른 플레이어가 있다면 게임이 종료됩니다.'
        : '방을 나가시겠습니까?';
    final confirmText = isHost ? '삭제' : '나가기';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveRoom();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isHost ? Colors.red : Colors.orange,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 게임 완료 확인
  void _checkGameCompletion() {
    final matchedCards = cards.where((card) => card.isMatched).length;
    print('게임 완료 확인: 매칭된 카드=$matchedCards, 전체 카드=$totalCards');
    
    if (matchedCards == totalCards) {
      print('게임 완료! 모든 카드가 매칭됨');
      _endGame();
    }
  }

  /// 게임 종료 처리
  void _endGame() {
    print('=== 게임 종료 처리 시작 ===');
    
    if (gameCompleted) {
      print('이미 게임이 종료되어 있음');
      return;
    }
    
    setState(() {
      gameCompleted = true;
      isGameRunning = false;
      isMyTurn = false;
    });
    
    // 타이머 정지
    _stopTimer();
    
    // 사운드 재생
    soundService.playGameOverSound();
    
    // 게임 결과 저장
    _saveGameResult();
    
    print('=== 게임 종료 처리 완료 ===');
  }

  /// 게임 결과 저장
  Future<void> _saveGameResult() async {
    try {
      final gameDuration = DateTime.now().difference(gameStartTime);
      final gameRecord = GameRecord(
        id: '', // Firebase에서 자동 생성
        playerName: currentPlayerName,
        email: firebaseService.currentUser?.email ?? '',
        score: currentPlayerScore,
        matchCount: scoreModel.matchCount,
        failCount: scoreModel.failCount,
        maxCombo: maxCombo,
        timeLeft: timeLeft,
        totalTime: gameTimeSec,
        createdAt: DateTime.now(),
        isCompleted: true,
      );
      
      // 로컬 저장
      await storageService.saveGameRecord(gameRecord);
      
      // 온라인 저장 (Firebase)
      if (firebaseService.currentUser != null) {
        await firebaseService.saveGameRecord(gameRecord);
      }
      
      print('게임 결과 저장 완료: 점수=$currentPlayerScore, 시간=${gameDuration.inSeconds}초');
    } catch (e) {
      print('게임 결과 저장 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 고정 그리드 크기: 가로 6 x 세로 8
    const int gridColumns = 6;
    const int gridRows = 8;
    const int totalCards = gridColumns * gridRows; // 48개 카드
    
    // 레이아웃 영역 정의 - 오버플로우 방지를 위해 조정
    final headerHeight = 60.0; // 부분1: 제목 영역
    final playerInfoHeight = 70.0; // 부분2: 플레이어 정보 영역 (줄임)
    final buttonAreaHeight = 70.0; // 부분4: 버튼 영역 (줄임)
    final padding = 8.0; // 전체 패딩 (줄임)
    
    // 부분3: 카드 레이아웃 영역 높이 계산
    final cardLayoutHeight = screenHeight - headerHeight - playerInfoHeight - buttonAreaHeight - padding;
    
    // 카드 간격 최소화
    const cardSpacing = 2.0; // 카드 간격을 2px로 고정
    
    // 카드 크기 계산 - 세로 기준으로 결정
    // 1. 카드 레이아웃 영역 높이에서 카드 간격을 제외한 실제 카드 영역 높이 계산
    final totalCardSpacingHeight = (gridRows - 1) * cardSpacing; // 세로 카드 간격 총합
    final availableCardHeight = cardLayoutHeight - totalCardSpacingHeight; // 카드가 차지할 수 있는 실제 높이
    
    // 2. 카드 높이를 8등분으로 결정
    final cardHeight = availableCardHeight / gridRows;
    
    // 3. 가로 크기 계산 - 정사각형 유지를 위해 높이와 동일하게 설정
    final cardWidth = cardHeight;
    
    // 4. 전체 그리드 너비 계산
    final totalCardSpacingWidth = (gridColumns - 1) * cardSpacing; // 가로 카드 간격 총합
    final totalGridWidth = (cardWidth * gridColumns) + totalCardSpacingWidth;
    
    // 5. 화면 너비를 초과하는지 확인
    final availableWidth = screenWidth - padding;
    final needsWidthAdjustment = totalGridWidth > availableWidth;
    
    // 6. 너비 조정이 필요한 경우 카드 크기 재계산
    final finalCardSize = needsWidthAdjustment ? 
        (availableWidth - totalCardSpacingWidth) / gridColumns : 
        cardWidth;
    
    // 7. 최종 그리드 크기 계산
    final actualGridWidth = (finalCardSize * gridColumns) + totalCardSpacingWidth;
    final actualGridHeight = (finalCardSize * gridRows) + totalCardSpacingHeight;
    
    // 8. 높이 조정이 필요한지 확인
    final needsHeightAdjustment = actualGridHeight > cardLayoutHeight;
    final adjustedCardSize = needsHeightAdjustment ? 
        (cardLayoutHeight - totalCardSpacingHeight) / gridRows : 
        finalCardSize;
    
    // 9. 최소/최대 카드 크기 제한
    final finalAdjustedCardSize = adjustedCardSize.clamp(20.0, 100.0);
    
    // 10. 최종 그리드 크기 재계산
    final finalGridWidth = (finalAdjustedCardSize * gridColumns) + totalCardSpacingWidth;
    final finalGridHeight = (finalAdjustedCardSize * gridRows) + totalCardSpacingHeight;
    
    print('=== 세로 기준 6x8 카드 레이아웃 정보 ===');
    print('화면 크기: ${screenWidth}x${screenHeight}');
    print('카드 레이아웃 영역 높이: $cardLayoutHeight');
    print('세로 카드 간격 총합: $totalCardSpacingHeight');
    print('카드가 차지할 수 있는 실제 높이: $availableCardHeight');
    print('초기 카드 높이 (8등분): ${cardHeight.toStringAsFixed(1)}px');
    print('초기 카드 너비 (정사각형): ${cardWidth.toStringAsFixed(1)}px');
    print('전체 그리드 너비: ${totalGridWidth.toStringAsFixed(1)}px');
    print('가용 너비: $availableWidth');
    print('너비 조정 필요: $needsWidthAdjustment');
    print('높이 조정 필요: $needsHeightAdjustment');
    print('최종 카드 크기: ${finalAdjustedCardSize.toStringAsFixed(1)}px');
    print('최종 그리드 크기: ${finalGridWidth.toStringAsFixed(1)}x${finalGridHeight.toStringAsFixed(1)}');
    print('카드 간격: ${cardSpacing}px');
    
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
        child: Column(
          children: [
            // 부분2: 플레이어 정보 영역 (고정 높이)
            Container(
              height: playerInfoHeight,
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 방장 정보
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: currentRoom.isHost(currentPlayerId) && isMyTurn ? 
                            Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: currentRoom.isHost(currentPlayerId) ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '방장: ${currentRoom.hostName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '점수: ${currentRoom.isHost(currentPlayerId) ? currentPlayerScore : opponentPlayerScore}',
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
                  // 참가자 정보
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: !currentRoom.isHost(currentPlayerId) && isMyTurn ? 
                            Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !currentRoom.isHost(currentPlayerId) ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '참가자: ${currentRoom.guestName ?? '대기 중...'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '점수: ${!currentRoom.isHost(currentPlayerId) ? currentPlayerScore : opponentPlayerScore}',
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
            
            // 부분3: 카드 레이아웃 영역 (세로 기준 6x8 레이아웃)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(2),
                child: Center(
                  child: SizedBox(
                    width: finalGridWidth,
                    height: finalGridHeight,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        childAspectRatio: 1.0, // 정사각형 카드
                        crossAxisSpacing: cardSpacing,
                        mainAxisSpacing: cardSpacing,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: finalAdjustedCardSize,
                          height: finalAdjustedCardSize,
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
              ),
            ),
            
            // 부분4: 버튼 영역 (고정 높이)
            Container(
              height: buttonAreaHeight,
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 게임 시작 버튼 (방장만, 게임 시작 전에만)
                  if (!isGameRunning && currentRoom.isHost(currentPlayerId))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('게임 시작', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  
                  // 대기 메시지 (게스트만, 게임 시작 전에만)
                  if (!isGameRunning && !currentRoom.isHost(currentPlayerId))
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '방장이 게임을 시작할 때까지 기다려주세요...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  
                  // 방 나가기 버튼
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        onPressed: _showLeaveRoomDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('방 나가기', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 