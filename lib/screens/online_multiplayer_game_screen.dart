import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/card_model.dart';
import '../models/online_room.dart';
import '../models/player_stats.dart';
import '../models/multiplayer_game_record.dart';
import '../services/firebase_service.dart';
import '../services/sound_service.dart';
import '../widgets/memory_card.dart';
import 'dart:async';
import 'dart:math';

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
  static const int rows = 8;
  static const int cols = 6;
  static const int numPairs = (rows * cols) ~/ 2;
  static const int totalCards = numPairs * 2;
  static const int gameTimeSec = 15 * 60;

  // 게임 상태 변수
  List<CardModel>? cards;
  int? firstSelectedIndex;
  int? secondSelectedIndex;
  bool isProcessingCardSelection = false;
  int timeLeft = gameTimeSec;
  bool isGameRunning = false;
  bool isTimerPaused = false;
  Timer? gameTimer;
  final SoundService soundService = SoundService.instance;
  final FirebaseService firebaseService = FirebaseService.instance;
  DateTime gameStartTime = DateTime.now();
  
  // 온라인 멀티플레이어 관련 변수
  late OnlineRoom currentRoom;
  String currentPlayerId = '';
  String currentPlayerName = '';
  
  Map<String, OnlinePlayerGameData> playersData = {};
  String currentTurnPlayerId = '';

  bool get isMyTurn => currentTurnPlayerId == currentPlayerId;

  // 점수 및 콤보 관리
  int myCombo = 0;
  int opponentCombo = 0;

  // 콤보 점수 표시 관련 변수
  String? comboScoreMessage;
  bool showComboScore = false;
  Timer? comboScoreTimer;
  bool isComboScoreSuccess = true; // true: 성공, false: 실패

  // 카드 로딩 상태 관리
  bool isCardsLoading = false;
  int cardLoadRetryCount = 0;
  static const int maxCardLoadRetries = 10;
  Timer? cardLoadRetryTimer;

  // 실시간 동기화 관련 변수
  StreamSubscription? _roomSubscription;
  StreamSubscription? _cardActionsSubscription;
  StreamSubscription? _turnChangeSubscription;
  StreamSubscription? _cardMatchesSubscription;
  StreamSubscription? _gameEndEventSubscription;
  StreamSubscription? _playerStatesSubscription;
  final Set<String> _processedActionIds = {};
  final Set<String> _processedStateIds = {};

  bool gameCompleted = false;
  int matchedCardCount = 0; // 매칭된 카드 수 추적
  
  @override
  void initState() {
    super.initState();
    currentRoom = widget.room;
    _initializeGameAndPlayers();
  }
  
  Future<void> _initializeGameAndPlayers() async {
    await _loadPlayerInfo();
    await _initGameCards();
    _setupListeners();
    // 호스트만 게임 시작을 트리거
    if (currentRoom.isHost(currentPlayerId)) {
      await firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    comboScoreTimer?.cancel();
    cardLoadRetryTimer?.cancel();
    _roomSubscription?.cancel();
    _cardActionsSubscription?.cancel();
    _turnChangeSubscription?.cancel();
    _cardMatchesSubscription?.cancel();
    _gameEndEventSubscription?.cancel();
    _playerStatesSubscription?.cancel();
    soundService.stopBackgroundMusic();
    
    // 방에서 나가기 (화면이 종료될 때) - 안전하게 처리
    if (mounted && currentRoom.id.isNotEmpty) {
      firebaseService.leaveOnlineRoom(currentRoom.id).catchError((e) {
        print('dispose에서 방 나가기 오류: $e');
      });
    }
    
    super.dispose();
  }

  Future<void> _loadPlayerInfo() async {
    final user = firebaseService.currentUser;
    if (user == null) {
      // 로그인되지 않은 경우 처리
      _showErrorDialog('로그인이 필요합니다.');
      Navigator.of(context).pop();
      return;
    }
    
    currentPlayerId = user.uid;
    final userData = await firebaseService.getUserData(user.uid);
    currentPlayerName = userData?['playerName'] ?? user.displayName ?? '플레이어';
    final currentPlayerLevel = userData?['level'] ?? 1;

    print('🔍 플레이어 정보 로드 시작:');
    print('  현재 플레이어: $currentPlayerName (${user.uid}) Lv$currentPlayerLevel');

    // 호스트/게스트 각각 level도 불러오기
    print('  호스트 ID: ${currentRoom.hostId}');
    final hostUserData = await firebaseService.getUserData(currentRoom.hostId);
    final hostLevel = hostUserData?['level'] ?? 1;
    print('  호스트 레벨 정보: $hostLevel (데이터: ${hostUserData?.toString() ?? 'null'})');

    OnlinePlayerGameData guestData;
    int guestLevel = 1;
    if (currentRoom.guestId != null && currentRoom.guestId!.isNotEmpty) {
      print('  게스트 ID: ${currentRoom.guestId}');
      final guestUserData = await firebaseService.getUserData(currentRoom.guestId!);
      guestLevel = guestUserData?['level'] ?? 1;
      print('  게스트 레벨 정보: $guestLevel (데이터: ${guestUserData?.toString() ?? 'null'})');
      
      guestData = OnlinePlayerGameData(
        id: currentRoom.guestId!,
        name: currentRoom.guestName ?? '게스트',
        score: 0,
        matchCount: 0,
        failCount: 0,
        combo: 0,
        maxCombo: 0,
        level: guestLevel,
      );
    } else {
      print('  게스트 없음 (대기 중)');
      guestData = OnlinePlayerGameData(
        id: 'waiting',
        name: '대기 중...',
        score: 0,
        matchCount: 0,
        failCount: 0,
        combo: 0,
        maxCombo: 0,
        level: 1,
      );
    }

    final hostData = OnlinePlayerGameData(
      id: currentRoom.hostId,
      name: currentRoom.hostName,
      score: 0,
      matchCount: 0,
      failCount: 0,
      combo: 0,
      maxCombo: 0,
      level: hostLevel,
    );

    setState(() {
      playersData = {
        hostData.id: hostData,
        guestData.id: guestData,
      };
      currentTurnPlayerId = currentRoom.hostId;
      print('✅ 플레이어 정보 초기화 완료:');
      print('  호스트: ${hostData.name} (${hostData.id}) Lv${hostData.level}');
      print('  게스트: ${guestData.name} (${guestData.id}) Lv${guestData.level}');
      print('  현재 플레이어: $currentPlayerName ($currentPlayerId)');
      print('  초기 턴: $currentTurnPlayerId (호스트)');
    });
  }

  Future<void> _initGameCards() async {
    if (currentRoom.isHost(currentPlayerId)) {
      // 호스트인 경우 카드 생성
      final generatedCards = _generateCards();
      setState(() {
        cards = generatedCards;
      });
      print('호스트가 카드 생성: ${cards!.length}개 카드');
      
      // 호스트가 카드를 Firebase에 저장 (게스트가 로딩할 수 있도록)
      print('호스트가 카드를 Firebase에 저장: ${cards!.length}개');
      
      // 카드 데이터 확인 (디버깅용)
      if (cards!.isNotEmpty) {
        print('호스트 카드 저장 데이터 확인:');
        print('  첫 번째 카드 - ID: ${cards![0].id}, 이모지: ${cards![0].emoji}, 이름: ${cards![0].name ?? "null"}');
        print('  두 번째 카드 - ID: ${cards![1].id}, 이모지: ${cards![1].emoji}, 이름: ${cards![1].name ?? "null"}');
      }
      
      await firebaseService.saveGameCards(currentRoom.id, cards!.map((card) => card.toJson()).toList());
      
      // 카드 저장 완료 후 방 상태를 ready로 변경
      print('카드 저장 완료, 방 상태를 ready로 변경');
      await firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.ready);

    } else {
      // 게스트인 경우 카드 정보를 로드할 때까지 임시로 빈 리스트 사용
      setState(() {
        cards = List.generate(totalCards, (index) => CardModel(
          id: index,
          emoji: '❓',
          name: '로딩 중...',
        ));
        isCardsLoading = true;
      });
      print('게스트가 임시 카드 생성: ${cards!.length}개 카드');
      
      // 카드 로딩 시작 (방 상태가 ready일 때만)
      if (currentRoom.status == RoomStatus.ready) {
        _startCardLoading();
      }
    }
  }
  
  List<CardModel> _generateCards() {
    final List<String> cardValues = [
      '🇰🇷', '🇺🇸', '🇯🇵', '🇨🇳', '🇬🇧', '🇫🇷', '🇩🇪', '🇮🇹',
      '🇪🇸', '🇨🇦', '🇦🇺', '🇧🇷', '🇦🇷', '🇲🇽', '🇮🇳', '🇷🇺',
      '🇰🇵', '🇹🇭', '🇻🇳', '🇵🇭', '🇲🇾', '🇸🇬', '🇮🇩', '🇹🇼'
    ];
    final List<String> flagNames = [
      '대한민국', '미국', '일본', '중국', '영국', '프랑스', '독일', '이탈리아',
      '스페인', '캐나다', '호주', '브라질', '아르헨티나', '멕시코', '인도', '러시아',
      '북한', '태국', '베트남', '필리핀', '말레이시아', '싱가포르', '인도네시아', '대만'
    ];
    
    // 이모지와 이름을 함께 섞기
    final List<MapEntry<String, String>> cardPairs = [];
    for (int i = 0; i < cardValues.length; i++) {
      cardPairs.add(MapEntry(cardValues[i], flagNames[i]));
    }
    cardPairs.shuffle();
    
    List<CardModel> generatedCards = [];
    for (int i = 0; i < numPairs; i++) {
      final emoji = cardPairs[i].key;
      final name = cardPairs[i].value;
      generatedCards.add(CardModel(id: i, emoji: emoji, name: name));
      generatedCards.add(CardModel(id: i, emoji: emoji, name: name));
    }
    
    generatedCards.shuffle();
    print('카드 생성 완료: ${generatedCards.length}개 (${numPairs}쌍)');
    return generatedCards;
  }

  int _getEmojiIndex(String emoji) {
    final List<String> flagEmojis = [
      '🇰🇷', '🇺🇸', '🇯🇵', '🇨🇳', '🇬🇧', '🇫🇷', '🇩🇪', '🇮🇹',
      '🇪🇸', '🇨🇦', '🇦🇺', '🇧🇷', '🇦🇷', '🇲🇽', '🇮🇳', '🇷🇺',
      '🇰🇵', '🇹🇭', '🇻🇳', '🇵🇭', '🇲🇾', '🇸🇬', '🇮🇩', '🇹🇼'
    ];
    return flagEmojis.indexOf(emoji);
  }

  void _setupListeners() {
    _roomSubscription = firebaseService.getRoomStream(currentRoom.id).listen((room) async {
      if (room == null) {
        // 방이 삭제된 경우 (방장이 나간 경우)
        if (mounted) {
          // 게임 타이머 정지
          gameTimer?.cancel();
          soundService.stopBackgroundMusic();
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('방장이 나갔습니다'),
              content: const Text('방장이 방을 나가서 게임이 종료되었습니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // 게임 화면에서 퇴장
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      bool needsUpdate = false;
      if (currentRoom.status != room.status || currentRoom.guestId != room.guestId) {
        needsUpdate = true;
      }

      currentRoom = room;

      if (needsUpdate) {
        // 게스트 정보 업데이트
        if (room.guestId != null && !playersData.containsKey(room.guestId)) {
          print('🆕 새로운 게스트 참가: ${room.guestId}');
          await _loadPlayerInfo();
        } else if (room.guestId != null && playersData.containsKey(room.guestId)) {
          // 기존 게스트의 레벨 정보 업데이트
          await _updateGuestLevelInfo();
        }

        // 게스트가 나간 경우 처리
        if (room.guestId == null && playersData.length > 1) {
          print('👋 게스트 나감: ${currentRoom.guestId}');
          // 게스트가 나간 경우, 남은 플레이어만 유지
          final remainingPlayers = playersData.entries
              .where((entry) => entry.key != 'waiting' && entry.key.isNotEmpty)
              .toList();
          
          if (remainingPlayers.length == 1) {
            // 방장만 남은 경우
            setState(() {
              playersData = {remainingPlayers.first.key: remainingPlayers.first.value};
              currentTurnPlayerId = remainingPlayers.first.key;
            });
            
            // 게임 중이었다면 일시정지
            if (isGameRunning) {
              setState(() {
                isTimerPaused = true;
              });
            }
            
            // 게스트 나감 알림
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('다른 플레이어가 방을 나갔습니다.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }

        if (room.status == RoomStatus.playing && !isGameRunning) {
          _startGame();
        } else if (room.status == RoomStatus.ready && !currentRoom.isHost(currentPlayerId) && isCardsLoading) {
          // 방 상태가 ready로 변경되고 게스트가 카드 로딩 중인 경우 카드 로딩 시작
          print('방 상태가 ready로 변경됨 - 게스트 카드 로딩 시작');
          _startCardLoading();
        } else if (room.status == RoomStatus.finished || room.status == RoomStatus.cancelled) {
          _gameOver();
        }
      }
      
      // 게스트이고 카드가 아직 로드되지 않은 경우 카드 로드
      if (!currentRoom.isHost(currentPlayerId) && isCardsLoading) {
        // 카드 로딩이 진행 중인 경우, 로딩 상태를 업데이트
        print('카드 로딩 상태 업데이트: 시도 ${cardLoadRetryCount + 1}/$maxCardLoadRetries');
      }
    });

    _cardActionsSubscription = firebaseService.getCardActionsStream(currentRoom.id).listen(_handleCardAction);
    _cardMatchesSubscription = firebaseService.getCardMatchesStream(currentRoom.id).listen(_handleCardMatch);
    _turnChangeSubscription = firebaseService.getTurnChangeStream(currentRoom.id).listen(_handleTurnChange);
    _gameEndEventSubscription = firebaseService.getGameEventsStream(currentRoom.id).listen(_handleGameEndEvent);
    _playerStatesSubscription = firebaseService.getPlayerStatesStream(currentRoom.id).listen(_handlePlayerStates);
  }

  void _startGame() {
    if (isGameRunning || !mounted) return;
    
    // 게임 시작 사운드 재생
    soundService.playButtonClickSound();
    
    // 게스트이고 카드가 아직 로딩 중인 경우 게임 시작을 지연
    if (!currentRoom.isHost(currentPlayerId) && isCardsLoading) {
      print('카드 로딩 중 - 게임 시작 지연');
      return;
    }
    
    // 게임 시작 시 카드 선택 상태 초기화
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    isProcessingCardSelection = false;
    matchedCardCount = 0; // 매칭된 카드 수 초기화
    gameCompleted = false; // 게임 완료 상태 초기화
    
    setState(() {
      isGameRunning = true;
      gameStartTime = DateTime.now();
    });
    
    soundService.playBackgroundMusic();
    gameTimer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    
    // 호스트가 시작했으므로 게스트에게도 시작 알림
    if (currentRoom.isHost(currentPlayerId)) {
      firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
      
      // 호스트가 카드를 Firebase에 저장 (게스트가 로딩할 수 있도록)
      if (cards != null && cards!.isNotEmpty) {
        print('호스트가 카드를 Firebase에 저장: ${cards!.length}개');
        firebaseService.saveGameCards(currentRoom.id, cards!.map((card) => card.toJson()).toList());
      }
    }
    
    // 게임 시작 시 현재 플레이어의 초기 상태를 동기화
    final currentPlayer = playersData[currentPlayerId];
    if (currentPlayer != null) {
      firebaseService.syncPlayerState(currentRoom.id, currentPlayerId, {
        'score': currentPlayer.score,
        'combo': currentPlayer.combo,
        'matchCount': currentPlayer.matchCount,
        'failCount': currentPlayer.failCount,
        'maxCombo': currentPlayer.maxCombo,
      });
    }
    
    print('게임 시작! 총 카드 수: ${cards?.length ?? 0}, 매칭해야 할 쌍: ${(cards?.length ?? 0) ~/ 2}');
  }

  void _updateTimer(Timer timer) {
    if (isTimerPaused) return;

    if (timeLeft > 0) {
      setState(() {
        timeLeft--;
      });
    } else {
      print('⏰ 시간 초과 - 게임 종료');
      soundService.playGameLose(); // 시간 초과 사운드
      _gameOver(message: "⏰ 시간 초과!");
    }
  }

  void onCardPressed(int index) {
    // 게임이 진행 중이 아니거나 내 턴이 아닌 경우 무시
    if (!isGameRunning || !isMyTurn) {
      print('카드 클릭 무시: 게임진행=${isGameRunning}, 내턴=${isMyTurn}');
      return;
    }

    // 카드가 로드되지 않았거나 이미 처리 중인 경우 무시
    if (cards == null || index >= cards!.length || isProcessingCardSelection) {
      print('카드 클릭 무시: 카드로드=${cards != null}, 인덱스=$index, 처리중=${isProcessingCardSelection}');
      return;
    }

    final card = cards![index];
    
    // 이미 뒤집혀있거나 매칭된 카드는 무시
    if (card.isFlipped || card.isMatched) {
      print('카드 클릭 무시: 뒤집힘=${card.isFlipped}, 매칭됨=${card.isMatched}');
      return;
    }

    // 같은 카드를 두 번 클릭하는 것 방지
    if (firstSelectedIndex == index || secondSelectedIndex == index) {
      print('카드 클릭 무시: 같은 카드 중복 클릭 index=$index');
      return;
    }

    // 이미 두 장이 선택된 상태에서 추가 카드 클릭 시 무시
    if (firstSelectedIndex != null && secondSelectedIndex != null) {
      print('카드 클릭 무시: 이미 두 장 선택됨');
      return;
    }

    print('카드 클릭: 인덱스=$index, 이모지=${card.emoji}');
    
    // 즉시 카드 뒤집기 (반응성 향상)
    setState(() {
      card.isFlipped = true;
      isProcessingCardSelection = true;
    });

    // 사운드는 비동기로 처리 (UI 블로킹 방지)
    Future.microtask(() {
      soundService.playCardFlipSound();
    });

    // Firebase에 카드 액션 기록 (비동기로 처리)
    firebaseService.recordCardAction(
      currentRoom.id,
      currentPlayerId,
      index,
      card.emoji,
    ).catchError((e) {
      print('카드 액션 기록 오류: $e');
    });

    // 첫 번째 카드 선택
    if (firstSelectedIndex == null) {
      firstSelectedIndex = index;
      print('첫 번째 카드 선택: $index');
      setState(() {
        isProcessingCardSelection = false;
      });
    } else {
      // 두 번째 카드 선택
      secondSelectedIndex = index;
      print('두 번째 카드 선택: $index');
      
      // 카드 매칭 처리 (지연 시간 단축)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && firstSelectedIndex != null && secondSelectedIndex != null) {
          _processCardMatch();
        } else {
          print('매칭 확인 실패: firstSelectedIndex=$firstSelectedIndex, secondSelectedIndex=$secondSelectedIndex');
          setState(() {
            isProcessingCardSelection = false;
          });
        }
      });
    }
  }

  void _processCardMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) {
      print('매칭 확인 실패: 선택된 카드가 부족함');
      setState(() {
        isProcessingCardSelection = false;
      });
      return;
    }

    // cards가 null인 경우 처리
    if (cards == null) {
      print('매칭 확인 실패: 카드 데이터가 없음');
      setState(() {
        isProcessingCardSelection = false;
      });
      return;
    }

    // ID로 매칭 확인 (더 정확함)
    final isMatch = cards![firstSelectedIndex!].id == cards![secondSelectedIndex!].id;
    print('매칭 확인: ${cards![firstSelectedIndex!].emoji} vs ${cards![secondSelectedIndex!].emoji}, 결과: $isMatch');

    // 선택 상태 초기화
    final index1 = firstSelectedIndex!;
    final index2 = secondSelectedIndex!;
    firstSelectedIndex = null;
    secondSelectedIndex = null;

    if (isMatch) {
      _handleMatchSuccess(index1, index2);
    } else {
      _handleMatchFailure(index1, index2);
    }
  }
  
  void _handleMatchSuccess(int index1, int index2) {
    // 사운드는 비동기로 처리
    Future.microtask(() {
      soundService.playMatchSound();
    });
    
    final player = playersData[currentPlayerId];
    if(player != null) {
      player.combo++;
      player.matchCount++;
      
      // 기본 매칭 점수 20점으로 조정 (기존 100점에서 대폭 감소)
      int matchScore = 20;
      
      // 콤보 보너스 점수 조정 (3콤보부터 적용, 콤보당 5점 추가)
      int comboBonus = 0;
      if (player.combo >= 3) {
        comboBonus = (player.combo - 2) * 5;
      }
      
      // 총 점수 계산
      int totalScore = matchScore + comboBonus;
      player.score += totalScore;
      
      if(player.combo > player.maxCombo) {
        player.maxCombo = player.combo;
      }
      
      // 콤보 점수 표시
      String scoreMessage = '+$matchScore';
      if (comboBonus > 0) {
        scoreMessage += ' + 콤보보너스 $comboBonus';
      }
      if (player.combo > 1) {
        scoreMessage += ' (${player.combo}콤보!)';
      }
      _showComboScore(scoreMessage, isSuccess: true);
    }

    // 매칭 성공을 Firebase에 동기화
    firebaseService.syncCardMatch(
      currentRoom.id, 
      index1, 
      index2, 
      true, 
      currentPlayerId, 
      player?.score,
      player?.combo,
      player?.matchCount,
      player?.failCount,
      player?.maxCombo,
    );

    // 플레이어 상태를 별도로 동기화 (실시간 업데이트를 위해)
    if (player != null) {
      firebaseService.syncPlayerState(currentRoom.id, currentPlayerId, {
        'score': player.score,
        'combo': player.combo,
        'matchCount': player.matchCount,
        'failCount': player.failCount,
        'maxCombo': player.maxCombo,
      });
    }

    // 매칭된 카드 상태 동기화
    firebaseService.syncCardFlip(currentRoom.id, index1, true, currentPlayerId);
    firebaseService.syncCardFlip(currentRoom.id, index2, true, currentPlayerId);

    // 카드 상태 업데이트 (안전장치 추가)
    if (cards != null && index1 < cards!.length && index2 < cards!.length) {
      setState(() {
        cards![index1].isMatched = true;
        cards![index2].isMatched = true;
        matchedCardCount += 2;
      });
      print('매칭 성공: 카드 $index1, $index2 매칭됨');
    } else {
      print('매칭 성공 처리 실패: 카드 데이터 없음 또는 인덱스 오류');
    }

    // 게임 종료 조건은 플레이어 상태 스트림에서 처리하므로 여기서는 제거
    // (중복 방지를 위해)

    // 매칭 성공 시 턴 유지 (즉시 다음 카드 선택 가능)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          isProcessingCardSelection = false;
        });
      }
    });
  }

  void _handleMatchFailure(int index1, int index2) {
    // 사운드는 비동기로 처리
    Future.microtask(() {
      soundService.playMismatchSound();
    });
    
    final player = playersData[currentPlayerId];
    if(player != null) {
      // 매칭 실패 시 -2점으로 조정 (기존 -10점에서 감소)
      if (player.score > 0) {
        player.score = (player.score - 2).clamp(0, double.infinity).toInt();
      }
      player.combo = 0; // 콤보 리셋
      player.failCount++;
      
      // 실패 점수 표시
      _showComboScore('-2 (콤보 리셋)', isSuccess: false);
    }

    // 매칭 실패도 Firebase에 동기화
    firebaseService.syncCardMatch(
      currentRoom.id, 
      index1, 
      index2, 
      false, 
      currentPlayerId, 
      player?.score,
      player?.combo,
      player?.matchCount,
      player?.failCount,
      player?.maxCombo,
    );

    // 플레이어 상태를 별도로 동기화 (실시간 업데이트를 위해)
    if (player != null) {
      firebaseService.syncPlayerState(currentRoom.id, currentPlayerId, {
        'score': player.score,
        'combo': player.combo,
        'matchCount': player.matchCount,
        'failCount': player.failCount,
        'maxCombo': player.maxCombo,
      });
    }

    // 매칭 실패 시 카드를 다시 뒤집는 동기화
    firebaseService.syncCardFlip(currentRoom.id, index1, false, currentPlayerId);
    firebaseService.syncCardFlip(currentRoom.id, index2, false, currentPlayerId);

    // 카드 뒤집기와 턴 변경을 더 빠르고 안전하게 처리
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      // 카드 상태 확인 후 안전하게 뒤집기
      if (cards != null && index1 < cards!.length && index2 < cards!.length) {
        setState(() {
          // 카드가 아직 뒤집혀있는지 확인 후 뒤집기
          if (cards![index1].isFlipped && !cards![index1].isMatched) {
            cards![index1].isFlipped = false;
          }
          if (cards![index2].isFlipped && !cards![index2].isMatched) {
            cards![index2].isFlipped = false;
          }
          isProcessingCardSelection = false;
        });
        print('카드 뒤집기 완료: $index1, $index2');
      } else {
        setState(() {
          isProcessingCardSelection = false;
        });
        print('카드 뒤집기 실패: 카드 데이터 없음 또는 인덱스 오류');
      }
      
      // 턴 변경
      _changeTurn();
    });
  }
  
  void _changeTurn() {
    if (!mounted) return;

    // 카드 선택 상태 초기화 (안전장치)
    if (firstSelectedIndex != null || secondSelectedIndex != null) {
      print('턴 변경 시 카드 선택 상태 초기화: firstSelectedIndex=$firstSelectedIndex, secondSelectedIndex=$secondSelectedIndex');
      firstSelectedIndex = null;
      secondSelectedIndex = null;
    }

    // 유효한 플레이어 ID 목록 생성 (대기 중이거나 빈 ID 제외)
    final validPlayerIds = playersData.keys
        .where((id) => id.isNotEmpty && id != 'waiting' && playersData[id] != null)
        .toList();
    
    print('턴 변경 전 유효성 검사:');
    print('  유효한 플레이어 수: ${validPlayerIds.length}');
    print('  현재 턴 플레이어: $currentTurnPlayerId');
    print('  유효한 플레이어 목록: $validPlayerIds');
    
    if (validPlayerIds.length < 2) {
      print('턴 변경 실패: 유효한 플레이어가 2명 미만');
      setState(() { isProcessingCardSelection = false; });
      return;
    }

    // 현재 턴 플레이어가 유효한 목록에 있는지 확인
    if (!validPlayerIds.contains(currentTurnPlayerId)) {
      print('턴 변경 실패: 현재 턴 플레이어가 유효하지 않음');
      // 첫 번째 유효한 플레이어로 설정
      setState(() {
        currentTurnPlayerId = validPlayerIds.first;
        isProcessingCardSelection = false;
      });
      return;
    }

    final String previousPlayerId = currentTurnPlayerId;
    final currentIndex = validPlayerIds.indexOf(previousPlayerId);
    
    if (currentIndex == -1) {
      print('턴 변경 실패: 현재 플레이어 인덱스를 찾을 수 없음');
      setState(() { isProcessingCardSelection = false; });
      return;
    }

    final nextIndex = (currentIndex + 1) % validPlayerIds.length;
    final nextPlayerId = validPlayerIds[nextIndex];

    // 턴 변경 전에 현재 상태 확인
    if (nextPlayerId == previousPlayerId) {
      print('턴 변경 실패: 다음 플레이어가 현재 플레이어와 동일');
      setState(() { isProcessingCardSelection = false; });
      return;
    }

    // 게임 상태 확인
    if (gameCompleted) {
      print('턴 변경 무시: 게임이 이미 종료됨');
      setState(() { isProcessingCardSelection = false; });
      return;
    }

    print('턴 변경 실행: $previousPlayerId -> $nextPlayerId');
    setState(() {
      currentTurnPlayerId = nextPlayerId;
      isProcessingCardSelection = false;
    });

    // Firebase에 턴 변경 동기화
    firebaseService.syncTurnChange(currentRoom.id, previousPlayerId, nextPlayerId)
        .then((_) {
      print('턴 변경 동기화 성공');
    }).catchError((e) {
      print('턴 변경 동기화 실패: $e');
      // 동기화 실패 시에도 로컬 상태는 유지
    });
  }

  void _gameOver({String? message}) {
    if (gameCompleted) {
      print('게임이 이미 종료됨 - 중복 호출 무시');
      return;
    }
    gameCompleted = true;

    print('🎮 게임 종료 시작: $message');
    print('현재 플레이어 데이터:');
    for (final player in playersData.values) {
      print('  ${player.name}: 점수=${player.score}, 콤보=${player.combo}, 성공=${player.matchCount}, 실패=${player.failCount}, 최대콤보=${player.maxCombo}');
    }

    // 게임 타이머 정지
    gameTimer?.cancel();
    
    // 배경 음악 정지
    print('🔇 배경 음악 정지');
    soundService.stopBackgroundMusic();
    
    // 게임 승리 사운드 재생 (더 확실하게)
    print('🎵 게임 승리 사운드 재생 시작');
    soundService.playGameWin().then((_) {
      print('🎵 게임 승리 사운드 재생 완료');
    }).catchError((e) {
      print('❌ 게임 승리 사운드 재생 오류: $e');
    });

    final winner = _getWinner();
    print('🏆 승자: ${winner?.name ?? '무승부'} (ID: ${winner?.id ?? 'none'})');
    print('👤 현재 플레이어: $currentPlayerName (ID: $currentPlayerId)');
    print('🏠 호스트 여부: ${currentRoom.isHost(currentPlayerId)}');
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(message ?? "게임 종료!"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 승자 표시
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: winner != null ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: winner != null ? Colors.green.shade200 : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    winner != null ? "🏆 승자: ${winner.name} 🏆" : "🤝 무승부 🤝",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: winner != null ? Colors.green.shade800 : Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // 각 플레이어의 상세 결과
                ...playersData.values.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.id == winner?.id ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p.id == winner?.id ? Colors.green.shade300 : Colors.grey.shade300,
                      width: p.id == winner?.id ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.id == winner?.id ? Colors.green.shade800 : Colors.black87,
                            ),
                          ),
                          if (p.id == currentPlayerId) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '나',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 점수 정보
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('점수', '${p.score}', Colors.blue.shade700),
                          _buildStatItem('콤보', '${p.combo}', Colors.orange.shade700),
                          _buildStatItem('최대콤보', '${p.maxCombo}', Colors.purple.shade700),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 매칭/실패 정보
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('성공', '${p.matchCount}', Colors.green.shade700),
                          _buildStatItem('실패', '${p.failCount}', Colors.red.shade700),
                          _buildStatItem('정확도', '${p.matchCount + p.failCount > 0 ? ((p.matchCount / (p.matchCount + p.failCount)) * 100).round() : 0}%', Colors.indigo.shade700),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 16),
                // 게임 시간 정보
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '게임 시간: ${_formatGameTime()}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                soundService.playButtonClickSound();
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // 게임 화면에서 퇴장
              },
              child: const Text("확인"),
            ),
          ],
        ),
      );
    }
    
    // 게임 종료 상태를 Firebase에 동기화
    if(currentRoom.isHost(currentPlayerId)) {
        firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.finished).catchError((e) {
          print('게임 종료 시 방 상태 업데이트 오류: $e');
        });
    }
    
    // 모든 플레이어가 각자 게임 기록 저장
    print('💾 게임 기록 저장 시작');
    _saveGameRecord();
    
    // 게임 종료 이벤트를 Firebase에 기록
    print('📝 게임 종료 이벤트 기록 시작');
    _recordGameEndEvent(winner?.id);
    
    // 각 플레이어의 경험치와 레벨 업데이트
    print('🎯 경험치/레벨 업데이트 시작');
    _updateAllPlayersExpAndLevel();
  }

  // 모든 플레이어의 경험치와 레벨 업데이트
  Future<void> _updateAllPlayersExpAndLevel() async {
    try {
      print('🎯 모든 플레이어의 경험치/레벨 업데이트 시작');
      
      // 현재 플레이어의 정보만 업데이트 (다른 플레이어는 각자 처리)
      final currentPlayer = playersData[currentPlayerId];
      if (currentPlayer != null && currentPlayer.id.isNotEmpty && currentPlayer.id != 'waiting') {
        // 경험치 계산 조정: 점수와 분리하여 더 합리적으로 계산
        int addExp = 0;
        
        // 기본 경험치: 매칭 성공당 5점
        addExp += currentPlayer.matchCount * 5;
        
        // 게임 완료 보너스: 50점
        addExp += 50;
        
        // 승리 보너스: 승자인 경우 추가 100점
        final winner = _getWinner();
        if (winner?.id == currentPlayerId) {
          addExp += 100;
        }
        
        // 최대 콤보 보너스: 최대 콤보당 2점 (최대 20점)
        addExp += (currentPlayer.maxCombo * 2).clamp(0, 20);
        
        print('내 정보 업데이트: ${currentPlayer.name} (${currentPlayer.id})');
        print('  매칭 성공: ${currentPlayer.matchCount}회 × 5점 = ${currentPlayer.matchCount * 5}점');
        print('  게임 완료 보너스: 50점');
        if (winner?.id == currentPlayerId) {
          print('  승리 보너스: 100점');
        }
        print('  최대 콤보 보너스: ${currentPlayer.maxCombo}콤보 × 2점 = ${currentPlayer.maxCombo * 2}점');
        print('  총 경험치: $addExp점');
        
        try {
          await _updateUserExpAndLevel(addExp);
          print('✅ 내 경험치/레벨 업데이트 완료');
        } catch (playerError) {
          print('❌ 내 경험치/레벨 업데이트 실패: $playerError');
        }
      }
      
      // 다른 플레이어들의 정보는 각자 처리하도록 알림 (실제로는 각 플레이어가 자신의 정보를 업데이트)
      print('📢 다른 플레이어들의 경험치/레벨은 각자 처리됩니다.');
      
      print('🎯 경험치/레벨 업데이트 프로세스 완료');
    } catch (e) {
      print('❌ 경험치/레벨 업데이트 오류: $e');
    }
  }

  // 게임 종료 이벤트를 Firebase에 기록
  Future<void> _recordGameEndEvent(String? winnerId) async {
    try {
      final gameEndData = {
        'winnerId': winnerId,
        'endTime': FieldValue.serverTimestamp(),
        'finalScores': playersData.map((key, value) => MapEntry(key, {
          'score': value.score,
          'matchCount': value.matchCount,
          'failCount': value.failCount,
          'maxCombo': value.maxCombo,
        })),
        'totalTime': gameTimeSec - timeLeft,
      };
      
      await firebaseService.recordGameEndEvent(currentRoom.id, gameEndData);
      print('게임 종료 이벤트 기록 완료');
    } catch (e) {
      print('게임 종료 이벤트 기록 오류: $e');
    }
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatGameTime() {
    final totalTime = gameTimeSec - timeLeft;
    final minutes = (totalTime / 60).floor();
    final seconds = totalTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  OnlinePlayerGameData? _getWinner() {
    if (playersData.length < 2) return playersData.values.firstOrNull;
    final p1 = playersData.values.first;
    final p2 = currentRoom.guestId != null ? playersData.values.firstWhere((p) => p.id == currentRoom.guestId) : null;

    if (p2 == null) return p1;

    if (p1.score > p2.score) return p1;
    if (p2.score > p1.score) return p2;
    return null; // Draw
  }

  Future<void> _saveGameRecord() async {
    final gameRecord = MultiplayerGameRecord(
      id: currentRoom.id,
      gameTitle: currentRoom.roomName,
      players: playersData.values.map((p) => PlayerGameResult(
        playerName: p.name,
        email: '', // playerId 대신 email 사용
        score: p.score,
        matchCount: p.matchCount,
        failCount: p.failCount,
        maxCombo: p.maxCombo,
        timeLeft: timeLeft,
      )).toList(),
      createdAt: DateTime.now(),
      isCompleted: true,
      totalTime: gameTimeSec - timeLeft,
      timeLeft: timeLeft,
    );
    await firebaseService.saveOnlineMultiplayerGameRecord(gameRecord);
  }

  // --- Real-time Sync Handlers ---
  void _handleCardAction(List<Map<String, dynamic>> actions) {
    if (!mounted) return;
    
    for (final action in actions) {
      final actionId = action['id'] as String;
      if (_processedActionIds.contains(actionId)) continue;

      final playerId = action['playerId'] as String;
      if (playerId == currentPlayerId) continue;
      
      final cardIndex = action['cardIndex'] as int;
      final isFlipped = action['isFlipped'] as bool;
      
      if (cards != null && cardIndex >= 0 && cardIndex < cards!.length) {
        final card = cards![cardIndex];
        
        // 로컬 상태와 이벤트 상태가 다를 경우에만 처리
        if (card.isFlipped != isFlipped) {
          if (mounted) {
            setState(() {
              card.isFlipped = isFlipped;
            });
          }
        }
      }
      _processedActionIds.add(actionId);
    }
  }

  void _handleCardMatch(List<Map<String, dynamic>> matches) {
    if (!mounted) return;
    for (final match in matches) {
      final actionId = match['id'] as String;
      if (_processedActionIds.contains(actionId)) continue;
      
      final playerId = match['playerId'] as String;
      if (playerId == currentPlayerId) continue;
      
      final index1 = match['cardIndex1'] as int;
      final index2 = match['cardIndex2'] as int;
      final isMatch = match['isMatch'] as bool? ?? false;

      // 매칭 성공 이벤트만 처리합니다.
      if (isMatch) {
        if (cards != null && index1 >= 0 && index1 < cards!.length && index2 >= 0 && index2 < cards!.length) {
          // 카드를 매칭된 상태로 UI 업데이트
          setState(() {
            if (!cards![index1].isMatched) {
              cards![index1].isMatched = true;
              matchedCardCount++;
            }
            if (!cards![index2].isMatched) {
              cards![index2].isMatched = true;
              matchedCardCount++;
            }
          });

          // 매칭 성공 직후에만 게임 종료 조건을 체크 (중복 방지)
          if (!gameCompleted && matchedCardCount >= totalCards - 2) {
            print('모든 카드를 매칭함 - 게임 종료!');
            _gameOver(message: "🎉 모든 카드를 맞췄습니다! 🎉");
          }
        }
      }
      // isMatch: false 경우는 syncCardFlip을 통해 _handleCardAction에서 처리하므로 여기서 무시합니다.
      _processedActionIds.add(actionId);
    }
  }

  void _handleTurnChange(Map<String, dynamic>? turnData) {
    if (!mounted || turnData == null) {
      print('턴 변경 수신 무시: mounted=$mounted, turnData=${turnData != null}');
      return;
    }
    
    final String nextPlayerId = turnData['nextPlayerId'] as String? ?? '';
    final String previousPlayerId = turnData['previousPlayerId'] as String? ?? '';
    
    print('턴 변경 수신: $previousPlayerId -> $nextPlayerId');
    print('현재 턴: $currentTurnPlayerId');
    
    // 유효성 검사
    if (nextPlayerId.isEmpty) {
      print('턴 변경 수신 무시: nextPlayerId가 비어있음');
      return;
    }
    
    if (currentTurnPlayerId == nextPlayerId) {
      print('턴 변경 수신 무시: 이미 해당 플레이어의 턴임');
      return;
    }
    
    // 플레이어가 유효한지 확인
    if (!playersData.containsKey(nextPlayerId)) {
      print('턴 변경 수신 무시: 유효하지 않은 플레이어 ID: $nextPlayerId');
      return;
    }
    
    // 게임이 종료되었는지 확인
    if (gameCompleted) {
      print('턴 변경 수신 무시: 게임이 이미 종료됨');
      return;
    }
    
    print('턴 변경 적용: $currentTurnPlayerId -> $nextPlayerId');
    setState(() {
      currentTurnPlayerId = nextPlayerId;
      isProcessingCardSelection = false;
    });
  }

  void _handleGameEndEvent(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty && mounted) {
      final doc = snapshot.docs.first;
      final event = doc.data() as Map<String, dynamic>;
      print('게임 종료 이벤트 수신: $event');
      
      // 게임 종료 이벤트 처리
      final eventData = event['data'] as Map<String, dynamic>?;
      if (eventData != null) {
        // 게임 종료 데이터 처리
        print('게임 종료 데이터: $eventData');
      }
    }
  }

  void _handlePlayerStates(Map<String, dynamic> states) {
    if (!mounted) return;
    
    setState(() {
      for (final entry in states.entries) {
        final playerId = entry.key;
        final stateData = entry.value as Map<String, dynamic>;
        
        if (playersData.containsKey(playerId)) {
          final player = playersData[playerId]!;
          player.score = stateData['score'] ?? player.score;
          player.combo = stateData['combo'] ?? player.combo;
          player.matchCount = stateData['matchCount'] ?? player.matchCount;
          player.failCount = stateData['failCount'] ?? player.failCount;
          player.maxCombo = stateData['maxCombo'] ?? player.maxCombo;
        }
      }
    });
    
    // 게임 종료 조건 확인: 모든 플레이어의 성공 개수 합이 총 카드 쌍의 개수인지 확인
    final totalMatchCount = playersData.values.fold<int>(0, (sum, player) => sum + player.matchCount);
    final totalCards = cards?.length ?? 48; // 기본값 48개 (24쌍)
    final totalPairs = totalCards ~/ 2; // 24쌍
    
    print('🎯 게임 종료 조건 확인: 총 성공 개수 $totalMatchCount, 총 카드 쌍 $totalPairs, gameCompleted: $gameCompleted');
    
    if (totalMatchCount >= totalPairs && !gameCompleted) {
      print('🎉 모든 플레이어의 성공 개수 합이 $totalPairs개에 도달 - 게임 종료!');
      print('최종 플레이어 상태:');
      for (final player in playersData.values) {
        print('  ${player.name}: 성공=${player.matchCount}, 실패=${player.failCount}, 점수=${player.score}');
      }
      _gameOver(message: "🎉 모든 카드를 맞췄습니다! 🎉");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              soundService.playButtonClickSound();
              Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _formatTime() {
    final minutes = (timeLeft / 60).floor().toString().padLeft(2, '0');
    final seconds = (timeLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showComboScore(String message, {bool isSuccess = true}) {
    setState(() {
      comboScoreMessage = message;
      showComboScore = true;
      isComboScoreSuccess = isSuccess;
    });
    
    comboScoreTimer?.cancel();
    comboScoreTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          showComboScore = false;
          comboScoreMessage = null;
        });
      }
    });
  }

  /// 게스트 플레이어의 카드 로딩 처리
  void _startCardLoading() {
    if (currentRoom.isHost(currentPlayerId)) return;
    
    setState(() {
      isCardsLoading = true;
      cardLoadRetryCount = 0;
    });
    
    _attemptCardLoad();
  }

  /// 카드 로딩 시도
  Future<void> _attemptCardLoad() async {
    if (!mounted || currentRoom.isHost(currentPlayerId)) return;
    
    try {
      print('카드 로딩 시도 ${cardLoadRetryCount + 1}/$maxCardLoadRetries');
      
      // 먼저 호스트가 카드를 저장했는지 확인
      final hasCards = await firebaseService.hasHostSavedCards(currentRoom.id);
      if (!hasCards) {
        print('호스트가 아직 카드를 저장하지 않음 - 재시도 대기');
        cardLoadRetryCount++;
        
        if (cardLoadRetryCount >= maxCardLoadRetries) {
          setState(() {
            isCardsLoading = false;
          });
          print('카드 로딩 최대 재시도 횟수 초과');
          _showErrorDialog('호스트가 카드를 준비하지 않았습니다. 방을 다시 입장해주세요.');
          return;
        }
        
        // 0.5초 후 재시도 (더 빠르게)
        cardLoadRetryTimer?.cancel();
        cardLoadRetryTimer = Timer(const Duration(milliseconds: 500), _attemptCardLoad);
        return;
      }
      
      // 호스트가 카드를 저장했으므로 로딩 시도
      final loadedCardsData = await firebaseService.loadGameCards(currentRoom.id);
      
      // 카드 데이터가 비어있는지 확인
      if (loadedCardsData.isEmpty) {
        print('카드 데이터가 비어있음 - 재시도');
        cardLoadRetryCount++;
        
        if (cardLoadRetryCount >= maxCardLoadRetries) {
          setState(() {
            isCardsLoading = false;
          });
          print('카드 로딩 최대 재시도 횟수 초과 (데이터 비어있음)');
          _showErrorDialog('카드 데이터를 불러올 수 없습니다. 방을 다시 입장해주세요.');
          return;
        }
        
        // 0.5초 후 재시도
        cardLoadRetryTimer?.cancel();
        cardLoadRetryTimer = Timer(const Duration(milliseconds: 500), _attemptCardLoad);
        return;
      }
      
      // 카드 데이터가 정상적으로 로드됨
      setState(() {
        cards = loadedCardsData;
        isCardsLoading = false;
      });
      cardLoadRetryTimer?.cancel();
      print('카드 로딩 완료: ${cards!.length}개 카드');
      
      // 카드 데이터 확인 (디버깅용)
      if (cards!.isNotEmpty) {
        print('첫 번째 카드 데이터 확인:');
        print('  ID: ${cards![0].id}');
        print('  이모지: ${cards![0].emoji}');
        print('  이름: ${cards![0].name ?? "null"}');
        print('  뒤집힘: ${cards![0].isFlipped}');
        print('  매칭됨: ${cards![0].isMatched}');
      }
      
      // 카드 로딩 완료 후 게임이 대기 상태라면 자동 시작
      if (currentRoom.status == RoomStatus.playing && !isGameRunning) {
        print('카드 로딩 완료 후 게임 자동 시작');
        _startGame();
      }
      
    } catch (e) {
      print('카드 로딩 오류: $e');
      cardLoadRetryCount++;
      
      if (cardLoadRetryCount >= maxCardLoadRetries) {
        setState(() {
          isCardsLoading = false;
        });
        _showErrorDialog('카드 로딩 중 오류가 발생했습니다: $e');
        return;
      }
      
      // 1초 후 재시도
      cardLoadRetryTimer?.cancel();
      cardLoadRetryTimer = Timer(const Duration(seconds: 1), _attemptCardLoad);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        // 게임 중이고 다른 플레이어가 있는 경우 확인
        if (isGameRunning && playersData.length > 1) {
          final shouldLeave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('게임 나가기'),
              content: const Text('게임이 진행 중입니다. 정말로 나가시겠습니까? 다른 플레이어에게 영향을 줄 수 있습니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    soundService.playButtonClickSound();
                    Navigator.pop(context, false);
                  }, 
                  child: const Text('취소')
                ),
                TextButton(
                  onPressed: () {
                    soundService.playButtonClickSound();
                    Navigator.pop(context, true);
                  }, 
                  child: const Text('나가기')
                ),
              ],
            ),
          ) ?? false;

          if (shouldLeave) {
            await _leaveRoom();
          }
        } else {
          // 게임이 끝났거나 혼자 있는 경우 바로 나가기
          await _leaveRoom();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.room.roomName),
          actions: [
            // 디버그용 턴 변경 버튼 (개발 중에만 표시)
            if (kDebugMode) ...[
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  soundService.playButtonClickSound();
                  print('수동 턴 변경 버튼 클릭');
                  print('현재 턴: $currentTurnPlayerId');
                  print('내 ID: $currentPlayerId');
                  print('유효한 플레이어: ${playersData.keys.where((id) => id.isNotEmpty && id != 'waiting').toList()}');
                  _changeTurn();
                },
                tooltip: '턴 변경 (디버그)',
              ),
              IconButton(
                icon: Icon(Icons.stop),
                onPressed: () {
                  // 게임 강제 종료 함수 호출
                  _gameOver(message: "디버그: 강제 종료");
                },
                tooltip: '강제 게임 종료(디버그)',
              ),
            ],
            // 턴 상태 표시 버튼
            IconButton(
              icon: Icon(
                isMyTurn ? Icons.play_circle_filled : Icons.pause_circle_filled,
                color: isMyTurn ? Colors.green : Colors.grey,
              ),
              onPressed: () {
                soundService.playButtonClickSound();
                _showTurnStatusDialog();
              },
              tooltip: '턴 상태 확인',
            ),
            IconButton(
              icon: Icon(isTimerPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () {
                soundService.playButtonClickSound();
                setState(() {
                  isTimerPaused = !isTimerPaused;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.flash_on),
              onPressed: _debugAutoSolveAllPairs,
              tooltip: '자동 정답(디버그)',
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildInfoPanel(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final availableWidth = constraints.maxWidth;
                        final availableHeight = constraints.maxHeight;

                        // 카드 그리드 레이아웃 계산
                        const double horizontalPadding = 8.0;
                        const double verticalPadding = 8.0;
                        const double horizontalSpacing = 1.0; // 간격 줄임
                        const double verticalSpacing = 1.0; // 간격 줄임

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
                            itemCount: totalCards,
                            itemBuilder: (context, index) {
                              // 카드가 로드되지 않은 경우 로딩 상태 표시
                              if (cards == null || index >= cards!.length || cards![index].emoji == '❓') {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                      const SizedBox(height: 4),
                                      Flexible(
                                        child: Text(
                                          isCardsLoading 
                                            ? '로딩중...\n(${cardLoadRetryCount + 1}/$maxCardLoadRetries)'
                                            : '준비중...',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade600,
                                            fontSize: 8,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              return MemoryCard(
                                card: cards![index],
                                onTap: () => onCardPressed(index),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // 콤보 점수 오버레이
              if (showComboScore && comboScoreMessage != null)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.3,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isComboScoreSuccess ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isComboScoreSuccess ? Colors.green.shade300 : Colors.red.shade300, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        comboScoreMessage!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isComboScoreSuccess ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    final p1 = playersData.values.firstWhere((p) => p.id == currentRoom.hostId, orElse: () => OnlinePlayerGameData(id: '', name: ''));
    final p2 = currentRoom.guestId != null ? playersData.values.firstWhere((p) => p.id == currentRoom.guestId, orElse: () => OnlinePlayerGameData(id: '', name: '')) : null;

    if (p1.id.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPlayerInfo(p1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '남은 시간',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCardsLoading 
                          ? Colors.grey.shade600  // 로딩 중일 때는 회색
                          : (timeLeft < 60 ? Colors.red : Colors.black),  // 로딩 완료 후에만 빨간색 조건 적용
                      ),
                    ),
                  ],
                ),
              ),
              if (p2 != null && p2.id.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPlayerInfo(p2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMyTurn ? Colors.green.shade200 : Colors.blue.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '현재 턴: ${playersData[currentTurnPlayerId]?.name ?? '알 수 없음'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isMyTurn ? Colors.green.shade800 : Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '내 턴: ${isMyTurn ? "✅" : "❌"} | ${playersData.length}명',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
                // 디버그 정보 추가 (축약된 버전)
                Text(
                  '${isGameRunning ? "진행중" : "대기중"} | ${(matchedCardCount / 2).round()}쌍/${numPairs}쌍',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 7,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${isCardsLoading ? "로딩(${cardLoadRetryCount + 1}/$maxCardLoadRetries)" : "완료"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 7,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isMyTurn) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '카드를 클릭하세요!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(OnlinePlayerGameData player) {
    bool isTurn = player.id == currentTurnPlayerId;
    bool isMe = player.id == currentPlayerId;
    
    // 플레이어 데이터가 없는 경우를 위한 방어 코드
    if (player.id.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Text('대기 중...')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isTurn ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTurn ? Colors.green.shade400 : Colors.grey.shade300,
          width: isTurn ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Lv${player.level} ${player.name}', // 레벨과 이름 함께 표시
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isTurn ? Colors.green.shade800 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '나',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6), // 간격 축소
          // 점수 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '점수',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${player.score}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '콤보',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${player.combo}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4), // 간격 축소
          // 매칭/실패 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '성공',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${player.matchCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '실패',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${player.failCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '최대콤보',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${player.maxCombo}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    try {
      await firebaseService.leaveOnlineRoom(currentRoom.id);
    } catch (e) {
      // 방 나가기 실패 시에도 화면은 닫기
      print('방 나가기 오류: $e');
    }
    
    if(mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showTurnStatusDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('턴 상태'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 턴: ${playersData[currentTurnPlayerId]?.name ?? '알 수 없음'}'),
            Text('내 턴: ${isMyTurn ? "✅" : "❌"}'),
            const SizedBox(height: 8),
            const Text('플레이어 목록:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...playersData.values.map((player) => Text(
              '• ${player.name} (${player.id == currentPlayerId ? "나" : "상대"}) ${player.id == currentTurnPlayerId ? "🔄" : ""}',
            )),
            const SizedBox(height: 8),
            Text('게임 상태: ${gameCompleted ? "종료" : "진행 중"}'),
            Text('카드 처리 중: ${isProcessingCardSelection ? "예" : "아니오"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              soundService.playButtonClickSound();
              Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  int calcLevel(int exp) {
    // 레벨 계산 공식 조정: 2000 경험치당 1레벨 (기존 1000에서 증가)
    return (exp ~/ 2000).clamp(0, 98) + 1;
  }

  Future<void> _updateUserExpAndLevel(int addExp) async {
    try {
      final user = firebaseService.currentUser;
      if (user == null) {
        print('❌ 사용자 정보가 없어 경험치/레벨 업데이트를 건너뜁니다.');
        return;
      }

      print('🔄 경험치/레벨 업데이트 시작: 사용자 ${user.uid}, 추가 경험치: $addExp');

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await userDoc.get();
      
      if (!snapshot.exists) {
        print('❌ 사용자 문서가 존재하지 않습니다: ${user.uid}');
        return;
      }

      final userData = snapshot.data()!;
      int currentExp = (userData['exp'] ?? 0) as int;
      int currentLevel = (userData['level'] ?? 1) as int;
      int newExp = currentExp + addExp;
      int newLevel = calcLevel(newExp);

      print('📊 경험치/레벨 업데이트: $currentExp -> $newExp, Lv$currentLevel -> Lv$newLevel');

      await userDoc.update({
        'exp': newExp,
        'level': newLevel,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ 경험치/레벨 업데이트 완료');
    } catch (e) {
      print('❌ 경험치/레벨 업데이트 오류: $e');
      rethrow;
    }
  }

  // 자동 정답 후 1초 뒤에도 게임이 안 끝나면 강제 종료 보정 유지
  Future<void> _debugAutoSolveAllPairs() async {
    if (cards == null) return;
    // id별로 인덱스 그룹핑
    Map<int, List<int>> pairMap = {};
    for (int i = 0; i < cards!.length; i++) {
      pairMap.putIfAbsent(cards![i].id, () => []).add(i);
    }
    // 모든 쌍에 대해 순서대로 클릭
    for (var pair in pairMap.values) {
      if (pair.length == 2) {
        onCardPressed(pair[0]);
        await Future.delayed(const Duration(milliseconds: 200));
        onCardPressed(pair[1]);
        await Future.delayed(const Duration(milliseconds: 600)); // 매칭 애니메이션 대기
      }
    }
    // 자동 정답 후 1초 뒤에도 게임이 안 끝나면 강제 종료
    await Future.delayed(const Duration(seconds: 1));
    // 수정: matchedCardCount는 매칭된 카드 개수이므로 totalCards - 2와 비교해야 함
    if (!gameCompleted && matchedCardCount >= totalCards - 2) {
      _gameOver(message: "디버그: 강제 종료(자동 정답 후)");
    }
  }

  /// 게스트 레벨 정보 실시간 업데이트
  Future<void> _updateGuestLevelInfo() async {
    if (currentRoom.guestId == null || currentRoom.guestId!.isEmpty) {
      return;
    }

    try {
      print('🔄 게스트 레벨 정보 업데이트: ${currentRoom.guestId}');
      final guestUserData = await firebaseService.getUserData(currentRoom.guestId!);
      final guestLevel = guestUserData?['level'] ?? 1;
      
      if (playersData.containsKey(currentRoom.guestId!)) {
        setState(() {
          playersData[currentRoom.guestId!]!.level = guestLevel;
        });
        print('✅ 게스트 레벨 업데이트 완료: Lv$guestLevel');
      }
    } catch (e) {
      print('❌ 게스트 레벨 업데이트 오류: $e');
    }
  }
}

// Helper class to manage player data within the game screen
class OnlinePlayerGameData {
  final String id;
  final String name;
  int score;
  int matchCount;
  int failCount;
  int combo;
  int maxCombo;
  int level; // 추가

  OnlinePlayerGameData({
    required this.id,
    required this.name,
    this.score = 0,
    this.matchCount = 0,
    this.failCount = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.level = 1, // 기본값
  });
} 