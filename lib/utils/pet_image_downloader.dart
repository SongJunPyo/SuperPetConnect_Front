import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_theme.dart';
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

/// SnackBar 피드백 포함된 다운로드 호출 — hospital / admin 시트 공통 사용.
///
/// imageUrl은 절대 URL (호출 측에서 `getFullImageUrl` 처리).
/// filename은 확장자 포함 (예: `2026-05-10_14-00_초코.jpg`).
Future<void> downloadPetImageWithFeedback({
  required BuildContext context,
  required String imageUrl,
  required String filename,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('사진을 받는 중...'),
      duration: Duration(seconds: 2),
    ),
  );

  final result = await PetImageDownloader.downloadFromUrl(
    imageUrl: imageUrl,
    filename: filename,
  );

  // ignore: use_build_context_synchronously
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();

  switch (result) {
    case DownloadResult.success:
      messenger.showSnackBar(
        const SnackBar(
          content: Text('사진을 저장했습니다.'),
          backgroundColor: AppTheme.success,
        ),
      );
      break;
    case DownloadResult.networkFailed:
      messenger.showSnackBar(
        const SnackBar(
          content: Text('사진을 받지 못했습니다. 네트워크를 확인해주세요.'),
          backgroundColor: AppTheme.error,
        ),
      );
      break;
    case DownloadResult.permissionDenied:
      messenger.showSnackBar(
        const SnackBar(
          content: Text('갤러리 접근 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.'),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 4),
        ),
      );
      break;
    case DownloadResult.saveFailed:
      messenger.showSnackBar(
        const SnackBar(
          content: Text('사진 저장에 실패했습니다.'),
          backgroundColor: AppTheme.error,
        ),
      );
      break;
  }
}
