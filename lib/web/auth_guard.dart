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
      print('AuthGuard: 인증 상태 확인 시작, 요청 경로: ${widget.requestedPath}');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userType = prefs.getInt('user_type');
      
      print('AuthGuard: 토큰 존재 여부: ${token != null}');
      print('AuthGuard: 사용자 타입: $userType');

      if (token == null || userType == null) {
        print('AuthGuard: 토큰 또는 사용자 타입이 없음, 인증 페이지로 이동');
        _redirectToAuth();
        return;
      }

      print('AuthGuard: 토큰 확인 완료, 대시보드로 리다이렉트');
      // 토큰이 있으면 사용자 타입에 따라 대시보드로 리다이렉트
      await _redirectToDashboard(userType, widget.requestedPath);
    } catch (e) {
      print('AuthGuard: 인증 상태 확인 중 오류: $e');
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
    
    print('AuthGuard: 대시보드 리다이렉트 시작, 사용자 타입: $userType, 요청 경로: $requestedPath');
    
    // 요청된 경로가 해당 사용자 타입에 맞는지 확인
    switch (userType) {
      case 1: // 관리자
        print('AuthGuard: 관리자로 인식, AdminDashboard로 이동');
        targetWidget = const AdminDashboard();
        break;
      case 2: // 병원
        print('AuthGuard: 병원으로 인식, HospitalDashboard로 이동');
        targetWidget = const HospitalDashboard();
        break;
      case 3: // 사용자
        print('AuthGuard: 사용자로 인식, UserDashboard로 이동');
        targetWidget = const UserDashboard();
        break;
      default:
        print('AuthGuard: 알 수 없는 사용자 타입, WelcomeScreen으로 이동');
        targetWidget = const WelcomeScreen();
    }

    print('AuthGuard: 대상 위젯 결정 완료: ${targetWidget.runtimeType}');

    setState(() {
      _isLoading = false;
      _targetWidget = targetWidget;
    });
  }

  Widget _getAdminWidget(String path) {
    // AdminPostCheck와 다른 관리자 페이지들을 import해야 합니다
    // 현재는 간단히 AdminDashboard만 반환
    return const AdminDashboard();
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