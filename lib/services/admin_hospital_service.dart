import 'dart:convert';
import 'auth_http_client.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
// 모델 클래스들은 lib/models/ 로 분리됨.
// 기존 `import '../services/admin_hospital_service.dart'` 사용처가 계속 동작하도록
// 아래 export로 심볼을 재노출. 신규 코드는 직접 모델 파일을 import 권장.
export '../models/hospital_info_model.dart';
export '../models/hospital_master_model.dart';

import '../models/hospital_info_model.dart';
import '../models/hospital_master_model.dart';

class AdminHospitalService {

  // 병원 목록 조회
  static Future<HospitalListResponse> getHospitalList({
    int page = 1,
    int pageSize = 10,
    String? search,
    bool? isActive,
    bool? approved,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      }
      if (approved != null) {
        queryParams['approved'] = approved.toString();
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminHospitalsList}',
      ).replace(queryParameters: queryParams);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 목록 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 목록 조회 중 오류 발생: $e');
    }
  }

  // 병원 검색
  static Future<HospitalListResponse> searchHospitals(
    HospitalSearchRequest request,
  ) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospitalsSearch}'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 검색에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 검색 중 오류 발생: $e');
    }
  }

  // 병원 상세 조회
  static Future<HospitalInfo> getHospitalDetail(int accountIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospital(accountIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 조회 중 오류 발생: $e');
    }
  }

  // 병원 정보 수정
  static Future<HospitalInfo> updateHospital(
    int accountIdx,
    HospitalUpdateRequest request,
  ) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospital(accountIdx)}'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        // API가 메시지만 반환하는 경우, 현재 병원 정보를 다시 조회
        if (data.containsKey('message') && !data.containsKey('account_idx')) {
          return await getHospitalDetail(accountIdx);
        }

        return HospitalInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 정보 수정에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 정보 수정 중 오류 발생: $e');
    }
  }

  // 병원 탈퇴 (삭제)
  static Future<void> deleteHospital(int accountIdx) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospital(accountIdx)}'),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 삭제 중 오류 발생: $e');
    }
  }

  // 병원 통계 조회
  static Future<Map<String, dynamic>> getHospitalStatistics() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospitalsStatistics}'),
      );

      if (response.statusCode == 200) {
        return response.parseJsonDynamic();
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('통계 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 통계 조회 중 오류 발생: $e');
    }
  }

  // ===== 병원 마스터 데이터 CRUD =====

  /// 병원 마스터 목록 조회 (서버 사이드 페이지네이션 + 검색).
  ///
  /// - [page]: 1-based 페이지 번호 (기본 1).
  /// - [pageSize]: 페이지 크기 (기본 20, 서버 max 100).
  /// - [search]: 코드 / 이름 / 주소 LIKE 검색어. 비어 있으면 전체 조회.
  ///
  /// 응답은 `{hospitals: [...], total_count: int}`. `total_count`는 **필터링 이후**
  /// 매칭된 전체 건수이므로 그대로 페이지 컨트롤 렌더에 사용 가능.
  static Future<HospitalMasterListResponse> getHospitalMasterList({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminHospitalsMaster}',
      ).replace(queryParameters: queryParams);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalMasterListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 마스터 목록 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 마스터 목록 조회 중 오류 발생: $e');
    }
  }

  /// 병원 마스터 등록
  static Future<HospitalMaster> registerHospitalMaster({
    required String hospitalName,
    String? hospitalAddress,
    String? hospitalPhone,
  }) async {
    try {
      final body = <String, dynamic>{
        'hospital_name': hospitalName,
      };
      if (hospitalAddress != null && hospitalAddress.isNotEmpty) {
        body['hospital_address'] = hospitalAddress;
      }
      if (hospitalPhone != null && hospitalPhone.isNotEmpty) {
        body['hospital_phone'] = hospitalPhone;
      }

      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospitalsMasterRegister}'),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.parseJsonDynamic();
        return HospitalMaster.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 등록에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 등록 중 오류 발생: $e');
    }
  }

  /// 병원 마스터 수정
  static Future<HospitalMaster> updateHospitalMaster(
    String hospitalCode, {
    String? hospitalName,
    String? hospitalAddress,
    String? hospitalPhone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (hospitalName != null) body['hospital_name'] = hospitalName;
      if (hospitalAddress != null) body['hospital_address'] = hospitalAddress;
      if (hospitalPhone != null) body['hospital_phone'] = hospitalPhone;

      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospitalMaster(hospitalCode)}'),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalMaster.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 수정에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 수정 중 오류 발생: $e');
    }
  }

  /// 병원 마스터 삭제
  static Future<void> deleteHospitalMaster(String hospitalCode) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminHospitalMaster(hospitalCode)}'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('병원 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('병원 삭제 중 오류 발생: $e');
    }
  }
}

// NOTE: 이 파일에 있던 모델 클래스 6개 (HospitalInfo, HospitalListResponse,
// HospitalUpdateRequest, HospitalSearchRequest, HospitalMaster,
// HospitalMasterListResponse)는 lib/models/ 하위로 이관되었습니다
// (2026-04 리팩토링). 이 파일 상단의 `export` 선언으로 기존 import는 그대로 동작합니다.
