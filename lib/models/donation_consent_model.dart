// lib/models/donation_consent_model.dart
//
// 헌혈 사전 정보 동의 모델 (2026-05 PR-2).
// 백엔드 GET /api/donation-consent/items 응답 + POST 설문 시 보내는 5개 동의 페이로드.

/// 동의 항목 5개 중 하나 (백엔드 키와 1:1 매칭).
///
/// 카페 설문지 25~29번. 백엔드 `donation_consent` 테이블의 `agree_*` 컬럼과 동일.
class DonationConsentItem {
  /// `agree_read_guidance` 등 백엔드 컬럼 키. POST 본문 키로도 사용.
  final String key;
  final String title;
  final String body;

  const DonationConsentItem({
    required this.key,
    required this.title,
    required this.body,
  });

  factory DonationConsentItem.fromJson(Map<String, dynamic> json) {
    return DonationConsentItem(
      key: json['key'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

/// `GET /api/donation-consent/items` 응답.
///
/// 신청 시점 / 설문 시점 모두 같은 응답 사용:
/// - 신청 시점: `guidance_html` 마크다운만 노출 + 단일 정독 체크박스 (DB 저장 X)
/// - 설문 시점: `guidance_html` + `items` 5개 체크박스 (DB 저장)
class DonationConsentItems {
  final String guidanceHtml; // 마크다운 — flutter_markdown으로 렌더
  final List<DonationConsentItem> items;
  /// 동의 시점에 `donation_consent.terms_version_at_consent`로 박제됨.
  final String version;

  const DonationConsentItems({
    required this.guidanceHtml,
    required this.items,
    required this.version,
  });

  factory DonationConsentItems.fromJson(Map<String, dynamic> json) {
    return DonationConsentItems(
      guidanceHtml: json['guidance_html'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => DonationConsentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as String,
    );
  }
}

/// 설문 제출 시 동의 5개 페이로드. 모두 true 필수 — 하나라도 false면 400 CONSENT_REQUIRED.
class DonationConsentPayload {
  final bool agreeReadGuidance;
  final bool agreeFamilyConsent;
  final bool agreeSufficientRest;
  final bool agreeAssociationCooperation;
  final bool agreeUnderstandingOperation;

  const DonationConsentPayload({
    required this.agreeReadGuidance,
    required this.agreeFamilyConsent,
    required this.agreeSufficientRest,
    required this.agreeAssociationCooperation,
    required this.agreeUnderstandingOperation,
  });

  /// 5개 모두 true인지 검사. POST 직전 클라이언트 측 가드.
  bool get isAllAgreed =>
      agreeReadGuidance &&
      agreeFamilyConsent &&
      agreeSufficientRest &&
      agreeAssociationCooperation &&
      agreeUnderstandingOperation;

  Map<String, dynamic> toJson() => {
        'agree_read_guidance': agreeReadGuidance,
        'agree_family_consent': agreeFamilyConsent,
        'agree_sufficient_rest': agreeSufficientRest,
        'agree_association_cooperation': agreeAssociationCooperation,
        'agree_understanding_operation': agreeUnderstandingOperation,
      };
}
