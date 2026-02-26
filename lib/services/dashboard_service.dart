import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../utils/app_constants.dart';
import '../models/unified_post_model.dart';
import '../models/column_post_model.dart';
import '../models/notice_post_model.dart';
import '../models/pagination_model.dart';
import '../models/dashboard_models.dart';
import 'auth_http_client.dart';

class DashboardService {
  static const int dashboardDonationLimit = AppConstants.dashboardItemLimit;
  static const int dashboardColumnLimit = AppConstants.dashboardItemLimit;
  static const int dashboardNoticeLimit = AppConstants.dashboardItemLimit;
  static const int detailListPageSize = AppConstants.detailListPageSize;

  // 통합 메인 대시보드 API
  static Future<DashboardResponse> getDashboardData({
    int donationLimit = dashboardDonationLimit,
    int columnLimit = dashboardColumnLimit,
    int noticeLimit = dashboardNoticeLimit,
  }) async {
    try {
      final queryParameters = <String, String>{};
      if (donationLimit != dashboardDonationLimit) {
        queryParameters['donation_limit'] = donationLimit.toString();
      }
      if (columnLimit != dashboardColumnLimit) {
        queryParameters['column_limit'] = columnLimit.toString();
      }
      if (noticeLimit != dashboardNoticeLimit) {
        queryParameters['notice_limit'] = noticeLimit.toString();
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.mainDashboard}',
      ).replace(
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return DashboardResponse.fromJson(data);
      } else {
        // API가 아직 구현되지 않은 경우 개별 API로 fallback
        return await _getFallbackDashboardData(
          donationLimit: donationLimit,
          columnLimit: columnLimit,
          noticeLimit: noticeLimit,
        );
      }
    } catch (e) {
      // 에러 발생 시 개별 API로 fallback
      return await _getFallbackDashboardData(
        donationLimit: donationLimit,
        columnLimit: columnLimit,
        noticeLimit: noticeLimit,
      );
    }
  }

  // Fallback: 개별 API들을 사용하여 데이터 수집
  static Future<DashboardResponse> _getFallbackDashboardData({
    required int donationLimit,
    required int columnLimit,
    required int noticeLimit,
  }) async {
    try {
      // 각 API를 병렬로 호출
      final futures = await Future.wait([
        getPublicPosts(limit: donationLimit),
        getPublicColumns(limit: columnLimit),
        getPublicNotices(limit: noticeLimit),
      ]);

      return DashboardResponse(
        success: true,
        data: DashboardData(
          donations: futures[0] as List<UnifiedPostModel>,
          columns: futures[1] as List<ColumnPost>,
          notices: futures[2] as List<NoticePost>,
          statistics: DashboardStatistics(
            activeDonations: (futures[0] as List<UnifiedPostModel>).length,
            totalPublishedColumns: (futures[1] as List<ColumnPost>).length,
            totalActiveNotices: (futures[2] as List<NoticePost>).length,
          ),
        ),
      );
    } catch (e) {
      throw Exception('대시보드 데이터 로드 실패: $e');
    }
  }

  // 개별 API: 헌혈 모집글 (통합 API 응답)
  // 서버에서 최신순(created_date DESC) 정렬하여 반환
  static Future<List<UnifiedPostModel>> getPublicPosts({
    int limit = 11,
    String? region,
    String? subRegion,
  }) async {
    try {
      Map<String, String> queryParams = {
        'page': '1',
        'page_size': limit.toString(),
      };

      // 지역 필터링 파라미터 추가
      if (region != null && region.isNotEmpty && region != '전체 지역') {
        queryParams['region'] = region;
        if (subRegion != null && subRegion.isNotEmpty) {
          queryParams['sub_region'] = subRegion;
        }
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.publicPosts}',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        List<dynamic> postsData;
        if (data is Map<String, dynamic>) {
          // 서버가 객체로 래핑한 경우
          postsData = data['items'] ?? data['posts'] ?? data['data'] ?? data['donations'] ?? [];
        } else if (data is List) {
          // 서버가 직접 리스트로 반환한 경우
          postsData = data;
        } else {
          postsData = [];
        }

        final posts =
            postsData
                .map((item) => UnifiedPostModel.fromJson(item))
                .toList();
        return posts;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('getPublicPosts error: $e');
      return [];
    }
  }

  /// 페이징 지원 공개 게시글 조회
  static Future<PaginatedPostsResult> fetchPublicPostsPage({
    int page = 1,
    int pageSize = detailListPageSize,
    String? region,
    String? subRegion,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (region != null && region.isNotEmpty && region != '전체 지역') {
        queryParameters['region'] = region;
        if (subRegion != null && subRegion.isNotEmpty) {
          queryParameters['sub_region'] = subRegion;
        }
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.publicPosts}',
      ).replace(queryParameters: queryParameters);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        List<dynamic> postsData;
        Map<String, dynamic>? paginationJson;

        if (data is Map<String, dynamic>) {
          postsData = data['items'] ?? data['posts'] ?? data['data'] ?? data['donations'] ?? [];
          paginationJson = data['pagination'] as Map<String, dynamic>?;
        } else if (data is List) {
          postsData = data;
        } else {
          postsData = [];
        }

        final posts = postsData
            .map((item) => UnifiedPostModel.fromJson(item))
            .toList();

        final pagination = paginationJson != null
            ? PaginationMeta.fromJson(paginationJson)
            : PaginationMeta.derived(
                currentPage: page,
                pageSize: pageSize,
                itemCount: posts.length,
              );

        return PaginatedPostsResult(posts: posts, pagination: pagination);
      } else {
        return PaginatedPostsResult(
          posts: [],
          pagination: PaginationMeta.singlePage(
            currentPage: page,
            pageSize: pageSize,
            totalCount: 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('fetchPublicPostsPage error: $e');
      return PaginatedPostsResult(
        posts: [],
        pagination: PaginationMeta.singlePage(
          currentPage: page,
          pageSize: pageSize,
          totalCount: 0,
        ),
      );
    }
  }

  /// 페이징 지원 관리자 게시글 조회 (인증 필요)
  static Future<PaginatedPostsResult> fetchAdminPostsPage({
    int page = 1,
    int pageSize = detailListPageSize,
    String? status,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParameters['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParameters['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParameters['end_date'] = endDate;
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPosts}',
      ).replace(queryParameters: queryParameters);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        List<dynamic> postsData;
        Map<String, dynamic>? paginationJson;

        if (data is Map<String, dynamic>) {
          postsData = data['items'] ?? data['posts'] ?? data['data'] ?? [];
          paginationJson = data['pagination'] as Map<String, dynamic>?;
        } else if (data is List) {
          postsData = data;
        } else {
          postsData = [];
        }

        final posts = postsData
            .map((item) => UnifiedPostModel.fromJson(item))
            .toList();

        final pagination = paginationJson != null
            ? PaginationMeta.fromJson(paginationJson)
            : PaginationMeta.derived(
                currentPage: page,
                pageSize: pageSize,
                itemCount: posts.length,
              );

        return PaginatedPostsResult(posts: posts, pagination: pagination);
      } else {
        return PaginatedPostsResult(
          posts: [],
          pagination: PaginationMeta.singlePage(
            currentPage: page,
            pageSize: pageSize,
            totalCount: 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('fetchAdminPostsPage error: $e');
      return PaginatedPostsResult(
        posts: [],
        pagination: PaginationMeta.singlePage(
          currentPage: page,
          pageSize: pageSize,
          totalCount: 0,
        ),
      );
    }
  }

  /// 페이징 지원 관리자 게시글 조회 - Raw JSON 반환 (기존 화면 호환)
  static Future<PaginatedRawPostsResult> fetchAdminPostsPageRaw({
    int page = 1,
    int pageSize = detailListPageSize,
    String? status,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParameters['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParameters['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParameters['end_date'] = endDate;
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPosts}',
      ).replace(queryParameters: queryParameters);

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        List<dynamic> postsData;
        Map<String, dynamic>? paginationJson;

        if (data is Map<String, dynamic>) {
          postsData = data['items'] ?? data['posts'] ?? data['data'] ?? [];
          paginationJson = data['pagination'] as Map<String, dynamic>?;
        } else if (data is List) {
          postsData = data;
        } else {
          postsData = [];
        }

        final posts = postsData
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        final pagination = paginationJson != null
            ? PaginationMeta.fromJson(paginationJson)
            : PaginationMeta.derived(
                currentPage: page,
                pageSize: pageSize,
                itemCount: posts.length,
              );

        return PaginatedRawPostsResult(posts: posts, pagination: pagination);
      } else {
        return PaginatedRawPostsResult(
          posts: [],
          pagination: PaginationMeta.singlePage(
            currentPage: page,
            pageSize: pageSize,
            totalCount: 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('fetchAdminPostsPageRaw error: $e');
      return PaginatedRawPostsResult(
        posts: [],
        pagination: PaginationMeta.singlePage(
          currentPage: page,
          pageSize: pageSize,
          totalCount: 0,
        ),
      );
    }
  }

  // 개별 API: 공개 칼럼
  static Future<List<ColumnPost>> getPublicColumns({
    int limit = dashboardColumnLimit,
  }) async {
    try {
      final pageSize = limit.clamp(1, detailListPageSize).toInt();
      final response = await fetchColumnsPage(page: 1, pageSize: pageSize);
      return response.columns.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PaginatedColumnsResult> fetchColumnsPage({
    int page = 1,
    int pageSize = detailListPageSize,
  }) async {
    final endpoints = [
      '${Config.serverUrl}${ApiEndpoints.publicColumns}',
      '${Config.serverUrl}${ApiEndpoints.columns}',
      '${Config.serverUrl}${ApiEndpoints.hospitalPublicColumns}',
    ];

    final queryParameters = <String, String>{};
    if (page > 1) {
      queryParameters['page'] = page.toString();
    }
    if (pageSize != detailListPageSize) {
      queryParameters['page_size'] = pageSize.toString();
    }

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint).replace(
          queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
        );

        final response = await http
            .get(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final rawData = response.parseJsonDynamic();
          final columnsData =
              (rawData is Map<String, dynamic> ? rawData['columns'] : null) ??
              (rawData is List ? rawData : []) ??
              [];

          final paginationJson =
              rawData is Map<String, dynamic> ? rawData['pagination'] : null;

          final columns =
              (columnsData as List).map((item) {
                return ColumnPost.fromJson(
                  (item as Map).cast<String, dynamic>(),
                );
              }).toList();

          final pagination =
              paginationJson is Map<String, dynamic>
                  ? PaginationMeta.fromJson(paginationJson)
                  : PaginationMeta.derived(
                    currentPage: page,
                    pageSize: pageSize,
                    itemCount: columns.length,
                  );

          return PaginatedColumnsResult(
            columns: columns,
            pagination: pagination,
          );
        }
      } catch (e) {
        if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
          break;
        }
        continue;
      }
    }

    throw Exception('칼럼 목록을 불러오지 못했습니다.');
  }

  // 개별 API: 공개 공지사항
  static Future<List<NoticePost>> getPublicNotices({
    int limit = dashboardNoticeLimit,
  }) async {
    try {
      final pageSize = limit.clamp(1, detailListPageSize).toInt();
      final response = await fetchNoticesPage(page: 1, pageSize: pageSize);
      return response.notices.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  // 개별 API: 인증된 공지사항 (병원/사용자 전용)
  static Future<List<NoticePost>> getAuthenticatedNotices({
    int limit = dashboardNoticeLimit,
  }) async {
    try {
      final pageSize = limit.clamp(1, detailListPageSize).toInt();
      final response = await fetchAuthenticatedNoticesPage(
        page: 1,
        pageSize: pageSize,
      );
      return response.notices.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PaginatedNoticesResult> fetchNoticesPage({
    int page = 1,
    int pageSize = detailListPageSize,
  }) async {
    final endpoints = [
      '${Config.serverUrl}${ApiEndpoints.publicNotices}',
      '${Config.serverUrl}${ApiEndpoints.notices}',
      '${Config.serverUrl}${ApiEndpoints.publicNotices}',
    ];

    final queryParameters = <String, String>{};
    if (page > 1) {
      queryParameters['page'] = page.toString();
    }
    if (pageSize != detailListPageSize) {
      queryParameters['page_size'] = pageSize.toString();
    }

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint).replace(
          queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
        );

        final response = await http
            .get(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final rawData = response.parseJsonDynamic();
          final noticesData =
              (rawData is Map<String, dynamic> ? rawData['notices'] : null) ??
              (rawData is List ? rawData : []) ??
              [];

          final paginationJson =
              rawData is Map<String, dynamic> ? rawData['pagination'] : null;

          final notices =
              (noticesData as List).map((item) {
                return NoticePost.fromJson(
                  (item as Map).cast<String, dynamic>(),
                );
              }).toList();

          final pagination =
              paginationJson is Map<String, dynamic>
                  ? PaginationMeta.fromJson(paginationJson)
                  : PaginationMeta.derived(
                    currentPage: page,
                    pageSize: pageSize,
                    itemCount: notices.length,
                  );

          return PaginatedNoticesResult(
            notices: notices,
            pagination: pagination,
          );
        }
      } catch (e) {
        if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
          break;
        }
        continue;
      }
    }

    throw Exception('공지 목록을 불러오지 못했습니다.');
  }

  // 인증된 공지사항 페이지 조회 (병원/사용자용)
  static Future<PaginatedNoticesResult> fetchAuthenticatedNoticesPage({
    int page = 1,
    int pageSize = detailListPageSize,
  }) async {
    try {
      final queryParameters = <String, String>{};
      if (page > 1) {
        queryParameters['page'] = page.toString();
      }
      if (pageSize != detailListPageSize) {
        queryParameters['page_size'] = pageSize.toString();
      }

      final uri = Uri.parse('${Config.serverUrl}${ApiEndpoints.notices}')
          .replace(
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );

      final response = await AuthHttpClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final rawData = response.parseJsonDynamic();
        final noticesData =
            (rawData is Map<String, dynamic> ? rawData['notices'] : null) ??
            (rawData is List ? rawData : []) ??
            [];

        final paginationJson =
            rawData is Map<String, dynamic> ? rawData['pagination'] : null;

        final notices =
            (noticesData as List).map((item) {
              return NoticePost.fromJson(
                (item as Map).cast<String, dynamic>(),
              );
            }).toList();

        final pagination =
            paginationJson is Map<String, dynamic>
                ? PaginationMeta.fromJson(paginationJson)
                : PaginationMeta.derived(
                  currentPage: page,
                  pageSize: pageSize,
                  itemCount: notices.length,
                );

        return PaginatedNoticesResult(
          notices: notices,
          pagination: pagination,
        );
      } else {
        throw Exception('공지 목록을 불러오지 못했습니다. (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('공지 목록을 불러오지 못했습니다: $e');
    }
  }

  // 개별 공지사항 상세 조회 API (조회수 자동 증가)
  // 인증된 API 사용 - 병원전용(target_audience=2) 공지도 조회 가능
  static Future<NoticePost?> getNoticeDetail(int noticeIdx) async {
    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.noticeDetail(noticeIdx)}',
      );

      final response = await AuthHttpClient.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return NoticePost.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 공개 공지사항 상세 조회 API (인증 불필요 - 웰컴페이지용)
  // /api/notices/{noticeIdx} 엔드포인트를 일반 http로 호출
  static Future<NoticePost?> getPublicNoticeDetail(int noticeIdx) async {
    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.noticeDetail(noticeIdx)}',
      );

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      });

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return NoticePost.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 상세 게시글 정보 및 헌혈 날짜 조회 (통합 API 응답)
  static Future<UnifiedPostModel?> getDonationPostDetail(int postIdx) async {
    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.publicPostDetail(postIdx)}',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJson();

        // 서버에서 통합된 UnifiedPostResponse 제공
        final donationPost = UnifiedPostModel.fromJson(data);

        return donationPost;
      } else {
        debugPrint('getDonationPostDetail error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('getDonationPostDetail error: $e');
      return null;
    }
  }
}
