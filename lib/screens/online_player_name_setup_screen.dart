import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// 온라인 플레이어 이름 설정 화면
class OnlinePlayerNameSetupScreen extends StatefulWidget {
  const OnlinePlayerNameSetupScreen({super.key});

  @override
  _OnlinePlayerNameSetupScreenState createState() => _OnlinePlayerNameSetupScreenState();
}

class _OnlinePlayerNameSetupScreenState extends State<OnlinePlayerNameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  String _currentEmail = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  /// 현재 사용자 정보 로드
  Future<void> _loadCurrentUserInfo() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        setState(() {
          _currentEmail = user.email ?? '';
        });
        
        // 기존 플레이어 이름이 있는지 확인
        final userData = await _firebaseService.getUserData(user.uid);
        if (userData != null && userData['playerName'] != null) {
          _playerNameController.text = userData['playerName'];
        }
      }
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
    }
  }

  /// 플레이어 이름 저장
  Future<void> _savePlayerName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _firebaseService.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      final playerName = _playerNameController.text.trim();
      print('플레이어 이름 저장 시도: $playerName');
      
      // Firebase 연결 상태 확인
      final isFirebaseAvailable = await _firebaseService.ensureInitialized();
      if (!isFirebaseAvailable) {
        throw Exception('Firebase가 사용할 수 없습니다. 네트워크 연결을 확인해주세요.');
      }
      
      // Firestore에 플레이어 이름 저장
      print('Firestore에 플레이어 이름 저장 중...');
      await _firebaseService.updatePlayerName(user.uid, playerName);
      print('Firestore 저장 완료');
      
      // Firebase Auth 프로필 업데이트 (안전하게 처리)
      print('Firebase Auth 프로필 업데이트 중...');
      try {
        await user.updateDisplayName(playerName);
        print('Firebase Auth 업데이트 완료');
      } catch (authError) {
        print('Firebase Auth 업데이트 실패 (무시하고 계속): $authError');
        // Auth 업데이트 실패해도 Firestore에는 저장되었으므로 계속 진행
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('플레이어 이름이 저장되었습니다: $playerName'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 잠시 후 온라인 메인 화면으로 이동
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/online-main');
          }
        });
      }
    } catch (e) {
      print('플레이어 이름 저장 오류: $e');
      setState(() {
        _errorMessage = _getErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 오류 메시지를 사용자 친화적으로 변환
  String _getErrorMessage(String error) {
    if (error.contains('permission-denied')) {
      return '권한이 없습니다. 다시 로그인해주세요.';
    } else if (error.contains('unavailable')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (error.contains('not-found')) {
      return '사용자 정보를 찾을 수 없습니다.';
    } else if (error.contains('already-exists')) {
      return '이미 존재하는 플레이어 이름입니다.';
    } else {
      return '플레이어 이름 저장에 실패했습니다: ${error.replaceAll('Exception: ', '')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이어 이름 설정'),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 아이콘
                        const Icon(
                          Icons.person_add,
                          size: 64,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        
                        // 제목
                        const Text(
                          '플레이어 이름 설정',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // 이메일 표시
                        if (_currentEmail.isNotEmpty)
                          Text(
                            '이메일: $_currentEmail',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 32),

                        // 플레이어 이름 입력
                        TextFormField(
                          controller: _playerNameController,
                          decoration: const InputDecoration(
                            labelText: '플레이어 이름',
                            hintText: '게임에서 사용할 이름을 입력하세요',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '플레이어 이름을 입력해주세요.';
                            }
                            if (value.trim().length < 2) {
                              return '플레이어 이름은 2자 이상이어야 합니다.';
                            }
                            if (value.trim().length > 20) {
                              return '플레이어 이름은 20자 이하여야 합니다.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 오류 메시지
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
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

                        if (_errorMessage != null) const SizedBox(height: 16),

                        // 저장 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _savePlayerName,
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
                                : const Text('저장'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 건너뛰기 버튼
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            Navigator.of(context).pushReplacementNamed('/online-main');
                          },
                          child: const Text('나중에 설정하기'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 