import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/hospital_column_model.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import 'auth_http_client.dart';

class HospitalColumnService {

  // 병원의 칼럼 작성 권한 확인
  static Future<bool> checkColumnPermission() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.authProfile}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return data['column_active'] == true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 칼럼 작성 (병원 전용)
  static Future<HospitalColumn> createColumn(
    HospitalColumnCreateRequest request,
  ) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumns}'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.parseJsonDynamic();
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 403) {
        throw response.toException('병원 계정만 접근할 수 있습니다. 또는 칼럼 작성 권한이 비활성화되었습니다.');
      } else if (response.statusCode == 500) {
        throw response.toException('서버에서 오류가 발생했습니다. 관리자에게 문의하세요.');
      } else {
        throw response.toException('칼럼 작성에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('칼럼 작성 중 오류 발생: $e');
    }
  }

  // 공개 칼럼 목록 조회 (모든 사용자 - 인증 불필요)
  static Future<HospitalColumnListResponse> getPublicColumns({
    int page = 1,
    int pageSize = 10,
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
        '${Config.serverUrl}${ApiEndpoints.hospitalPublicColumns}',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumnListResponse.fromJson(data);
      } else {
        throw response.toException('칼럼 목록 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('칼럼 목록 조회 중 오류 발생: $e');
    }
  }

  // 서버 API 테스트용 함수 (인증 불필요)
  static Future<void> testServerConnection() async {
    try {
      // 공개 칼럼 목록 조회 테스트 (인증 불필요)
      await http.get(Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalPublicColumns}?page=1&page_size=10'));
    } catch (e) {
      // 테스트 연결 실패 시 로그 출력
      debugPrint('Server connection test failed: $e');
    }
  }

  // 공개 칼럼 상세 조회 (인증 불필요 - 웰컴 페이지 등 로그인 전 화면에서 사용)
  static Future<HospitalColumn> getPublicColumnDetail(int columnIdx) async {
    final endpoints = [
      '${Config.serverUrl}${ApiEndpoints.columnDetail(columnIdx)}',
      '${Config.serverUrl}${ApiEndpoints.hospitalPublicColumn(columnIdx)}',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(Uri.parse(endpoint));
        if (response.statusCode == 200) {
          final data = response.parseJsonDynamic();
          return HospitalColumn.fromJson(data);
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception('칼럼을 불러오지 못했습니다.');
  }

  // 칼럼 상세 조회 (인증된 사용자 - 미발행 칼럼도 조회 가능)
  static Future<HospitalColumn> getColumnDetail(int columnIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumn(columnIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        // 404 또는 403인 경우 "내 칼럼" 목록에서 찾아보기
        try {
          final myColumns = await getMyColumns(page: 1, pageSize: 50);
          final targetColumn = myColumns.columns.firstWhere(
            (column) => column.columnIdx == columnIdx,
          );
          return targetColumn;
        } catch (e) {
          if (response.statusCode == 403) {
            throw Exception('칼럼 조회 권한이 없습니다. 작성자만 조회할 수 있습니다.');
          }
          throw Exception('칼럼을 찾을 수 없습니다.');
        }
      } else {
        throw response.toException('칼럼 조회에 실패했습니다.');
      }
    } catch (e) {
      if (e.toString().contains('칼럼을 찾을 수 없습니다')) {
        rethrow;
      }
      throw Exception('칼럼 조회 중 오류 발생: $e');
    }
  }

  // 내 칼럼 목록 조회 (병원 전용)
  static Future<HospitalColumnListResponse> getMyColumns({
    int page = 1,
    int pageSize = 10,
    bool? isPublished,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isPublished != null) {
        queryParams['is_published'] = isPublished.toString();
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.hospitalColumnsMy}',
      ).replace(queryParameters: queryParams);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumnListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw response.toException('권한이 없습니다.');
      } else {
        throw response.toException('내 칼럼 목록 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('내 칼럼 목록 조회 중 오류 발생: $e');
    }
  }

  // 칼럼 수정 (작성자만)
  static Future<HospitalColumn> updateColumn(
    int columnIdx,
    HospitalColumnUpdateRequest request,
  ) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumn(columnIdx)}'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('수정 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        throw response.toException('칼럼 수정에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('칼럼 수정 중 오류 발생: $e');
    }
  }

  // 칼럼 삭제 (작성자만)
  static Future<void> deleteColumn(int columnIdx) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumn(columnIdx)}'),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 403) {
        throw Exception('삭제 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        throw response.toException('칼럼 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('칼럼 삭제 중 오류 발생: $e');
    }
  }

  // 관리자용: 모든 칼럼 목록 조회 (새로운 전용 API 사용)
  static Future<HospitalColumnListResponse> getAllColumns({
    int page = 1,
    int pageSize = 20,
    bool? isPublished,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isPublished != null) {
        queryParams['is_published'] = isPublished.toString();
      }

      if (startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }

      if (endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminColumns}',
      ).replace(queryParameters: queryParams);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumnListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 없습니다.');
      } else {
        throw response.toException('관리자 칼럼 목록 조회에 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 관리자용: 칼럼 발행 승인/해제 (전용 API 사용)
  static Future<HospitalColumn> adminTogglePublish(int columnIdx) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminColumnPublish(columnIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        throw response.toException('공개 상태 변경에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('공개 상태 변경 중 오류 발생: $e');
    }
  }

  // 조회수 증가 (세션 스토리지로 중복 방지)
  // 인증 여부에 관계없이 동작해야 하므로 토큰이 있으면 인증 요청, 없으면 비인증 요청
  static Future<void> increaseViewCount(int columnIdx) async {
    try {
      // AuthHttpClient 사용 시도 (토큰이 있으면 인증 헤더 포함)
      try {
        final response = await AuthHttpClient.post(
          Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumnView(columnIdx)}'),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return;
        }
      } catch (_) {
        // 인증 실패 시 비인증 요청으로 fallback
        final response = await http.post(
          Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumnView(columnIdx)}'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return;
        }
      }
    } catch (e) {
      // 조회수 증가 실패는 사용자 경험에 영향을 주지 않도록 예외를 던지지 않음
    }
  }

  // 관리자용: 칼럼 상세 조회 (전용 API 사용)
  static Future<HospitalColumn> getAdminColumnDetail(int columnIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminColumn(columnIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        throw response.toException('관리자 칼럼 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('관리자 칼럼 조회 중 오류 발생: $e');
    }
  }
}
