import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../utils/app_constants.dart';
import '../models/donation_post_model.dart';
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
          donations: futures[0] as List<DonationPost>,
          columns: futures[1] as List<ColumnPost>,
          notices: futures[2] as List<NoticePost>,
          statistics: DashboardStatistics(
            activeDonations: (futures[0] as List<DonationPost>).length,
            totalPublishedColumns: (futures[1] as List<ColumnPost>).length,
            totalActiveNotices: (futures[2] as List<NoticePost>).length,
          ),
        ),
      );
    } catch (e) {
      throw Exception('대시보드 데이터 로드 실패: $e');
    }
  }

  // 개별 API: 헌혈 모집글
  static Future<List<DonationPost>> getPublicPosts({
    int limit = 11,
    String? region,
    String? subRegion,
  }) async {
    try {
      Map<String, String> queryParams = {};

      // 지역 필터링 파라미터 추가
      if (region != null && region.isNotEmpty && region != '전체 지역') {
        queryParams['region'] = region;
        if (subRegion != null && subRegion.isNotEmpty) {
          queryParams['sub_region'] = subRegion;
        }
      }

      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.publicPosts}',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        List<dynamic> postsData;
        if (data is Map<String, dynamic>) {
          // 서버가 객체로 래핑한 경우
          postsData = data['posts'] ?? data['data'] ?? data['donations'] ?? [];
        } else if (data is List) {
          // 서버가 직접 리스트로 반환한 경우
          postsData = data;
        } else {
          postsData = [];
        }

        final posts =
            postsData
                .take(limit)
                .map((item) => DonationPost.fromJson(item))
                .toList();
        return posts;
      } else {
        return [];
      }
    } catch (e) {
      return [];
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
  static Future<NoticePost?> getNoticeDetail(int noticeIdx) async {
    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.publicNoticeDetail(noticeIdx)}',
      );

      final response = await http.get(uri);

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

  // 상세 게시글 정보 및 헌혈 날짜 조회 (통합 데이터 사용)
  static Future<DonationPost?> getDonationPostDetail(int postIdx) async {
    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.publicPostDetail(postIdx)}',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.parseJson();

        // 서버에서 통합된 데이터를 제공하므로 바로 DonationPost 생성
        final donationPost = DonationPost.fromJson(data);

        return donationPost;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
