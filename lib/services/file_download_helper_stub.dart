// lib/services/file_download_helper_stub.dart
//
// dart:html이 없는 환경(모바일/데스크톱)을 위한 stub.
// 실제 호출은 io 변형이 처리. 본 파일은 conditional import의 unreachable 분기.

import 'dart:typed_data';

/// 다운로드 결과: 사용자에게 보여줄 안내 메시지 (저장 경로 또는 "다운로드 완료").
typedef FileDownloadResult = String;

Future<FileDownloadResult> saveAndOpenDownload({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Stub fallback should not be invoked.');
}
