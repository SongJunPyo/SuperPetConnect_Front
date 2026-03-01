// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// 웹 브라우저의 localStorage/sessionStorage/쿠키를 직접 관리하는 헬퍼
class WebStorageHelper {
  /// localStorage, sessionStorage, 쿠키 등 모든 인증 관련 데이터를 완전히 삭제
  static void clearAll() {
    try {
      // localStorage 전체 삭제 (이 도메인의 모든 데이터)
      web.window.localStorage.clear();

      // sessionStorage도 삭제
      web.window.sessionStorage.clear();

      // 브라우저 쿠키 삭제 (서버 세션 쿠키가 남아있으면 F5 시 자동 로그인됨)
      _clearAllCookies();
    } catch (_) {
      // 스토리지 삭제 실패 시 무시
    }
  }

  /// 현재 도메인의 모든 쿠키를 삭제
  /// (httpOnly 쿠키는 JS에서 접근 불가 → 서버 logout API에서 처리 필요)
  static void _clearAllCookies() {
    try {
      final cookieStr = web.document.cookie;
      if (cookieStr.isEmpty) return;

      final cookies = cookieStr.split(';');
      final hostname = web.window.location.hostname;
      for (final cookie in cookies) {
        final name = cookie.split('=')[0].trim();
        if (name.isNotEmpty) {
          // 다양한 path/domain 조합으로 쿠키 삭제 시도
          web.document.cookie =
              '$name=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/';
          web.document.cookie =
              '$name=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=$hostname';
        }
      }
    } catch (_) {
      // 쿠키 삭제 실패 시 무시
    }
  }

  /// localStorage에 인증 토큰이 있는지 직접 확인
  /// SharedPreferences의 인메모리 캐시를 우회하여 실제 localStorage 값을 확인
  static bool hasAuthToken() {
    try {
      final token = web.window.localStorage.getItem('flutter.auth_token');
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// localStorage에 인증 토큰이 남아있는지 확인 (디버깅용)
  static void dumpAuthKeys() {
    // 디버깅 완료 - no-op
  }
}
