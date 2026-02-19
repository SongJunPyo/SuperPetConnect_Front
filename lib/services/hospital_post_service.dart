import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/hospital_post_model.dart';
import '../models/donation_application_model.dart';
import '../models/post_time_item_model.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../utils/preferences_manager.dart';
import 'auth_http_client.dart';

class HospitalPostService {
  // 병원 코드 가져오기 (병원 사용자용)
  static Future<String?> _getHospitalCode() async {
    // 디버깅: SharedPreferences의 모든 관련 키 확인

    return await PreferencesManager.getHospitalCode();
  }

  // 병원의 헌혈 게시글 목록 조회
  static Future<List<HospitalPost>> getHospitalPosts({
    String? hospitalCode,
  }) async {
    try {
      String url = '${Config.serverUrl}${ApiEndpoints.publicPosts}';
      if (hospitalCode != null && hospitalCode.isNotEmpty) {
        url += '?hospital_code=$hospitalCode';
      }

      final response = await AuthHttpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          final posts =
              data.map((post) {
                return HospitalPost.fromJson(post);
              }).toList();
          return posts;
        }
        // 서버가 {posts: [...]} 형태로 반환하는 경우
        else if (data is Map && data['posts'] != null) {
          final posts =
              (data['posts'] as List).map((post) {
                return HospitalPost.fromJson(post);
              }).toList();
          return posts;
        }

        return [];
      } else {
        throw Exception('게시글 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 현재 병원 사용자의 게시글만 조회
  static Future<List<HospitalPost>> getHospitalPostsForCurrentUser() async {
    try {
      final hospitalCode = await _getHospitalCode();

      if (hospitalCode == null || hospitalCode.isEmpty) {
        return await getHospitalPosts();
      }

      // 먼저 기존 hospital API 시도
      try {
        final hospitalPosts = await _getHospitalPostsViaHospitalAPI();
        if (hospitalPosts.isNotEmpty) {
          return hospitalPosts;
        }
      } catch (e) {
        // 병원 게시물 조회 실패 시 다음 API 시도
        debugPrint('Failed to fetch hospital posts: $e');
      }

      // hospital API가 실패하거나 빈 결과면 필터링 API 시도
      final filteredPosts = await getHospitalPosts(hospitalCode: hospitalCode);
      if (filteredPosts.isNotEmpty) {
        return filteredPosts;
      }

      // 모두 실패하면 전체 게시글 조회
      return await getHospitalPosts();
    } catch (e) {
      // 에러 발생 시에도 전체 게시글 조회 시도
      try {
        return await getHospitalPosts();
      } catch (fallbackError) {
        rethrow; // 원래 에러 throw
      }
    }
  }

  // 기존 hospital API 사용
  static Future<List<HospitalPost>> _getHospitalPostsViaHospitalAPI() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalPosts}'),
    );

