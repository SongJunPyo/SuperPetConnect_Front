// services/black_list_service.dart

import 'dart:convert';
import 'auth_http_client.dart';
import '../models/black_list_model.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';

class BlackListService {

  // ===== 블랙리스트 관리 API =====

  // 1. 블랙리스트 등록 (관리자)
  static Future<BlackList> createBlackList(
    BlackListCreateRequest request,
  ) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.blackList}'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.parseJson();
        return BlackList.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('블랙리스트 등록에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('블랙리스트 등록 중 오류 발생: $e');
    }
  }

  // 2. 블랙리스트 목록 조회 (관리자)
  static Future<BlackListResponse> getBlackLists({
    int page = 1,
    int pageSize = 10,
    String? search,
    bool? activeOnly, // true: 정지 중, false: 해제됨, null: 전체
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (activeOnly != null) {
        queryParams['active_only'] = activeOnly.toString();
      }

      final uri = Uri.parse('${Config.serverUrl}${ApiEndpoints.blackList}').replace(queryParameters: queryParams);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return BlackListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('블랙리스트 목록 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('블랙리스트 목록 조회 중 오류 발생: $e');
    }
  }

  // 3. 특정 블랙리스트 상세 조회 (관리자)
  static Future<BlackList> getBlackListDetail(int blackUserIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.blackListDetail(blackUserIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return BlackList.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        throw response.toException('블랙리스트 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('블랙리스트 조회 중 오류 발생: $e');
    }
  }

  // 4. 블랙리스트 정보 수정 (관리자)
  static Future<BlackList> updateBlackList(
    int blackUserIdx,
    BlackListUpdateRequest request,
  ) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.blackListDetail(blackUserIdx)}'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return BlackList.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else {
        throw response.toException('블랙리스트 수정에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('블랙리스트 수정 중 오류 발생: $e');
    }
  }

  // 5. 블랙리스트 삭제 (관리자)
  static Future<void> deleteBlackList(int blackUserIdx) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.blackListDetail(blackUserIdx)}'),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else {
        throw response.toException('블랙리스트 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('블랙리스트 삭제 중 오류 발생: $e');
    }
  }

  // 6. 즉시 해제 (관리자)
  static Future<BlackList> releaseBlackList(int blackUserIdx) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.blackListRelease(blackUserIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return BlackList.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else {
        throw response.toException('즉시 해제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('블랙리스트 해제 중 오류 발생: $e');
    }
  }

  // 7. 사용자 정지 상태 확인 (본인 또는 관리자)
  static Future<UserBlackListStatus> getUserBlackListStatus(
    int accountIdx,
  ) async {
    try {
      final url =
          '${Config.serverUrl}${ApiEndpoints.adminUserBlackListStatus(accountIdx)}';

      final response = await AuthHttpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return UserBlackListStatus.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('사용자를 찾을 수 없습니다.');
      } else {
        throw response.toException('사용자 상태 확인에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('사용자 상태 확인 중 오류 발생: $e');
    }
  }

  // ===== 편의 메서드 =====

  // 8. 현재 활성화된 블랙리스트만 조회
  static Future<List<BlackList>> getActiveBlackLists({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final response = await getBlackLists(
      page: page,
      pageSize: pageSize,
      search: search,
      activeOnly: true,
    );
    return response.blackLists;
  }

  // 9. 해제된 블랙리스트만 조회
  static Future<List<BlackList>> getReleasedBlackLists({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final response = await getBlackLists(
      page: page,
      pageSize: pageSize,
      search: search,
      activeOnly: false,
    );
    return response.blackLists;
  }

  // 10. 사용자가 현재 정지 중인지 확인
  static Future<bool> isUserSuspended(int accountIdx) async {
    try {
      final status = await getUserBlackListStatus(accountIdx);
      return status.isSuspended;
    } catch (e) {
      return false; // 확인 실패 시 정지되지 않은 것으로 간주
    }
  }

  // 11. 특정 사용자의 현재 블랙리스트 정보 조회
  static Future<BlackList?> getUserCurrentBlackList(int accountIdx) async {
    try {
      final blackLists = await getActiveBlackLists(
        pageSize: 100,
      ); // 충분히 큰 페이지 크기

      for (final blackList in blackLists) {
        if (blackList.accountIdx == accountIdx && blackList.isActive) {
          return blackList;
        }
      }

      return null; // 활성화된 블랙리스트가 없음
    } catch (e) {
      return null;
    }
  }

  // 12. 블랙리스트 검색 (이메일, 이름, 전화번호로 검색)
  static Future<List<BlackList>> searchBlackLists(String query) async {
    final response = await getBlackLists(
      page: 1,
      pageSize: 50, // 검색 결과는 적당한 크기로 제한
      search: query,
    );
    return response.blackLists;
  }
}
