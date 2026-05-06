// lib/services/file_download_helper_web.dart
//
// 웹용 다운로드 helper (2026-05 PR-4).
// dart:html Blob + anchor element로 브라우저 다운로드 트리거.
// 사용자 다운로드 폴더에 직접 저장 — 시스템 viewer 분기 없음.

// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

typedef FileDownloadResult = String;

/// PDF/Excel bytes를 anchor element로 다운로드 트리거.
/// 백엔드가 이미 Content-Disposition으로 한글 파일명 지정해 주지만,
/// 브라우저별 처리 차이 회피를 위해 클라이언트 측에서도 명시적으로 지정.
Future<FileDownloadResult> saveAndOpenDownload({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
  return '$fileName 다운로드 완료';
}
