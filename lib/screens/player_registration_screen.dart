import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';

import '../services/storage_service.dart';
import '../models/player_stats.dart';

/// 플레이어 등록 화면
/// 사용자의 이름과 이메일을 입력받아 계정을 생성
class PlayerRegistrationScreen extends StatefulWidget {
  const PlayerRegistrationScreen({super.key});

  @override
  _PlayerRegistrationScreenState createState() => _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends State<PlayerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final StorageService _storageService = StorageService();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 이메일 중복 검사
  Future<bool> _checkEmailDuplicate(String email) async {
    try {
      final existingStats = await _storageService.loadPlayerStats();
      if (existingStats != null && existingStats.email.toLowerCase() == email.toLowerCase()) {
        return true; // 중복됨
      }
      return false; // 중복되지 않음
    } catch (e) {
      print('이메일 중복 검사 오류: $e');
      return false;
    }
  }

  /// 플레이어 등록 처리
  Future<void> _registerPlayer() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('개인정보처리방침에 동의해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // 이메일 중복 검사
      final isDuplicate = await _checkEmailDuplicate(email);
      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 등록된 이메일입니다.')),
        );
        return;
      }

      // 새 플레이어 통계 생성
      final playerStats = PlayerStats(
        id: _storageService.generateId(),
        playerName: name,
        email: email,
        lastPlayed: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // 로컬에 저장
      await _storageService.savePlayerStats(playerStats);
      await _storageService.saveCurrentPlayer(name, email);

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('플레이어 등록이 완료되었습니다!')),
        );
        
        // 게임 화면으로 이동
        Navigator.of(context).pushReplacementNamed('/game');
      }
    } catch (e) {
      print('플레이어 등록 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 개인정보처리방침 다이얼로그 표시
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보처리방침'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '메모리 게임 개인정보처리방침',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text('1. 수집하는 개인정보'),
              Text('• 이메일 주소: 계정 식별 및 랭킹 시스템 운영'),
              Text('• 플레이어 이름: 게임 내 표시 및 랭킹 보드'),
              Text('• 게임 기록: 점수, 시간, 매칭 기록 등'),
              SizedBox(height: 8),
              Text('2. 개인정보의 이용목적'),
              Text('• 게임 서비스 제공 및 개선'),
              Text('• 랭킹 시스템 운영'),
              Text('• 고객 지원 및 문의 응답'),
              SizedBox(height: 8),
              Text('3. 개인정보의 보유 및 이용기간'),
              Text('• 서비스 이용 종료 시까지'),
              Text('• 계정 삭제 요청 시 즉시 삭제'),
              SizedBox(height: 8),
              Text('4. 개인정보의 제3자 제공'),
              Text('• 사용자 동의 없이 제3자에게 제공하지 않음'),
              Text('• 법령에 따른 요구사항이 있는 경우 제외'),
              SizedBox(height: 8),
              Text('5. 개인정보 보호책임자'),
              Text('• 이메일: lsy3709@naver.com'),
              Text('• 문의: 앱 내 설정 > 문의하기'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이어 등록'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 앱 로고 또는 제목
              const Icon(
                Icons.psychology,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                '메모리 게임',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '플레이어 정보를 입력하여 게임을 시작하세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // 플레이어 이름 입력
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '플레이어 이름 *',
                  hintText: '게임에서 사용할 이름을 입력하세요',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '플레이어 이름을 입력해주세요';
                  }
                  if (value.trim().length < 2) {
                    return '이름은 2자 이상 입력해주세요';
                  }
                  if (value.trim().length > 20) {
                    return '이름은 20자 이하로 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 이메일 입력
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '이메일 *',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!EmailValidator.validate(value.trim())) {
                    return '올바른 이메일 형식을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: '비밀번호 *',
                  hintText: '8자 이상 입력해주세요',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요';
                  }
                  if (value.length < 8) {
                    return '비밀번호는 8자 이상 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인 입력
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: '비밀번호 확인 *',
                  hintText: '비밀번호를 다시 입력해주세요',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호 확인을 입력해주세요';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 개인정보처리방침 동의
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (value) {
                      setState(() => _agreeToTerms = value ?? false);
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _agreeToTerms = !_agreeToTerms);
                      },
                      child: const Text(
                        '개인정보처리방침에 동의합니다',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showPrivacyPolicy,
                    child: const Text('보기'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 등록 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _registerPlayer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '플레이어 등록',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // 기존 계정으로 로그인 링크
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('이미 계정이 있으신가요? 로그인하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 