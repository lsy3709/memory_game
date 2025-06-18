import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/player_stats.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 온라인 게임 메인 화면
class OnlineMainScreen extends StatefulWidget {
  const OnlineMainScreen({super.key});

  @override
  _OnlineMainScreenState createState() => _OnlineMainScreenState();
}

class _OnlineMainScreenState extends State<OnlineMainScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _playerName = '';
  String _email = '';
  bool _isLoading = true;
  PlayerStats? _playerStats;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 사용자 정보 로드
  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _playerName = user.displayName ?? '플레이어';
          _email = user.email ?? '';
        });
        
        // 플레이어 통계 로드
        await _loadPlayerStats();
      }
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 플레이어 통계 로드
  Future<void> _loadPlayerStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('player_stats')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          setState(() {
            _playerStats = PlayerStats.fromMap(doc.data()!);
          });
        }
      }
    } catch (e) {
      print('플레이어 통계 로드 오류: $e');
    }
  }

  /// 로그아웃 처리
  Future<void> _handleLogout() async {
    try {
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그아웃 오류: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            colors: [Colors.red, Colors.orange],
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
                                  '온라인 메모리 게임',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Online Memory Game',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 로그아웃 버튼
                          IconButton(
                            onPressed: _handleLogout,
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 플레이어 정보 카드
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else if (_playerStats != null)
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
                      )
                    else
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
                              '환영합니다, $_playerName님!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '온라인 게임을 시작하여 기록을 남겨보세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
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
                          // 온라인 싱글플레이어 게임 시작 버튼
                          _buildMenuButton(
                            icon: Icons.play_arrow,
                            title: '온라인 싱글플레이어',
                            subtitle: '온라인 랭킹에 기록되는 싱글 게임',
                            color: Colors.green,
                            onTap: () => Navigator.of(context).pushNamed('/online-game'),
                          ),
                          const SizedBox(height: 20),

                          // 온라인 멀티플레이어 게임 시작 버튼
                          _buildMenuButton(
                            icon: Icons.people,
                            title: '온라인 멀티플레이어',
                            subtitle: '온라인에서 다른 플레이어와 대결',
                            color: Colors.orange,
                            onTap: () => Navigator.of(context).pushNamed('/online-multiplayer-setup'),
                          ),
                          const SizedBox(height: 20),

                          // 온라인 랭킹 보드 버튼
                          _buildMenuButton(
                            icon: Icons.leaderboard,
                            title: '온라인 랭킹',
                            subtitle: '전 세계 플레이어들의 기록',
                            color: Colors.purple,
                            onTap: () => Navigator.of(context).pushNamed('/online-ranking'),
                          ),
                          const SizedBox(height: 20),

                          // 내 기록 보기 버튼
                          _buildMenuButton(
                            icon: Icons.history,
                            title: '내 기록',
                            subtitle: '나의 온라인 게임 기록',
                            color: Colors.blue,
                            onTap: () => Navigator.of(context).pushNamed('/online-my-records'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 하단 정보
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        '온라인에서 전 세계 플레이어들과 경쟁해보세요!',
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

  /// 게임 모드 카드 위젯
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