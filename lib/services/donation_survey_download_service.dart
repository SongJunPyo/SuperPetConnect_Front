// lib/services/donation_survey_download_service.dart
//
// 헌혈 설문 PDF/Excel 다운로드 (2026-05 PR-4).
//
// 4 endpoint:
// - admin 단건 PDF / 게시글 일괄 Excel
// - hospital 단건 PDF / 게시글 일괄 Excel
//
// 백엔드 응답:
// - Content-Type: application/pdf 또는 application/vnd.openxmlformats-...sheet
// - Content-Disposition: attachment; filename*=UTF-8''<%encoded 한글>
//
// 한글 파일명 처리: RFC 5987 (filename*=UTF-8'') 수동 percent-decode.
// 모바일 = 임시 저장 + 시스템 viewer / 웹 = anchor download — 플랫폼 conditional import.

import 'dart:typed_data';

import 'auth_http_client.dart';
import '../utils/api_endpoints.dart';
import '../utils/config.dart';
import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

class DonationSurveyDownloadService {
  DonationSurveyDownloadService._();

  static const String _pdfMime = 'application/pdf';
  static const String _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// 관리자 단건 PDF 다운로드 + 시스템 viewer.
  static Future<String> downloadAdminSurveyPdf(int surveyIdx) {
    return _download(
      uri: Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminDonationSurveyPdf(surveyIdx)}',
      ),
      fallbackName: 'admin_survey_$surveyIdx.pdf',
      mimeType: _pdfMime,
    );
  }

  /// 관리자 게시글 일괄 Excel 다운로드.
  static Future<String> downloadAdminPostSurveysXlsx(int postIdx) {
    return _download(
      uri: Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostDonationSurveysXlsx(postIdx)}',
      ),
      fallbackName: 'admin_post_${postIdx}_surveys.xlsx',
      mimeType: _xlsxMime,
    );
  }

  /// 병원 단건 PDF 다운로드 (assert_hospital_owns_application 가드 대상).
  static Future<String> downloadHospitalSurveyPdf(int surveyIdx) {
    return _download(
      uri: Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.hospitalDonationSurveyPdf(surveyIdx)}',
      ),
      fallbackName: 'hospital_survey_$surveyIdx.pdf',
      mimeType: _pdfMime,
    );
  }

  /// 병원 게시글 일괄 Excel 다운로드 (assert_hospital_owns_post 가드 대상).
  static Future<String> downloadHospitalPostSurveysXlsx(int postIdx) {
    return _download(
      uri: Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.hospitalPostDonationSurveysXlsx(postIdx)}',
      ),
      fallbackName: 'hospital_post_${postIdx}_surveys.xlsx',
      mimeType: _xlsxMime,
    );
  }

  /// 인증된 GET 요청 → bytes 추출 → 헤더에서 파일명 파싱 → 플랫폼별 저장/열기.
  static Future<String> _download({
    required Uri uri,
    required String fallbackName,
    required String mimeType,
  }) async {
    final response = await AuthHttpClient.get(uri);
    if (response.statusCode != 200) {
      throw response.toException('파일을 불러오지 못했습니다.');
    }
    final fileName = _extractFileName(
          response.headers['content-disposition'],
        ) ??
        fallbackName;
    final bytes = Uint8List.fromList(response.bodyBytes);
    return saveAndOpenDownload(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  /// `Content-Disposition` 헤더에서 파일명 추출.
  ///
  /// 백엔드는 RFC 5987 `filename*=UTF-8''<percent-encoded>` 형식 사용.
  /// 호환성을 위해 `filename="..."` (구형 ASCII) 도 fallback 처리.
  /// 둘 다 없으면 null 반환 — 호출 측이 fallback 이름 사용.
  static String? _extractFileName(String? headerValue) {
    if (headerValue == null || headerValue.isEmpty) return null;

    // RFC 5987: filename*=UTF-8''<%encoded>
    // 정규식 — 인코딩 라벨(보통 UTF-8) 무시하고 본문만 percent-decode.
    final extMatch = RegExp(
      r"filename\*\s*=\s*([^']+)'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(headerValue);
    if (extMatch != null) {
      final encodedName = extMatch.group(2)!.trim();
      try {
        return Uri.decodeComponent(encodedName);
      } catch (_) {
        // 디코드 실패 시 다음 fallback으로 진행.
      }
    }

    // 구형 ASCII filename="..." fallback.
    final asciiMatch = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(headerValue);
    if (asciiMatch != null) {
      return asciiMatch.group(1)!.trim();
    }
    return null;
  }
}
