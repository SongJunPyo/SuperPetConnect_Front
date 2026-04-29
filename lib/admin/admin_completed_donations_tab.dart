import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/applied_donation_model.dart';
import '../services/auth_http_client.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/time_format_util.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';

/// 관리자 게시글 관리의 Tab 3(헌혈완료) 전용 위젯.
///
/// `applied_donation.status = COMPLETED(3)` 레코드를 게시글 형태로 변환해 표시.
/// 읽기 전용 — 승인/거절 / 시간대 마감 / 상태 변경 액션 없음. 행 탭 시 부모의
/// 헌혈완료 신청자 시트(`_openCompletionApplicantSheet`)로 위임.
///
/// 부모와의 인터페이스:
/// - `searchQuery` / `startDate` / `endDate`는 props로 받아 클라이언트 측 필터.
///   Tab 3 API(`/applied_donation/admin/by-status/3`)는 query 미지원이라
///   전체 fetch 후 메모리 필터링 (서버 측 필터 도입 시 fetchData에서 분기).
/// - `onTapPost(post)` — 행 탭 시 부모가 [showCompletionApplicantSheet]를 열도록
///   delegate.
/// - 부모는 GlobalKey&lt;AdminCompletedDonationsTabState&gt;로 [refresh]를 호출 가능.
class AdminCompletedDonationsTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(Map<String, dynamic> post) onTapPost;

  const AdminCompletedDonationsTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapPost,
  });

  @override
  State<AdminCompletedDonationsTab> createState() =>
      AdminCompletedDonationsTabState();
}

class AdminCompletedDonationsTabState
    extends State<AdminCompletedDonationsTab> {
  /// 서버에서 받아 변환한 게시글 형태의 리스트 전체. 검색/날짜 필터는
  /// [filteredPosts]에서 메모리로 적용.
  List<Map<String, dynamic>> _allPosts = [];
  bool isLoading = true;
  String errorMessage = '';

  int _currentPage = 1;
  int _totalPages = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchCompletedDonations();
  }

  @override
  void didUpdateWidget(covariant AdminCompletedDonationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 검색/날짜는 클라이언트 필터이므로 refetch 없이 페이지만 1로 리셋 후 rebuild.
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      setState(() {
        _currentPage = 1;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _fetchCompletedDonations();

  Future<void> _fetchCompletedDonations() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final apiUrl =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/${AppliedDonationStatus.completed}';
      final response = await AuthHttpClient.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List<Map<String, dynamic>> raw = [];
        if (data is List) {
          raw = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['donations'] != null) {
          raw = List<Map<String, dynamic>>.from(data['donations']);
        }

        if (!mounted) return;
        setState(() {
          _allPosts = raw.map(_convertToPost).toList();
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = '헌혈완료 목록을 불러오는데 실패했습니다: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '헌혈완료 데이터 로드 실패: $e';
        isLoading = false;
      });
    }
  }

  /// applied_donation 응답을 게시글(post) 형태로 변환.
  ///
  /// 시트/리스트 행이 사용하는 키를 통합된 형태로 노출 — 변경하지 말 것.
  Map<String, dynamic> _convertToPost(Map<String, dynamic> app) {
    String createdAt = app['created_at'] ?? '';
    if (createdAt.contains('T')) {
      createdAt = createdAt.split('T')[0];
    } else if (createdAt.length > 10) {
      createdAt = createdAt.substring(0, 10);
    }

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
        app['hospital_location'] ??
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
      'title': app['post_title'] ?? '헌혈 완료',
      'nickname':
          app['hospital_nickname'] ?? app['hospital_name'] ?? '병원',
      'location': location,
      'created_date': createdAt,
      'animalType': animalType,
      'types': types,
      'blood_type': app['emergency_blood_type'] ?? '상관없음',
      'pet_blood_type': app['pet']?['blood_type'],
      'applicantCount': 1,
      'description': app['description'],
      'contentDelta': app['content_delta'],
      'blood_volume': app['blood_volume'],
      'status': AppliedDonationStatus.completed,
      'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
      'pet_breed': app['pet']?['breed'] ?? app['pet_breed'],
      'pet_idx': app['pet']?['pet_idx'] ?? app['pet_idx'],
      'user_name': app['user_name'] ?? app['name'],
      'user_nickname': app['user_nickname'] ?? '',
      'completed_at': app['completed_at'],
      'donation_date': donationTime ?? app['donation_date'] ?? '',
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
      'applications': [
        {
          'applied_donation_idx': app['applied_donation_idx'],
          'status': AppliedDonationStatus.completed,
          'user_email': app['user_email'],
          'user_nickname':
              app['user_nickname'] ?? app['nickname'] ?? '',
          'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
          'donation_time': donationTime ?? '',
        },
      ],
    };
  }

  /// 검색/날짜 필터 적용 후 페이지네이션 슬라이스 반환.
  List<Map<String, dynamic>> get filteredPosts {
    var filtered = _allPosts;

    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = filtered.where((post) {
        final title = post['title']?.toString().toLowerCase() ?? '';
        final hospitalName = post['nickname']?.toString().toLowerCase() ?? '';
        final description =
            post['description']?.toString().toLowerCase() ?? '';
        return title.contains(query) ||
            hospitalName.contains(query) ||
            description.contains(query);
      }).toList();
    }

    if (widget.startDate != null && widget.endDate != null) {
      filtered = filtered.where((post) {
        final createdAt = DateTime.tryParse(post['created_date'] ?? '');
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('헌혈완료 목록을 불러오고 있습니다...'),
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
                '완료된 헌혈이 없습니다.',
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
            badgeType: '완료',
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
