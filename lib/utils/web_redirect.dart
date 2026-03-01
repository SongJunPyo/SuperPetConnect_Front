// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// 웹 브라우저에서 현재 탭을 해당 URL로 리다이렉트
void redirectToUrl(String url) {
  web.window.location.href = url;
}

/// 브라우저 URL에서 쿼리 파라미터를 제거하여 새로고침 시 재처리 방지
/// (네이버 콜백 등에서 access_token이 URL에 남아있는 문제 해결)
///
/// Flutter hash URL 전략과 호환: hash 부분(#/naver-callback)은 보존하여
/// 렌더링 중 라우트 변경으로 인한 에러를 방지
void clearUrlQueryParams() {
  try {
    // hash 부분을 보존하여 Flutter 라우터 간섭 방지
    final hash = web.window.location.hash;
    final newUrl = '/${hash.isNotEmpty ? hash : ''}';
    web.window.history.replaceState(null, '', newUrl);
  } catch (_) {
    // replaceState 실패 시 무시
  }
}
