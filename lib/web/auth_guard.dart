import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../auth/welcome.dart';
import '../admin/admin_dashboard.dart';
import '../hospital/hospital_dashboard.dart';
import '../user/user_dashboard.dart';
import '../auth/login.dart';
import '../utils/preferences_manager.dart';
import '../utils/config.dart';
import 'web_storage_helper_stub.dart'
    if (dart.library.html) 'web_storage_helper.dart';

/// 웹에서 JWT 토큰 기반 인증 상태를 확인하고 적절한 화면으로 리다이렉트하는 위젯
class AuthGuard extends StatefulWidget {
  final String requestedPath;

  const AuthGuard({super.key, required this.requestedPath});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isLoading = true;
  Widget? _targetWidget;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      // [핵심 수정] SharedPreferences 인메모리 캐시 우회
      // SharedPreferences 2.5.x 버그: clear() 호출 시 localStorage는 삭제되지만
      // 싱글턴의 인메모리 캐시에 토큰이 남아있는 문제가 있음.
      // localStorage를 직접 확인하여 실제로 토큰이 존재하는지 먼저 검증.
      final hasTokenInStorage = WebStorageHelper.hasAuthToken();

      if (!hasTokenInStorage) {
        // 주의: 여기서 clearAll()을 호출하면 안 됨!
        // localStorage가 이미 비어있으므로 정리할 것이 없고,
        // clearAll()이 SharedPreferences 싱글턴 상태를 리셋하면
        // 이후 로그인 시 setAuthToken()이 정상 작동하지 않을 수 있음.
        _redirectToAuth();
        return;
      }

      final token = await PreferencesManager.getAuthToken();
      final userType = await PreferencesManager.getAccountType();

      if (token == null || userType == null) {
        _redirectToAuth();
        return;
      }

      // 서버에 토큰 유효성 검증 (로그아웃 후 만료된 토큰으로 자동 로그인 방지)
      final isValid = await _verifyToken(token);
      if (!isValid) {
        await PreferencesManager.clearAll();
        WebStorageHelper.clearAll();
        _redirectToAuth();
        return;
      }

      // 토큰이 유효하면 사용자 타입에 따라 대시보드로 리다이렉트
      await _redirectToDashboard(userType, widget.requestedPath);
    } catch (_) {
      _redirectToAuth();
    }
  }

  /// 서버에 토큰 유효성 검증
  Future<bool> _verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.serverUrl}/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      // 웹에서는 오프라인 상황이 없으므로, 오류 시 인증 실패로 처리
      // (CORS 오류, 서버 다운 등 모두 포함)
      return false;
    }
  }

  void _redirectToAuth() {
    setState(() {
      _isLoading = false;
      // 요청된 경로가 로그인 페이지면 로그인 화면, 아니면 웰컴 화면
      _targetWidget =
          widget.requestedPath == '/login'
              ? const LoginScreen()
              : const WelcomeScreen();
    });
  }

  Future<void> _redirectToDashboard(int userType, String requestedPath) async {
    Widget targetWidget;

    // 요청된 경로가 해당 사용자 타입에 맞는지 확인
    switch (userType) {
      case 1: // 관리자
        targetWidget = const AdminDashboard();
        break;
      case 2: // 병원
        targetWidget = const HospitalDashboard();
        break;
      case 3: // 사용자
        targetWidget = const UserDashboard();
        break;
      default:
        targetWidget = const WelcomeScreen();
    }

    setState(() {
      _isLoading = false;
      _targetWidget = targetWidget;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _targetWidget ?? const WelcomeScreen();
  }
}
