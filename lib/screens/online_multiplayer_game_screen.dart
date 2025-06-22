import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:memory_game/models/player_stats.dart';
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
  static const int rows = 8;
  static const int cols = 6;
  static const int numPairs = (rows * cols) ~/ 2;
  static const int totalCards = numPairs * 2;
  static const int gameTimeSec = 15 * 60;

  // 게임 상태 변수
  late List<CardModel> cards;
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
  
  Map<String, PlayerGameData> playersData = {};
  String currentTurnPlayerId = '';

  bool get isMyTurn => currentTurnPlayerId == currentPlayerId;

  // 점수 및 콤보 관리
  int myCombo = 0;
  int opponentCombo = 0;

  // 실시간 동기화 관련 변수
  StreamSubscription? _roomSubscription;
  StreamSubscription? _cardActionsSubscription;
  StreamSubscription? _turnChangeSubscription;
  StreamSubscription? _cardMatchesSubscription;
  final Set<String> _processedActionIds = {};

  bool gameCompleted = false;

  @override
  void initState() {
    super.initState();
    currentRoom = widget.room;
    _initializeGameAndPlayers();
  }

  Future<void> _initializeGameAndPlayers() async {
    await _loadPlayerInfo();
    _initGameCards();
    _setupListeners();
    // 호스트만 게임 시작을 트리거
    if (currentRoom.isHost(currentPlayerId)) {
      await firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _roomSubscription?.cancel();
    _cardActionsSubscription?.cancel();
    _turnChangeSubscription?.cancel();
    _cardMatchesSubscription?.cancel();
    soundService.stopBackgroundMusic();
    
    // 방에서 나가기 (화면이 종료될 때)
    if (mounted && currentRoom.id.isNotEmpty) {
      firebaseService.leaveOnlineRoom(currentRoom.id);
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

    setState(() {
      final hostData = PlayerGameData(id: currentRoom.hostId, name: currentRoom.hostName);
      final guestData = currentRoom.guestId != null
          ? PlayerGameData(id: currentRoom.guestId!, name: currentRoom.guestName ?? '게스트')
          : PlayerGameData(id: 'waiting', name: '대기 중...');
      
      playersData = {
        hostData.id: hostData,
        guestData.id: guestData,
      };

      // 호스트가 선공하도록 설정
      currentTurnPlayerId = currentRoom.hostId;
      print('초기 턴 설정: $currentTurnPlayerId (호스트)');
    });
  }

  void _initGameCards() {
    // 호스트인 경우에만 카드를 생성하고 저장
    if (currentRoom.isHost(currentPlayerId)) {
      cards = _generateCards();
      print('호스트가 카드 생성: ${cards.length}개 카드');
      // 생성된 카드 정보를 Firestore에 저장
      firebaseService.saveGameCards(currentRoom.id, cards.map((c) => c.toJson()).toList());
    } else {
      // 게스트인 경우 카드 정보를 로드할 때까지 임시로 빈 리스트 사용
      cards = List.generate(totalCards, (index) => CardModel(
        id: index,
        emoji: '❓',
        name: '로딩 중...',
        isMatched: false,
        isFlipped: false,
      ));
      print('게스트가 임시 카드 생성: ${cards.length}개 카드');
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
      generatedCards.add(CardModel(
        id: i,
        emoji: emoji,
        name: name,
        isMatched: false,
        isFlipped: false,
      ));
      generatedCards.add(CardModel(
        id: i,
        emoji: emoji,
        name: name,
        isMatched: false,
        isFlipped: false,
      ));
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
        _gameOver(message: '방이 사라졌습니다.');
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
          await _loadPlayerInfo();
        }

        // 게스트가 나간 경우 처리
        if (room.guestId == null && playersData.length > 1) {
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
        } else if (room.status == RoomStatus.finished || room.status == RoomStatus.cancelled) {
          _gameOver();
        }
      }
      
      // 게스트이고 카드가 아직 로드되지 않은 경우 카드 로드
      if (!currentRoom.isHost(currentPlayerId) && cards.every((c) => c.emoji == '❓')) {
        final loadedCardsData = await firebaseService.loadGameCards(room.id);
        if (loadedCardsData.isNotEmpty) {
          setState(() {
            cards = loadedCardsData.map((data) {
              final card = CardModel.fromJson(data);
              // name이 없거나 비어있는 경우 emoji에 따라 설정
              if (card.name == null || card.name!.isEmpty) {
                final emojiIndex = _getEmojiIndex(card.emoji);
                if (emojiIndex != -1) {
                  final flagNames = [
                    '대한민국', '미국', '일본', '중국', '영국', '프랑스', '독일', '이탈리아',
                    '스페인', '캐나다', '호주', '브라질', '아르헨티나', '멕시코', '인도', '러시아',
                    '북한', '태국', '베트남', '필리핀', '말레이시아', '싱가포르', '인도네시아', '대만'
                  ];
                  return card.copyWith(name: flagNames[emojiIndex]);
                }
              }
              return card;
            }).toList();
          });
          print('카드 로드 완료: ${cards.length}개 카드');
        }
      }
    });

    _cardActionsSubscription = firebaseService.getCardActionsStream(currentRoom.id).listen(_handleCardAction);
    _turnChangeSubscription = firebaseService.getTurnChangeStream(currentRoom.id).listen(_handleTurnChange);
    _cardMatchesSubscription = firebaseService.getCardMatchesStream(currentRoom.id).listen(_handleCardMatch);
  }

  void _startGame() {
    if (isGameRunning || !mounted) return;
    
    setState(() {
      isGameRunning = true;
      gameStartTime = DateTime.now();
    });
    
    soundService.playBackgroundMusic();
    gameTimer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    
    // 호스트가 시작했으므로 게스트에게도 시작 알림
    if (currentRoom.isHost(currentPlayerId)) {
        firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.playing);
    }
  }

  void _updateTimer(Timer timer) {
    if (isTimerPaused) return;

    if (timeLeft > 0) {
      setState(() {
        timeLeft--;
      });
    } else {
      _gameOver(message: "시간 초과!");
    }
  }

  void onCardPressed(int index) {
    print('카드 클릭 시도: 인덱스=$index, 현재 턴=$currentTurnPlayerId, 내 ID=$currentPlayerId, isMyTurn=$isMyTurn');
    
    if (isProcessingCardSelection) {
      print('카드 처리 중 - 클릭 무시');
      return;
    }
    
    if (cards[index].isFlipped) {
      print('이미 뒤집힌 카드 - 클릭 무시');
      return;
    }
    
    if (cards[index].isMatched) {
      print('이미 매칭된 카드 - 클릭 무시');
      return;
    }
    
    if (!isMyTurn) {
      print('내 턴이 아님 - 클릭 무시');
      return;
    }
    
    if (!isGameRunning) {
      print('게임이 진행 중이 아님 - 클릭 무시');
      return;
    }

    print('카드 클릭 성공: 인덱스=$index, 카드 내용: ${cards[index].emoji} - ${cards[index].name}');

    // 즉시 카드 뒤집기
    setState(() {
      cards[index].isFlipped = true;
      isProcessingCardSelection = true;
    });
    
    // Firebase에 동기화
    firebaseService.syncCardFlip(currentRoom.id, index, true, currentPlayerId);

    // 첫 번째 카드 선택
    if (firstSelectedIndex == null) {
      firstSelectedIndex = index;
      print('첫 번째 카드 선택: $index');
      setState(() {
        isProcessingCardSelection = false;
      });
    } else if (secondSelectedIndex == null) {
      // 두 번째 카드 선택
      secondSelectedIndex = index;
      print('두 번째 카드 선택: $index, 매칭 확인 시작');
      
      // 매칭 확인
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && firstSelectedIndex != null && secondSelectedIndex != null) {
          _checkForMatch();
        }
      });
    }
  }

  void _checkForMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) {
      print('매칭 확인 실패: 선택된 카드가 부족');
      setState(() {
        isProcessingCardSelection = false;
      });
      return;
    }

    print('매칭 확인: 카드1=$firstSelectedIndex, 카드2=$secondSelectedIndex');
    print('카드1 내용: ${cards[firstSelectedIndex!].emoji} (ID: ${cards[firstSelectedIndex!].id})');
    print('카드2 내용: ${cards[secondSelectedIndex!].emoji} (ID: ${cards[secondSelectedIndex!].id})');

    // ID로 매칭 확인 (더 정확함)
    final isMatch = cards[firstSelectedIndex!].id == cards[secondSelectedIndex!].id;
    print('매칭 결과: $isMatch');

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
    soundService.playMatchSound();
    
    final player = playersData[currentPlayerId];
    if(player != null) {
      player.combo++;
      player.matchCount++;
      player.score += 10 * player.combo;
      if(player.combo > player.maxCombo) {
        player.maxCombo = player.combo;
      }
    }

    print('매칭 성공! 턴 유지: $currentPlayerId');

    setState(() {
      cards[index1].isMatched = true;
      cards[index2].isMatched = true;
      isProcessingCardSelection = false;
    });

    firebaseService.syncCardMatch(currentRoom.id, index1, index2, true, currentPlayerId, player?.score);

    // 게임 종료 조건 확인
    if (cards.every((card) => card.isMatched)) {
      _gameOver(message: "모든 카드를 맞췄습니다!");
      return;
    }

    // 매칭 성공 시 턴 유지 (즉시 다음 카드 선택 가능)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isProcessingCardSelection = false;
        });
      }
    });
  }

  void _handleMatchFailure(int index1, int index2) {
    soundService.playMismatchSound();
    
    playersData[currentPlayerId]?.combo = 0;
    playersData[currentPlayerId]?.failCount++;

    // 매칭 실패 시 카드를 다시 뒤집는 동기화
    firebaseService.syncCardFlip(currentRoom.id, index1, false, currentPlayerId);
    firebaseService.syncCardFlip(currentRoom.id, index2, false, currentPlayerId);

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      
      setState(() {
        cards[index1].isFlipped = false;
        cards[index2].isFlipped = false;
        isProcessingCardSelection = false;
      });
      
      _changeTurn();
    });
  }
  
  void _changeTurn() {
    if (!mounted) return;

    final validPlayerIds = playersData.keys.where((id) => id.isNotEmpty && id != 'waiting').toList();
    if (validPlayerIds.length < 2) {
      print("턴 변경 불가: 유효한 플레이어가 2명 미만입니다.");
      setState(() { isProcessingCardSelection = false; });
      return;
    }

    final String previousPlayerId = currentTurnPlayerId;
    final currentIndex = validPlayerIds.indexOf(previousPlayerId);
    
    if (currentIndex == -1) {
        print("오류: 현재 턴 플레이어($previousPlayerId)를 유효한 플레이어 목록에서 찾을 수 없습니다.");
        setState(() { isProcessingCardSelection = false; });
        return;
    }

    final nextIndex = (currentIndex + 1) % validPlayerIds.length;
    final nextPlayerId = validPlayerIds[nextIndex];
    
    print("--- 턴 변경: $previousPlayerId -> $nextPlayerId ---");

    setState(() {
      currentTurnPlayerId = nextPlayerId;
      isProcessingCardSelection = false;
    });

    firebaseService.syncTurnChange(currentRoom.id, previousPlayerId, nextPlayerId);
  }

  void _gameOver({String? message}) {
    if (gameCompleted) return;
    gameCompleted = true;

    gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    soundService.playGameWinSound();

    final winner = _getWinner();
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(message ?? "게임 종료!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("승자: ${winner?.name ?? '무승부'}"),
              const SizedBox(height: 10),
              ...playersData.values.map((p) => Text("${p.name}: ${p.score}점")).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // 게임 화면에서 퇴장
              },
              child: const Text("확인"),
            ),
          ],
        ),
      );
    }
    
    if(currentRoom.isHost(currentPlayerId)) {
        _saveGameRecord();
        firebaseService.updateRoomStatus(currentRoom.id, RoomStatus.finished);
    }
  }

  PlayerGameData? _getWinner() {
    if (playersData.length < 2) return playersData.values.firstOrNull;
    final p1 = playersData.values.first;
    final p2 = playersData.values.last;

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
    
    bool needsUpdate = false;
    List<int> cardsToUpdate = [];
    
    for (final action in actions) {
        final actionId = action['id'] as String;
        if (_processedActionIds.contains(actionId)) continue;

        final playerId = action['playerId'] as String;
        if (playerId == currentPlayerId) continue;
        
        final cardIndex = action['cardIndex'] as int;
        final isFlipped = action['isFlipped'] as bool;
        
        if (cardIndex >= 0 && cardIndex < cards.length) {
            if (cards[cardIndex].isFlipped != isFlipped) {
                cardsToUpdate.add(cardIndex);
                needsUpdate = true;
            }
        }
        _processedActionIds.add(actionId);
    }
    
    // 배치 업데이트로 성능 향상
    if (needsUpdate) {
        setState(() {
            for (final index in cardsToUpdate) {
                final action = actions.firstWhere((a) => a['cardIndex'] == index);
                final isFlipped = action['isFlipped'] as bool;
                cards[index].isFlipped = isFlipped;
            }
        });
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
        final score = match['score'] as int?;

        if (index1 >= 0 && index1 < cards.length && index2 >= 0 && index2 < cards.length) {
            setState(() {
                cards[index1].isMatched = true;
                cards[index2].isMatched = true;
                cards[index1].isFlipped = true;
                cards[index2].isFlipped = true;

                final player = playersData[playerId];
                if (player != null && score != null) {
                    player.score = score;
                }
            });
        }
        _processedActionIds.add(actionId);
    }
  }

  void _handleTurnChange(Map<String, dynamic>? turnData) {
    if (!mounted || turnData == null) return;
    
    final String nextPlayerId = turnData['nextPlayerId'] as String;
    
    if (currentTurnPlayerId == nextPlayerId) return;

    print("Firebase로부터 턴 변경 수신: $currentTurnPlayerId -> $nextPlayerId");
    setState(() {
      currentTurnPlayerId = nextPlayerId;
      isProcessingCardSelection = false;
    });
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
            onPressed: () => Navigator.of(context).pop(),
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
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('나가기')),
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
            // 디버그용 턴 변경 버튼
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () {
                print('수동 턴 변경 버튼 클릭');
                _changeTurn();
              },
              tooltip: '턴 변경 (디버그)',
            ),
            IconButton(
              icon: Icon(isTimerPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () {
                setState(() {
                  isTimerPaused = !isTimerPaused;
                });
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildInfoPanel(),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final availableWidth = constraints.maxWidth;
                    final availableHeight = constraints.maxHeight;

                    // Tighten padding and spacing for a better fit
                    const double horizontalPadding = 4.0;
                    const double verticalPadding = 4.0;
                    const double horizontalSpacing = 2.0;
                    const double verticalSpacing = 2.0;

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
                          if (index >= cards.length || cards[index].emoji == '❓') {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          
                          return MemoryCard(
                            card: cards[index],
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
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    final p1 = playersData.values.firstOrNull;
    final p2 = playersData.values.length > 1 ? playersData.values.last : null;

    if (p1 == null) return const SizedBox.shrink();

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
                        color: timeLeft < 60 ? Colors.red : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              if (p2 != null) ...[
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
                  '내 턴: ${isMyTurn ? "✅ 예" : "❌ 아니오"} | 플레이어 수: ${playersData.length} | 턴 ID: $currentTurnPlayerId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
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

  Widget _buildPlayerInfo(PlayerGameData player) {
    bool isTurn = player.id == currentTurnPlayerId;
    bool isMe = player.id == currentPlayerId;
    
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
              Text(
                player.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isTurn ? Colors.green.shade800 : Colors.black87,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
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
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    await firebaseService.leaveOnlineRoom(currentRoom.id);
    if(mounted) {
      Navigator.of(context).pop();
    }
  }
}

// Helper class to manage player data within the game screen
class PlayerGameData {
  final String id;
  final String name;
  int score;
  int matchCount;
  int failCount;
  int combo;
  int maxCombo;

  PlayerGameData({
    required this.id,
    required this.name,
    this.score = 0,
    this.matchCount = 0,
    this.failCount = 0,
    this.combo = 0,
    this.maxCombo = 0,
  });
} 