import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/multiplayer_game_record.dart';
import '../models/player_game_result.dart';

/// 온라인 멀티플레이어 게임 설정 화면
class OnlineMultiplayerSetupScreen extends StatefulWidget {
  const OnlineMultiplayerSetupScreen({super.key});

  @override
  _OnlineMultiplayerSetupScreenState createState() => _OnlineMultiplayerSetupScreenState();
}

class _OnlineMultiplayerSetupScreenState extends State<OnlineMultiplayerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _player2NameController = TextEditingController();
  final _gameTitleController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  String _currentPlayerName = '';
  String _currentPlayerEmail = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentPlayerInfo();
  }

  @override
  void dispose() {
    _player2NameController.dispose();
    _gameTitleController.dispose();
    super.dispose();
  }

  /// 현재 플레이어 정보 로드
  Future<void> _loadCurrentPlayerInfo() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final userData = await _firebaseService.getUserData(user.uid);
        if (userData != null) {
          setState(() {
            _currentPlayerName = userData['playerName'] ?? user.displayName ?? '플레이어';
            _currentPlayerEmail = userData['email'] ?? user.email ?? '';
          });
        }
      }
    } catch (e) {
      print('플레이어 정보 로드 오류: $e');
    }
  }

  /// 게임 시작
  void _startGame() {
    if (!_formKey.currentState!.validate()) return;

    final player2Name = _player2NameController.text.trim();
    final gameTitle = _gameTitleController.text.trim();

    Navigator.of(context).pushNamed('/multiplayer-game', arguments: {
      'player1Name': _currentPlayerName,
      'player2Name': player2Name,
      'isOnlineMode': true,
      'gameTitle': gameTitle,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 멀티플레이어 설정'),
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
                  // 제목
                  const Text(
                    '온라인 멀티플레이어 게임',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '2명의 플레이어가 온라인에서 경쟁합니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // 게임 제목 입력
                  Card(
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
                            '게임 제목',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _gameTitleController,
                            decoration: const InputDecoration(
                              labelText: '게임 제목을 입력하세요',
                              prefixIcon: Icon(Icons.games),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '게임 제목을 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 플레이어 정보 입력
                  Card(
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
                            '플레이어 정보',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 플레이어 1 (현재 사용자)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '플레이어 1 (나)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      _currentPlayerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 플레이어 2
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _player2NameController,
                                  decoration: const InputDecoration(
                                    labelText: '플레이어 2 이름',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '플레이어 2 이름을 입력해주세요.';
                                    }
                                    if (value.trim() == _currentPlayerName) {
                                      return '다른 이름을 사용해주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 게임 규칙 안내
                  Card(
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
                            '게임 규칙',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• 15분 제한 시간 내에 모든 카드를 맞춰야 합니다\n'
                            '• 플레이어가 번갈아가며 카드를 선택합니다\n'
                            '• 매칭 성공 시 해당 플레이어가 점수를 얻습니다\n'
                            '• 매칭 실패 시 턴이 넘어갑니다\n'
                            '• 더 높은 점수를 얻은 플레이어가 승리합니다',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 게임 시작 버튼
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        '게임 시작',
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
} 