    if (response.statusCode == 200) {
      final data = response.parseJsonDynamic();
      debugPrint(
        '[HospitalPostService] API 응답 데이터 샘플: ${data is List && data.isNotEmpty ? data[0] : data}',
      );

      if (data is List) {
        return data.map((post) => HospitalPost.fromJson(post)).toList();
      } else if (data is Map && data['posts'] != null) {
        return (data['posts'] as List)
            .map((post) => HospitalPost.fromJson(post))
            .toList();
      }
      return [];
    } else {
      throw Exception('hospital API 호출 실패: ${response.statusCode}');
    }
  }

  // 특정 게시글의 신청자 목록 조회 (수정된 API 사용)
  static Future<ApplicationListResponse> getApplicants(String postId) async {
    try {
      final postIdInt = int.tryParse(postId) ?? 0;

      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.hospitalPostApplicants(postIdInt)}',
        ),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();

        // 새로운 API 응답 구조에 따른 파싱
        return ApplicationListResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('권한이 없습니다. 해당 게시글의 작성자만 신청자를 확인할 수 있습니다.');
      } else {
        throw response.toException('신청자 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 신청자 승인/거절 (수정된 API 사용)
  static Future<bool> updateApplicantStatus(
    int appliedDonationIdx,
    int statusCode, {
    String? hospitalNotes,
  }) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.appliedDonationStatus(appliedDonationIdx)}',
        ),
        body: json.encode({
          'status': statusCode,
          if (hospitalNotes != null) 'hospital_notes': hospitalNotes,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 403) {
        throw Exception('권한이 없습니다. 해당 신청에 대한 권한이 없습니다.');
      } else {
        throw response.toException('상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 게시글 상태 변경
  static Future<bool> updatePostStatus(String postIdx, String status) async {
    try {
      final postIdxInt = int.tryParse(postIdx) ?? 0;
      final response = await AuthHttpClient.put(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.hospitalPostStatus(postIdxInt)}',
        ),
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw response.toException('상태 변경에 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 게시글 삭제 (승인 대기 중인 게시글만 삭제 가능)
  static Future<bool> deletePost(String postIdx) async {
    try {
      final postIdxInt = int.tryParse(postIdx) ?? 0;
      final response = await AuthHttpClient.delete(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.hospitalPostDelete(postIdxInt)}',
        ),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 400) {
        throw Exception('승인 대기 중인 게시글만 삭제할 수 있습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('게시글을 찾을 수 없거나 삭제 권한이 없습니다.');
      } else {
        throw response.toException('게시글 삭제에 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 시간대별 게시글 조회 API ====================

  /// 시간대별 게시글 목록 조회
  ///
  /// [applicantStatus]: 신청자 상태 필터 (0-7)
  /// [postStatus]: 게시글 상태 필터 (0-4)
  /// [excludeApplicantStatus]: 제외할 신청자 상태 (예: "5,6")
  static Future<List<PostTimeItem>> getPostTimes({
    int? applicantStatus,
    int? postStatus,
    String? excludeApplicantStatus,
  }) async {
    try {
      // 쿼리 파라미터 구성
      final queryParams = <String, String>{};
      if (applicantStatus != null) {
        queryParams['applicant_status'] = applicantStatus.toString();
      }
      if (postStatus != null) {
        queryParams['post_status'] = postStatus.toString();
      }
      if (excludeApplicantStatus != null && excludeApplicantStatus.isNotEmpty) {
        queryParams['exclude_applicant_status'] = excludeApplicantStatus;
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.hospitalPostTimes}',
      ).replace(queryParameters: queryParams);

      debugPrint('Fetching post-times: $uri');

      final response = await AuthHttpClient.get(uri);

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        // 서버 응답이 { "success": true, "post_times": [...] } 형태
        if (data is Map && data['post_times'] != null) {
          final postTimesList =
              (data['post_times'] as List)
                  .map((item) => PostTimeItem.fromJson(item))
                  .toList();
          debugPrint('Fetched ${postTimesList.length} post-times');
          return postTimesList;
        }
        // 또는 직접 배열 반환
        else if (data is List) {
          final postTimesList =
              data.map((item) => PostTimeItem.fromJson(item)).toList();
          debugPrint('Fetched ${postTimesList.length} post-times');
          return postTimesList;
        }

        return [];
      } else {
        throw Exception('시간대별 게시글 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      debugPrint('Error fetching post-times: $e');
      rethrow;
    }
  }

  /// 모집거절 게시글 목록 조회
  static Future<List<RejectedPost>> getRejectedPosts() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalPostsRejected}'),
      );

      debugPrint('getRejectedPosts response status: ${response.statusCode}');

      // 422 에러 발생 시 대체 방법 시도: post_status=2로 시간대별 조회
      if (response.statusCode == 422) {
        debugPrint(
          '422 error - trying alternative method with getPostTimes(postStatus=2)',
        );
        return await getRejectedPostsViaPostTimes();
      }

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        // 서버 응답이 { "success": true, "posts": [...] } 형태
        if (data is Map && data['posts'] != null) {
          final rejectedPostsList =
              (data['posts'] as List)
                  .map((item) => RejectedPost.fromJson(item))
                  .toList();
          debugPrint('Fetched ${rejectedPostsList.length} rejected posts');
          return rejectedPostsList;
        }
        // 또는 직접 배열 반환
        else if (data is List) {
          final rejectedPostsList =
              data.map((item) => RejectedPost.fromJson(item)).toList();
          debugPrint('Fetched ${rejectedPostsList.length} rejected posts');
          return rejectedPostsList;
        }

        return [];
      } else {
        throw Exception('모집거절 게시글 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      debugPrint('Error fetching rejected posts: $e');
      rethrow;
    }
  }

  /// 대체 방법: post_status=2로 거절된 게시글 조회
  static Future<List<RejectedPost>> getRejectedPostsViaPostTimes() async {
    try {
      debugPrint(
        'Fetching rejected posts via post-times API with postStatus=2',
      );

      // post_status=2 (모집거절)인 시간대 조회
      final postTimeItems = await getPostTimes(postStatus: 2);

      debugPrint(
        'Found ${postTimeItems.length} time-slot items with postStatus=2',
      );

      // PostTimeItem을 RejectedPost로 변환 (중복 제거)
      final Map<int, RejectedPost> rejectedPostsMap = {};

      for (var item in postTimeItems) {
        if (!rejectedPostsMap.containsKey(item.postIdx)) {
          rejectedPostsMap[item.postIdx] = RejectedPost(
            postIdx: item.postIdx,
            title: item.postTitle,
            description: item.postDescription,
            types: item.postTypes,
            status: item.postStatus,
            rejectionReason: null, // 시간대 API에서는 거절 사유 없음
            createdDate: item.createdDate,
            rejectedDate: null, // 시간대 API에서는 거절 날짜 없음
          );
        }
      }

      final rejectedPosts = rejectedPostsMap.values.toList();
      debugPrint('Converted to ${rejectedPosts.length} unique rejected posts');

      return rejectedPosts;
    } catch (e) {
      debugPrint('Error in getRejectedPostsViaPostTimes: $e');
      rethrow;
    }
  }
}
