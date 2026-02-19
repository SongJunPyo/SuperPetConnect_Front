// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// 웹 브라우저에서 현재 탭을 해당 URL로 리다이렉트
void redirectToUrl(String url) {
  web.window.location.href = url;
}
