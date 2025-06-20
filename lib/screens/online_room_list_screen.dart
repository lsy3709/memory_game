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
  List<Map<String, dynamic>> _gameInvites = [];

  @override
  void initState() {
    super.initState();
    _loadGameInvites();
  }

  /// 게임 초대 목록 로드
  void _loadGameInvites() {
    _firebaseService.getReceivedGameInvites().listen((invites) {
      setState(() {
        _gameInvites = invites;
      });
    });
  }

  /// 초대받은 방인지 확인
  bool _isInvitedToRoom(OnlineRoom room) {
    return _gameInvites.any((invite) => invite['roomId'] == room.id);
  }

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
              _refreshRooms();
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
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              '방 목록을 불러오는 중...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

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
    final currentUserId = _firebaseService.currentUser?.uid ?? '';
    final isMyRoom = room.isHost(currentUserId);
    final isInvited = _isInvitedToRoom(room);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMyRoom 
            ? BorderSide(color: Colors.green, width: 2)
            : isInvited
                ? BorderSide(color: Colors.orange, width: 2)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 행 (방 이름과 내 방 표시)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Row(
                  children: [
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
                    if (isInvited)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '초대받음',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 방 정보
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '방장: ${room.hostName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '생성: ${_formatTimeAgo(room.createdAt)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '참가자: ${room.isFull ? "2/2" : "1/2"}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            if (room.isPrivate) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text(
                    '비공개 방',
                    style: TextStyle(color: Colors.orange, fontSize: 14),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 액션 버튼들
            _buildRoomActions(room),
          ],
        ),
      ),
    );
  }

  /// 방 액션 버튼 위젯
  Widget _buildRoomActions(OnlineRoom room) {
    final currentUserId = _firebaseService.currentUser?.uid ?? '';
    final isMyRoom = room.isHost(currentUserId);
    final isInvited = _isInvitedToRoom(room);

    if (isMyRoom) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (room.isFull)
            ElevatedButton(
              onPressed: () => _startGame(room),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(80, 36),
              ),
              child: const Text('게임 시작'),
            ),
          if (room.isFull) const SizedBox(width: 8),
          TextButton(
            onPressed: () => _showRoomOptions(room),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
            child: Text(room.isFull ? '방 관리' : '방 삭제'),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: (room.canJoin || isInvited) ? () => _joinRoom(room) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: (room.canJoin || isInvited) ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
            child: Text(
              isInvited ? '초대받음' : (room.canJoin ? '참가하기' : '가득참'),
            ),
          ),
        ],
      );
    }
  }

  /// 방 참가
  Future<void> _joinRoom(OnlineRoom room) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 초대받은 방인지 확인하고 초대 정보 삭제
      final invite = _gameInvites.firstWhere(
        (invite) => invite['roomId'] == room.id,
        orElse: () => <String, dynamic>{},
      );
      
      if (invite.isNotEmpty) {
        try {
          await _firebaseService.acceptGameInvite(invite['id']);
        } catch (e) {
          print('초대 수락 오류: $e');
          // 초대 수락 실패해도 방 참가는 계속 진행
        }
      }

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
      String userFriendlyMessage = '방 참가에 실패했습니다.';
      
      // 구체적인 오류 상황에 맞는 메시지 제공
      if (e.toString().contains('Firebase가 초기화되지 않았습니다')) {
        userFriendlyMessage = '네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('로그인이 필요합니다')) {
        userFriendlyMessage = '로그인이 필요합니다. 다시 로그인해주세요.';
      } else if (e.toString().contains('방을 찾을 수 없습니다')) {
        userFriendlyMessage = '방이 이미 삭제되었습니다.';
      } else if (e.toString().contains('방에 참가할 수 없습니다')) {
        userFriendlyMessage = '방이 가득 찼습니다.';
      } else if (e.toString().contains('네트워크')) {
        userFriendlyMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
      }
      
      setState(() {
        _errorMessage = userFriendlyMessage;
      });
      
      print('방 참가 오류 상세: $e');
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
    final isMyRoom = room.isHost(_firebaseService.currentUser?.uid ?? '');
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyRoom) ...[
              if (room.isFull)
                ListTile(
                  leading: const Icon(Icons.play_arrow, color: Colors.green),
                  title: const Text('게임 시작'),
                  onTap: () {
                    Navigator.pop(context);
                    _startGame(room);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('방 정보 수정'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 방 정보 수정 화면으로 이동
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('방 정보 수정 기능은 추후 업데이트 예정입니다.')),
                  );
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
            ] else ...[
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('방 정보'),
                onTap: () {
                  Navigator.pop(context);
                  _showRoomInfoDialog(room);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 방 정보 다이얼로그
  void _showRoomInfoDialog(OnlineRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(room.roomName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('방장: ${room.hostName}'),
            const SizedBox(height: 8),
            Text('생성: ${_formatTimeAgo(room.createdAt)}'),
            const SizedBox(height: 8),
            Text('참가자: ${room.isFull ? "2/2" : "1/2"}'),
            if (room.isPrivate) ...[
              const SizedBox(height: 8),
              const Text('비공개 방', style: TextStyle(color: Colors.orange)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말로 이 방을 삭제하시겠습니까?'),
            const SizedBox(height: 8),
            if (room.isFull)
              const Text(
                '⚠️ 다른 플레이어가 참가 중입니다.\n방을 삭제하면 게임이 강제 종료됩니다.',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              
              try {
                await _firebaseService.leaveOnlineRoom(room.id);
                
                if (mounted && context.mounted) {
                  if (ScaffoldMessenger.of(context).mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('방이 삭제되었습니다.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  
                  setState(() {});
                }
              } catch (e) {
                String userFriendlyMessage = '방 삭제에 실패했습니다.';
                
                if (e.toString().contains('Firebase가 초기화되지 않았습니다')) {
                  userFriendlyMessage = '네트워크 연결을 확인해주세요.';
                } else if (e.toString().contains('로그인이 필요합니다')) {
                  userFriendlyMessage = '로그인이 필요합니다. 다시 로그인해주세요.';
                } else if (e.toString().contains('방을 찾을 수 없습니다')) {
                  userFriendlyMessage = '방이 이미 삭제되었습니다.';
                } else if (e.toString().contains('권한')) {
                  userFriendlyMessage = '방을 삭제할 권한이 없습니다.';
                } else if (e.toString().contains('네트워크')) {
                  userFriendlyMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
                }
                
                if (mounted && context.mounted) {
                  setState(() {
                    _errorMessage = userFriendlyMessage;
                  });
                }
                
                print('방 삭제 오류 상세: $e');
              } finally {
                if (mounted && context.mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
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

  /// 방 목록 새로고침
  Future<void> _refreshRooms() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // StreamBuilder가 자동으로 새로고침되므로 잠시 대기 후 로딩 상태 해제
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted && context.mounted) {
        setState(() {
          _errorMessage = '방 목록을 불러오는데 실패했습니다.';
        });
      }
      print('방 목록 새로고침 오류: $e');
    } finally {
      if (mounted && context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 에러 위젯
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
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
            onPressed: _refreshRooms,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            '생성된 방이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '새로운 방을 만들어보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/online-room-creation');
            },
            icon: const Icon(Icons.add),
            label: const Text('방 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
} 