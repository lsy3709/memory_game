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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 제목 영역
                  _buildHeaderSection(),
                  const SizedBox(height: 24),

                  // 게임 제목 입력
                  _buildGameTitleSection(),
                  const SizedBox(height: 20),

                  // 플레이어 정보 입력
                  _buildPlayerInfoSection(),
                  const SizedBox(height: 20),

                  // 게임 규칙 안내
                  _buildGameRulesSection(),
                  const SizedBox(height: 24),

                  // 게임 시작 버튼
                  _buildStartButton(),
                  const SizedBox(height: 20),
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
          Icons.people,
          size: 60,
          color: Colors.white,
        ),
        const SizedBox(height: 12),
        const Text(
          '멀티플레이어 게임',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '2명의 플레이어가 번갈아가며 카드를 매칭합니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// 게임 제목 섹션 위젯
  Widget _buildGameTitleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '게임 제목',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _gameTitleController,
            decoration: const InputDecoration(
              hintText: '게임 제목을 입력하세요',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  /// 플레이어 정보 섹션 위젯
  Widget _buildPlayerInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                '플레이어 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 플레이어 1
          _buildPlayerInputField(
            controller: _player1Controller,
            label: '플레이어 1 이름',
            hint: '첫 번째 플레이어 이름',
            playerNumber: 1,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),

          // 플레이어 2
          _buildPlayerInputField(
            controller: _player2Controller,
            label: '플레이어 2 이름',
            hint: '두 번째 플레이어 이름',
            playerNumber: 2,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  /// 플레이어 입력 필드 위젯
  Widget _buildPlayerInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int playerNumber,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              playerNumber.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '플레이어 $playerNumber 이름을 입력해주세요';
              }
              if (value.trim().length < 2) {
                return '이름은 2자 이상 입력해주세요';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  /// 게임 규칙 섹션 위젯
  Widget _buildGameRulesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '게임 규칙',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleItem('플레이어가 번갈아가며 카드를 선택합니다'),
          _buildRuleItem('카드 매칭에 성공하면 같은 플레이어가 계속 진행합니다'),
          _buildRuleItem('카드 매칭에 실패하면 다음 플레이어로 턴이 넘어갑니다'),
          _buildRuleItem('모든 카드를 매칭하면 게임이 종료됩니다'),
          _buildRuleItem('더 높은 점수를 얻은 플레이어가 승리합니다'),
        ],
      ),
    );
  }

  /// 게임 규칙 아이템 위젯
  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 게임 시작 버튼 위젯
  Widget _buildStartButton() {
    return Container(
      height: 56,
      child: ElevatedButton(
        onPressed: _startGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 24),
            const SizedBox(width: 8),
            const Text(
              '게임 시작',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 