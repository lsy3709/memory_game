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
  static const int gameTimeSec = 15 * 60; // 게임 제한 시간(초 단위, 15분)

  // 게임 상태 변수
  late List<CardModel> cards;             // 카드 목록
  int? firstSelectedIndex;                // 첫 번째로 선택된 카드 인덱스
  int? secondSelectedIndex;               // 두 번째로 선택된 카드 인덱스
  int timeLeft = gameTimeSec;             // 남은 시간(초)
  bool isGameRunning = false;             // 게임 진행 여부
  bool isTimerPaused = false;             // 타이머 일시정지 여부
  Timer? gameTimer;                       // 게임 타이머 (nullable로 변경)
  final SoundService soundService = SoundService(); // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final StorageService storageService = StorageService(); // 저장소 관리
  
  // 기록 관련 변수
  int maxCombo = 0;                       // 최고 연속 매칭 기록
  String currentPlayerName = '게스트';     // 현재 플레이어 이름
  String currentPlayerEmail = '';         // 현재 플레이어 이메일
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간

  @override
  void initState() {
    super.initState();
    scoreModel = ScoreModel();
    _loadPlayerInfo();
    _initGame();
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

  /// 게임 시작 시 카드 생성 및 타이머 설정
  void _initGame() {
    cards = [];
    _createCards();
    _setupTimer();
  }

  /// 카드 쌍을 생성하고 셔플
  void _createCards() {
    cards.clear(); // 기존 카드 리스트 초기화

    // 카드 쌍의 개수만큼 반복
    for (int i = 0; i < numPairs; i++) {
      // 각 쌍마다 두 장의 카드를 생성
      for (int j = 0; j < 2; j++) {
        cards.add(CardModel(
          id: i * 2 + j, // 고유 id
          pairId: i, // 쌍 id
          imagePath: 'assets/flag_image/img${i + 1}.png', // 이미지 경로
        ));
      }
    }
    cards.shuffle(); // 카드 순서 섞기
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

  /// 두 카드가 매칭되는지 검사
  void _checkMatch() {
    if (firstSelectedIndex == null || secondSelectedIndex == null) return;
    final a = firstSelectedIndex!, b = secondSelectedIndex!;
    firstSelectedIndex = null;
    secondSelectedIndex = null;

    // 0.7초 후 매칭 결과 처리(뒤집힌 카드 보여주기)
    Future.delayed(const Duration(milliseconds: 700), () {
      // mounted 상태 확인 후 setState 호출
      if (mounted) {
        setState(() {
          if (cards[a].pairId == cards[b].pairId) {
            soundService.playCardMatch();
            cards[a] = cards[a].copyWith(isMatched: true);
            cards[b] = cards[b].copyWith(isMatched: true);
            scoreModel.addMatchScore(); // 매칭 성공 시 점수 추가
            
            // 최고 연속 매칭 기록 업데이트
            if (scoreModel.comboCount > maxCombo) {
              maxCombo = scoreModel.comboCount;
            }
            
            _checkGameEnd();
          } else {
            soundService.playCardMismatch();
            cards[a] = cards[a].copyWith(isFlipped: false);
            cards[b] = cards[b].copyWith(isFlipped: false);
            scoreModel.addFailPenalty(); // 매칭 실패 시 패널티
          }
        });
      }
    });
  }

  /// 모든 카드가 매칭되었는지 확인 후 게임 종료 처리
  void _checkGameEnd() {
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
                Text('최종 점수: ${scoreModel.currentScore}점'),
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
        score: scoreModel.currentScore,
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
            score: scoreModel.currentScore,
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

  /// 게임 시작 또는 일시정지 해제
  void _startGame() {
    // 일시정지 상태에서 계속하기
    if (isGameRunning && isTimerPaused) {
      setState(() => isTimerPaused = false);
      soundService.resumeBackgroundMusic();
      return;
    }
    
    soundService.playGameStart(); // 게임 시작 사운드
    setState(() {
      _createCards(); // 카드 새로 생성
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec; // 시간 초기화
      isGameRunning = true;
      isTimerPaused = false;
      maxCombo = 0; // 최고 연속 매칭 기록 초기화
      gameStartTime = DateTime.now(); // 게임 시작 시간 기록
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel(); // 기존 타이머 중지
    _setupTimer(); // 타이머 재설정
    soundService.startBackgroundMusic(); // 배경음악 시작
  }

  /// 게임 일시정지
  void _pauseGame() {
    if (!isGameRunning || isTimerPaused) return;
    setState(() => isTimerPaused = true);
    soundService.pauseBackgroundMusic(); // 배경음악 일시정지
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    soundService.playButtonSound();
    setState(() {
      _createCards();
      firstSelectedIndex = null;
      secondSelectedIndex = null;
      timeLeft = gameTimeSec;
      isGameRunning = false;
      isTimerPaused = false;
      maxCombo = 0; // 최고 연속 매칭 기록 초기화
      scoreModel.reset(); // 점수 초기화
    });
    if (gameTimer?.isActive == true) gameTimer?.cancel();
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  /// 시간 초과 시 게임 오버 처리
  void _gameOver() {
    isGameRunning = false;
    gameTimer?.cancel();
    soundService.stopBackgroundMusic();
    
    // 게임 기록 저장 (미완료)
    _saveGameRecord(false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('시간 초과!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('게임 오버'),
            const SizedBox(height: 8),
            Text('최종 점수: ${scoreModel.currentScore}점'),
            Text('매칭 성공: ${scoreModel.matchCount}회'),
            Text('매칭 실패: ${scoreModel.failCount}회'),
            Text('최고 연속 매칭: ${maxCombo}회'),
            if (scoreModel.currentScore > scoreModel.bestScore)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모리 카드 게임'),
        centerTitle: true,
        actions: [
          // 랭킹 보드 버튼
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.of(context).pushNamed('/ranking');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 게임 정보 영역
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 시간 표시
                Text(
                  '남은 시간: ${_formatTime()}',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 점수 표시
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '점수: ${scoreModel.currentScore}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (scoreModel.comboCount > 1)
                      Text(
                        '${scoreModel.comboCount}콤보!',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (maxCombo > 0)
                      Text(
                        '최고 콤보: $maxCombo',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 카드 그리드 영역
          // 화면의 남은 공간을 모두 차지하도록 Expanded로 감쌈
          Expanded(
            child: Padding(
              // 좌우에 16픽셀씩 여백 추가
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LayoutBuilder(
                // LayoutBuilder로 실제 그리드 영역의 크기 계산
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;   // 가용 너비
                  final gridHeight = constraints.maxHeight; // 가용 높이
                  const spacing = 12.0;                     // 카드 사이 간격
                  // 각 카드의 가로/세로 크기 계산
                  final itemWidth =
                      (gridWidth - (cols - 1) * spacing) / cols;
                  final itemHeight =
                      (gridHeight - (rows - 1) * spacing) / rows;
                  final aspectRatio = itemWidth / itemHeight; // 카드 비율

                  // 그리드 형태로 카드 목록을 표시
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(), // 스크롤 비활성화
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,                // 열 개수 지정
                      childAspectRatio: aspectRatio,        // 카드 비율 적용
                      crossAxisSpacing: spacing,            // 열 간격
                      mainAxisSpacing: spacing,             // 행 간격
                    ),
                    itemCount: totalCards,                  // 전체 카드 개수
                    itemBuilder: (context, index) {
                      // 각 카드에 대한 위젯 생성
                      return MemoryCard(
                        card: cards[index],                 // 카드 데이터 전달
                        onTap: () => _onCardTap(index),     // 카드 터치 시 콜백
                        isEnabled: isGameRunning && !isTimerPaused, // 활성화 여부
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 하단 버튼 영역
          Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 시작/계속하기 버튼
                ElevatedButton(
                  onPressed: () {
                    soundService.playButtonSound();
                    _startGame();
                  },
                  child: Text(isGameRunning && isTimerPaused
                      ? '계속하기'
                      : '시작'),
                ),
                // 멈춤 버튼
                ElevatedButton(
                  onPressed: isGameRunning && !isTimerPaused
                      ? () {
                    soundService.playButtonSound();
                    _pauseGame();
                  }
                      : null,
                  child: const Text('멈춤'),
                ),
                // 다시하기 버튼
                ElevatedButton(
                  onPressed: _resetGame,
                  child: const Text('다시하기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}