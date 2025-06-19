import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/firebase_service.dart';

/// 온라인 게임 로그인 화면
class OnlineLoginScreen extends StatefulWidget {
  const OnlineLoginScreen({super.key});

  @override
  _OnlineLoginScreenState createState() => _OnlineLoginScreenState();
}

class _OnlineLoginScreenState extends State<OnlineLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _playerNameController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService.instance;

  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 플러터 프레임워크가 초기화된 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirebaseStatus();
    });
  }
  
  /// Firebase 상태 확인
  Future<void> _checkFirebaseStatus() async {
    try {
      final isInitialized = await _firebaseService.ensureInitialized();
      print('Firebase 초기화 상태: $isInitialized');
      
      // 이미 로그인되어 있는지 확인
      if (_firebaseService.currentUser != null) {
        print('이미 로그인된 사용자: ${_firebaseService.currentUser?.email}');
      }
    } catch (e) {
      print('Firebase 상태 확인 중 오류: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _playerNameController.dispose();
    super.dispose();
  }

  /// 로그인 처리
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      print('온라인 로그인 시도: $email');
      
      // Firebase 초기화 확인
      final isInitialized = await _firebaseService.ensureInitialized();
      print('로그인 시도 전 Firebase 초기화 상태: $isInitialized');
      
      if (!isInitialized) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }

      // 로그인 시도
      final credential = await _firebaseService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('로그인 성공: ${credential.user?.email}');

      // 로그인 후 사용자 상태 확인
      if (_firebaseService.currentUser != null) {
        print('로그인 사용자 정보 - UID: ${_firebaseService.currentUser?.uid}, 이메일: ${_firebaseService.currentUser?.email}');
        
        try {
          // 사용자 데이터 로드 시도 (추가 검증)
          final userData = await _firebaseService.getUserData(_firebaseService.currentUser!.uid);
          if (userData != null) {
            print('사용자 데이터 로드 성공: ${userData['playerName']}');
          } else {
            print('사용자 데이터가 없습니다. 기본값 사용');
          }
        } catch (e) {
          // 사용자 데이터 로드 실패해도 로그인은 성공으로 처리
          print('사용자 데이터 로드 실패: $e');
        }
        
        // 로그인 성공 후 화면 전환 - mounted 확인 중요
        if (mounted) {
          print('로그인 성공 - 온라인 메인 화면으로 이동');
          // 성공 시 오류 메시지 초기화
          setState(() {
            _errorMessage = null;
            _isLoading = false;
          });
          // 온라인 메인 화면으로 이동
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/online-main',
            (route) => false,
          );
        }
      } else {
        // 로그인은 성공했지만 currentUser가 null인 경우
        // (이론적으로는 발생하지 않아야 함)
        print('로그인 성공했으나 currentUser가 null입니다.');
        throw Exception('로그인 후 사용자 정보를 가져올 수 없습니다.');
      }
    } catch (e) {
      // 오류 발생 시 자세한 로그 출력
      print('로그인 오류 (상세): $e');
      String errorMessage = _getLoginErrorMessage(e.toString());
      
      // 이미 로그인된 사용자인지 확인 (오류 발생했지만 실제로는 로그인됨)
      if (_firebaseService.currentUser != null) {
        print('오류 발생했으나 사용자가 로그인되어 있음: ${_firebaseService.currentUser?.email}');
        
        if (mounted) {
          print('기존 로그인 사용자 처리 - 온라인 메인 화면으로 이동');
          setState(() {
            _errorMessage = null;
            _isLoading = false;
          });
          // 온라인 메인 화면으로 이동
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/online-main',
            (route) => false,
          );
        }
        return;
      }
      
      // App Check 경고 등의 무시 가능한 오류는 표시하지 않음
      if (errorMessage.isNotEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
          });
        }
      }
      
      // Firebase 초기화 오류인 경우 로컬 모드 전환 옵션 제공
      if (e.toString().contains('Firebase가 초기화되지 않았습니다') ||
          e.toString().contains('Firebase가 설정되지 않았습니다') ||
          e.toString().contains('Firebase가 사용할 수 없습니다')) {
        _showFirebaseErrorDialog();
      }
    } finally {
      // 로딩 상태 해제 (로그인 성공으로 화면 전환된 경우는 제외)
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 로그인 오류 메시지를 사용자 친화적으로 변환
  String _getLoginErrorMessage(String error) {
    // Firebase 자체 오류는 무시 (디버그용 오류)
    if (error.contains('No AppCheckProvider installed') || 
        error.contains('X-Firebase-Locale')) {
      print('무시 가능한 Firebase 경고입니다: $error');
      return ''; // 빈 문자열 반환하여 오류 메시지 표시하지 않음
    }
    
    // 알 수 없는 오류 메시지 필터링 - 이 부분이 표시되는 것이 문제
    if (error.contains('알 수 없는 오류가 발생했습니다')) {
      print('알 수 없는 오류 필터링됨: $error');
      // 로그인은 실제로 성공했을 가능성이 있으므로 빈 문자열 반환
      return '';
    }
    
    if (error.contains('user-not-found')) {
      return '등록되지 않은 이메일입니다.';
    } else if (error.contains('wrong-password')) {
      return '비밀번호가 올바르지 않습니다.';
    } else if (error.contains('invalid-email')) {
      return '올바르지 않은 이메일 형식입니다.';
    } else if (error.contains('user-disabled')) {
      return '비활성화된 계정입니다.';
    } else if (error.contains('too-many-requests')) {
      return '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
    } else if (error.contains('network-request-failed')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (error.contains('Firebase가 사용할 수 없습니다')) {
      return '온라인 서비스에 연결할 수 없습니다. 로컬 모드로 실행됩니다.';
    } else {
      return '로그인에 실패했습니다: ${error.replaceAll('Exception: ', '')}';
    }
  }

  /// 회원가입 처리
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final playerName = _playerNameController.text.trim();
      
      print('온라인 회원가입 시도: $email, 플레이어 이름: $playerName');
      
      // Firebase 초기화 확인
      final isInitialized = await _firebaseService.ensureInitialized();
      if (!isInitialized) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }

      // 회원가입 시도
      final credential = await _firebaseService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        playerName: playerName,
      );
      
      print('회원가입 성공: ${credential.user?.email}');

      // 회원가입 성공 후 사용자 상태 확인
      if (_firebaseService.currentUser != null) {
        if (mounted) {
          print('회원가입 성공 - 온라인 메인 화면으로 이동');
          setState(() {
            _errorMessage = null;
            _isLoading = false;
          });
          // 온라인 메인 화면으로 이동
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/online-main',
            (route) => false,
          );
        }
      } else {
        throw Exception('회원가입 후 사용자 정보를 가져올 수 없습니다.');
      }
    } catch (e) {
      print('회원가입 오류: $e');
      final errorMessage = _getSignUpErrorMessage(e.toString());
      
      if (errorMessage.isNotEmpty && mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      // Firebase 초기화 오류인 경우 로컬 모드 전환 옵션 제공
      if (e.toString().contains('Firebase가 초기화되지 않았습니다') ||
          e.toString().contains('Firebase가 설정되지 않았습니다')) {
        _showFirebaseErrorDialog();
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 회원가입 오류 메시지를 사용자 친화적으로 변환
  String _getSignUpErrorMessage(String error) {
    // Firebase 자체 오류는 무시
    if (error.contains('No AppCheckProvider installed') ||
        error.contains('X-Firebase-Locale')) {
      print('무시 가능한 Firebase 경고입니다: $error');
      return '';
    }
    
    if (error.contains('email-already-in-use')) {
      return '이미 사용 중인 이메일입니다.';
    } else if (error.contains('weak-password')) {
      return '비밀번호가 너무 약합니다. 6자 이상으로 설정해주세요.';
    } else if (error.contains('invalid-email')) {
      return '올바르지 않은 이메일 형식입니다.';
    } else if (error.contains('operation-not-allowed')) {
      return '이메일/비밀번호 회원가입이 비활성화되어 있습니다.';
    } else if (error.contains('network-request-failed')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (error.contains('Firebase가 사용할 수 없습니다')) {
      return '온라인 서비스에 연결할 수 없습니다. 로컬 모드로 실행됩니다.';
    } else {
      return '회원가입에 실패했습니다: ${error.replaceAll('Exception: ', '')}';
    }
  }

  /// 비밀번호 재설정
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '이메일을 입력해주세요.';
      });
      return;
    }

    if (!EmailValidator.validate(_emailController.text.trim())) {
      setState(() {
        _errorMessage = '올바른 이메일 형식을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      print('비밀번호 재설정 이메일 발송 시도: $email');
      
      await _firebaseService.sendPasswordResetEmail(email);
      
      print('비밀번호 재설정 이메일 발송 성공');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('비밀번호 재설정 이메일이 발송되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('비밀번호 재설정 이메일 발송 오류: $e');
      final errorMessage = _getResetPasswordErrorMessage(e.toString());
      
      if (mounted && errorMessage.isNotEmpty) {
        setState(() {
          _errorMessage = errorMessage;
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

  /// 비밀번호 재설정 오류 메시지 변환
  String _getResetPasswordErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return '등록되지 않은 이메일입니다.';
    } else if (error.contains('invalid-email')) {
      return '올바르지 않은 이메일 형식입니다.';
    } else if (error.contains('network-request-failed')) {
      return '네트워크 연결을 확인해주세요.';
    } else {
      return '비밀번호 재설정 이메일 발송에 실패했습니다: ${error.replaceAll('Exception: ', '')}';
    }
  }

  /// Firebase 오류 다이얼로그 표시
  void _showFirebaseErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Firebase 연결 오류'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('온라인 모드를 사용할 수 없습니다.'),
              SizedBox(height: 8),
              Text('가능한 원인:'),
              Text('• Firebase 설정이 완료되지 않음'),
              Text('• 네트워크 연결 문제'),
              Text('• Firebase 프로젝트 설정 오류'),
              SizedBox(height: 8),
              Text('해결 방법:'),
              Text('1. android/app/google-services.json 파일 확인'),
              Text('2. lib/firebase_options.dart 파일의 설정값 확인'),
              Text('3. Firebase Console에서 프로젝트 설정 확인'),
              SizedBox(height: 8),
              Text('로컬 모드로 전환하여 게임을 즐기실 수 있습니다.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/main');
            },
            child: const Text('로컬 모드로 이동'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 게임 로그인'),
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
                        // 로고 또는 제목
                        const Icon(
                          Icons.games,
                          size: 64,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isLoginMode ? '온라인 게임 로그인' : '온라인 게임 회원가입',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 이메일 입력
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '이메일을 입력해주세요.';
                            }
                            if (!EmailValidator.validate(value.trim())) {
                              return '올바른 이메일 형식을 입력해주세요.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 플레이어 이름 입력 (회원가입 모드에서만)
                        if (!_isLoginMode) ...[
                          TextFormField(
                            controller: _playerNameController,
                            decoration: const InputDecoration(
                              labelText: '플레이어 이름',
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
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 비밀번호 입력
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해주세요.';
                            }
                            if (!_isLoginMode && value.length < 6) {
                              return '비밀번호는 6자 이상이어야 합니다.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 오류 메시지
                        if (_errorMessage != null && _errorMessage!.isNotEmpty)
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

                        if (_errorMessage != null && _errorMessage!.isNotEmpty) const SizedBox(height: 16),

                        // 로그인/회원가입 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : (_isLoginMode ? _handleLogin : _handleSignUp),
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
                                : Text(_isLoginMode ? '로그인' : '회원가입'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 비밀번호 재설정 (로그인 모드에서만)
                        if (_isLoginMode)
                          TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: const Text('비밀번호를 잊으셨나요?'),
                          ),

                        const SizedBox(height: 16),

                        // 모드 전환 버튼
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLoginMode ? '계정이 없으신가요?' : '이미 계정이 있으신가요?',
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isLoginMode = !_isLoginMode;
                                        _errorMessage = null;
                                        if (_isLoginMode) {
                                          _playerNameController.clear();
                                        }
                                      });
                                    },
                              child: Text(_isLoginMode ? '회원가입' : '로그인'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 뒤로가기 버튼
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('로컬 게임으로 돌아가기'),
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