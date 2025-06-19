import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import '../widgets/memory_card.dart';
import '../models/card_model.dart';
import '../models/score_model.dart';
import '../models/game_record.dart';
import '../models/player_stats.dart';
import '../services/sound_service.dart';
import '../services/firebase_service.dart';

/// 온라인 싱글플레이어 메모리 카드 게임 화면
class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key});

  @override
  _OnlineGameScreenState createState() => _OnlineGameScreenState();
}

/// 온라인 게임의 상태와 로직을 관리하는 State 클래스
class _OnlineGameScreenState extends State<OnlineGameScreen> {
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
  late Timer gameTimer;                   // 게임 타이머
  final SoundService soundService = SoundService(); // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final FirebaseService firebaseService = FirebaseService(); // Firebase 서비스
  
  // 기록 관련 변수
  int maxCombo = 0;                       // 최고 연속 매칭 기록
  String currentPlayerName = '플레이어';   // 현재 플레이어 이름
  String currentPlayerEmail = '';         // 현재 플레이어 이메일
  DateTime gameStartTime = DateTime.now(); // 게임 시작 시간
  bool isOnlineMode = true;               // 온라인 모드 여부

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
      if (gameTimer.isActive) {
        gameTimer.cancel();
        print('게임 타이머 정리 완료');
      }
    } catch (e) {
      print('타이머 정리 오류: $e');
    }
    
    // 사운드 리소스 해제
    try {
      soundService.dispose();
      print('사운드 서비스 정리 완료');
    } catch (e) {
      print('사운드 서비스 정리 오류: $e');
    }
    
    // 상태 변수 초기화
    isGameRunning = false;
    isTimerPaused = false;
    firstSelectedIndex = null;
    secondSelectedIndex = null;
    
    print('OnlineGameScreen dispose 완료');
    super.dispose();
  }

  /// 플레이어 정보 로드
  Future<void> _loadPlayerInfo() async {
    try {
      final user = firebaseService.currentUser;
      if (user != null) {
        final userData = await firebaseService.getUserData(user.uid);
        if (userData != null) {
          setState(() {
            currentPlayerName = userData['playerName'] ?? user.displayName ?? '플레이어';
            currentPlayerEmail = userData['email'] ?? user.email ?? '';
          });
          print('게임 화면 - 플레이어 이름: $currentPlayerName');
          print('게임 화면 - 플레이어 이메일: $currentPlayerEmail');
        } else {
          // Firestore에서 데이터를 가져올 수 없는 경우 Firebase Auth 정보 사용
          setState(() {
            currentPlayerName = user.displayName ?? '플레이어';
            currentPlayerEmail = user.email ?? '';
          });
          print('Firestore 데이터 없음 - Firebase Auth 정보 사용');
          print('게임 화면 - 플레이어 이름: $currentPlayerName');
          print('게임 화면 - 플레이어 이메일: $currentPlayerEmail');
        }
      } else {
        print('로그인된 사용자가 없습니다.');
        // 로그인되지 않은 경우 로컬 메인 화면으로 이동
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } catch (e) {
      print('플레이어 정보 로드 오류: $e');
      // Firebase 오류 시 로컬 메인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
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
    if (gameTimer.isActive) {
      gameTimer.cancel();
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
      gameTimer.cancel(); // 타이머 중지
      soundService.stopBackgroundMusic(); // 배경음악 중지
      soundService.playGameWin(); // 승리 사운드
      
      // 온라인 게임 기록 저장
      _saveOnlineGameRecord(true);
      
      // 0.5초 후 축하 다이얼로그 표시
      Future.delayed(const Duration(milliseconds: 500), () {
        // mounted 상태 확인 후 다이얼로그 표시
        if (mounted) {
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
                  const SizedBox(height: 8),
                  const Text('온라인 랭킹에 기록이 저장되었습니다!', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
      });
    }
  }

  /// 온라인 게임 기록 저장
  Future<void> _saveOnlineGameRecord(bool isCompleted) async {
    try {
      // Firebase 연결 상태 확인
      final isFirebaseAvailable = await firebaseService.ensureInitialized();
      if (!isFirebaseAvailable) {
        print('Firebase가 사용할 수 없어 온라인 기록을 저장할 수 없습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('온라인 기록 저장을 위해 Firebase 설정이 필요합니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 로그인 상태 확인
      if (firebaseService.currentUser == null) {
        print('로그인되지 않은 상태에서 온라인 기록 저장 시도');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('온라인 기록 저장을 위해 로그인이 필요합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final gameRecord = GameRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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

      print('온라인 게임 기록 저장 시작...');
      print('플레이어: $currentPlayerName');
      print('점수: ${scoreModel.currentScore}');
      print('완료 여부: $isCompleted');

      // 온라인 게임 기록 저장
      await firebaseService.saveOnlineGameRecord(gameRecord);
      print('온라인 게임 기록 저장 완료');

      // 온라인 플레이어 통계 업데이트
      final onlineStats = await firebaseService.getOnlinePlayerStats();
      if (onlineStats != null) {
        final updatedStats = onlineStats.updateWithGameResult(
          score: scoreModel.currentScore,
          gameTime: gameTimeSec - timeLeft,
          maxCombo: maxCombo,
          matchCount: scoreModel.matchCount,
          failCount: scoreModel.failCount,
          isWin: isCompleted,
        );
        await firebaseService.saveOnlinePlayerStats(updatedStats);
        print('온라인 플레이어 통계 업데이트 완료');
      } else {
        // 새로운 플레이어 통계 생성
        final newStats = PlayerStats(
          id: firebaseService.currentUser!.uid,
          playerName: currentPlayerName,
          email: currentPlayerEmail,
          totalGames: 1,
          totalWins: isCompleted ? 1 : 0,
          bestScore: scoreModel.currentScore,
          bestTime: gameTimeSec - timeLeft,
          maxCombo: maxCombo,
          totalMatches: scoreModel.matchCount,
          totalFails: scoreModel.failCount,
          totalMatchCount: scoreModel.matchCount,
          totalFailCount: scoreModel.failCount,
          lastPlayed: DateTime.now(),
          createdAt: DateTime.now(),
        );
        await firebaseService.saveOnlinePlayerStats(newStats);
        print('새로운 온라인 플레이어 통계 생성 완료');
      }

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('온라인 랭킹에 기록이 저장되었습니다! (${scoreModel.currentScore}점)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('온라인 게임 기록 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('온라인 기록 저장에 실패했습니다: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    
    // 기존 타이머 정리
    if (gameTimer.isActive) {
      gameTimer.cancel();
    }
    
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
    
    // 기존 타이머 정리
    if (gameTimer.isActive) {
      gameTimer.cancel();
    }
    
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
    
    _setupTimer();
    soundService.stopBackgroundMusic();
  }

  /// 시간 초과 시 게임 오버 처리
  void _gameOver() {
    isGameRunning = false;
    gameTimer.cancel();
    soundService.stopBackgroundMusic();
    
    // 온라인 게임 기록 저장 (미완료)
    _saveOnlineGameRecord(false);
    
    // mounted 상태 확인 후 다이얼로그 표시
    if (mounted) {
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
              const SizedBox(height: 8),
              const Text('온라인 랭킹에 기록이 저장되었습니다!', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 메모리 게임'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // 온라인 랭킹 보드 버튼
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.of(context).pushNamed('/online-ranking');
            },
            tooltip: '온라인 랭킹',
          ),
        ],
      ),
      body: Column(
        children: [
          // 게임 정보 영역
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.blue.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 시간 표시
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '남은 시간: ${_formatTime()}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '플레이어: $currentPlayerName',
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.blue,
                      ),
                    ),
                  ],
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;
                  final gridHeight = constraints.maxHeight;
                  const spacing = 12.0;
                  final itemWidth = (gridWidth - (cols - 1) * spacing) / cols;
                  final itemHeight = (gridHeight - (rows - 1) * spacing) / rows;
                  final aspectRatio = itemWidth / itemHeight;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: totalCards,
                    itemBuilder: (context, index) {
                      return MemoryCard(
                        card: cards[index],
                        onTap: () => _onCardTap(index),
                        isEnabled: isGameRunning && !isTimerPaused,
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 하단 버튼 영역
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: Colors.blue.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 시작/계속하기 버튼
                ElevatedButton(
                  onPressed: () {
                    soundService.playButtonSound();
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isGameRunning && isTimerPaused ? '계속하기' : '시작'),
                ),
                // 멈춤 버튼
                ElevatedButton(
                  onPressed: isGameRunning && !isTimerPaused
                      ? () {
                          soundService.playButtonSound();
                          _pauseGame();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('멈춤'),
                ),
                // 다시하기 버튼
                ElevatedButton(
                  onPressed: _resetGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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