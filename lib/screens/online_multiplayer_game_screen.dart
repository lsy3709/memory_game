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
      cards = List.generate(totalCards, (index) => CardModel(id: index, emoji: '❓'));
      print('게스트가 임시 카드 생성: ${cards.length}개 카드');
    }
  }
  
  List<CardModel> _generateCards() {
    final List<String> cardValues = ['🐧', '🐨', '🦄', '🦊', '🦉', '🦋', '🐳', '🦖', '🐙', '🐸', '🦁', '🐵', '🐰', '🐼', '🐷', '🐻', '🐶', '🐱', '🐭', '🐹', '🐻‍❄️', '🐯', '🐮', '🐴'];
    cardValues.shuffle();
    
    List<CardModel> generatedCards = [];
    for (int i = 0; i < numPairs; i++) {
      final emoji = cardValues[i];
      generatedCards.add(CardModel(id: i * 2, emoji: emoji));
      generatedCards.add(CardModel(id: i * 2 + 1, emoji: emoji));
    }
    
    generatedCards.shuffle();
    print('카드 생성 완료: ${generatedCards.length}개 (${numPairs}쌍)');
    return generatedCards;
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
            cards = loadedCardsData.map((data) => CardModel.fromJson(data)).toList();
          });
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

    print('카드 클릭 성공: 인덱스=$index');

    setState(() {
      cards[index].isFlipped = true;
      isProcessingCardSelection = true;
    });
    
    firebaseService.syncCardFlip(currentRoom.id, index, true, currentPlayerId);

    if (firstSelectedIndex == null) {
      firstSelectedIndex = index;
      print('첫 번째 카드 선택: $index');
      setState(() {
        isProcessingCardSelection = false;
      });
    } else {
      secondSelectedIndex = index;
      print('두 번째 카드 선택: $index, 매칭 확인 시작');
      _checkForMatch();
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
    print('카드1 내용: ${cards[firstSelectedIndex!].emoji}');
    print('카드2 내용: ${cards[secondSelectedIndex!].emoji}');

    final isMatch = cards[firstSelectedIndex!].emoji == cards[secondSelectedIndex!].emoji;
    print('매칭 결과: $isMatch');

    if (isMatch) {
      _handleMatchSuccess(firstSelectedIndex!, secondSelectedIndex!);
    } else {
      _handleMatchFailure(firstSelectedIndex!, secondSelectedIndex!);
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
      firstSelectedIndex = null;
      secondSelectedIndex = null;
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
    
    final player = playersData[currentPlayerId];
    if(player != null) {
      player.combo = 0;
      player.failCount++;
    }

    print('매칭 실패 후 턴 변경: ${currentPlayerId} -> 다음 플레이어');

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          cards[index1].isFlipped = false;
          cards[index2].isFlipped = false;
          firstSelectedIndex = null;
          secondSelectedIndex = null;
          isProcessingCardSelection = false;
        });
        
        firebaseService.syncCardFlip(currentRoom.id, index1, false, currentPlayerId);
        firebaseService.syncCardFlip(currentRoom.id, index2, false, currentPlayerId);
        
        // 턴 변경 - 강제 실행
        _forceTurnChange();
      }
    });
  }
  
  void _handleTurnChange(Map<String, dynamic>? turnData) {
    if (!mounted || turnData == null) return;
    
    final actionId = turnData['id'] as String;
    if (_processedActionIds.contains(actionId)) {
      print('이미 처리된 턴 변경 액션: $actionId');
      return;
    }

    final nextPlayerId = turnData['nextPlayerId'] as String;
    print('턴 변경 수신: $currentTurnPlayerId -> $nextPlayerId');
    print('현재 플레이어 ID: $currentPlayerId');
    print('내 턴 여부: ${nextPlayerId == currentPlayerId}');
    
    // 강제로 상태 업데이트
    if (mounted) {
      setState(() {
        currentTurnPlayerId = nextPlayerId;
        
        // 내 턴이 시작되면 카드 선택 상태 초기화
        if (nextPlayerId == currentPlayerId) {
          firstSelectedIndex = null;
          secondSelectedIndex = null;
          isProcessingCardSelection = false;
          print('내 턴 시작 - 카드 선택 상태 초기화');
        }
      });
      
      // 턴 변경 후 상태 확인
      print('턴 변경 완료 - 현재 턴: $currentTurnPlayerId, 내 턴: ${currentTurnPlayerId == currentPlayerId}');
    }

    _processedActionIds.add(actionId);
  }

  void _forceTurnChange() {
    print('강제 턴 변경 시작');
    print('현재 플레이어 데이터: $playersData');
    print('현재 턴 플레이어: $currentTurnPlayerId');
    
    if (playersData.length < 2) {
      print('플레이어가 2명 미만이므로 턴 변경 안함');
      return;
    }
    
    final validPlayerIds = playersData.keys.where((id) => id != 'waiting').toList();
    print('유효한 플레이어 ID 목록: $validPlayerIds');
    
    if (validPlayerIds.length < 2) {
      print('유효한 플레이어가 2명 미만이므로 턴 변경 안함');
      return;
    }
    
    final currentPlayerIndex = validPlayerIds.indexOf(currentTurnPlayerId);
    print('현재 턴 플레이어 인덱스: $currentPlayerIndex');
    
    final nextPlayerIndex = (currentPlayerIndex + 1) % validPlayerIds.length;
    final nextPlayerId = validPlayerIds[nextPlayerIndex];
    
    print('강제 턴 변경: $currentTurnPlayerId -> $nextPlayerId');
    print('유효한 플레이어 목록: $validPlayerIds');
    print('현재 플레이어: $currentPlayerId, 다음 턴: $nextPlayerId');
    
    // 로컬 상태 강제 업데이트
    if (mounted) {
      setState(() {
        currentTurnPlayerId = nextPlayerId;
        // 카드 선택 상태 초기화
        firstSelectedIndex = null;
        secondSelectedIndex = null;
        isProcessingCardSelection = false;
      });
      
      print('로컬 상태 업데이트 완료 - 새로운 턴: $currentTurnPlayerId');
    }
    
    // Firebase에 턴 변경 전송
    try {
      firebaseService.syncTurnChange(currentRoom.id, currentTurnPlayerId, nextPlayerId);
      print('턴 변경 Firebase 전송 완료');
    } catch (e) {
      print('턴 변경 Firebase 전송 실패: $e');
    }
  }
  
  void _changeTurn() {
    _forceTurnChange();
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
    for (final action in actions) {
        final actionId = action['id'] as String;
        if (_processedActionIds.contains(actionId)) continue;

        final playerId = action['playerId'] as String;
        if (playerId == currentPlayerId) continue;
        
        final cardIndex = action['cardIndex'] as int;
        final isFlipped = action['isFlipped'] as bool;
        
        if (cardIndex >= 0 && cardIndex < cards.length) {
            setState(() {
                cards[cardIndex].isFlipped = isFlipped;
            });
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
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    print('화면 크기: ${screenWidth.toInt()} x ${screenHeight.toInt()}');
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('게임 나가기'),
                content: const Text('정말로 게임을 나가시겠습니까? 게임 기록은 저장되지 않습니다.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('나가기')),
                ],
              ),
            ) ?? false;

        if (shouldLeave) {
          await firebaseService.leaveOnlineRoom(currentRoom.id);
          if(mounted) {
            Navigator.of(context).pop();
          }
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
                _forceTurnChange();
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
                    // 헤더 영역을 제외한 실제 사용 가능한 공간
                    final availableWidth = constraints.maxWidth;
                    final availableHeight = constraints.maxHeight;
                    
                    print('사용 가능한 공간: ${availableWidth.toInt()} x ${availableHeight.toInt()}');
                    
                    // 고정된 카드 크기 계산 (최소 크기 보장)
                    final minCardWidth = 50.0;
                    final minCardHeight = 60.0;
                    
                    // 사용 가능한 공간을 6x8로 분할 (패딩 고려)
                    final padding = 8.0;
                    final spacing = 2.0;
                    final cardAreaWidth = availableWidth - (padding * 2) - (spacing * (cols - 1));
                    final cardAreaHeight = availableHeight - (padding * 2) - (spacing * (rows - 1));
                    
                    final cardWidth = cardAreaWidth / cols;
                    final cardHeight = cardAreaHeight / rows;
                    
                    // 최소 크기 보장
                    final finalCardWidth = cardWidth < minCardWidth ? minCardWidth : cardWidth;
                    final finalCardHeight = cardHeight < minCardHeight ? minCardHeight : cardHeight;
                    
                    print('카드 크기: ${finalCardWidth.toInt()} x ${finalCardHeight.toInt()}');
                    print('총 카드 수: $totalCards (${cols}x${rows})');
                    
                    // 카드의 종횡비 계산
                    final cardAspectRatio = finalCardWidth / finalCardHeight;
                    
                    print('카드 종횡비: ${cardAspectRatio.toStringAsFixed(2)}');

                    return Container(
                      width: availableWidth,
                      height: availableHeight,
                      padding: const EdgeInsets.all(8),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          childAspectRatio: cardAspectRatio,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemCount: totalCards,
                        itemBuilder: (context, index) {
                          if (index >= cards.length) {
                            print('카드 인덱스 오류: $index >= ${cards.length}');
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red),
                              ),
                              child: const Center(
                                child: Text('오류', style: TextStyle(color: Colors.red)),
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