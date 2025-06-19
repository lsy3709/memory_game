import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/online_room.dart';
import 'online_room_creation_screen.dart';
import 'online_multiplayer_game_screen.dart';

/// 온라인 멀티플레이어 방 목록 화면
class OnlineRoomListScreen extends StatefulWidget {
  const OnlineRoomListScreen({super.key});

  @override
  _OnlineRoomListScreenState createState() => _OnlineRoomListScreenState();
}

class _OnlineRoomListScreenState extends State<OnlineRoomListScreen> {
  final FirebaseService _firebaseService = FirebaseService.instance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 멀티플레이어'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
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
        child: Column(
          children: [
            // 헤더 섹션
            _buildHeaderSection(),
            
            // 방 목록
            Expanded(
              child: _buildRoomList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const OnlineRoomCreationScreen(),
            ),
          );
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('방 만들기'),
      ),
    );
  }

  /// 헤더 섹션 위젯
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(
            Icons.people,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          const Text(
            '온라인 멀티플레이어',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '다른 플레이어와 실시간으로 대결하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          
          // 오류 메시지
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// 방 목록 위젯
  Widget _buildRoomList() {
    return StreamBuilder<List<OnlineRoom>>(
      stream: _firebaseService.getOnlineRooms(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('방 목록을 불러오는 중 오류가 발생했습니다.');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        final rooms = snapshot.data ?? [];

        if (rooms.isEmpty) {
          return _buildEmptyWidget();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return _buildRoomCard(room);
          },
        );
      },
    );
  }

  /// 방 카드 위젯
  Widget _buildRoomCard(OnlineRoom room) {
    final isMyRoom = room.isHost(_firebaseService.currentUser?.uid ?? '');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMyRoom 
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isMyRoom ? Colors.green : Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isMyRoom ? Icons.person : Icons.people,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                room.roomName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isMyRoom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '내 방',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('방장: ${room.hostName}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('생성: ${_formatTimeAgo(room.createdAt)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('참가자: ${room.isFull ? "2/2" : "1/2"}'),
              ],
            ),
            if (room.isPrivate) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text('비공개 방', style: TextStyle(color: Colors.orange)),
                ],
              ),
            ],
          ],
        ),
        trailing: _buildRoomActions(room),
      ),
    );
  }

  /// 방 액션 버튼 위젯
  Widget _buildRoomActions(OnlineRoom room) {
    final isMyRoom = room.isHost(_firebaseService.currentUser?.uid ?? '');
    
    if (isMyRoom) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: room.isFull ? () => _startGame(room) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('게임 시작'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _showRoomOptions(room),
            child: const Text('방 관리'),
          ),
        ],
      );
    } else {
      return ElevatedButton(
        onPressed: room.canJoin ? () => _joinRoom(room) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: room.canJoin ? Colors.blue : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(room.canJoin ? '참가하기' : '가득참'),
      );
    }
  }

  /// 빈 목록 위젯
  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.meeting_room,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            '현재 대기 중인 방이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '첫 번째 방을 만들어보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OnlineRoomCreationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('방 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 방 참가
  Future<void> _joinRoom(OnlineRoom room) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updatedRoom = await _firebaseService.joinOnlineRoom(room.id);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnlineMultiplayerGameScreen(
              room: updatedRoom,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '방 참가에 실패했습니다: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 게임 시작
  Future<void> _startGame(OnlineRoom room) async {
    try {
      await _firebaseService.updateRoomStatus(room.id, RoomStatus.playing);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnlineMultiplayerGameScreen(
              room: room,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '게임 시작에 실패했습니다: ${e.toString()}';
      });
    }
  }

  /// 방 관리 옵션 표시
  void _showRoomOptions(OnlineRoom room) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('방 정보 수정'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 방 정보 수정 화면으로 이동
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('친구 초대'),
              onTap: () {
                Navigator.pop(context);
                _showFriendInviteDialog(room);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('방 삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteRoomDialog(room);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 친구 초대 다이얼로그
  void _showFriendInviteDialog(OnlineRoom room) {
    // TODO: 친구 목록에서 선택하여 초대하는 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('친구 초대 기능은 추후 업데이트 예정입니다.'),
      ),
    );
  }

  /// 방 삭제 확인 다이얼로그
  void _showDeleteRoomDialog(OnlineRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방 삭제'),
        content: const Text('정말로 이 방을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firebaseService.leaveOnlineRoom(room.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('방이 삭제되었습니다.')),
                  );
                }
              } catch (e) {
                setState(() {
                  _errorMessage = '방 삭제에 실패했습니다: ${e.toString()}';
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 시간 포맷팅 (몇 분 전, 몇 시간 전 등)
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