import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/applied_donation_model.dart';
import '../services/auth_http_client.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/time_format_util.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';

/// 관리자 게시글 관리의 Tab 2(헌혈마감) 전용 위젯.
///
/// **두 종류의 데이터를 한 화면에 합쳐 보여주는 mixed 탭**:
/// 1. `applied_donation.status = PENDING_COMPLETION(2)` — 병원이 1차 완료 처리한
///    신청. post 형태로 변환되며 `is_completion_pending=true`로 마킹.
/// 2. `donation_posts.status = 3 (모집마감)` — 게시글 자체가 마감된 것.
///    donation_posts 형식 그대로.
///
/// 행 탭 시 `is_completion_pending` 분기에 따라 부모가 어떤 시트를 열지 결정 —
/// PENDING_COMPLETION이면 신청자 시트(헌혈 마감 승인용), 모집마감 게시글이면
/// 일반 게시글 상세 시트.
///
/// 부모와의 인터페이스:
/// - `searchQuery` 변경 시 클라이언트 필터(donation_posts는 서버, applied_donation은
///   클라이언트라 부모는 search/날짜를 query로 보내지만 첫 번째는 서버 응답에
///   반영, 두 번째는 클라이언트 필터로 동일하게 처리 — 기존 동작 보존).
/// - `onTapPost(post)` — 행 탭 시 부모가 시트 분기.
/// - 부모는 GlobalKey&lt;AdminPendingCompletionsTabState&gt;로 [refresh]를 호출해
///   헌혈 마감 최종 승인 후 목록 갱신.
class AdminPendingCompletionsTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(Map<String, dynamic> post) onTapPost;

  const AdminPendingCompletionsTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapPost,
  });

  @override
  State<AdminPendingCompletionsTab> createState() =>
      AdminPendingCompletionsTabState();
}

