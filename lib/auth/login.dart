import 'package:flutter/material.dart';
import 'package:connect/auth/register.dart';
import 'package:connect/hospital/hospital_dashboard.dart';
import 'package:connect/user/user_dashboard.dart';
import 'package:connect/admin/admin_dashboard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input_field.dart';
import '../widgets/app_app_bar.dart';
import 'package:connect/auth/fcm_token_screen.dart';

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

          await prefs.setInt(
            'guardian_idx',
            data['account_idx'] ?? 0,
          ); // guardian_idx 저장 확인

          // 🚨 저장 후 바로 확인하는 디버그 로그 추가
          print(
            'DEBUG: SharedPreferences에 저장된 guardian_idx: ${prefs.getInt('guardian_idx')}',
          );
          print(
            'DEBUG: SharedPreferences에 저장된 auth_token: ${prefs.getString('auth_token')}',
          );
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
    return Scaffold(
      appBar: const AppAppBar(
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: AppTheme.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spacing40),
              Text(
                '로그인',
                style: AppTheme.h1Style,
              ),
              const SizedBox(height: AppTheme.spacing32),
              AppEmailField(
                controller: _emailController,
                required: true,
              ),
              const SizedBox(height: AppTheme.spacing16),
              AppPasswordField(
                controller: _passwordController,
                required: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing32),
              AppPrimaryButton(
                text: '로그인',
                onPressed: _login,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: AppTheme.spacing20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _signUp,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                    ),
                    child: Text(
                      '회원가입',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  Text(
                    ' | ',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                    ),
                    child: Text(
                      '비밀번호 찾기',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing40),
              Text(
                '개발용 임시 이동 버튼',
                style: AppTheme.h3Style.copyWith(
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: '관리자 토큰',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FcmTokenScreen(),
                          ),
                        );
                      },
                      customColor: AppTheme.success,
                      size: AppButtonSize.small,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: AppButton(
                      text: '사용자',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserDashboard(),
                          ),
                        );
                      },
                      customColor: AppTheme.warning,
                      size: AppButtonSize.small,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: AppButton(
                      text: '병원',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HospitalDashboard(),
                          ),
                        );
                      },
                      customColor: AppTheme.warning,
                      size: AppButtonSize.small,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: AppButton(
                      text: '관리자',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboard(),
                          ),
                        );
                      },
                      customColor: AppTheme.warning,
                      size: AppButtonSize.small,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing20),
            ],
          ),
        ),
      ),
    );
  }
}
