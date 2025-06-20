import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/game_record.dart';
import '../models/player_stats.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import 'package:memory_game/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

/// 메모리 카드 게임의 메인 화면을 담당하는 StatefulWidget
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

/// 게임의 상태와 로직을 관리하는 State 클래스
class _GameScreenState extends State<GameScreen> {
  // 게임 설정 상수
  static const int rows = 8;              // 카드 그리드의 행 수
  static const int cols = 6;              // 카드 그리드의 열 수
  static const int numPairs = 24;         // 카드 쌍의 개수
  static const int totalCards = numPairs * 2; // 전체 카드 수
  static const int gameTimeSec = 15 * 60; // 15분

  // 게임 상태 변수
  List<CardModel> cards = [];
  int? firstSelectedIndex;
  int? secondSelectedIndex;
  bool isGameRunning = false;
  bool isTimerPaused = false;
  Timer? gameTimer;
  int timeLeft = gameTimeSec; // 15분
  int maxCombo = 0;
  final SoundService soundService = SoundService.instance; // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final StorageService storageService = StorageService.instance; // 저장소 관리
  
  // 기록 관련 변수
  String currentPlayerName = '게스트';     // 현재 플레이어 이름
  String currentPlayerEmail = '';         // 현재 플레이어 이메일
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간

  /// 게임 완료 여부
  bool gameCompleted = false;

  /// 현재 점수
  int get score => scoreModel.score;

