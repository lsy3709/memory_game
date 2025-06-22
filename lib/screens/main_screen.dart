import 'package:flutter/material.dart';
import 'dart:io';

import '../services/storage_service.dart';
import '../models/player_stats.dart';
import '../services/firebase_service.dart';
import '../services/sound_service.dart';
import '../screens/game_screen.dart';

/// 메인 화면
/// 게임 시작, 랭킹 보드, 설정 등의 메뉴를 제공
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final SoundService _soundService = SoundService.instance;
  final StorageService _storageService = StorageService.instance;
  
  PlayerStats? _playerStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayerStats();
  }

  /// 플레이어 통계 로드
  Future<void> _loadPlayerStats() async {
    try {
      final stats = await _storageService.loadPlayerStats();
      setState(() {
        _playerStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('플레이어 통계 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 게임 시작
  void _startGame() {
    _soundService.playButtonClickSound();
    if (_playerStats != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(playerName: _playerStats!.playerName),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('플레이어 정보를 불러오는 중입니다...')),
      );
    }
  }

  /// 멀티플레이어 게임 시작
  void _startMultiplayerGame() {
    _soundService.playButtonClickSound();
    Navigator.of(context).pushNamed('/multiplayer_setup');
  }

  /// 온라인 게임 시작
  void _startOnlineGame() async {
    _soundService.playButtonClickSound();
    try {
      // Firebase 초기화 확인
      final isInitialized = await _firebaseService.ensureInitialized();
      
      if (!isInitialized) {
        _showFirebaseErrorDialog();
        return;
      }

      // 로그인 상태 확인
      final currentUser = _firebaseService.currentUser;
      if (currentUser != null) {
        Navigator.of(context).pushNamed('/online-main');
      } else {
        Navigator.of(context).pushNamed('/online-login');
      }
    } catch (e) {
      print('온라인 게임 시작 오류: $e');
      _showFirebaseErrorDialog();
    }
  }

  /// Firebase 상태 확인
  Future<void> _checkFirebaseStatus() async {
    try {
      final isInitialized = await _firebaseService.ensureInitialized();
      print('Firebase 초기화 상태: $isInitialized');
      
      // 이미 로그인되어 있는지 확인
      if (_firebaseService.currentUser != null) {
        print('이미 로그인된 사용자: ${_firebaseService.currentUser?.email}');
      }
    } catch (e) {
      print('Firebase 상태 확인 중 오류: $e');
    }
  }

  /// Firebase 설정 파일 상태 확인
  Future<void> _checkFirebaseConfigFiles() async {
    try {
      print('=== Firebase 설정 파일 확인 ===');
      
      final firebaseOptionsExists = await _checkFileExists('lib/firebase_options.dart');
      final androidConfigExists = await _checkFileExists('android/app/google-services.json');
      final iosConfigExists = await _checkFileExists('ios/Runner/GoogleService-Info.plist');
      
      print('Firebase Options 파일: ${firebaseOptionsExists ? '있음' : '없음'}');
      print('Android 설정 파일: ${androidConfigExists ? '있음' : '없음'}');
      print('iOS 설정 파일: ${iosConfigExists ? '있음' : '없음'}');
      
      if (!firebaseOptionsExists) {
        print('❌ 누락: lib/firebase_options.dart');
        print('   해결: flutterfire configure 실행');
      }
      
      if (!androidConfigExists) {
        print('❌ 누락: android/app/google-services.json');
        print('   해결: Firebase Console에서 Android 앱 등록');
      }
      
      if (!iosConfigExists) {
        print('❌ 누락: ios/Runner/GoogleService-Info.plist');
        print('   해결: Firebase Console에서 iOS 앱 등록');
      }
      
      final allFilesExist = firebaseOptionsExists && androidConfigExists && iosConfigExists;
      print('설정 완료 상태: ${allFilesExist ? '✅ 완료' : '❌ 미완료'}');
      print('=== Firebase 설정 파일 확인 완료 ===');
    } catch (e) {
      print('설정 파일 확인 오류: $e');
    }
  }

  /// 파일 존재 여부 확인
  Future<bool> _checkFileExists(String path) async {
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 랭킹 보드 열기
  void _openRanking() {
    _soundService.playButtonClickSound();
    Navigator.of(context).pushNamed('/ranking');
  }

  /// 설정 화면 열기
  void _openSettings() {
    _soundService.playButtonClickSound();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('계정 관리'),
              onTap: () {
                _soundService.playButtonClickSound();
                Navigator.of(context).pop();
                _showAccountDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('Firebase 상태 확인'),
              onTap: () {
                _soundService.playButtonClickSound();
                Navigator.of(context).pop();
                _checkFirebaseStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Firebase 설정 가이드'),
              onTap: () {
                _soundService.playButtonClickSound();
                Navigator.of(context).pop();
                _showFirebaseSetupGuide();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('데이터 초기화'),
              onTap: () {
                _soundService.playButtonClickSound();
                Navigator.of(context).pop();
                _showResetDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('앱 정보'),
              onTap: () {
                _soundService.playButtonClickSound();
                Navigator.of(context).pop();
                _showAppInfo();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _soundService.playButtonClickSound();
              Navigator.of(context).pop();
            },
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 계정 관리 다이얼로그
  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 관리'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_playerStats != null) ...[
              Text('플레이어: ${_playerStats!.playerName}'),
              Text('이메일: ${_playerStats!.email}'),
              const SizedBox(height: 16),
              Text('총 게임 수: ${_playerStats!.totalGames}'),
              Text('승리 수: ${_playerStats!.totalWins}'),
              Text('승률: ${_playerStats!.winRate.toStringAsFixed(1)}%'),
              Text('최고 점수: ${_playerStats!.bestScore}'),
              Text('최단 시간: ${_playerStats!.formattedBestTime}'),
              Text('최고 콤보: ${_playerStats!.maxCombo}'),
            ] else ...[
              const Text('등록된 계정이 없습니다.'),
            ],
          ],
        ),
        actions: [
          if (_playerStats != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text('로그아웃'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 데이터 초기화 다이얼로그
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text(
          '모든 게임 기록과 계정 정보가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.\n정말로 초기화하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  /// 앱 정보 다이얼로그
  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 정보'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('메모리 카드 게임'),
            SizedBox(height: 8),
            Text('버전: 1.0.0'),
            Text('개발자: Memory Game Team'),
            SizedBox(height: 16),
            Text('특징:'),
            Text('• 48장의 카드로 구성된 메모리 게임'),
            Text('• 싱글플레이어 및 멀티플레이어 모드'),
            Text('• 최고 점수, 최단 시간, 최고 콤보 기록'),
            Text('• 랭킹 보드 시스템'),
            Text('• 사운드 효과 및 배경음악'),
            Text('• 로컬 데이터 저장'),
            SizedBox(height: 16),
            Text('온라인 기능:'),
            Text('• Firebase 설정이 완료되면 온라인 모드 사용 가능'),
            Text('• 전 세계 플레이어와 랭킹 경쟁'),
            Text('• 온라인 멀티플레이어 게임'),
            Text('• 클라우드 데이터 저장'),
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

  /// 로그아웃
  Future<void> _logout() async {
    try {
      await _storageService.clearPlayerStats();
      setState(() => _playerStats = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }

  /// 데이터 초기화
  Future<void> _resetData() async {
    try {
      await _storageService.clearAllGameRecords();
      await _storageService.clearPlayerStats();
      setState(() => _playerStats = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 데이터가 초기화되었습니다.')),
      );
    } catch (e) {
      print('데이터 초기화 오류: $e');
    }
  }

  /// Firebase 오류 다이얼로그 표시
  void _showFirebaseErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('온라인 모드 사용 불가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('온라인 모드를 사용할 수 없습니다.'),
            const SizedBox(height: 8),
            const Text('가능한 원인:'),
            const Text('• Firebase 설정이 완료되지 않음'),
            const Text('• 네트워크 연결 문제'),
            const Text('• Firebase 프로젝트 설정 오류'),
            const SizedBox(height: 8),
            const Text('로컬 모드로 게임을 즐기실 수 있습니다.'),
            const SizedBox(height: 16),
            const Text('설정 > Firebase 상태 확인에서 자세한 정보를 확인할 수 있습니다.'),
            const SizedBox(height: 8),
            const Text('설정 > Firebase 설정 가이드에서 설정 방법을 확인할 수 있습니다.'),
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

  /// Firebase 상태 다이얼로그 표시
  void _showFirebaseStatusDialog(bool isInitialized, dynamic currentUser) async {
    // 설정 파일 상태 확인
    final firebaseOptionsExists = await _checkFileExists('lib/firebase_options.dart');
    final androidConfigExists = await _checkFileExists('android/app/google-services.json');
    final iosConfigExists = await _checkFileExists('ios/Runner/GoogleService-Info.plist');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase 상태'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('초기화 상태: ${isInitialized ? '성공' : '실패'}'),
            Text('사용 가능: ${_firebaseService.isFirebaseAvailable ? '예' : '아니오'}'),
            Text('온라인 상태: ${_firebaseService.currentUser != null ? '로그인됨' : '로그인 안됨'}'),
            if (_firebaseService.currentUser != null) Text('사용자: ${_firebaseService.currentUser?.email}'),
            const SizedBox(height: 16),
            const Text('설정 파일 상태:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Firebase Options: ${firebaseOptionsExists ? '✅' : '❌'}'),
            Text('• Android Config: ${androidConfigExists ? '✅' : '❌'}'),
            Text('• iOS Config: ${iosConfigExists ? '✅' : '❌'}'),
            const SizedBox(height: 16),
            const Text('콘솔에서 자세한 정보를 확인할 수 있습니다.'),
            if (!firebaseOptionsExists || !androidConfigExists || !iosConfigExists) ...[
              const SizedBox(height: 8),
              const Text('설정 > Firebase 설정 가이드에서 설정 방법을 확인하세요.'),
            ],
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

  /// Firebase 설정 가이드 표시
  void _showFirebaseSetupGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase 설정 가이드'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('온라인 기능을 사용하려면 Firebase 설정을 완료해야 합니다.'),
              SizedBox(height: 16),
              Text('1. Firebase 프로젝트 생성:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('   • https://console.firebase.google.com 접속'),
              Text('   • "프로젝트 만들기" 클릭'),
              Text('   • 프로젝트 이름 입력 (예: memory-game)'),
              Text('   • Google Analytics 활성화 (선택사항)'),
              SizedBox(height: 8),
              Text('2. Authentication 설정:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('   • 왼쪽 메뉴에서 "Authentication" 선택'),
              Text('   • "시작하기" 클릭'),
              Text('   • "이메일/비밀번호" 제공업체 활성화'),
              SizedBox(height: 8),
              Text('3. Firestore Database 설정:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('   • 왼쪽 메뉴에서 "Firestore Database" 선택'),
              Text('   • "데이터베이스 만들기" 클릭'),
              Text('   • "테스트 모드에서 시작" 선택'),
              SizedBox(height: 8),
              Text('4. FlutterFire CLI 설치:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('   • npm install -g firebase-tools'),
              Text('   • firebase login'),
              Text('   • dart pub global activate flutterfire_cli'),
              SizedBox(height: 8),
              Text('5. Firebase 설정 파일 생성:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('   • flutterfire configure'),
              Text('   • 프로젝트 선택'),
              Text('   • 플랫폼 선택 (Android, iOS)'),
              SizedBox(height: 8),
              Text('6. 앱 재시작:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('   • 설정 완료 후 앱을 재시작'),
              Text('   • 온라인 기능 사용 가능'),
              SizedBox(height: 16),
              Text('자세한 설정 방법은 README.md 파일을 참조하세요.'),
            ],
          ),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // 상단 영역
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 앱 제목
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '메모리 카드 게임',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Memory Card Game',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 설정 버튼
                          IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 플레이어 정보 카드
                    if (_playerStats != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '환영합니다, ${_playerStats!.playerName}님!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem('최고 점수', '${_playerStats!.bestScore}'),
                                _buildStatItem('최단 시간', _playerStats!.formattedBestTime),
                                _buildStatItem('최고 콤보', '${_playerStats!.maxCombo}'),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 40),

                    // 메인 메뉴 버튼들
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          // 싱글플레이어 게임 시작 버튼
                          _buildMenuButton(
                            icon: Icons.play_arrow,
                            title: '싱글플레이어',
                            subtitle: '혼자서 메모리 카드 게임을 즐깁니다',
                            color: Colors.green,
                            onTap: _startGame,
                          ),
                          const SizedBox(height: 20),

                          // 멀티플레이어 게임 시작 버튼
                          _buildMenuButton(
                            icon: Icons.people,
                            title: '멀티플레이어',
                            subtitle: '2명이서 함께하는 대결 게임',
                            color: Colors.orange,
                            onTap: _startMultiplayerGame,
                          ),
                          const SizedBox(height: 20),

                          // 온라인 게임 버튼
                          _buildMenuButton(
                            icon: Icons.wifi,
                            title: '온라인 게임',
                            subtitle: '전 세계 플레이어와 경쟁',
                            color: Colors.red,
                            onTap: _startOnlineGame,
                          ),
                          const SizedBox(height: 20),

                          // 랭킹 보드 버튼
                          _buildMenuButton(
                            icon: Icons.leaderboard,
                            title: '랭킹 보드',
                            subtitle: '최고 기록들을 확인합니다',
                            color: Colors.purple,
                            onTap: _openRanking,
                          ),
                          const SizedBox(height: 20),

                          // 계정 관리 버튼
                          if (_playerStats == null)
                            _buildMenuButton(
                              icon: Icons.person_add,
                              title: '계정 등록',
                              subtitle: '새로운 계정을 만듭니다',
                              color: Colors.blue,
                              onTap: () => Navigator.of(context).pushNamed('/player-registration'),
                            )
                          else
                            _buildMenuButton(
                              icon: Icons.login,
                              title: '다른 계정으로 로그인',
                              subtitle: '기존 계정으로 로그인합니다',
                              color: Colors.blue,
                              onTap: () => Navigator.of(context).pushNamed('/login'),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 하단 정보
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        '게임을 즐기고 최고 기록에 도전해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 메뉴 버튼 위젯
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 화살표 아이콘
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 통계 아이템 위젯
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
} 