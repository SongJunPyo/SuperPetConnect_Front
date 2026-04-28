// 가입 직후 펫 사진 일괄 업로드 헬퍼.
//
// 이메일/네이버 가입 응답에 포함된 `pet_idxs[]` 배열을 받아 폼에서 메모리로 보관 중인
// `pets[i].profileImage`(XFile)를 `pet_idxs[i]`에 multipart 업로드.
// 백엔드 contract: 가입 응답의 `access_token`은 미승인 상태여도 본인 소유 펫의 사진
// 업로드/삭제만 허용 (CLAUDE.md "가입 직후 access_token 정책" 섹션).
//
// 호출자는 이 함수 호출 전에 토큰을 PreferencesManager에 이미 저장한 상태여야 함.
// 함수는 토큰을 직접 헤더에 붙여 multipart 호출, 토큰 정리는 호출자 책임.

import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import '../widgets/registration_pet_manager.dart';

class RegistrationPetPhotoUploadResult {
  final int total; // 시도 건수 (사진 선택한 펫 수)
  final int success;
  final int failed;
  const RegistrationPetPhotoUploadResult({
    required this.total,
    required this.success,
    required this.failed,
  });

  bool get hasFailure => failed > 0;
  bool get hasNoUploads => total == 0;
}

/// 가입 응답의 [petIdxs]와 폼의 [pets]를 인덱스 매칭하여 사진을 일괄 업로드.
/// 사진 선택 안 한 펫은 자동 스킵. 부분 실패는 카운트만 집계하고 throw 안 함.
Future<RegistrationPetPhotoUploadResult> uploadRegistrationPetPhotos({
  required List<RegistrationPetData> pets,
  required List<int> petIdxs,
}) async {
  if (pets.length != petIdxs.length) {
    // pet_idxs[i] ↔ pets[i] 인덱스 1:1 일치가 contract라서 길이 불일치는
    // 백엔드 응답 깨진 상태. 안전하게 짧은 쪽 길이로 매칭하고 진행.
  }
  final maxLen = pets.length < petIdxs.length ? pets.length : petIdxs.length;
  int total = 0;
  int success = 0;
  int failed = 0;

  final token = await PreferencesManager.getAuthToken();

  for (int i = 0; i < maxLen; i++) {
    final image = pets[i].profileImage;
    if (image == null) continue;
    total++;

    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.petProfileImage(petIdxs[i])}',
      );
      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: image.name),
      );

      final streamedResponse = await request.send();
      final statusCode = streamedResponse.statusCode;
      // PENDING 펫이라 검토 워크플로우 진입 안 함 → 200만 성공.
      // (202는 APPROVED 펫의 사진 변경 흐름이며 가입 시점에는 발생 안 함)
      if (statusCode == 200) {
        success++;
      } else {
        failed++;
      }
    } catch (_) {
      failed++;
    }
  }

  return RegistrationPetPhotoUploadResult(
    total: total,
    success: success,
    failed: failed,
  );
}