class AdminPendingCompletionsTabState
    extends State<AdminPendingCompletionsTab> {
  /// 변환된 PENDING_COMPLETION 신청 + 모집마감 게시글이 합쳐진 리스트.
  List<Map<String, dynamic>> _allPosts = [];
  bool isLoading = true;
  String errorMessage = '';

  int _currentPage = 1;
  int _totalPages = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPendingCompletions();
  }

  @override
  void didUpdateWidget(covariant AdminPendingCompletionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      _currentPage = 1;
      _fetchPendingCompletions();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _fetchPendingCompletions();

  Future<void> _fetchPendingCompletions() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // 1) PENDING_COMPLETION(2) — applied_donation 기반
      final apiUrl2 =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/${AppliedDonationStatus.pendingCompletion}';
      final response2 = await AuthHttpClient.get(Uri.parse(apiUrl2));

      // 2) 모집마감(donation_posts.status=3) — 서버 측 search/date query 적용
      final closedQuery = <String>['status=헌혈마감', 'page_size=100'];
      if (widget.searchQuery.isNotEmpty) {
        closedQuery.add('search=${Uri.encodeComponent(widget.searchQuery)}');
      }
      if (widget.startDate != null) {
        closedQuery.add(
          'start_date=${DateFormat('yyyy-MM-dd').format(widget.startDate!)}',
        );
      }
      if (widget.endDate != null) {
        closedQuery.add(
          'end_date=${DateFormat('yyyy-MM-dd').format(widget.endDate!)}',
        );
      }
      final apiUrl3 =
          '${Config.serverUrl}/api/admin/posts?${closedQuery.join('&')}';
      final response3 = await AuthHttpClient.get(Uri.parse(apiUrl3));

      if (response2.statusCode == 401 || response3.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
          isLoading = false;
        });
        return;
      }

      if (response2.statusCode != 200 && response3.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          errorMessage =
              '헌혈 마감 목록을 불러오는데 실패했습니다. status=2: ${response2.statusCode}, status=3: ${response3.statusCode}';
          isLoading = false;
        });
        return;
      }

      // PENDING_COMPLETION 응답 파싱 + 변환
      final List<Map<String, dynamic>> convertedPosts = [];
      if (response2.statusCode == 200) {
        final data2 = json.decode(utf8.decode(response2.bodyBytes));
        List<Map<String, dynamic>> raw2 = [];
        if (data2 is List) {
          raw2 = List<Map<String, dynamic>>.from(data2);
        } else if (data2 is Map && data2['donations'] != null) {
          raw2 = List<Map<String, dynamic>>.from(data2['donations']);
        }
        convertedPosts.addAll(raw2.map(_convertToPost));
      }

      // 모집마감 응답 파싱 - donation_posts 형식 그대로 사용 + status=3 보장
      final List<Map<String, dynamic>> closedPosts = [];
      if (response3.statusCode == 200) {
        final data3 = json.decode(utf8.decode(response3.bodyBytes));
        if (data3 is Map) {
          final list3 = data3['items'] ?? data3['posts'] ?? [];
          closedPosts.addAll(List<Map<String, dynamic>>.from(list3));
        } else if (data3 is List) {
          closedPosts.addAll(List<Map<String, dynamic>>.from(data3));
        }
        for (final post in closedPosts) {
          post['status'] = 3;
        }
      }

      if (!mounted) return;
      setState(() {
        _allPosts = [...convertedPosts, ...closedPosts];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '헌혈 마감 데이터 로드 실패: $e';
        isLoading = false;
      });
    }
  }

  /// applied_donation(status=2)을 post 형태로 변환.
  Map<String, dynamic> _convertToPost(Map<String, dynamic> app) {
    String animalType = 'unknown';
    if (app['pet'] != null) {
      final petAnimalType = app['pet']['animal_type']?.toString() ??
          app['pet']['species']?.toString() ??
          '';
      if (petAnimalType == '0' ||
          petAnimalType.toLowerCase() == 'dog' ||
          petAnimalType == '강아지') {
        animalType = 'dog';
      } else if (petAnimalType == '1' ||
          petAnimalType.toLowerCase() == 'cat' ||
          petAnimalType == '고양이') {
        animalType = 'cat';
      }
    }
    if (animalType == 'unknown' && app['animal_type'] != null) {
      final apiAnimalType = app['animal_type'].toString();
      if (apiAnimalType == '0' || apiAnimalType.toLowerCase() == 'dog') {
        animalType = 'dog';
      } else if (apiAnimalType == '1' || apiAnimalType.toLowerCase() == 'cat') {
        animalType = 'cat';
      }
    }

    final title = app['post_title']?.toString() ?? '';
    if (animalType == 'unknown') {
      if (title.contains('강아지')) {
        animalType = 'dog';
      } else if (title.contains('고양이')) {
        animalType = 'cat';
      }
    }

    int types = 1;
    if (title.contains('긴급')) types = 0;

    final location = app['hospital_address'] ??
        '${app['hospital_name'] ?? '병원'} (병원 코드: ${app['hospital_code'] ?? ''})';

    final donationTime = app['donation_time'] as String?;
    final donationDateStr = donationTime != null && donationTime.length >= 10
        ? donationTime.substring(0, 10)
        : '';
    final donationTimeStr = donationTime != null && donationTime.length >= 16
        ? donationTime.substring(11, 16)
        : '';

    return {
      'id': app['applied_donation_idx'],
      'application_id': app['applied_donation_idx'],
      'title': app['post_title'] ?? '헌혈 요청',
      'nickname': app['hospital_name'] ?? '병원',
      'location': location,
      'created_date': app['created_at']?.substring(0, 10) ?? '',
      'animalType': animalType,
      'types': types,
      'blood_type': app['pet']?['blood_type'] ?? '상관없음',
      'applicantCount': 1,
      'description': app['description'] ?? '병원에서 1차 완료 처리된 헌혈입니다.',
      'status': app['status'],
      'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
      'pet_breed': app['pet']?['breed'] ?? app['pet_breed'],
      'pet_blood_type': app['pet']?['blood_type'],
      'pet_idx': app['pet']?['pet_idx'] ?? app['pet_idx'],
      'user_name': app['user_name'] ?? app['name'],
      'user_nickname': app['user_nickname'] ?? '',
      'blood_volume': app['blood_volume'],
      'completed_at': app['completed_at'],
      'incompletion_reason': app['incompletion_reason'],
      'donation_date': donationTime ?? app['donation_date'] ?? '',
      'is_completion_pending': true,
      'timeRanges': donationTime != null
          ? [
              {
                'id': app['applied_donation_idx'],
                'donation_date': donationDateStr,
                'time': donationTimeStr,
                'status': 0,
              },
            ]
          : <Map<String, dynamic>>[],
      'availableDates': donationTime != null
          ? {
              donationDateStr: [
                {
                  'post_times_idx': app['applied_donation_idx'],
                  'time': donationTimeStr,
                  'datetime': donationTime,
                },
              ],
            }
          : <String, List<Map<String, dynamic>>>{},
    };
  }

  /// 클라이언트 측 검색·날짜 필터(서버 필터와 이중 적용 — 기존 동작 보존) +
  /// 페이지네이션.
  List<Map<String, dynamic>> get filteredPosts {
    var filtered = _allPosts;

    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = filtered.where((post) {
        final title = post['title']?.toString().toLowerCase() ?? '';
        final content = post['content']?.toString().toLowerCase() ?? '';
        final hospitalName =
            post['hospital_name']?.toString().toLowerCase() ?? '';
        return title.contains(query) ||
            content.contains(query) ||
            hospitalName.contains(query);
      }).toList();
    }

    if (widget.startDate != null && widget.endDate != null) {
      filtered = filtered.where((post) {
        final createdAt = DateTime.tryParse(post['created_at'] ?? '');
        if (createdAt == null) return false;
        return createdAt.isAfter(widget.startDate!) &&
            createdAt.isBefore(widget.endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Tab 2 전용 게시글 뱃지 라벨.
  /// PENDING_COMPLETION(2)이면 '완료대기', 모집마감(3)이면 '마감'.
  String _getPostType(Map<String, dynamic> post) {
    return post['status'] == AppliedDonationStatus.pendingCompletion
        ? '완료대기'
        : '마감';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('헌혈 마감 목록을 불러오고 있습니다...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.red[500]),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: refresh,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final posts = filteredPosts;
    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                '마감이 필요한 게시글이 없습니다.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final paginationBarCount = _totalPages > 1 ? 1 : 0;
    final postCount = posts.length;

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: postCount + 1 + paginationBarCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const PostListHeader();
          }
          if (index > postCount) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }
          final post = posts[index - 1];
          return PostListRow(
            badgeType: _getPostType(post),
            title: post['title'] ?? '제목 없음',
            dateText: TimeFormatUtils.formatFlexibleShortDate(
              post['createdDate'] ??
                  post['created_date'] ??
                  post['created_at'],
            ),
            hospitalProfileImage: post['hospitalProfileImage'] ??
                post['hospital_profile_image'],
            onTap: () => widget.onTapPost(post),
          );
        },
      ),
    );
  }
}
