import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/player_stats.dart';
import '../models/online_room.dart';
import 'online_multiplayer_game_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';

/// 온라인 게임 메인 화면
class OnlineMainScreen extends StatefulWidget {
  const OnlineMainScreen({super.key});

  @override
  _OnlineMainScreenState createState() => _OnlineMainScreenState();
}

class _OnlineMainScreenState extends State<OnlineMainScreen> {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final SoundService _soundService = SoundService.instance;
  final StorageService _storageService = StorageService.instance;
  String _playerName = '';
  String _email = '';
  bool _isLoading = true;
  PlayerStats? _playerStats;
  List<Map<String, dynamic>> _gameInvites = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _setupGameInviteListener();
  }

  /// 사용자 정보 로드
  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firebase 서비스를 통해 사용자 정보 가져오기
        Map<String, dynamic>? userData;
        try {
          userData = await _firebaseService.getUserData(user.uid);
        } catch (e) {
          print('사용자 데이터 로드 오류: $e');
          // 오류가 발생해도 기본값 사용
        }
        
        setState(() {
          if (userData != null && userData['playerName'] != null) {
            _playerName = userData['playerName'];
          } else {
            _playerName = user.displayName ?? '플레이어';
          }
          _email = userData?['email'] ?? user.email ?? '';
        });
        
        print('로드된 플레이어 이름: $_playerName');
        print('로드된 이메일: $_email');
        
        // 플레이어 이름이 기본값이면 설정 화면으로 이동
        if (_playerName == '플레이어' && mounted) {
          print('플레이어 이름이 기본값입니다. 설정 화면으로 이동합니다.');
          // 잠시 후 설정 화면으로 이동 (UI가 완전히 로드된 후)
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/online-player-name-setup');
            }
          });
          return;
        }
        
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
      final stats = await _firebaseService.getOnlinePlayerStats();
      setState(() {
        _playerStats = stats;
      });
    } catch (e) {
      print('플레이어 통계 로드 오류: $e');
    }
  }

  /// 로그아웃
  Future<void> _signOut() async {
    try {
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/main',
          (route) => false,
        );
      }
    } catch (e) {
      print('로그아웃 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃에 실패했습니다: $e')),
        );
      }
    }
  }

  /// 게임 초대 리스너 설정
  void _setupGameInviteListener() {
    _firebaseService.getReceivedGameInvites().listen((invites) {
      setState(() {
        _gameInvites = invites;
      });
      
      // 새로운 초대가 있으면 알림 표시
      if (invites.isNotEmpty && mounted) {
        _showGameInviteNotification(invites.first);
      }
    });
  }

  /// 게임 초대 알림 표시
  void _showGameInviteNotification(Map<String, dynamic> invite) {
    final fromUserName = invite['fromUserName'] ?? '플레이어';
    final roomId = invite['roomId'] ?? '';
    final inviteId = invite['id'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게임 초대'),
        content: Text('$fromUserName님이 게임에 초대했습니다!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectGameInvite(inviteId);
            },
            child: const Text('거부'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptGameInvite(inviteId, roomId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }

  /// 게임 초대 수락
  Future<void> _acceptGameInvite(String inviteId, String roomId) async {
    try {
      await _firebaseService.acceptGameInvite(inviteId);
      
      // 방에 참가
      final room = await _firebaseService.joinOnlineRoom(roomId);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineMultiplayerGameScreen(room: room),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게임 참가에 실패했습니다: $e')),
        );
      }
    }
  }

  /// 게임 초대 거부
  Future<void> _rejectGameInvite(String inviteId) async {
    try {
      await _firebaseService.rejectGameInvite(inviteId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 거부에 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 게임'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: '로그아웃',
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 사용자 정보 섹션
                _buildUserInfoSection(),

                const SizedBox(height: 40),

                // 메인 메뉴 버튼들
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // 온라인 멀티플레이어 게임 시작 버튼
                      _buildMenuButton(
                        icon: Icons.people,
                        title: '온라인 멀티플레이어',
                        subtitle: '실시간 멀티플레이어 게임',
                        color: Colors.orange,
                        onTap: () => Navigator.of(context).pushNamed('/online-room-list'),
                      ),
                      const SizedBox(height: 20),

                      // 친구 관리 버튼
                      _buildMenuButton(
                        icon: Icons.people_outline,
                        title: '친구 관리',
                        subtitle: '친구 추가, 요청 관리, 게임 초대',
                        color: Colors.pink,
                        onTap: () => Navigator.of(context).pushNamed('/friend-management'),
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

                // 플레이어 통계 섹션
                if (_playerStats != null) _buildPlayerStatsSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 사용자 정보 섹션 위젯
  Widget _buildUserInfoSection() {
    return Container(
      margin: const EdgeInsets.all(24.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue,
            child: Text(
              _playerName.isNotEmpty ? _playerName[0].toUpperCase() : 'P',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 사용자 이름
          Text(
            _playerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),

          // 이메일
          Text(
            _email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),

          // 레벨과 스코어 정보
          if (_playerStats != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 레벨 정보
                  Column(
                    children: [
                      Text(
                        '레벨',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_playerStats!.level ?? 1}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.blue.shade200,
                  ),
                  // 최고 점수 정보
                  Column(
                    children: [
                      Text(
                        '최고 점수',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_playerStats!.bestScore}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 플레이어 이름 설정 버튼 (기본값인 경우)
          if (_playerName == '플레이어') ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/online-player-name-setup');
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('플레이어 이름 설정'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ],
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  /// 플레이어 통계 섹션 위젯
  Widget _buildPlayerStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 통계',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.games,
                  label: '총 게임',
                  value: '${_playerStats!.totalGames}',
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.emoji_events,
                  label: '승리',
                  value: '${_playerStats!.totalWins}',
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.star,
                  label: '최고 점수',
                  value: '${_playerStats!.bestScore}',
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.flash_on,
                  label: '최고 콤보',
                  value: '${_playerStats!.maxCombo}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 통계 아이템 위젯
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
} 