// lib/services/file_download_helper_io.dart
//
// 모바일/데스크톱용 다운로드 helper (2026-05 PR-4).
// 임시 디렉토리에 파일 저장 → 시스템 viewer로 열기.
// iOS는 share sheet 호환, Android는 적절한 viewer 자동 매칭.

import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

typedef FileDownloadResult = String;

/// PDF/Excel bytes를 임시 디렉토리에 저장하고 OS 기본 viewer로 연다.
///
/// 반환값은 사용자에게 보여줄 안내 메시지 (저장 경로 또는 viewer 안내).
/// 실패 시 throw — 호출 측이 SnackBar 등으로 표시.
Future<FileDownloadResult> saveAndOpenDownload({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  // 파일명 충돌 방지를 위해 timestamp prefix. 한글 파일명 그대로 보존.
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${dir.path}${Platform.pathSeparator}${timestamp}_$fileName');
  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(file.path, type: mimeType);
  if (result.type != ResultType.done) {
    // 열기 실패 — 저장은 되었으니 경로 안내. 사용자가 파일 매니저로 접근 가능.
    return '저장됨: ${file.path}';
  }
  return '$fileName 다운로드 완료';
}
