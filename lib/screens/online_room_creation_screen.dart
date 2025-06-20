import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/online_room.dart';
import 'online_multiplayer_game_screen.dart';

/// 온라인 멀티플레이어 방 생성 화면
class OnlineRoomCreationScreen extends StatefulWidget {
  const OnlineRoomCreationScreen({super.key});

  @override
  _OnlineRoomCreationScreenState createState() => _OnlineRoomCreationScreenState();
}

class _OnlineRoomCreationScreenState extends State<OnlineRoomCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService.instance;

  bool _isPrivate = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _roomNameController.text = '${_getRandomRoomName()}의 방';
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방 만들기'),
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
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 헤더
                  _buildHeaderSection(),
                  const SizedBox(height: 32),

                  // 방 정보 입력
                  _buildRoomInfoSection(),
                  const SizedBox(height: 24),

                  // 비공개 설정
                  _buildPrivacySection(),
                  const SizedBox(height: 32),

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

                  // 방 만들기 버튼
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
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
                          : const Text(
                              '방 만들기',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 헤더 섹션 위젯
  Widget _buildHeaderSection() {
    return Column(
      children: [
        const Icon(
          Icons.add_circle,
          size: 64,
          color: Colors.white,
        ),
        const SizedBox(height: 16),
        const Text(
          '새로운 방 만들기',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          '다른 플레이어가 참가할 수 있는 방을 만드세요',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 방 정보 입력 섹션 위젯
  Widget _buildRoomInfoSection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '방 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: '방 이름',
                prefixIcon: Icon(Icons.meeting_room),
                border: OutlineInputBorder(),
                hintText: '예: 메모리 게임 대결방',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '방 이름을 입력해주세요.';
                }
                if (value.trim().length < 2) {
                  return '방 이름은 2자 이상이어야 합니다.';
                }
                if (value.trim().length > 20) {
                  return '방 이름은 20자 이하여야 합니다.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '방 이름은 다른 플레이어들이 방을 찾을 때 표시됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 비공개 설정 섹션 위젯
  Widget _buildPrivacySection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '방 설정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            
            // 비공개 방 설정
            SwitchListTile(
              title: const Text('비공개 방'),
              subtitle: const Text('비밀번호가 있는 방으로 설정'),
              value: _isPrivate,
              onChanged: (value) {
                setState(() {
                  _isPrivate = value;
                  if (!value) {
                    _passwordController.clear();
                  }
                });
              },
              secondary: Icon(
                _isPrivate ? Icons.lock : Icons.lock_open,
                color: _isPrivate ? Colors.orange : Colors.grey,
              ),
            ),
            
            // 비밀번호 입력 (비공개 방인 경우)
            if (_isPrivate) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: Icon(Icons.vpn_key),
                  border: OutlineInputBorder(),
                  hintText: '4-8자리 비밀번호',
                ),
                validator: (value) {
                  if (_isPrivate) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요.';
                    }
                    if (value.length < 4) {
                      return '비밀번호는 4자 이상이어야 합니다.';
                    }
                    if (value.length > 8) {
                      return '비밀번호는 8자 이하여야 합니다.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '비공개 방은 비밀번호를 아는 플레이어만 참가할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // 방 규칙 안내
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rule, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '방 규칙',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 최대 2명의 플레이어가 참가할 수 있습니다\n'
                    '• 방장이 게임을 시작할 수 있습니다\n'
                    '• 방장이 나가면 방이 삭제됩니다\n'
                    '• 게임 중에는 새로운 플레이어가 참가할 수 없습니다',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 방 생성
  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final roomName = _roomNameController.text.trim();
      final password = _isPrivate ? _passwordController.text : null;

      final roomId = await _firebaseService.createOnlineRoom(
        roomName: roomName,
        isPrivate: _isPrivate,
        password: password,
      );

      if (mounted && context.mounted) {
        if (ScaffoldMessenger.of(context).mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('방이 생성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        Navigator.pop(context, roomId);
      }
    } catch (e) {
      String userFriendlyMessage = '방 생성에 실패했습니다.';
      
      // 구체적인 오류 상황에 맞는 메시지 제공
      if (e.toString().contains('Firebase가 초기화되지 않았습니다')) {
        userFriendlyMessage = '네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('로그인이 필요합니다')) {
        userFriendlyMessage = '로그인이 필요합니다. 다시 로그인해주세요.';
      } else if (e.toString().contains('권한')) {
        userFriendlyMessage = '방을 생성할 권한이 없습니다.';
      } else if (e.toString().contains('네트워크')) {
        userFriendlyMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
      }
      
      if (mounted && context.mounted) {
        setState(() {
          _errorMessage = userFriendlyMessage;
        });
      }
      
      print('방 생성 오류 상세: $e');
    } finally {
      if (mounted && context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 랜덤 방 이름 생성
  String _getRandomRoomName() {
    final adjectives = [
      '즐거운', '신나는', '도전적인', '재미있는', '특별한',
      '멋진', '훌륭한', '완벽한', '최고의', '최강의'
    ];
    
    final nouns = [
      '게이머', '플레이어', '챔피언', '마스터', '전사',
      '영웅', '레전드', '킹', '퀸', '스타'
    ];

    final random = DateTime.now().millisecondsSinceEpoch;
    final adjIndex = random % adjectives.length;
    final nounIndex = (random ~/ 10) % nouns.length;

    return '${adjectives[adjIndex]} ${nouns[nounIndex]}';
  }
} 