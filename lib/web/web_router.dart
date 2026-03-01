import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth/login.dart';
import '../auth/naver_callback.dart';
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
  static const String naverCallback = '/naver-callback';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '/';

    // 로그인 페이지만 인증 없이 접근 가능
    if (routeName == login) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    }

    // 네이버 로그인 콜백 (인증 없이 접근 가능)
    // access_token이 없으면 콜백 처리 불가 → AuthGuard로 리다이렉트
    // (로그아웃 후 URL에 /naver-callback 경로만 남은 경우 자동 재로그인 방지)
    if (routeName == naverCallback) {
      final queryParams = Uri.base.queryParameters;
      if (queryParams.containsKey('access_token')) {
        return MaterialPageRoute(
          builder: (_) => NaverCallbackScreen(queryParams: queryParams),
        );
      }
      // access_token 없으면 일반 인증 체크로 이동
      return MaterialPageRoute(
        builder: (_) => AuthGuard(requestedPath: '/'),
      );
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
    final uri = Uri.base;

    // 네이버 콜백: URL에 access_token이 있으면 직접 /naver-callback 라우트로 시작
    // 이렇게 하면 didPushRoute 충돌 없이 NaverCallbackScreen이 바로 생성됨
    if (uri.queryParameters.containsKey('access_token')) {
      return naverCallback;
    }

    // 일반 접근: 실제 인증 확인은 AuthGuard에서 처리
    return uri.path == '/' ? welcome : uri.path;
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

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
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
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
