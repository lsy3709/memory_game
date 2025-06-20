import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/online_room.dart';
import '../models/friend.dart';
import 'online_multiplayer_game_screen.dart';

/// 온라인 방 생성 화면
class OnlineRoomCreationScreen extends StatefulWidget {
  const OnlineRoomCreationScreen({super.key});

  @override
  _OnlineRoomCreationScreenState createState() => _OnlineRoomCreationScreenState();
}

class _OnlineRoomCreationScreenState extends State<OnlineRoomCreationScreen> {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final _roomNameController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  List<Friend> _friends = [];
  Friend? _selectedFriend;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  /// 친구 목록 로드
  Future<void> _loadFriends() async {
    try {
      final friendsStream = _firebaseService.getFriendsList();
      friendsStream.listen((friends) {
        setState(() {
          _friends = friends;
        });
      });
    } catch (e) {
      print('친구 목록 로드 오류: $e');
    }
  }

  /// 방 생성
  Future<void> _createRoom() async {
    if (_roomNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '방 이름을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final room = await _firebaseService.createOnlineRoom(
        roomName: _roomNameController.text.trim(),
        inviteEmail: _inviteEmailController.text.trim().isNotEmpty 
            ? _inviteEmailController.text.trim() 
            : null,
      );

      if (mounted) {
        setState(() {
          _successMessage = '방이 생성되었습니다!';
        });

        // 잠시 후 게임 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OnlineMultiplayerGameScreen(room: room),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '방 생성에 실패했습니다: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 방 생성'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 메시지 표시 영역
                if (_errorMessage != null || _successMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _errorMessage != null ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _errorMessage != null ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      _errorMessage ?? _successMessage ?? '',
                      style: TextStyle(
                        color: _errorMessage != null ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 방 이름 입력
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '방 이름',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _roomNameController,
                          decoration: const InputDecoration(
                            hintText: '방 이름을 입력하세요',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 친구 초대 섹션
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '친구 초대',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // 친구 목록
                        if (_friends.isNotEmpty) ...[
                          const Text(
                            '친구 목록에서 선택:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              itemCount: _friends.length,
                              itemBuilder: (context, index) {
                                final friend = _friends[index];
                                final isSelected = _selectedFriend?.id == friend.id;
                                
                                return ListTile(
                                  title: Text(friend.getOtherUserName(_firebaseService.currentUser?.uid ?? '')),
                                  subtitle: Text(friend.getOtherUserEmail(_firebaseService.currentUser?.uid ?? '')),
                                  leading: CircleAvatar(
                                    child: Text(
                                      friend.getOtherUserName(_firebaseService.currentUser?.uid ?? '').isNotEmpty 
                                          ? friend.getOtherUserName(_firebaseService.currentUser?.uid ?? '')[0]
                                          : '?',
                                    ),
                                  ),
                                  trailing: isSelected 
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedFriend = isSelected ? null : friend;
                                      _inviteEmailController.text = friend.getOtherUserEmail(_firebaseService.currentUser?.uid ?? '');
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 또는 이메일 직접 입력
                        const Text(
                          '또는 이메일 직접 입력:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _inviteEmailController,
                          decoration: const InputDecoration(
                            hintText: '초대할 친구의 이메일을 입력하세요',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            // 이메일 입력 시 선택된 친구 해제
                            if (_selectedFriend != null) {
                              setState(() {
                                _selectedFriend = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 방 생성 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _createRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '방 생성하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),

                const SizedBox(height: 16),

                // 친구 추가 링크
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/friend-management');
                  },
                  child: const Text(
                    '친구가 없나요? 친구 추가하기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 