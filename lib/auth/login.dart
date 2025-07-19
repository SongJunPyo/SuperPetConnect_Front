import 'package:flutter/material.dart';
import 'package:connect/auth/register.dart'; // register.dart로 파일명 변경
import 'package:connect/hospital/hospital_dashboard.dart';
import 'package:connect/user/user_dashboard.dart';
import 'package:connect/admin/admin_dashboard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import 'package:connect/auth/fcm_token_screen.dart'; // FcmTokenScreen 임포트

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true; // 비밀번호 가시성 토글을 위한 변수

  // 로그인 버튼 클릭 시 호출될 함수
  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 로딩 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // API 요청
        final response = await http.post(
          Uri.parse('${Config.serverUrl}/api/v1/login'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'username': _emailController.text,
            'password': _passwordController.text,
          },
        );

        // 로딩 닫기
        if (mounted) {
          // 위젯이 여전히 마운트되어 있는지 확인
          Navigator.pop(context);
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['access_token']);

          // 사용자 정보 저장
          await prefs.setString('user_email', data['email'] ?? '');
          await prefs.setString('user_name', data['name'] ?? '');
          // TODO: 기타 필요한 사용자 정보 저장 (예: phone_number, address, user_id 등)

          // 승인 여부 확인
          if (data['approved'] == false) {
            _showAlertDialog(
              context,
              '승인 대기 중',
              '관리자의 승인을 기다리고 있습니다. \n승인 후 로그인이 가능합니다.',
            );
            return;
          }

          print('디버그!!!!!!: ${data['account_type']}');

          // 사용자 유형에 따라 적절한 화면으로 이동
          switch (data['account_type']) {
            case 1: // 관리자
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
              break;
            case 2: // 병원
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HospitalDashboard(),
                ),
              );
              break;
            case 3: // 일반 사용자
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const UserDashboard()),
              );
              break;
            default:
              _showAlertDialog(context, '오류', '알 수 없는 사용자 유형입니다.');
          }
        } else if (response.statusCode == 403) {
          // 승인되지 않은 계정인 경우
          _showAlertDialog(
            context,
            '승인 대기 중',
            '관리자의 승인을 기다리고 있습니다. \n승인 후 로그인이 가능합니다.',
          );
        } else if (response.statusCode == 401) {
          // 인증 실패 (이메일 또는 비밀번호 오류)
          _showAlertDialog(context, '로그인 실패', '이메일 또는 비밀번호가 올바르지 않습니다.');
        } else {
          // 기타 서버 오류
          _showAlertDialog(
            context,
            '오류 발생',
            '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.\n${utf8.decode(response.bodyBytes)}',
          );
        }
      } catch (e) {
        if (mounted) {
          // 에러 발생 시 로딩 닫기 전 위젯 마운트 상태 확인
          Navigator.pop(context);
        }
        _showAlertDialog(
          context,
          '연결 오류',
          '서버 연결 오류가 발생했습니다. 네트워크 상태를 확인해주세요.\n$e',
        );
        print('Login Error: $e'); // 자세한 오류 로깅
      }
    }
  }

  // 공통 Alert Dialog 함수
  void _showAlertDialog(
    BuildContext context,
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // BuildContext 이름을 dialogContext로 변경
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onOkPressed?.call(); // 확인 버튼 콜백 실행
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 회원가입 버튼 클릭 시 호출될 함수
  void _signUp() {
    print('회원가입 페이지로 이동');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  // 비밀번호 찾기 버튼 클릭 시 호출될 함수 (현재는 스낵바만 표시)
  void _forgotPassword() {
    print('비밀번호 찾기 페이지로 이동');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 찾기 기능은 나중에 구현됩니다!')));
    // TODO: 실제 비밀번호 찾기 페이지로 이동하는 로직 추가
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기
          },
        ),
        title: const SizedBox.shrink(), // 로그인 아이콘 대신 빈 위젯으로 대체
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40), // 상단 여백
              Text(
                '로그인',
                style: textTheme.headlineLarge?.copyWith(
                  // 더 큰 제목 스타일
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              // 이메일 입력 필드
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: '이메일 주소',
                  filled: true,
                  fillColor: Colors.grey[100], // 배경색
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // 둥근 모서리
                    borderSide: BorderSide.none, // 테두리 없음
                  ),
                  focusedBorder: OutlineInputBorder(
                    // 포커스 시 테두리
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    // 기본 테두리
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요.';
                  }
                  // TODO: 이메일 형식 유효성 검사 추가 (정규식 등)
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 입력 필드
              TextFormField(
                controller: _passwordController,
                obscureText: _isObscure, // _isObscure 값에 따라 비밀번호 가림/보임
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    // 눈 모양 아이콘 추가
                    icon: Icon(
                      _isObscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined, // 아이콘 변경
                      color: Colors.grey[600], // 아이콘 색상
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscure = !_isObscure; // 상태 토글
                      });
                    },
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요.';
                  }
                  // TODO: 비밀번호 강도/길이 유효성 검사 추가
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // 로그인 버튼
              SizedBox(
                width: double.infinity, // 너비를 최대로
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // 버튼 배경색
                    foregroundColor: Colors.white, // 버튼 글자색
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // 둥근 모서리
                    ),
                    elevation: 0, // 그림자 없음
                  ),
                  child: Text(
                    '로그인',
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 회원가입 및 비밀번호 찾기 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _signUp,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueAccent, // 글자색
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    child: Text(
                      '회원가입',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    ' | ',
                    style: textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600], // 글자색
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    child: Text(
                      '비밀번호 찾기',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // 개발용 임시 이동 버튼 섹션 (새로 추가된 부분)
              const SizedBox(height: 40), // 추가 여백
              Text(
                '개발용 임시 이동 버튼', // 임시 버튼임을 명시
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent, // 눈에 띄는 색상
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FcmTokenScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // 임시 버튼 색상
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('관리자 토큰'),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserDashboard(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, // 임시 버튼 색상
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('사용자'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HospitalDashboard(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('병원'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboard(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('관리자'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // 마지막 여백
            ],
          ),
        ),
      ),
    );
  }
}
