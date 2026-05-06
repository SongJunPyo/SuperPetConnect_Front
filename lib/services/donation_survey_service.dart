// lib/services/donation_survey_service.dart
//
// 헌혈 사전 정보 설문 시스템 API wrapper (2026-05 PR-2).
// 5개 endpoint:
//   - GET /api/donation-consent/items
//   - GET /api/applied-donations/{id}/survey/template
//   - GET /api/applied-donations/{id}/survey
//   - POST /api/applied-donations/{id}/survey
//   - PATCH /api/applied-donations/{id}/survey
//
// 모든 호출은 AuthHttpClient로 인증 필요. 본인 신청만 접근 가능 (백엔드 가드).

import 'dart:convert';

import '../models/donation_consent_model.dart';
import '../models/donation_survey_model.dart';
import '../utils/api_endpoints.dart';
import '../utils/config.dart';
import 'auth_http_client.dart';

class DonationSurveyService {
  DonationSurveyService._();

  /// 동의 텍스트 + 5개 동의 항목 조회.
  /// 신청 시점에는 `guidanceHtml`만 마크다운 렌더 + 단일 정독 체크박스 (DB 저장 X).
  /// 설문 시점에는 `items` 5개 체크박스도 함께 노출 + DB 저장.
  static Future<DonationConsentItems> getConsentItems() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}${ApiEndpoints.donationConsentItems}'),
    );
    if (response.statusCode != 200) {
      throw response.toException('동의 항목을 불러오지 못했습니다.');
    }
    return DonationConsentItems.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 설문 작성용 자동 채움 데이터 조회 (status==APPROVED 신청만 200).
  /// 거절 사유:
  /// - 403 PERMISSION_DENIED: 본인 신청 아님
  /// - 404 APPLICATION_NOT_FOUND
  /// - 400 SURVEY_NOT_EDITABLE_NOT_APPROVED: PENDING/PENDING_COMPLETION/COMPLETED/CLOSED
  static Future<DonationSurveyTemplate> getTemplate(int applicationId) async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.donationSurveyTemplate(applicationId)}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('설문 양식을 불러오지 못했습니다.');
    }
    return DonationSurveyTemplate.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 본인 설문 조회 (잠금 후에도 200 — read-only로 표시).
  /// 거절: 403 PERMISSION_DENIED, 404 SURVEY_NOT_FOUND (POST 먼저 필요).
  static Future<DonationSurveyResponse> getSurvey(int applicationId) async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.donationSurvey(applicationId)}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('설문을 불러오지 못했습니다.');
    }
    return DonationSurveyResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 설문 신규 작성 (1신청당 1설문).
  /// 거절:
  /// - 400 CONSENT_REQUIRED: 5개 동의 중 하나라도 false
  /// - 400 SURVEY_NOT_EDITABLE_NOT_APPROVED: status != APPROVED
  /// - 403 PERMISSION_DENIED
  /// - 404 APPLICATION_NOT_FOUND
  /// - 409 SURVEY_ALREADY_EXISTS (이미 작성 → PATCH로 전환)
  static Future<DonationSurveyResponse> createSurvey(
    int applicationId,
    DonationSurveyPayload payload,
  ) async {
    final response = await AuthHttpClient.post(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.donationSurvey(applicationId)}',
      ),
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw response.toException('설문 제출에 실패했습니다.');
    }
    return DonationSurveyResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 설문 부분 수정 (exclude_unset — null 필드는 보내지 않음).
  /// 거절:
  /// - 400 SURVEY_LOCKED: 헌혈 D-2 23:55 이후 잠금됨
  /// - 400 SURVEY_NOT_EDITABLE_NOT_APPROVED
  /// - 403 PERMISSION_DENIED
  /// - 404 SURVEY_NOT_FOUND (POST 먼저 필요)
  ///
  /// 옵션 A+C: admin이 열람한 상태에서 수정하면 admin_reviewed_at NULL로 복귀
  /// → 관리자에게 재검토 알림 emit (PR-5에서 추가).
  static Future<DonationSurveyResponse> updateSurvey(
    int applicationId,
    DonationSurveyPayload payload,
  ) async {
    final response = await AuthHttpClient.patch(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.donationSurvey(applicationId)}',
      ),
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode != 200) {
      throw response.toException('설문 수정에 실패했습니다.');
    }
    return DonationSurveyResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

/// 관리자 설문 조회 API wrapper (2026-05 PR-3).
///
/// 인증 + account_type==1 가드 (백엔드). 호출자 측 추가 가드 불필요.
class AdminSurveyService {
  AdminSurveyService._();

  /// 관리자 설문 목록 + 필터 + 페이지네이션 + 배지 카운트.
  /// 응답에 `pending_count` 포함 — 별도 `getPendingCount()` 호출 안 해도 배지 갱신 가능.
  static Future<DonationSurveyListResponse> getList(
    AdminSurveyListFilter filter,
  ) async {
    final uri = Uri.parse(
      '${Config.serverUrl}${ApiEndpoints.adminDonationSurveys}',
    ).replace(queryParameters: filter.toQueryParameters());
    final response = await AuthHttpClient.get(uri);
    if (response.statusCode != 200) {
      throw response.toException('설문 목록을 불러오지 못했습니다.');
    }
    return DonationSurveyListResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 검토 대기 카운트만 조회 (배지 전용 경량 endpoint).
  /// 알림 페이지/대시보드 진입 시 빠르게 호출.
  static Future<int> getPendingCount() async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminDonationSurveysPendingCount}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('검토 대기 카운트를 불러오지 못했습니다.');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['pending_count'] as num?)?.toInt() ?? 0;
  }

  /// 관리자 설문 단건 조회 — **첫 GET 시 옵션 a 자동 PATCH 발생**
  /// (admin_reviewed_at = NOW + admin_reviewed_by 설정).
  /// 두 번째 이후 호출은 read-only.
  static Future<DonationSurveyResponse> getSurvey(int surveyIdx) async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminDonationSurvey(surveyIdx)}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('설문을 불러오지 못했습니다.');
    }
    return DonationSurveyResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 게시글별 설문 일괄 조회 (admin).
  /// 응답 스키마는 `getList` 형식과 동일. 게시글 단위 워크플로우 (전체 신청자 일괄 검토용).
  static Future<DonationSurveyListResponse> getByPost(int postIdx) async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostDonationSurveys(postIdx)}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('게시글 설문을 불러오지 못했습니다.');
    }
    return DonationSurveyListResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

/// 병원 설문 조회 API wrapper (2026-05 PR-3).
///
/// 인증 + account_type==2 + 본인 병원 게시글만 (백엔드 권한 격리).
/// 단건: assert_hospital_owns_application — 다른 병원 → 403
/// 목록: WHERE post.hospital_idx = current.hospital_idx 자동 필터
class HospitalSurveyService {
  HospitalSurveyService._();

  /// 병원 자기 게시글의 신청자 설문 일괄 조회.
  static Future<DonationSurveyListResponse> getByPost(int postIdx) async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.hospitalPostDonationSurveys(postIdx)}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('게시글 설문을 불러오지 못했습니다.');
    }
    return DonationSurveyListResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 병원 설문 단건 조회 (본인 병원 신청만, 그 외 403 PERMISSION_DENIED).
  static Future<DonationSurveyResponse> getSurvey(int surveyIdx) async {
    final response = await AuthHttpClient.get(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.hospitalDonationSurvey(surveyIdx)}',
      ),
    );
    if (response.statusCode != 200) {
      throw response.toException('설문을 불러오지 못했습니다.');
    }
    return DonationSurveyResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
