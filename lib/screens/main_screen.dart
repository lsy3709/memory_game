import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../models/player_stats.dart';

/// 메인 화면
/// 게임 시작, 랭킹 보드, 설정 등의 메뉴를 제공
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final StorageService _storageService = StorageService();
  
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
    Navigator.of(context).pushNamed('/game');
  }

  /// 랭킹 보드 열기
  void _openRanking() {
    Navigator.of(context).pushNamed('/ranking');
  }

  /// 설정 화면 열기
  void _openSettings() {
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
                Navigator.of(context).pop();
                _showAccountDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('데이터 초기화'),
              onTap: () {
                Navigator.of(context).pop();
                _showResetDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('앱 정보'),
              onTap: () {
                Navigator.of(context).pop();
                _showAppInfo();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
            Text('• 최고 점수, 최단 시간, 최고 콤보 기록'),
            Text('• 랭킹 보드 시스템'),
            Text('• 사운드 효과 및 배경음악'),
            Text('• 로컬 데이터 저장'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
          child: Column(
            children: [
              // 상단 영역
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 앱 제목
                    const Column(
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 게임 시작 버튼
                      _buildMenuButton(
                        icon: Icons.play_arrow,
                        title: '게임 시작',
                        subtitle: '메모리 카드 게임을 시작합니다',
                        color: Colors.green,
                        onTap: _startGame,
                      ),
                      const SizedBox(height: 20),

                      // 랭킹 보드 버튼
                      _buildMenuButton(
                        icon: Icons.leaderboard,
                        title: '랭킹 보드',
                        subtitle: '최고 기록들을 확인합니다',
                        color: Colors.orange,
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
                          onTap: () => Navigator.of(context).pushNamed('/register'),
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
              ),

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
    );
  }

  /// 메뉴 버튼 위젯 생성
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.9),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// 통계 아이템 위젯 생성
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
} 