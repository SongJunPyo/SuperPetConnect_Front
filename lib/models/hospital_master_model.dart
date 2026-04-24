// 병원 마스터 데이터(hospital_master 테이블) 관련 모델.
//
// - [HospitalMaster]             : 마스터 레코드 단건. `hospital_code`는 서버 자동 발급(H0001)이며 immutable.
// - [HospitalMasterListResponse] : `GET /api/admin/hospitals/master` 응답.
//   빈 검색: `{"hospitals": [], "total_count": 0}` — `hospitals`/`total_count` 모두 null 불가.
//
// API 계약 상세는 루트 CLAUDE.md "병원 마스터 데이터 API 계약" 섹션 참조.

class HospitalMaster {
  final int hospitalMasterIdx;

  /// 서버 자동 발급 코드 (포맷: H0001, H0002 ...). **immutable** — 수정 엔드포인트에서도 변경 불가.
  /// `accounts.hospital_code`가 이 값을 참조하므로 DB 레벨에서도 변경 금지.
  final String hospitalCode;

  final String hospitalName;
  final String? hospitalAddress;
  final String? hospitalPhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  HospitalMaster({
    required this.hospitalMasterIdx,
    required this.hospitalCode,
    required this.hospitalName,
    this.hospitalAddress,
    this.hospitalPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HospitalMaster.fromJson(Map<String, dynamic> json) {
    return HospitalMaster(
      hospitalMasterIdx: json['hospital_master_idx'] ?? 0,
      hospitalCode: json['hospital_code'] ?? '',
      hospitalName: json['hospital_name'] ?? '',
      hospitalAddress: json['hospital_address'],
      hospitalPhone: json['hospital_phone'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class HospitalMasterListResponse {
  final List<HospitalMaster> hospitals;

  /// 필터링 후 전체 건수. 서버가 `count or 0`으로 null 방지 보장.
  final int totalCount;

  HospitalMasterListResponse({
    required this.hospitals,
    required this.totalCount,
  });

  factory HospitalMasterListResponse.fromJson(dynamic jsonData) {
    List<dynamic> hospitalsData = [];
    Map<String, dynamic> json = {};

    if (jsonData is List) {
      hospitalsData = jsonData;
    } else if (jsonData is Map<String, dynamic>) {
      json = jsonData;
      hospitalsData = json['hospitals'] ?? json['data'] ?? [];
    }

    final hospitalsList = hospitalsData
        .map((h) => HospitalMaster.fromJson(h as Map<String, dynamic>))
        .toList();

    return HospitalMasterListResponse(
      hospitals: hospitalsList,
      totalCount:
          json['total_count'] ?? json['totalCount'] ?? hospitalsList.length,
    );
  }
}
