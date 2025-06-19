import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/friend.dart';
import 'online_room_list_screen.dart';

/// 친구 관리 화면
class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  _FriendManagementScreenState createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 관리'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '친구 목록'),
            Tab(text: '받은 요청'),
            Tab(text: '친구 추가'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Column(
          children: [
            // 메시지 표시 영역
            if (_errorMessage != null || _successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _errorMessage != null 
                      ? Colors.red.shade50 
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _errorMessage != null 
                        ? Colors.red.shade200 
                        : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  _errorMessage ?? _successMessage!,
                  style: TextStyle(
                    color: _errorMessage != null 
                        ? Colors.red.shade700 
                        : Colors.green.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsList(),
                  _buildReceivedRequests(),
                  _buildAddFriend(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 친구 목록 탭
  Widget _buildFriendsList() {
    return StreamBuilder<List<Friend>>(
      stream: _firebaseService.getFriendsList(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('친구 목록을 불러오는 중 오류가 발생했습니다.');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return _buildEmptyWidget(
            icon: Icons.people_outline,
            title: '친구가 없습니다',
            subtitle: '친구를 추가하여 함께 게임을 즐겨보세요!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _buildFriendCard(friend);
          },
        );
      },
    );
  }

  /// 받은 친구 요청 탭
  Widget _buildReceivedRequests() {
    return StreamBuilder<List<Friend>>(
      stream: _firebaseService.getReceivedFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('받은 요청을 불러오는 중 오류가 발생했습니다.');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildEmptyWidget(
            icon: Icons.mark_email_unread_outlined,
            title: '받은 친구 요청이 없습니다',
            subtitle: '다른 플레이어가 친구 요청을 보내면 여기에 표시됩니다.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildFriendRequestCard(request);
          },
        );
      },
    );
  }

  /// 친구 추가 탭
  Widget _buildAddFriend() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // 헤더
          const Icon(
            Icons.person_add,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            '친구 추가',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이메일 주소로 친구를 찾아 요청을 보내세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // 이메일 입력
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '친구의 이메일',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                      hintText: 'example@email.com',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendFriendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('친구 요청 보내기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 안내 정보
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '친구 추가 안내',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 친구의 정확한 이메일 주소를 입력해주세요\n'
                    '• 친구 요청을 보내면 상대방이 수락할 때까지 대기합니다\n'
                    '• 친구가 되면 게임 초대를 보낼 수 있습니다\n'
                    '• 친구 요청은 언제든지 취소할 수 있습니다',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 친구 카드 위젯
  Widget _buildFriendCard(Friend friend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            friend.getOtherUserName(_firebaseService.currentUser?.uid ?? '')[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          friend.getOtherUserName(_firebaseService.currentUser?.uid ?? ''),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friend.getOtherUserEmail(_firebaseService.currentUser?.uid ?? '')),
            if (friend.lastGameAt != null)
              Text(
                '마지막 게임: ${_formatTimeAgo(friend.lastGameAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleFriendAction(value, friend),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'invite',
              child: Row(
                children: [
                  Icon(Icons.games),
                  SizedBox(width: 8),
                  Text('게임 초대'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.red),
                  SizedBox(width: 8),
                  Text('친구 삭제', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 친구 요청 카드 위젯
  Widget _buildFriendRequestCard(Friend request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Text(
            request.getOtherUserName(_firebaseService.currentUser?.uid ?? '')[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          request.getOtherUserName(_firebaseService.currentUser?.uid ?? ''),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.getOtherUserEmail(_firebaseService.currentUser?.uid ?? '')),
            Text(
              '요청 시간: ${_formatTimeAgo(request.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _acceptFriendRequest(request.id),
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: '수락',
            ),
            IconButton(
              onPressed: () => _rejectFriendRequest(request.id),
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: '거부',
            ),
          ],
        ),
      ),
    );
  }

  /// 빈 목록 위젯
  Widget _buildEmptyWidget({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 오류 위젯
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 친구 요청 보내기
  Future<void> _sendFriendRequest() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _errorMessage = '이메일을 입력해주세요.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _firebaseService.sendFriendRequest(email);
      
      setState(() {
        _successMessage = '친구 요청을 보냈습니다.';
        _errorMessage = null;
        _emailController.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _successMessage = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 친구 요청 수락
  Future<void> _acceptFriendRequest(String friendId) async {
    try {
      await _firebaseService.acceptFriendRequest(friendId);
      setState(() {
        _successMessage = '친구 요청을 수락했습니다.';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '친구 요청 수락에 실패했습니다: $e';
        _successMessage = null;
      });
    }
  }

  /// 친구 요청 거부
  Future<void> _rejectFriendRequest(String friendId) async {
    try {
      await _firebaseService.rejectFriendRequest(friendId);
      setState(() {
        _successMessage = '친구 요청을 거부했습니다.';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '친구 요청 거부에 실패했습니다: $e';
        _successMessage = null;
      });
    }
  }

  /// 친구 액션 처리
  void _handleFriendAction(String action, Friend friend) {
    switch (action) {
      case 'invite':
        _inviteFriendToGame(friend);
        break;
      case 'remove':
        _showRemoveFriendDialog(friend);
        break;
    }
  }

  /// 친구에게 게임 초대
  void _inviteFriendToGame(Friend friend) {
    // TODO: 게임 초대 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${friend.getOtherUserName(_firebaseService.currentUser?.uid ?? '')}에게 게임 초대를 보냈습니다.'),
      ),
    );
  }

  /// 친구 삭제 확인 다이얼로그
  void _showRemoveFriendDialog(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('${friend.getOtherUserName(_firebaseService.currentUser?.uid ?? '')}을(를) 친구 목록에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 친구 삭제 기능 구현
              setState(() {
                _successMessage = '친구를 삭제했습니다.';
                _errorMessage = null;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 시간 포맷팅
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }
} 