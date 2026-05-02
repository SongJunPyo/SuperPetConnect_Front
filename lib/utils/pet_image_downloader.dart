import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'pet_image_downloader_io.dart'
    if (dart.library.html) 'pet_image_downloader_web.dart' as platform;

/// 펫 프로필 사진을 받아 플랫폼별 위치에 저장하는 단일 진입점.
///
/// - **모바일**: `gal` 패키지로 시스템 사진 갤러리(iOS Photos / Android Pictures)에 저장
/// - **웹**: `web` 패키지로 Blob → AnchorElement.click() 트리거하여 브라우저 다운로드
///
/// 호출 측은 결과 enum으로 케이스 분기 (성공/네트워크 실패/권한 거부/저장 실패).
enum DownloadResult {
  success,
  networkFailed,
  permissionDenied,
  saveFailed,
}

class PetImageDownloader {
  /// 이미지 URL을 받아 다운로드 → 플랫폼별 저장.
  ///
  /// [imageUrl]은 절대 URL이어야 함 (호출 측에서 `getFullImageUrl`로 prefix 처리).
  /// [filename]은 확장자 포함 (예: `2026-05-10_14-00_초코.jpg`).
  static Future<DownloadResult> downloadFromUrl({
    required String imageUrl,
    required String filename,
  }) async {
    // 1. 이미지 바이트 fetch
    final Uint8List bytes;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        debugPrint('PetImageDownloader: HTTP ${response.statusCode} from $imageUrl');
        return DownloadResult.networkFailed;
      }
      bytes = response.bodyBytes;
    } catch (e) {
      debugPrint('PetImageDownloader: fetch failed - $e');
      return DownloadResult.networkFailed;
    }

    // 2. 플랫폼별 저장
    try {
      await platform.savePetImage(bytes, filename);
      return DownloadResult.success;
    } on PetImagePermissionException {
      return DownloadResult.permissionDenied;
    } catch (e) {
      debugPrint('PetImageDownloader: save failed - $e');
      return DownloadResult.saveFailed;
    }
  }
}

/// 모바일에서 갤러리 권한이 거부되었을 때 throw.
class PetImagePermissionException implements Exception {
  final String message;
  PetImagePermissionException(this.message);

  @override
  String toString() => 'PetImagePermissionException: $message';
}
