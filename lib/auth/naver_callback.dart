import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/admin/admin_dashboard.dart';
import 'package:connect/hospital/hospital_dashboard.dart';
import 'package:connect/user/user_dashboard.dart';
import '../constants/dialog_messages.dart';
import '../services/notification_service.dart';
import '../providers/notification_provider.dart';
import '../utils/app_constants.dart';
import '../utils/preferences_manager.dart';
import '../utils/web_redirect_stub.dart'
    if (dart.library.html) '../utils/web_redirect.dart';
import 'onboarding_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // 첫 프레임 렌더링 완료 후 콜백 처리
    // (빌드 중 clearUrlQueryParams → replaceState → 라우팅 상태 변경 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processCallback();
    });
  }

  /// 이메일 로그인의 _showAlertDialog와 동일한 패턴.
  /// 확인 버튼 누르면 onOkPressed 콜백 실행 (보통 /login으로 이동).
  void _showAlertDialog(
    BuildContext context,
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onOkPressed?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 콜백 페이지에서 발생한 에러/대기 상태를 다이얼로그로 표시 후 로그인 화면으로 복귀.
  /// 풀스크린 모래시계 UI 대신 이메일 로그인과 동일한 AlertDialog 패턴 (2026-05-07 통일).
  void _showAlertAndReturnToLogin(String title, String content) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showAlertDialog(context, title, content, () {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  Future<void> _processCallback() async {
    final params = widget.queryParams;

    // 에러 파라미터가 있으면 에러 표시
    if (params.containsKey('error')) {
      _showAlertAndReturnToLogin(
        '로그인 실패',
        params['message'] ?? '네이버 로그인에 실패했습니다.',
      );
      return;
    }

    // access_token이 있으면 로그인 성공 처리
    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.isEmpty) {
      _showAlertAndReturnToLogin(
        '로그인 실패',
        '인증 정보를 받지 못했습니다. 다시 시도해주세요.',
      );
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

      // 온보딩 완료 여부 확인
      final onboardingCompleted = params['onboarding_completed'] == 'true';
      await PreferencesManager.setOnboardingCompleted(onboardingCompleted);

      // 온보딩 미완료 시 온보딩 화면으로 이동.
      // 네이버 자동 보강된 phone이 있으면 prefill (BE가 콜백 query에 phone_number
      // 추가 ship 후 자동 작동).
      if (!onboardingCompleted) {
        if (mounted) {
          final initialPhone = params['phone_number'] ?? '';
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OnboardingScreen(initialPhone: initialPhone),
            ),
            (route) => false,
          );
        }
        return;
      }

      // 승인 여부 확인
      final approved = params['approved'] == 'true';
      if (!approved) {
        _showAlertAndReturnToLogin(
          DialogMsg.pendingApprovalTitle,
          DialogMsg.pendingApprovalBody,
        );
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
            _showAlertAndReturnToLogin('오류', '알 수 없는 사용자 유형입니다.');
            return;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => dashboard),
          (route) => false,
        );
      }
    } catch (e) {
      _showAlertAndReturnToLogin('연결 오류', '로그인 처리 중 오류가 발생했습니다.\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 처리 중에는 로딩 인디케이터, 에러/승인 대기는 _showAlertDialog가 띄우는 다이얼로그가 화면 위에 표시됨.
    // 다이얼로그 닫으면 /login으로 이동하므로 build 본체는 항상 빈 Scaffold + 처리 중 스피너로 충분.
    return Scaffold(
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }
}
