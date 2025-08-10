import 'package:flutter/material.dart';
import 'package:connect/auth/register.dart';
import 'package:connect/hospital/hospital_dashboard.dart';
import 'package:connect/user/user_dashboard.dart';
import 'package:connect/admin/admin_dashboard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input_field.dart';
import '../widgets/app_app_bar.dart';
import 'package:connect/auth/fcm_token_screen.dart';
import 'package:flutter/foundation.dart';

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

        // FCM 토큰 가져오기 (웹에서는 스킵)
        String? fcmToken;
        if (!kIsWeb) {
          try {
            fcmToken = await FirebaseMessaging.instance.getToken();
            print('FCM 토큰 획득: $fcmToken');
          } catch (e) {
            print('FCM 토큰 획득 실패: $e');
            // FCM 토큰이 없어도 로그인은 계속 진행
          }
        } else {
          print('웹 환경에서는 FCM 토큰 스킵');
        }

        // API 요청 body 구성
        final requestBody = {
          'username': _emailController.text,
          'password': _passwordController.text,
        };
        
        // FCM 토큰이 있으면 추가
        if (fcmToken != null && fcmToken.isNotEmpty) {
          requestBody['fcm_token'] = fcmToken;
        }

        // API 요청 (웹 환경 대응)
        print('DEBUG: 로그인 API 요청 시작');
        print('DEBUG: 서버 URL: ${Config.serverUrl}');
        print('DEBUG: 요청 데이터: $requestBody');
        
        final response = await http.post(
          Uri.parse('${Config.serverUrl}/api/login'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: requestBody,
        ).timeout(const Duration(seconds: 15));

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

          // 병원 사용자인 경우 hospital_code 저장
          if (data['account_type'] == 2 && data['hospital_code'] != null) {
            await prefs.setString('hospital_code', data['hospital_code']);
            print('DEBUG: 병원 코드 저장됨: ${data['hospital_code']}');
          }

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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
                (route) => false,
              );
              break;
            case 2: // 병원
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const HospitalDashboard(),
                ),
                (route) => false,
              );
              break;
            case 3: // 일반 사용자
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UserDashboard()),
                (route) => false,
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
        
        print('ERROR: 로그인 요청 실패: $e');
        print('ERROR: 에러 타입: ${e.runtimeType}');
        
        String errorMessage = '서버 연결 오류가 발생했습니다.';
        
        if (e.toString().contains('NotInitializedError')) {
          errorMessage = 'HTTP 클라이언트 초기화 오류가 발생했습니다.\n웹 브라우저를 새로고침하거나 앱을 재시작해주세요.';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = '요청 시간이 초과되었습니다.\n네트워크 연결을 확인해주세요.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = '네트워크 연결을 확인해주세요.';
        }
        
        _showAlertDialog(
          context,
          '연결 오류',
          '$errorMessage\n\n상세 오류: $e',
        );
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
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FcmTokenScreen(),
                          ),
                          (route) => false,
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
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserDashboard(),
                          ),
                          (route) => false,
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
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HospitalDashboard(),
                          ),
                          (route) => false,
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
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboard(),
                          ),
                          (route) => false,
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
