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
    // 카드 액션 리스너
    _cardActionsSubscription = firebaseService.getCardActionsStream(currentRoom.id)
        .listen((actions) {
      if (actions.isNotEmpty) {
        final latestAction = actions.first;
        final actionPlayerId = latestAction['playerId'] as String;
        final actionTimestamp = latestAction['timestamp'] as int? ?? 0;
        final actionId = latestAction['id'] as String? ?? '';
        
        // 다른 플레이어의 액션만 처리
        if (actionPlayerId != currentPlayerId) {
          // 이미 처리된 액션인지 확인
          final actionKey = '${actionPlayerId}_${actionId}';
          if (lastProcessedTimestamps.containsKey(actionKey) && 
              lastProcessedTimestamps[actionKey]! >= actionTimestamp) {
            print('이미 처리된 카드 액션 무시: $actionKey, 타임스탬프: $actionTimestamp');
            return;
          }
          
          final cardIndex = latestAction['cardIndex'] as int;
          final isFlipped = latestAction['isFlipped'] as bool;
          
          print('다른 플레이어 카드 액션 감지: 플레이어=$actionPlayerId, 카드=$cardIndex, 뒤집힘=$isFlipped, 시간=$actionTimestamp, ID=$actionId');
          
          // 카드 인덱스 유효성 확인
          if (cardIndex >= 0 && cardIndex < cards.length) {
            setState(() {
              cards[cardIndex].isFlipped = isFlipped;
            });
            
            // 처리된 타임스탬프 기록
            lastProcessedTimestamps[actionKey] = actionTimestamp;
            
            print('카드 상태 업데이트 완료: 인덱스=$cardIndex, 뒤집힘=$isFlipped');
          } else {
            print('잘못된 카드 인덱스: $cardIndex (총 카드 수: ${cards.length})');
          }
        }
      }
    });

    // 카드 매칭 리스너
    _cardMatchesSubscription = firebaseService.getCardMatchesStream(currentRoom.id)
        .listen((matches) {
      if (matches.isNotEmpty) {
        final latestMatch = matches.first;
        final matchPlayerId = latestMatch['playerId'] as String;
        final matchTimestamp = latestMatch['timestamp'] as int? ?? 0;
        final matchId = latestMatch['id'] as String? ?? '';
        
        // 다른 플레이어의 매칭만 처리
        if (matchPlayerId != currentPlayerId) {
          // 이미 처리된 매칭인지 확인
          final matchKey = '${matchPlayerId}_${matchId}';
          if (lastProcessedTimestamps.containsKey(matchKey) && 
              lastProcessedTimestamps[matchKey]! >= matchTimestamp) {
            print('이미 처리된 매칭 무시: $matchKey, 타임스탬프: $matchTimestamp');
            return;
          }
          
          final cardIndex1 = latestMatch['cardIndex1'] as int;
          final cardIndex2 = latestMatch['cardIndex2'] as int;
          final isMatched = latestMatch['isMatched'] as bool;
          final score = latestMatch['score'] as int? ?? 0;
          
          print('다른 플레이어 매칭 감지: 플레이어=$matchPlayerId, 카드1=$cardIndex1, 카드2=$cardIndex2, 매칭=$isMatched, 점수=$score, 시간=$matchTimestamp, ID=$matchId');
          
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
                    print('다른 플레이어 매칭 실패 - 카드 뒤집기 해제 완료: $cardIndex1, $cardIndex2');
                  }
                });
              }
            });
            
            // 처리된 타임스탬프 기록
            lastProcessedTimestamps[matchKey] = matchTimestamp;
            
            print('매칭 상태 업데이트 완료: 카드1=$cardIndex1, 카드2=$cardIndex2, 매칭=$isMatched');
          } else {
            print('잘못된 카드 인덱스: $cardIndex1, $cardIndex2 (총 카드 수: ${cards.length})');
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
          // 이미 처리된 턴 변경인지 확인
          final turnKey = '${changePlayerId}_${turnId}';
          if (lastProcessedTimestamps.containsKey(turnKey) && 
              lastProcessedTimestamps[turnKey]! >= turnTimestamp) {
            print('이미 처리된 턴 변경 무시: $turnKey, 타임스탬프: $turnTimestamp');
            return;
          }
          
          print('턴 변경 감지: $changePlayerId -> $nextPlayerId, 시간=$turnTimestamp, ID=$turnId');
          print('현재 플레이어: $currentPlayerId, 내 턴: ${nextPlayerId == currentPlayerId}');
          
          setState(() {
            isMyTurn = nextPlayerId == currentPlayerId;
          });
          
          // 처리된 타임스탬프 기록
          lastProcessedTimestamps[turnKey] = turnTimestamp;
          
          print('턴 변경 완료: 내 턴 = $isMyTurn');
          
          // 턴 변경 시 선택된 카드 초기화
          if (isMyTurn) {
            firstSelectedIndex = null;
            secondSelectedIndex = null;
            isProcessingCardSelection = false;
            print('내 턴 시작 - 선택된 카드 초기화');
          }
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
    
    print('카드 생성 완료 - 방 ID: ${currentRoom.id}, 시드: $seed');
    print('카드 배치: ${tempCards.map((c) => '${c.emoji}(${c.id})').toList()}');
    
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
    print('게임 시작 - 방장: ${currentRoom.isHost(currentPlayerId)}');
    
    // 모든 플레이어가 동일한 시드로 카드 생성 (Firebase 로드 대신)
    _createCardsWithFixedSeed();
    
    setState(() {
      isGameRunning = true;
      gameStartTime = DateTime.now();
      // 방장이 먼저 시작
      isMyTurn = currentRoom.isHost(currentPlayerId);
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      isProcessingCardSelection = false;
    });
    
    // 타임스탬프 추적 초기화
    lastProcessedTimestamps.clear();
    
    // 타이머 시작
    _startTimer();
    
    // Firebase에 게임 상태 업데이트
    _updateGameState();
    
    print('게임 시작됨 - 내 턴: $isMyTurn');
  }

  /// 카드 선택 처리
  void _onCardTap(int index) async {
    // 중복 클릭 방지
    if (isProcessingCardSelection) {
      print('카드 선택 무시 - 처리 중: $index');
      return;
    }
    
    // 게임 상태 확인
    if (!isGameRunning || !isMyTurn || isTimerPaused) {
      print('카드 선택 무시 - 게임상태: $isGameRunning, 내턴: $isMyTurn, 일시정지: $isTimerPaused');
      return;
    }
    
    // 카드 상태 확인
    final card = cards[index];
    print('카드 상태 확인 - 인덱스: $index, 매칭됨: ${card.isMatched}, 뒤집힘: ${card.isFlipped}, ID: ${card.id}');
    
    if (card.isMatched) {
      print('카드 선택 무시 - 이미 매칭됨: $index');
      return;
    }
    
    // 이미 뒤집힌 카드인지 확인 (현재 턴에서 선택한 카드가 아닌 경우)
    if (card.isFlipped && firstSelectedIndex != index && secondSelectedIndex != index) {
      print('카드 선택 무시 - 이미 뒤집힌 카드: $index');
      return;
    }
    
    // 두 번째 카드 선택 시 첫 번째 카드와 같은 카드인지 확인
    if (firstSelectedIndex != null && secondSelectedIndex == null && firstSelectedIndex == index) {
      print('카드 선택 무시 - 같은 카드 재선택: $index');
      return;
    }
    
    print('카드 선택: 인덱스=$index, 카드ID=${card.id}, 이모지=${card.emoji}');
    print('현재 선택 상태 - 첫번째: $firstSelectedIndex, 두번째: $secondSelectedIndex');
    
    // 카드 선택 처리 시작
    isProcessingCardSelection = true;
    
    try {
      soundService.playCardFlipSound();
      
      setState(() {
        card.isFlipped = true;
        
        if (firstSelectedIndex == null) {
          firstSelectedIndex = index;
          print('첫 번째 카드 선택: $index');
        } else if (secondSelectedIndex == null) {
          secondSelectedIndex = index;
          print('두 번째 카드 선택: $index');
          // 매칭 확인은 별도로 처리
        }
      });
      
      // 실시간 동기화 - 카드 플립 정보 전송
      await firebaseService.syncCardFlip(currentRoom.id, index, true, currentPlayerId);
      
      // 동기화 전송 후 잠시 대기 (다른 플레이어 액션과 충돌 방지)
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 두 번째 카드가 선택된 경우 매칭 확인
      if (secondSelectedIndex != null) {
        // 잠시 대기 후 매칭 확인 (시각적 효과를 위해)
        await Future.delayed(const Duration(milliseconds: 300));
        _checkMatch();
      }
    } catch (e) {
      print('카드 선택 처리 오류: $e');
      // 오류 발생 시 카드 상태 복원
      setState(() {
        card.isFlipped = false;
        if (firstSelectedIndex == index) {
          firstSelectedIndex = null;
        } else if (secondSelectedIndex == index) {
          secondSelectedIndex = null;
        }
      });
    } finally {
      // 카드 선택 처리 완료
      isProcessingCardSelection = false;
    }
  }

  /// 카드 매칭 확인
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) {
      print('매칭 확인 실패 - 선택된 카드가 부족: 첫번째=$firstSelectedIndex, 두번째=$secondSelectedIndex');
      return;
    }
    
    final firstCard = cards[firstSelectedIndex!];
    final secondCard = cards[secondSelectedIndex!];
    
    print('=== 매칭 확인 ===');
    print('첫 번째 카드 (인덱스: $firstSelectedIndex): ID=${firstCard.id}, 이모지=${firstCard.emoji}, 뒤집힘=${firstCard.isFlipped}');
    print('두 번째 카드 (인덱스: $secondSelectedIndex): ID=${secondCard.id}, 이모지=${secondCard.emoji}, 뒤집힘=${secondCard.isFlipped}');
    print('매칭 결과: ${firstCard.id == secondCard.id}');
    
    if (firstCard.id == secondCard.id) {
      // 매칭 성공
      print('매칭 성공!');
      _handleMatchSuccess();
    } else {
      // 매칭 실패
      print('매칭 실패!');
      _handleMatchFailure();
    }
  }

  /// 매칭 성공 처리
  void _handleMatchSuccess() {
    print('=== 매칭 성공 처리 시작 ===');
    soundService.playMatchSound();
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    print('매칭 성공 - 카드 인덱스: $firstIndex, $secondIndex');
    print('매칭 전 카드 상태 - 첫번째: ${cards[firstIndex].isMatched}, 두번째: ${cards[secondIndex].isMatched}');
    
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
      isProcessingCardSelection = false;
    });
    
    print('매칭 후 카드 상태 - 첫번째: ${cards[firstIndex].isMatched}, 두번째: ${cards[secondIndex].isMatched}');
    print('현재 점수: $currentPlayerScore, 최고 콤보: $maxCombo');
    
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
      print('연속 매칭이 아니므로 턴 변경');
      _changeTurn();
    } else {
      print('연속 매칭이므로 턴 유지');
    }
    
    // 게임 완료 확인
    _checkGameCompletion();
    print('=== 매칭 성공 처리 완료 ===');
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    print('=== 매칭 실패 처리 시작 ===');
    soundService.playMismatchSound();
    
    final firstIndex = firstSelectedIndex!;
    final secondIndex = secondSelectedIndex!;
    
    print('매칭 실패 - 카드 뒤집기 해제: $firstIndex, $secondIndex');
    print('매칭 실패 전 카드 상태 - 첫번째: ${cards[firstIndex].isFlipped}, 두번째: ${cards[secondIndex].isFlipped}');
    
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
    
    print('선택 상태 초기화 완료');
    
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
        
        print('매칭 실패 - 카드 뒤집기 해제 완료: $firstIndex, $secondIndex');
        print('매칭 실패 후 카드 상태 - 첫번째: ${cards[firstIndex].isFlipped}, 두번째: ${cards[secondIndex].isFlipped}');
        
        // 턴 변경
        _changeTurn();
      }
    });
    print('=== 매칭 실패 처리 완료 ===');
  }

  /// 턴 변경
  void _changeTurn() {
    if (!mounted) return;
    
    // 현재 플레이어가 방장인지 게스트인지 확인
    final isCurrentPlayerHost = currentRoom.isHost(currentPlayerId);
    
    // 다음 플레이어 ID 결정
    String nextPlayerId;
    if (isCurrentPlayerHost) {
      // 방장인 경우 게스트로 턴 변경
      nextPlayerId = currentRoom.guestId ?? currentRoom.hostId;
    } else {
      // 게스트인 경우 방장으로 턴 변경
      nextPlayerId = currentRoom.hostId;
    }
    
    print('턴 변경: $currentPlayerId -> $nextPlayerId');
    print('현재 플레이어가 방장: $isCurrentPlayerHost');
    
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
      print('게임 시작 상태를 Firebase에 업데이트 완료');
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
    
    // 레이아웃 계산 - 더 효율적인 공간 활용
    final headerHeight = 60.0; // 헤더 높이
    final controlHeight = 60.0; // 컨트롤 영역 높이
    final padding = 16.0; // 패딩
    final availableHeight = screenHeight - headerHeight - controlHeight - padding;
    
    // 카드 간격 최소화
    const cardSpacing = 2.0; // 카드 간격을 2px로 고정
    
    // 가용 그리드 영역 계산
    final availableGridWidth = screenWidth - padding - (gridColumns - 1) * cardSpacing;
    final availableGridHeight = availableHeight - (gridRows - 1) * cardSpacing;
    
    // 카드 크기 계산 - 높이 기준으로 계산
    final cardHeight = availableGridHeight / gridRows;
    final cardWidth = availableGridWidth / gridColumns;
    
    // 카드 크기 결정 - 높이와 너비 중 작은 값 사용 (정사각형 유지)
    final cardSize = cardHeight < cardWidth ? cardHeight : cardWidth;
    
    // 최소/최대 카드 크기 제한
    final finalCardSize = cardSize.clamp(30.0, 80.0);
    
    // 실제 그리드 크기 계산
    final actualGridWidth = (finalCardSize * gridColumns) + ((gridColumns - 1) * cardSpacing);
    final actualGridHeight = (finalCardSize * gridRows) + ((gridRows - 1) * cardSpacing);
    
    print('=== 온라인 멀티플레이어 게임 반응형 카드 레이아웃 정보 ===');
    print('화면 크기: ${screenWidth}x${screenHeight}');
    print('가용 높이: $availableHeight');
    print('그리드: ${gridColumns}x${gridRows} (고정)');
    print('카드 크기: ${finalCardSize.toStringAsFixed(1)}px');
    print('실제 그리드 크기: ${actualGridWidth.toStringAsFixed(1)}x${actualGridHeight.toStringAsFixed(1)}');
    print('카드 간격: ${cardSpacing}px');
    
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
                    // 플레이어 1 정보
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
                    // 플레이어 2 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: !isMyTurn ? Colors.orange.withOpacity(0.3) : Colors.white.withOpacity(0.2),
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
              
              // 카드 그리드 (고정 6x8 레이아웃)
              if (isGameRunning)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Center(
                      child: SizedBox(
                        width: actualGridWidth,
                        height: actualGridHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(), // 스크롤 비활성화
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridColumns,
                            childAspectRatio: 1.0, // 정사각형 카드
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
                  ),
                ),

              // 게임 완료 메시지
              if (!isGameRunning && gameCompleted)
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
                        '최고 연속 매칭: $maxCombo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

              // 게임 컨트롤
              _buildGameControls(),
            ],
          ),
        ),
      ),
    );
  }

  /// 게임 컨트롤 위젯
  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('방 나가기'),
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