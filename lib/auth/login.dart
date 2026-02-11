import 'package:flutter/material.dart';
import 'package:connect/auth/register.dart';
import 'package:connect/hospital/hospital_dashboard.dart';
import 'package:connect/user/user_dashboard.dart';
import 'package:connect/admin/admin_dashboard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_token.dart';
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input_field.dart';
import '../widgets/app_app_bar.dart';
import 'package:connect/auth/fcm_token_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../providers/notification_provider.dart';
import '../utils/web_redirect_stub.dart'
    if (dart.library.html) '../utils/web_redirect.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 로그인 성공 후 공통 처리 로직
  Future<void> _handleLoginSuccess(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['access_token']);
    // Refresh Token 저장 (보안 업데이트: Access Token 15분 + Refresh Token 7일)
    if (data['refresh_token'] != null) {
      await prefs.setString('refresh_token', data['refresh_token']);
    }

    // 사용자 정보 저장
    await prefs.setString('user_email', data['email'] ?? '');
    await prefs.setString('user_name', data['name'] ?? '');
    await prefs.setInt('account_type', data['account_type'] ?? 0);
    await prefs.setInt('account_idx', data['account_idx'] ?? 0);

    // 병원 사용자인 경우 hospital_code 저장
    if (data['account_type'] == 2 && data['hospital_code'] != null) {
      await prefs.setString('hospital_code', data['hospital_code']);
    }

    // 로그인 성공 후 FCM 토큰 서버 업데이트
    try {
      await NotificationService.updateTokenAfterLogin();
    } catch (e) {
      // FCM 토큰 서버 업데이트 실패
    }

    // 알림 Provider 초기화 (대시보드에서 뱃지 표시용)
    if (mounted) {
      context.read<NotificationProvider>().initialize();
    }

    // 승인 여부 확인
    if (data['approved'] == false) {
      if (mounted) {
        _showAlertDialog(
          context,
          '승인 대기 중',
          '관리자의 승인을 기다리고 있습니다. \n승인 후 로그인이 가능합니다.',
        );
      }
      return;
    }

    // 사용자 유형에 따라 적절한 화면으로 이동
    if (mounted) {
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
    }
  }

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
          } catch (e) {
            // FCM 토큰이 없어도 로그인은 계속 진행
          }
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

        final response = await http
            .post(
              Uri.parse('${Config.serverUrl}/api/login'),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 15));

        // 로딩 닫기
        if (mounted) {
          Navigator.pop(context);
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _handleLoginSuccess(data);
        } else if (response.statusCode == 403) {
          if (mounted) {
            _showAlertDialog(
              context,
              '승인 대기 중',
              '관리자의 승인을 기다리고 있습니다. \n승인 후 로그인이 가능합니다.',
            );
          }
        } else if (response.statusCode == 429) {
          if (mounted) {
            final retryAfter = response.headers['retry-after'];
            final seconds = int.tryParse(retryAfter ?? '') ?? 60;
            _showAlertDialog(
              context,
              '요청 제한',
              '너무 많은 로그인 시도를 했습니다.\n$seconds초 후 다시 시도해주세요.',
            );
          }
        } else if (response.statusCode == 401) {
          if (mounted) {
            _showAlertDialog(context, '로그인 실패', '이메일 또는 비밀번호가 올바르지 않습니다.');
          }
        } else {
          if (mounted) {
            _showAlertDialog(
              context,
              '오류 발생',
              '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.\n${utf8.decode(response.bodyBytes)}',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }

        String errorMessage = '서버 연결 오류가 발생했습니다.';

        if (e.toString().contains('NotInitializedError')) {
          errorMessage =
              'HTTP 클라이언트 초기화 오류가 발생했습니다.\n웹 브라우저를 새로고침하거나 앱을 재시작해주세요.';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = '요청 시간이 초과되었습니다.\n네트워크 연결을 확인해주세요.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = '네트워크 연결을 확인해주세요.';
        }

        if (mounted) {
          _showAlertDialog(context, '연결 오류', '$errorMessage\n\n상세 오류: $e');
        }
      }
    }
  }

  // 네이버 로그인 처리 (웹/모바일 분기)
  void _naverLogin() async {
    if (kIsWeb) {
      _naverLoginWeb();
    } else {
      _naverLoginMobile();
    }
  }

  // 웹: 서버의 authorization_url로 브라우저 리다이렉트
  void _naverLoginWeb() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http
          .get(
            Uri.parse('${Config.serverUrl}/api/auth/naver/login'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authUrl = data['authorization_url'];
        if (authUrl != null) {
          redirectToUrl(authUrl);
        } else {
          if (mounted) {
            _showAlertDialog(context, '오류', '네이버 인증 URL을 받지 못했습니다.');
          }
        }
      } else {
        if (mounted) {
          _showAlertDialog(
            context,
            '오류 발생',
            '네이버 로그인 요청에 실패했습니다.\n${utf8.decode(response.bodyBytes)}',
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showAlertDialog(context, '연결 오류', '서버 연결에 실패했습니다.\n\n상세 오류: $e');
      }
    }
  }

  // 모바일: 네이버 SDK로 로그인 후 서버에 토큰 전달
  void _naverLoginMobile() async {
    try {
      // 먼저 로그아웃 상태로 초기화 (이전 세션 클리어)
      try {
        await FlutterNaverLogin.logOut();
      } catch (e) {
        // 기존 세션 없음 (정상)
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(child: CircularProgressIndicator()),
      );

      // 네이버 SDK 로그인 호출
      final NaverLoginResult result = await FlutterNaverLogin.logIn();

      if (result.status != NaverLoginStatus.loggedIn) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          _showAlertDialog(context, '네이버 로그인 실패', '네이버 로그인이 취소되었습니다.');
        }
        return;
      }

      // 네이버 SDK에서 access token 추출
      final NaverToken naverToken =
          await FlutterNaverLogin.getCurrentAccessToken();

      // 서버에 네이버 access token 전달
      final response = await http
          .post(
            Uri.parse('${Config.serverUrl}/api/auth/naver/token-login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'access_token': naverToken.accessToken,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _handleLoginSuccess(data);
      } else if (response.statusCode == 409) {
        if (mounted) {
          _showAlertDialog(
            context,
            '로그인 실패',
            '이미 가입된 이메일입니다. 기존 계정으로 로그인해주세요.',
          );
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          _showAlertDialog(
            context,
            '인증 실패',
            '네이버 인증에 실패했습니다. 다시 시도해주세요.',
          );
        }
      } else {
        if (mounted) {
          _showAlertDialog(
            context,
            '오류 발생',
            '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.\n${utf8.decode(response.bodyBytes)}',
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      String errorMessage = '네이버 로그인 중 오류가 발생했습니다.';

      if (e.toString().contains('TimeoutException')) {
        errorMessage = '요청 시간이 초과되었습니다.\n네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      }

      if (mounted) {
        _showAlertDialog(context, '연결 오류', '$errorMessage\n\n상세 오류: $e');
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
    // 회원가입 페이지로 이동
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  // 비밀번호 찾기 버튼 클릭 시 호출될 함수 (현재는 스낵바만 표시)
  void _forgotPassword() {
    // 비밀번호 찾기 페이지로 이동
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 찾기 기능은 나중에 구현됩니다!')));
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
      appBar: const AppAppBar(showBackButton: true),
      body: SingleChildScrollView(
        padding: AppTheme.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spacing40),
              Text('로그인', style: AppTheme.h1Style),
              const SizedBox(height: AppTheme.spacing32),
              AppEmailField(controller: _emailController, required: true),
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
              AppButton(
                text: '로그인',
                onPressed: _login,
                size: AppButtonSize.large,
                customColor: AppTheme.textPrimary,
              ),
              const SizedBox(height: AppTheme.spacing16),
              // 네이버 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _naverLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF03C75A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'N',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '네이버로 로그인',
                        style: TextStyle(
                          fontSize: AppTheme.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _signUp,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                    ),
                    child: Text(
                      '회원가입',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
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
            ],
          ),
        ),
      ),
    );
  }
}
