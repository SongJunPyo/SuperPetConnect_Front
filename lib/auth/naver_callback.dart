import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/admin/admin_dashboard.dart';
import 'package:connect/hospital/hospital_dashboard.dart';
import 'package:connect/user/user_dashboard.dart';
import '../services/notification_service.dart';
import '../providers/notification_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/preferences_manager.dart';
import '../utils/web_redirect_stub.dart'
    if (dart.library.html) '../utils/web_redirect.dart';

/// 네이버 로그인 웹 콜백 처리 페이지
/// 서버가 네이버 인증 처리 후 /#/naver-callback?... 으로 리다이렉트하면
/// 이 페이지에서 URL 쿼리 파라미터를 파싱하여 로그인 처리
class NaverCallbackScreen extends StatefulWidget {
  final Map<String, String> queryParams;

  const NaverCallbackScreen({super.key, required this.queryParams});

  @override
  State<NaverCallbackScreen> createState() => _NaverCallbackScreenState();
}

class _NaverCallbackScreenState extends State<NaverCallbackScreen> {
  bool _isProcessing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 렌더링 완료 후 콜백 처리
    // (빌드 중 clearUrlQueryParams → replaceState → 라우팅 상태 변경 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processCallback();
    });
  }

  Future<void> _processCallback() async {
    final params = widget.queryParams;

    // 에러 파라미터가 있으면 에러 표시
    if (params.containsKey('error')) {
      setState(() {
        _isProcessing = false;
        _errorMessage = params['message'] ?? '네이버 로그인에 실패했습니다.';
      });
      return;
    }

    // access_token이 있으면 로그인 성공 처리
    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.isEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '인증 정보를 받지 못했습니다. 다시 시도해주세요.';
      });
      return;
    }

    try {
      // [핵심] 브라우저 URL에서 access_token 등 쿼리 파라미터 즉시 제거
      // 이렇게 하지 않으면 로그아웃 후 새로고침 시 URL의 토큰으로 자동 재로그인됨
      clearUrlQueryParams();

      // 기존 로그인 성공 처리 로직과 동일
      await PreferencesManager.setAuthToken(accessToken);
      // Refresh Token 저장 (보안 업데이트: Access Token 15분 + Refresh Token 7일)
      if (params['refresh_token'] != null &&
          params['refresh_token']!.isNotEmpty) {
        await PreferencesManager.setRefreshToken(params['refresh_token']!);
      }
      await PreferencesManager.setUserEmail(params['email'] ?? '');
      await PreferencesManager.setUserName(params['name'] ?? '');

      final accountType = int.tryParse(params['account_type'] ?? '') ?? 0;
      final accountIdx = int.tryParse(params['account_idx'] ?? '') ?? 0;
      await PreferencesManager.setAccountType(accountType);
      await PreferencesManager.setAccountIdx(accountIdx);

      // 병원 사용자인 경우 hospital_code 저장
      if (accountType == AppConstants.accountTypeHospital &&
          params['hospital_code'] != null) {
        await PreferencesManager.setHospitalCode(params['hospital_code']!);
      }

      // FCM 토큰 서버 업데이트
      try {
        await NotificationService.updateTokenAfterLogin();
      } catch (e) {
        // FCM 토큰 서버 업데이트 실패
      }

      // 알림 Provider 초기화
      if (mounted) {
        context.read<NotificationProvider>().initialize();
      }

      // 승인 여부 확인
      final approved = params['approved'] == 'true';
      if (!approved) {
        setState(() {
          _isProcessing = false;
          _errorMessage = '관리자의 승인을 기다리고 있습니다.\n승인 후 로그인이 가능합니다.';
        });
        return;
      }

      // 사용자 유형에 따라 대시보드로 이동
      if (mounted) {
        Widget dashboard;
        switch (accountType) {
          case AppConstants.accountTypeAdmin:
            dashboard = const AdminDashboard();
            break;
          case AppConstants.accountTypeHospital:
            dashboard = const HospitalDashboard();
            break;
          case AppConstants.accountTypeUser:
            dashboard = const UserDashboard();
            break;
          default:
            setState(() {
              _isProcessing = false;
              _errorMessage = '알 수 없는 사용자 유형입니다.';
            });
            return;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => dashboard),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '로그인 처리 중 오류가 발생했습니다.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 에러 또는 승인 대기 화면
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _errorMessage != null && _errorMessage!.contains('승인')
                    ? Icons.hourglass_empty
                    : Icons.error_outline,
                size: 64,
                color:
                    _errorMessage != null && _errorMessage!.contains('승인')
                        ? AppTheme.warning
                        : AppTheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage != null && _errorMessage!.contains('승인')
                    ? '승인 대기 중'
                    : '로그인 실패',
                style: AppTheme.h2Style,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: AppTheme.bodyLargeStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('로그인 페이지로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
