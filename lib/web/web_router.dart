import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_post_check.dart';
import '../admin/admin_approved_posts.dart';
import '../admin/admin_signup_management.dart';
import '../admin/admin_hospital_check.dart';
import '../auth/login.dart';
import '../auth/welcome.dart';

class WebRouter {
  static const String welcome = '/';
  static const String login = '/login';
  static const String adminDashboard = '/admin';
  static const String adminPostCheck = '/admin/posts';
  static const String adminApprovedPosts = '/admin/approved-posts';
  static const String adminSignupManagement = '/admin/signup';
  static const String adminHospitalCheck = '/admin/hospitals';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());
      
      case adminPostCheck:
        return MaterialPageRoute(builder: (_) => const AdminPostCheck());
      
      case adminApprovedPosts:
        return MaterialPageRoute(builder: (_) => const AdminApprovedPostsScreen());
      
      case adminSignupManagement:
        return MaterialPageRoute(builder: (_) => const AdminSignupManagement());
      
      case adminHospitalCheck:
        return MaterialPageRoute(builder: (_) => const AdminHospitalCheck());
      
      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundPage(),
        );
    }
  }

  static String? getInitialRoute() {
    if (kIsWeb) {
      // 웹에서는 URL에 따라 초기 라우트 결정
      final uri = Uri.base;
      if (uri.path.startsWith('/admin')) {
        return uri.path;
      }
      return uri.path == '/' ? welcome : uri.path;
    }
    return null; // 모바일에서는 기본 라우팅 사용
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