  @override
  void initState() {
    super.initState();
    scoreModel = ScoreModel();
    _loadPlayerInfo();
    _createCards();
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  @override
  void dispose() {
    // 타이머 정리
    try {
      if (gameTimer?.isActive == true) {
        gameTimer?.cancel();
        print('로컬 게임 타이머 정리 완료');
      }
    } catch (e) {
      print('로컬 타이머 정리 오류: $e');
    }
    
    // 사운드 리소스 해제
    try {
      soundService.dispose();
      print('로컬 사운드 서비스 정리 완료');
    } catch (e) {
      print('로컬 사운드 서비스 정리 오류: $e');
    }
    
    // 상태 변수 초기화
    isGameRunning = false;
    isTimerPaused = false;
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    print('GameScreen dispose 완료');
    super.dispose();
  }

  /// 플레이어 정보 로드
  Future<void> _loadPlayerInfo() async {
    try {
      final playerInfo = await storageService.loadCurrentPlayer();
      if (playerInfo != null) {
        setState(() {
          currentPlayerName = playerInfo['playerName'] ?? '게스트';
          currentPlayerEmail = playerInfo['email'] ?? '';
        });
      }
    } catch (e) {
      print('플레이어 정보 로드 오류: $e');
    }
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

  /// 카드 생성 및 섞기
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

  /// 1초마다 남은 시간을 감소시키는 타이머 설정
  void _setupTimer() {
    // 기존 타이머가 있다면 취소
    if (gameTimer?.isActive == true) {
      gameTimer?.cancel();
    }
    
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // mounted 상태 확인 후 setState 호출
      if (mounted && isGameRunning && !isTimerPaused) {
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
    // 게임이 진행 중이 아니거나 일시정지, 이미 뒤집힌/맞춘 카드, 같은 카드 두 번 클릭, 두 장 이미 선택된 경우 무시
    if (!isGameRunning || isTimerPaused) return;
    if (cards[index].isMatched || cards[index].isFlipped) return;
    if (firstSelectedIndex == index) return;
    if (firstSelectedIndex != null && secondSelectedIndex != null) return;

    soundService.playCardFlip(); // 카드 뒤집기 사운드
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true); // 카드 뒤집기
      if (firstSelectedIndex == null) {
        firstSelectedIndex = index; // 첫 번째 카드 선택
      } else {
        secondSelectedIndex = index; // 두 번째 카드 선택
        Future.microtask(_checkMatch); // 매칭 검사 예약
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
      scoreModel.addMatch();
      
      // 연속 매칭 기록 업데이트
      if (scoreModel.currentCombo > maxCombo) {
        maxCombo = scoreModel.currentCombo;
      }
    });
    
    // 선택된 카드 초기화
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    // 게임 완료 확인
    _checkGameCompletion();
  }

  /// 매칭 실패 처리
  void _handleMatchFailure() {
    soundService.playMismatchSound();
    
    setState(() {
      // 실패 횟수 증가
      scoreModel.addFail();
    });
    
    // 1초 후 카드 뒤집기
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          cards[firstSelectedIndex!].isFlipped = false;
          cards[secondSelectedIndex!].isFlipped = false;
          firstSelectedIndex = null;
          secondSelectedIndex = null;
        });
      }
    });
  }

  /// 모든 카드가 매칭되었는지 확인 후 게임 종료 처리
  void _checkGameCompletion() {
    if (cards.every((c) => c.isMatched)) {
      isGameRunning = false;
      gameTimer?.cancel(); // 타이머 중지
      soundService.stopBackgroundMusic(); // 배경음악 중지
      soundService.playGameWin(); // 승리 사운드
      
      // 게임 기록 저장
      _saveGameRecord(true);
      
      // 0.5초 후 축하 다이얼로그 표시
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('축하합니다!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('모든 카드를 맞췄어요!'),
                const SizedBox(height: 8),
                Text('최종 점수: ${scoreModel.score}점'),
                Text('최고 연속 매칭: ${maxCombo}회'),
                Text('완료 시간: ${_formatTime()}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      });
    }
  }

  /// 게임 기록 저장
  Future<void> _saveGameRecord(bool isCompleted) async {
    try {
      final gameRecord = GameRecord(
        id: storageService.generateId(),
        playerName: currentPlayerName,
        email: currentPlayerEmail,
        score: scoreModel.score,
        matchCount: scoreModel.matchCount,
        failCount: scoreModel.failCount,
        maxCombo: maxCombo,
        timeLeft: timeLeft,
        totalTime: gameTimeSec,
        createdAt: DateTime.now(),
        isCompleted: isCompleted,
      );

      // 게임 기록 저장
      await storageService.saveGameRecord(gameRecord);

      // 플레이어 통계 업데이트 (등록된 플레이어인 경우)
      if (currentPlayerEmail.isNotEmpty) {
        final playerStats = await storageService.loadPlayerStats();
        if (playerStats != null) {
          final updatedStats = playerStats.updateWithGameResult(
            score: scoreModel.score,
            gameTime: gameTimeSec - timeLeft,
            maxCombo: maxCombo,
            matchCount: scoreModel.matchCount,
            failCount: scoreModel.failCount,
            isWin: isCompleted,
          );
          await storageService.savePlayerStats(updatedStats);
        }
      }
    } catch (e) {
      print('게임 기록 저장 오류: $e');
    }
  }

  /// 게임 결과 다이얼로그 표시
  void _showGameResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('게임 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('모든 카드를 맞췄어요!'),
            const SizedBox(height: 8),
            Text('최종 점수: ${scoreModel.score}점'),
            Text('최고 연속 매칭: ${maxCombo}회'),
            Text('완료 시간: ${_formatTime()}'),
            if (scoreModel.score > 0)
              const Text('새로운 최고 점수!', style: TextStyle(color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 게임 일시정지
  void _pauseGame() {
    setState(() {
      isTimerPaused = true;
    });
    soundService.stopAllSounds();
  }

  /// 게임 재개
  void _resumeGame() {
    setState(() {
      isTimerPaused = false;
    });
    soundService.playBackgroundMusic();
  }

  /// 게임 시작
  void _startGame() {
    setState(() {
      _createCards();
      timeLeft = gameTimeSec;
      isGameRunning = true;
      isTimerPaused = false;
      scoreModel.reset();
      maxCombo = 0;
    });
    _setupTimer();
    soundService.playBackgroundMusic();
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    setState(() {
      _createCards();
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      maxCombo = 0;
      scoreModel.reset();
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  /// 시간 초과 시 게임 오버 처리
  void _gameOver() {
    setState(() {
      isGameRunning = false;
    });
    
    soundService.stopAllSounds();
    soundService.playGameOverSound();
    
    // 게임 기록 저장
    _saveGameRecord(false);
    
    // 게임 결과 다이얼로그 표시
    _showGameResultDialog();
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
    
    print('=== 반응형 카드 레이아웃 정보 ===');
    print('화면 크기: ${screenWidth}x${screenHeight}');
    print('가용 높이: $availableHeight');
    print('그리드: ${gridColumns}x${gridRows} (고정)');
    print('카드 크기: ${finalCardSize.toStringAsFixed(1)}px');
    print('실제 그리드 크기: ${actualGridWidth.toStringAsFixed(1)}x${actualGridHeight.toStringAsFixed(1)}');
    print('카드 간격: ${cardSpacing}px');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모리 게임'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
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
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 점수
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '점수: $score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                    // 최고 콤보
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '최고 콤보: $maxCombo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 카드 그리드 (고정 6x8 레이아웃)
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
                              isEnabled: isGameRunning,
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
                    if (!isGameRunning)
                      ElevatedButton(
                        onPressed: _startGame,
                        child: Text('시작'),
                      ),
                    if (isGameRunning && !isTimerPaused)
                      ElevatedButton(
                        onPressed: _pauseGame,
                        child: Text('멈춤'),
                      ),
                    if (isGameRunning && isTimerPaused)
                      ElevatedButton(
                        onPressed: _resumeGame,
                        child: Text('계속'),
                      ),
                    ElevatedButton(
                      onPressed: _resetGame,
                      child: Text('다시 시작'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('나가기'),
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