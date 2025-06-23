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
  Timer? gameTimer;                       // 게임 타이머 (nullable로 변경)
  final SoundService soundService = SoundService.instance; // 사운드 관리
  late ScoreModel scoreModel;             // 점수 관리
  final FirebaseService firebaseService = FirebaseService.instance; // Firebase 서비스
  
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
      if (gameTimer?.isActive == true) {
        gameTimer?.cancel();
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
        Map<String, dynamic>? userData;
        try {
          userData = await firebaseService.getUserData(user.uid);
        } catch (e) {
          print('사용자 데이터 로드 오류: $e');
          // 오류가 발생해도 기본값 사용
        }
        
        if (userData != null) {
          setState(() {
            currentPlayerName = (userData as Map<String, dynamic>)['playerName'] ?? user.displayName ?? '플레이어';
            currentPlayerEmail = (userData as Map<String, dynamic>)['email'] ?? user.email ?? '';
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

  /// 카드 쌍을 생성하고 셔플
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

    // 즉시 카드 뒤집기 (반응성 향상)
    setState(() {
      cards[index] = cards[index].copyWith(isFlipped: true);
    });

    // 사운드는 비동기로 처리 (UI 블로킹 방지)
    Future.microtask(() {
      soundService.playCardFlipSound();
    });

    if (firstSelectedIndex == null) {
      firstSelectedIndex = index; // 첫 번째 카드 선택
    } else {
      secondSelectedIndex = index; // 두 번째 카드 선택
      Future.delayed(const Duration(milliseconds: 300), _checkMatch); // 매칭 검사 예약 (지연 시간 단축)
    }
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
          if (cards[a].id == cards[b].id) {
            // 사운드는 비동기로 처리
            Future.microtask(() {
              soundService.playMatchSound();
            });
            cards[a] = cards[a].copyWith(isMatched: true);
            cards[b] = cards[b].copyWith(isMatched: true);
            scoreModel.addMatchScore(); // 매칭 성공 시 점수 추가
            
            // 최고 연속 매칭 기록 업데이트
            if (scoreModel.currentCombo > maxCombo) {
              maxCombo = scoreModel.currentCombo;
            }
            
            _checkGameEnd();
          } else {
            // 사운드는 비동기로 처리
            Future.microtask(() {
              soundService.playMismatchSound();
            });
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
                  Text('현재 점수: ${scoreModel.score}점'),
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
        score: scoreModel.score,
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
      print('점수: ${scoreModel.score}');
      print('완료 여부: $isCompleted');

      // 온라인 게임 기록 저장
      await firebaseService.saveOnlineGameRecord(gameRecord);
      print('온라인 게임 기록 저장 완료');

      // 온라인 플레이어 통계 업데이트
      final onlineStats = await firebaseService.getOnlinePlayerStats();
      if (onlineStats != null) {
        final updatedStats = onlineStats.updateWithGameResult(
          score: scoreModel.score,
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
          bestScore: scoreModel.score,
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
            content: Text('새로운 기록이 저장되었습니다! (${scoreModel.score}점)'),
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
    
    soundService.playButtonClickSound(); // 게임 시작 사운드
    
    // 기존 타이머 정리
    if (gameTimer?.isActive == true) {
      gameTimer?.cancel();
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
    soundService.playBackgroundMusic(); // 배경음악 시작
  }

  /// 게임 일시정지
  void _pauseGame() {
    if (!isGameRunning || isTimerPaused) return;
    setState(() => isTimerPaused = true);
    soundService.pauseBackgroundMusic(); // 배경음악 일시정지
  }

  /// 게임 리셋(카드, 시간, 상태 초기화)
  void _resetGame() {
    soundService.playButtonClickSound();
    
    // 기존 타이머 정리
    if (gameTimer?.isActive == true) {
      gameTimer?.cancel();
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
    gameTimer?.cancel();
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
              Text('현재 점수: ${scoreModel.score}점'),
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
                        '점수: ${scoreModel.score}',
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
                              isEnabled: isGameRunning && !isTimerPaused,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 하단 버튼 영역
              Container(
                height: controlHeight,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!isGameRunning)
                      ElevatedButton(
                        onPressed: () {
                          soundService.playButtonClickSound();
                          _startGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('시작'),
                      ),
                    if (isGameRunning)
                      ElevatedButton(
                        onPressed: _resetGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('다시 시작'),
                      ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('나가기'),
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