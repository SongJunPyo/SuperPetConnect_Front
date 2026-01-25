import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/welcome.dart';
import '../admin/admin_dashboard.dart';
import '../hospital/hospital_dashboard.dart';
import '../user/user_dashboard.dart';
import '../auth/login.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // 로그인 시 'account_type'으로 저장됨
      final userType = prefs.getInt('account_type');

      debugPrint('[AuthGuard] 토큰 확인: ${token != null ? '있음' : '없음'}, userType: $userType');

      if (token == null || userType == null) {
        _redirectToAuth();
        return;
      }

      // 토큰이 있으면 사용자 타입에 따라 대시보드로 리다이렉트
      await _redirectToDashboard(userType, widget.requestedPath);
    } catch (e) {
      debugPrint('[AuthGuard] 인증 확인 오류: $e');
      _redirectToAuth();
    }
  }

  void _redirectToAuth() {
    setState(() {
      _isLoading = false;
      // 요청된 경로가 로그인 페이지면 로그인 화면, 아니면 웰컴 화면
      _targetWidget = widget.requestedPath == '/login' 
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _targetWidget ?? const WelcomeScreen();
  }
}