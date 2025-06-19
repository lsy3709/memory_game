import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../services/storage_service.dart';
import '../models/player_stats.dart';

/// 로그인 화면
/// 기존 사용자의 이메일과 비밀번호로 로그인
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final StorageService _storageService = StorageService.instance;
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 비밀번호 해시 생성 (간단한 구현)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 로그인 처리
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // 저장된 플레이어 통계 불러오기
      final playerStats = await _storageService.loadPlayerStats();
      
      if (playerStats == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록된 계정이 없습니다. 먼저 회원가입을 해주세요.')),
        );
        return;
      }

      // 이메일 확인
      if (playerStats.email.toLowerCase() != email) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록되지 않은 이메일입니다.')),
        );
        return;
      }

      // 비밀번호 확인 (실제 구현에서는 더 안전한 방법 사용)
      // 여기서는 간단히 이메일과 비밀번호 조합으로 확인
      final expectedPassword = _hashPassword(email + password);
      final actualPassword = _hashPassword(playerStats.email + password);
      
      if (expectedPassword != actualPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')),
        );
        return;
      }

      // 로그인 성공 - 현재 플레이어 정보 저장
      await _storageService.saveCurrentPlayer(playerStats.playerName, playerStats.email);

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인되었습니다!')),
        );
        
        // 게임 화면으로 이동
        Navigator.of(context).pushReplacementNamed('/game');
      }
    } catch (e) {
      print('로그인 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 비밀번호 재설정 (간단한 구현)
  void _resetPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 재설정'),
        content: const Text(
          '현재는 로컬 저장소만 지원하므로, 앱을 삭제하고 다시 설치하여 새 계정을 만드세요.',
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
        title: const Text('로그인'),
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
                '계정 정보를 입력하여 로그인하세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // 이메일 입력
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력해주세요';
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
                  labelText: '비밀번호',
                  hintText: '비밀번호를 입력하세요',
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
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // 비밀번호 재설정 링크
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: const Text('비밀번호를 잊으셨나요?'),
                ),
              ),
              const SizedBox(height: 24),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
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
                        '로그인',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // 회원가입 링크
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/register');
                },
                child: const Text('계정이 없으신가요? 회원가입하기'),
              ),
              const SizedBox(height: 32),

              // 게스트 모드 (선택사항)
              OutlinedButton(
                onPressed: () {
                  // 게스트 모드로 게임 시작
                  Navigator.of(context).pushReplacementNamed('/game');
                },
                child: const Text('게스트로 게임하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 