// 웹 펫 이미지 저장 — web 패키지로 브라우저 다운로드 트리거.
// pet_image_downloader.dart의 conditional import로 자동 선택됨 (dart:html이 있는 환경).

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Blob → AnchorElement.click()으로 브라우저 다운로드 트리거.
/// 권한 개념 없음 — 사용자가 다운로드 폴더 / 저장 위치를 결정.
Future<void> savePetImage(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: _inferMimeType(filename)),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

/// 확장자로 MIME type 추정 — Blob을 정확한 type으로 만들면 일부 브라우저에서
/// "Save image as" 컨텍스트 메뉴가 더 자연스럽게 동작.
String _inferMimeType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
