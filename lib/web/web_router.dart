import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_post_check.dart';
import '../admin/admin_approved_posts.dart';
import '../admin/admin_signup_management.dart';
import '../admin/admin_hospital_check.dart';
import '../hospital/hospital_dashboard.dart';
import '../user/user_dashboard.dart';
import '../auth/login.dart';
import '../auth/welcome.dart';
import 'auth_guard.dart';

class WebRouter {
  static const String welcome = '/';
  static const String login = '/login';
  static const String adminDashboard = '/admin';
  static const String hospitalDashboard = '/hospital';
  static const String userDashboard = '/user';
  static const String adminPostCheck = '/admin/posts';
  static const String adminApprovedPosts = '/admin/approved-posts';
  static const String adminSignupManagement = '/admin/signup';
  static const String adminHospitalCheck = '/admin/hospitals';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '/';
    
    // 로그인 페이지만 인증 없이 접근 가능
    if (routeName == login) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
    
    // 모든 경로(루트 경로 포함)는 AuthGuard를 통해 인증 확인
    return MaterialPageRoute(
      builder: (_) => AuthGuard(requestedPath: routeName),
    );
  }

  static String? getInitialRoute() {
    if (kIsWeb) {
      // 웹에서는 JWT 토큰 상태를 확인하여 초기 라우트 결정
      return _getAuthenticatedRoute();
    }
    return null; // 모바일에서는 기본 라우팅 사용
  }

  static String _getAuthenticatedRoute() {
    // 웹에서 새로고침 시 현재 URL을 기반으로 라우트 반환
    // 실제 인증 확인은 AuthGuard에서 처리
    final uri = Uri.base;
    final route = uri.path == '/' ? welcome : uri.path;
    print('WebRouter: 현재 URL: ${uri.path}, 결정된 라우트: $route');
    return route;
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('페이지를 찾을 수 없음'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '404 - 페이지를 찾을 수 없습니다',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '요청하신 페이지가 존재하지 않습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, WebRouter.welcome);
              },
              child: const Text('홈으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}