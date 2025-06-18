import 'package:flutter/material.dart';

import 'multiplayer_game_screen.dart';

/// 멀티플레이어 게임 설정 화면
/// 플레이어 이름을 입력받고 멀티플레이어 게임을 시작
class MultiplayerSetupScreen extends StatefulWidget {
  const MultiplayerSetupScreen({super.key});

  @override
  _MultiplayerSetupScreenState createState() => _MultiplayerSetupScreenState();
}

class _MultiplayerSetupScreenState extends State<MultiplayerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _player1Controller = TextEditingController();
  final _player2Controller = TextEditingController();
  final _gameTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 기본값 설정
    _player1Controller.text = '플레이어 1';
    _player2Controller.text = '플레이어 2';
    _gameTitleController.text = '멀티플레이어 게임';
  }

  @override
  void dispose() {
    _player1Controller.dispose();
    _player2Controller.dispose();
    _gameTitleController.dispose();
    super.dispose();
  }

  /// 게임 시작
  void _startGame() {
    if (!_formKey.currentState!.validate()) return;

    final player1Name = _player1Controller.text.trim();
    final player2Name = _player2Controller.text.trim();
    final gameTitle = _gameTitleController.text.trim();

    // 같은 이름인지 확인
    if (player1Name.toLowerCase() == player2Name.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('플레이어 이름이 같습니다. 다른 이름을 사용해주세요.')),
      );
      return;
    }

    // 멀티플레이어 게임 화면으로 이동
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MultiplayerGameScreen(
          player1Name: player1Name,
          player2Name: player2Name,
          player1Email: '', // 멀티플레이어에서는 이메일 생략
          player2Email: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('멀티플레이어 설정'),
        centerTitle: true,
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 제목
                  const Icon(
                    Icons.people,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '멀티플레이어 게임',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '2명의 플레이어가 번갈아가며 카드를 매칭합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 게임 제목 입력
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '게임 제목',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _gameTitleController,
                          decoration: const InputDecoration(
                            hintText: '게임 제목을 입력하세요',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '게임 제목을 입력해주세요';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 플레이어 정보 입력
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '플레이어 정보',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 플레이어 1
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _player1Controller,
                                decoration: const InputDecoration(
                                  labelText: '플레이어 1 이름',
                                  hintText: '첫 번째 플레이어 이름',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '플레이어 1 이름을 입력해주세요';
                                  }
                                  if (value.trim().length < 2) {
                                    return '이름은 2자 이상 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 플레이어 2
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '2',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _player2Controller,
                                decoration: const InputDecoration(
                                  labelText: '플레이어 2 이름',
                                  hintText: '두 번째 플레이어 이름',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '플레이어 2 이름을 입력해주세요';
                                  }
                                  if (value.trim().length < 2) {
                                    return '이름은 2자 이상 입력해주세요';
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
                  const SizedBox(height: 32),

                  // 게임 규칙 안내
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '게임 규칙',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('• 플레이어가 번갈아가며 카드를 선택합니다'),
                        const Text('• 카드 매칭에 성공하면 같은 플레이어가 계속 진행합니다'),
                        const Text('• 카드 매칭에 실패하면 다음 플레이어로 턴이 넘어갑니다'),
                        const Text('• 모든 카드를 매칭하면 게임이 종료됩니다'),
                        const Text('• 더 높은 점수를 얻은 플레이어가 승리합니다'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 게임 시작 버튼
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '게임 시작',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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