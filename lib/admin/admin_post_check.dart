import 'package:flutter/material.dart';
import 'dart:convert';

import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/api_endpoints.dart';
import '../utils/phone_formatter.dart';
import '../widgets/pet_profile_image.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';
import 'package:intl/intl.dart';
import '../services/admin_completed_donation_service.dart';
import '../widgets/post_detail/post_detail_header.dart';
import '../utils/time_format_util.dart';
import 'admin_active_posts_tab.dart';
import 'admin_completed_donations_tab.dart';
import 'admin_pending_posts_tab.dart';
import 'admin_post_edit.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/admin/applicant_detail_sheet.dart';
import '../widgets/admin/post_detail_sheet.dart';
import '../widgets/admin/completion_applicant_sheet.dart';

class AdminPostCheck extends StatefulWidget {
  /// 알림 탭 등 외부 진입 시 강조할 게시글 post_idx.
  /// 2-5a에서는 받아두기만 하고 활용 보류 — 탭 분리 리팩토링 후 2-5b에서
  /// 단건 fetch + 신청자 바텀시트 자동 오픈 보강 예정.
  final int? initialPostIdx;

  /// 알림 탭 진입 시 보일 초기 탭 (0~4). null이면 default 탭(0=모집대기).
  /// new_donation_application은 1=헌혈모집 탭으로 보냄.
  final int? initialTabIndex;

  const AdminPostCheck({
    super.key,
    this.initialPostIdx,
    this.initialTabIndex,
  });

  @override
  State createState() => _AdminPostCheckState();
}

class _AdminPostCheckState extends State<AdminPostCheck>
    with SingleTickerProviderStateMixin {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // 페이징 관련 (전체 탭 공용)
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _totalPages = 1;

  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0;

  // Tab 0(모집대기) 분리 위젯의 refresh 호출용 키.
  // 승인/거절 API 성공 후 부모가 자식 위젯의 fetchPosts를 트리거.
  final GlobalKey<AdminPendingPostsTabState> _pendingTabKey = GlobalKey();

  // Tab 3(헌혈완료) 분리 위젯 키. 새로고침/리스트 갱신 위임용.
  final GlobalKey<AdminCompletedDonationsTabState> _completedTabKey =
      GlobalKey();

  // Tab 1(헌혈모집) 분리 위젯 키. 시간대 마감/재오픈/대기 변경/삭제 후 갱신용.
  final GlobalKey<AdminActivePostsTabState> _activeTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.initialTabIndex ?? 0).clamp(0, 3);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_handleTabChange);
    _currentTabIndex = initialIndex;

    // 초기 탭에 맞는 데이터 로드 (default 탭 0이 아닌 경우 알림 진입 케이스).
    // _handleTabChange는 인덱스 변경 시에만 호출되므로 초기 fetch는 직접 분기.
    // Tab 0/1/3은 자식 위젯이 자체 initState에서 fetch하므로 여기서 호출 안 함.
    if (initialIndex == 2) {
      fetchPendingCompletions();
    }
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
      });

      // 모든 탭 전환 시 1페이지로 리셋
      _currentPage = 1;

      // 탭에 따라 다른 API 호출
      if (_currentTabIndex == 1) {
        // 헌혈모집 탭 - 자식 위젯에 위임. build 전이면 자식 initState에서 자동 fetch.
        _activeTabKey.currentState?.refresh();
      } else if (_currentTabIndex == 2) {
        // 헌혈마감 탭 - 병원이 1차 완료한 것들 조회
        fetchPendingCompletions();
      } else if (_currentTabIndex == 3) {
        // 헌혈완료 탭 - 자식 위젯에 위임. build 전이면 자식 initState에서 자동 fetch.
        _completedTabKey.currentState?.refresh();
      } else {
        // 모집대기(0) 탭 - 자식 위젯에 위임. 위젯이 살아 있으면 refresh,
        // 아직 build 전이면 자식의 initState에서 자동 fetch.
        _pendingTabKey.currentState?.refresh();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// 페이지 변경 핸들러 (탭 1~3 공용. 탭 0은 자식 위젯 내부에서 처리)
  void _onPageChanged(int page) {
    _currentPage = page;
    // 탭 1~3: 클라이언트 페이지네이션 (setState로 filteredPosts 재계산)
    setState(() {});
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  // 상태 관리는 AppliedDonationStatus 클래스 사용
  // (미사용 함수 제거됨 - lib/models/applied_donation_model.dart 참조)

  // 헌혈 완료 최종 승인
  Future<void> _finalApproveCompletion(int applicationId) async {
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 핸들 바
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 제목
                  Text(
                    '헌혈 마감',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 내용
                  Text(
                    '헌혈 완료를 최종 승인하시겠습니까?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade400),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text('헌혈 마감'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      );

      if (result == true) {
        await AdminCompletedDonationService.finalApprove(applicationId);
        // 데이터 새로고침 - 현재 탭에 있을 때만 새로고침
        if (_currentTabIndex == 2) {
          fetchPendingCompletions(); // 헌혈마감 탭 (현재 탭)
        }
        // 헌혈완료 탭은 나중에 탭 이동 시 자동으로 로드됨
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('승인 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 게시글 필터링 함수 (탭 1~3 전용. 탭 0은 자식 위젯이 자체 관리)
  List<dynamic> get filteredPosts {
    List<dynamic> filtered = posts;

    // 검색어 필터링 (탭 1~3 클라이언트 필터)
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((post) {
        final title = post['title']?.toString().toLowerCase() ?? '';
        final content = post['content']?.toString().toLowerCase() ?? '';
        final hospitalName =
            post['hospital_name']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();

        return title.contains(query) ||
            content.contains(query) ||
            hospitalName.contains(query);
      }).toList();
    }

    // 날짜 필터링
    if (startDate != null && endDate != null) {
      filtered = filtered.where((post) {
        final createdAt = DateTime.tryParse(post['created_at'] ?? '');
        if (createdAt == null) return false;

        return createdAt.isAfter(startDate!) &&
            createdAt.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // 클라이언트 측 페이지네이션
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);

    return filtered.sublist(startIndex, endIndex);
  }

  // 헌혈 마감 목록 조회 (탭 2) - 병원이 1차 완료한 것들
  Future<void> fetchPendingCompletions() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // 완료 대기 + 모집마감 (헌혈마감 탭에 묶어 표시)
      List<Map<String, dynamic>> allApplications = [];

      // 상태 2 (완료 대기) 조회
      String apiUrl5 =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/2';

      final response5 = await AuthHttpClient.get(Uri.parse(apiUrl5));

      // 상태 3 (모집마감) 조회 - donation_posts에서
      String apiUrl3 = '${Config.serverUrl}/api/admin/posts?status=헌혈마감&page_size=100';
      if (searchQuery.isNotEmpty) {
        apiUrl3 += '&search=${Uri.encodeComponent(searchQuery)}';
      }
      if (startDate != null) {
        apiUrl3 +=
            '&start_date=${DateFormat('yyyy-MM-dd').format(startDate!)}';
      }
      if (endDate != null) {
        apiUrl3 += '&end_date=${DateFormat('yyyy-MM-dd').format(endDate!)}';
      }
      final response3 = await AuthHttpClient.get(Uri.parse(apiUrl3));

      if (response5.statusCode == 200 || response3.statusCode == 200) {
        // 상태 5 데이터 처리
        if (response5.statusCode == 200) {
          final data5 = json.decode(utf8.decode(response5.bodyBytes));
          if (data5 is List) {
            allApplications.addAll(List<Map<String, dynamic>>.from(data5));
          } else if (data5 is Map && data5['donations'] != null) {
            allApplications.addAll(
              List<Map<String, dynamic>>.from(data5['donations']),
            );
          }
        }

        // 상태 3 (모집마감) 데이터 처리 - donation_posts 형식을 그대로 사용
        List<Map<String, dynamic>> closedPosts = [];
        if (response3.statusCode == 200) {
          final data3 = json.decode(utf8.decode(response3.bodyBytes));
          if (data3 is Map) {
            final list3 = data3['items'] ?? data3['posts'] ?? [];
            closedPosts = List<Map<String, dynamic>>.from(list3);
          } else if (data3 is List) {
            closedPosts = List<Map<String, dynamic>>.from(data3);
          }
        }

        if (mounted) {
          setState(() {
            // applied_donation 데이터를 posts 형태로 변환하여 기존 UI에서 사용 가능하게 함
            List<Map<String, dynamic>> convertedPosts =
                allApplications.map((app) {
                  // 동물 종류 추출 - API 응답에서 우선 추출, 없으면 제목에서 추출
                  String animalType = 'unknown';

                  // 1순위: pet 정보에서 추출
                  if (app['pet'] != null) {
                    final petAnimalType =
                        app['pet']['animal_type']?.toString() ??
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

                  // 2순위: animal_type 필드에서 추출
                  if (animalType == 'unknown' && app['animal_type'] != null) {
                    final apiAnimalType = app['animal_type'].toString();
                    if (apiAnimalType == '0' ||
                        apiAnimalType.toLowerCase() == 'dog') {
                      animalType = 'dog';
                    } else if (apiAnimalType == '1' ||
                        apiAnimalType.toLowerCase() == 'cat') {
                      animalType = 'cat';
                    }
                  }

                  // 제목 정보 추출
                  String title = app['post_title']?.toString() ?? '';

                  // 3순위: 제목에서 추출
                  if (animalType == 'unknown') {
                    if (title.contains('강아지')) {
                      animalType = 'dog';
                    } else if (title.contains('고양이')) {
                      animalType = 'cat';
                    }
                  }

                  // 제목에서 긴급/정기 구분 추출
                  int types = 1; // 기본값 정기
                  if (title.contains('긴급')) {
                    types = 0; // 긴급
                  }

                  // 주소 정보 설정 (hospital_address 필드 사용)
                  String location =
                      app['hospital_address'] ??
                      '${app['hospital_name'] ?? '병원'} (병원 코드: ${app['hospital_code'] ?? ''})';

                  return {
                    'id': app['applied_donation_idx'],
                    'application_id': app['applied_donation_idx'], // 완료 승인 시 사용
                    'title': app['post_title'] ?? '헌혈 요청',
                    'nickname': app['hospital_name'] ?? '병원',
                    'location': location,
                    'created_date': app['created_at']?.substring(0, 10) ?? '',
                    'animalType': animalType,
                    'types': types, // 긴급/정기 구분
                    'blood_type': app['pet']?['blood_type'] ?? '상관없음',
                    'applicantCount': 1,
                    'description':
                        app['description'] ?? '병원에서 1차 완료 처리된 헌혈입니다.',
                    'status': app['status'], // 2 (PENDING_COMPLETION)
                    'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
                    'pet_breed': app['pet']?['breed'] ?? app['pet_breed'],
                    'pet_blood_type': app['pet']?['blood_type'],
                    'pet_idx': app['pet']?['pet_idx'] ?? app['pet_idx'],
                    'user_name': app['user_name'] ?? app['name'],
                    'user_nickname': app['user_nickname'] ?? '',
                    'blood_volume': app['blood_volume'],
                    'completed_at': app['completed_at'],
                    'incompletion_reason': app['incompletion_reason'],
                    // 헌혈 예정일 정보 (donation_time 사용)
                    'donation_date':
                        app['donation_time'] ?? app['donation_date'] ?? '',
                    // 헌혈마감 탭임을 표시
                    'is_completion_pending': true,
                    // 단일 시간대 정보를 timeRanges 형식으로 변환
                    'timeRanges':
                        app['donation_time'] != null
                            ? [
                              {
                                'id': app['applied_donation_idx'],
                                'donation_date':
                                    app['donation_time']?.substring(0, 10) ??
                                    '',
                                'time':
                                    app['donation_time']?.substring(11, 16) ??
                                    '',
                                'status': 0, // 활성 상태
                              },
                            ]
                            : [],
                    'availableDates':
                        app['donation_time'] != null
                            ? {
                              app['donation_time']?.substring(0, 10) ?? '': [
                                {
                                  'post_times_idx': app['applied_donation_idx'],
                                  'time':
                                      app['donation_time']?.substring(11, 16) ??
                                      '',
                                  'datetime': app['donation_time'],
                                },
                              ],
                            }
                            : {},
                  };
                }).toList();

            // 모집마감(status=3) 게시글은 donation_posts 형식 그대로 추가 (status 3 유지)
            // 기존 키 호환을 위해 status 필드를 3으로 보장
            for (final closedPost in closedPosts) {
              closedPost['status'] = 3;
            }

            posts = [...convertedPosts, ...closedPosts];
            isLoading = false;
          });
        }
      } else if (response5.statusCode == 401 ||
          response3.statusCode == 401) {
        if (mounted) {
          setState(() {
            errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                '헌혈 마감 목록을 불러오는데 실패했습니다. 상태 5: ${response5.statusCode}, 상태 3: ${response3.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '헌혈 마감 데이터 로드 실패: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  // 현재 탭에 맞는 데이터 조회 함수 호출.
  // 탭 0/1/3은 자식 위젯이 보유하므로 GlobalKey로 refresh를 위임.
  Future<void> _fetchDataForCurrentTab() async {
    if (_currentTabIndex == 1) {
      await _activeTabKey.currentState?.refresh();
    } else if (_currentTabIndex == 2) {
      await fetchPendingCompletions();
    } else if (_currentTabIndex == 3) {
      await _completedTabKey.currentState?.refresh();
    } else {
      await _pendingTabKey.currentState?.refresh();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _currentPage = 1;
    });
    _fetchDataForCurrentTab();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryBlue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
        _currentPage = 1;
      });
      _fetchDataForCurrentTab();
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
      _currentPage = 1;
    });
    _fetchDataForCurrentTab();
  }

  Future<void> _showConfirmDialog(
    int postId,
    bool approve,
    String title,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 제목
              Text(
                approve ? '게시글 승인' : '게시글 거절',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),

              // 내용
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: 24),

              // 버튼들
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.lightGray),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            approve ? AppTheme.success : AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(approve ? '승인' : '거절'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      approvePost(postId, approve);
    }
  }

  Future<void> approvePost(int postId, bool approve) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postId/approval',
      );
      final response = await AuthHttpClient.put(
        url,
        body: jsonEncode({'approved': approve}),
      );

      if (response.statusCode == 200) {
        _fetchDataForCurrentTab();
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                '처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
    }
  }

  /// 게시글 대기상태로 변경 (모집중 → 대기)
  Future<void> _suspendPost(int postIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostSuspend(postIdx)}',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 대기 상태로 변경되었습니다.')),
          );
        }
        _fetchDataForCurrentTab();
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? '상태 변경에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 게시글 모집중으로 변경 (대기 → 모집중)
  Future<void> _resumePost(int postIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostResume(postIdx)}',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 모집중 상태로 변경되었습니다.')),
          );
        }
        _fetchDataForCurrentTab();
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? '상태 변경에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 게시글 삭제
  Future<void> _deletePost(int postIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostDelete(postIdx)}',
      );
      final response = await AuthHttpClient.delete(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 삭제되었습니다.')),
          );
        }
        _fetchDataForCurrentTab();
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? '게시글 삭제에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 삭제 확인 다이얼로그
  Future<void> _showDeleteConfirmDialog(int postIdx, String title) async {
    final ok = await AppDialog.confirm(
      context,
      title: '게시글 삭제',
      message: "'$title' 게시글을 삭제하시겠습니까?\n\n삭제된 게시글은 복구할 수 없습니다.",
      confirmLabel: '삭제',
      isDestructive: true,
    );
    if (ok == true) _deletePost(postIdx);
  }

  /// 대기 변경 확인 다이얼로그
  Future<void> _showSuspendConfirmDialog(int postIdx, String title) async {
    final ok = await AppDialog.confirm(
      context,
      title: '대기 상태로 변경',
      message: "'$title' 게시글을 대기 상태로 변경하시겠습니까?\n\n병원에게 알림이 발송됩니다.",
      confirmLabel: '변경',
    );
    if (ok == true) _suspendPost(postIdx);
  }

  /// 마감 상태에서 전환 시 경고 다이얼로그 (시간대 열기 + 신청자 초기화)
  void _showStatusChangeWithResetDialog(int postIdx, String title, String targetStatus, Future<void> Function(int) action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$targetStatus 상태로 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("'$title' 게시글을 $targetStatus 상태로 변경하시겠습니까?"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '승인된 신청자가 대기 상태로 변경됩니다.',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              action(postIdx);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  /// 모집 재개 확인 다이얼로그
  Future<void> _showResumeConfirmDialog(int postIdx, String title) async {
    final ok = await AppDialog.confirm(
      context,
      title: '모집중으로 변경',
      message: "'$title' 게시글을 모집중 상태로 변경하시겠습니까?\n\n병원에게 알림이 발송됩니다.",
      confirmLabel: '변경',
    );
    if (ok == true) _resumePost(postIdx);
  }

  /// 게시글 상세 헤더의 ... 메뉴 항목 구성
  List<PostDetailMenuItem> _buildPostDetailMenuItems(Map<String, dynamic> post) {
    final items = <PostDetailMenuItem>[];
    final postId = post['id'];
    final postIdx = postId is int ? postId : int.tryParse(postId?.toString() ?? '') ?? 0;
    final title = post['title'] ?? '제목 없음';
    final applicantCount = post['applicantCount'] ?? post['applicant_count'] ?? 0;

    // 수정 (탭 0, 1 공통)
    items.add(PostDetailMenuItem(
      icon: Icons.edit_outlined,
      label: '수정',
      onTap: () async {
        Navigator.pop(context); // 바텀시트 닫기
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPostEdit(post: post),
          ),
        );
        if (result == true) {
          _fetchDataForCurrentTab();
        }
      },
    ));

    // 대기로 변경 (탭 1: 모집중, 탭 2: 헌혈마감)
    if ((_currentTabIndex == 1 && post['status'] == 1 && post['is_completion_pending'] != true) ||
        (_currentTabIndex == 2 && post['status'] == 3 && post['is_completion_pending'] != true)) {
      final isFromClosed = post['status'] == 3;
      items.add(PostDetailMenuItem(
        icon: Icons.pause_circle_outline,
        label: '대기',
        onTap: () {
          Navigator.pop(context);
          if (isFromClosed) {
            _showStatusChangeWithResetDialog(postIdx, title, '대기', _suspendPost);
          } else {
            _showSuspendConfirmDialog(postIdx, title);
          }
        },
      ));
    }

    // 모집중으로 변경 (탭 0: 대기상태, 탭 2: 헌혈마감)
    if ((_currentTabIndex == 0 && post['status'] == 5) ||
        (_currentTabIndex == 2 && post['status'] == 3 && post['is_completion_pending'] != true)) {
      final isFromClosed = post['status'] == 3;
      items.add(PostDetailMenuItem(
        icon: Icons.play_circle_outline,
        label: '모집',
        onTap: () {
          Navigator.pop(context);
          if (isFromClosed) {
            _showStatusChangeWithResetDialog(postIdx, title, '모집중', _resumePost);
          } else {
            _showResumeConfirmDialog(postIdx, title);
          }
        },
      ));
    }

    // 삭제
    // 탭 0: WAIT(0), SUSPENDED(5) 모두 삭제 가능
    // 탭 1: 신청자 0명일 때만
    if (_currentTabIndex == 0 ||
        (_currentTabIndex == 1 &&
            post['is_completion_pending'] != true &&
            applicantCount == 0)) {
      items.add(PostDetailMenuItem(
        icon: Icons.delete_outline,
        label: '삭제',
        onTap: () {
          Navigator.pop(context);
          _showDeleteConfirmDialog(postIdx, title);
        },
      ));
    }

    return items;
  }

  String _getPostStatus(dynamic status) {
    // 상태값이 숫자로 전달됨: 0=대기, 1=승인/모집중, 2=거절, 3=모집마감, 5=대기상태
    int statusNum =
        status is int ? status : int.tryParse(status.toString()) ?? 0;

    switch (statusNum) {
      case 0:
        return '승인 대기';
      case 1:
        return '모집중';
      case 2:
        return '거절됨';
      case 3:
        return '모집마감';
      case 5:
        return '대기상태';
      default:
        return '승인 대기'; // 기본값
    }
  }

  // 시간대별 신청자 목록을 가져오는 메소드
  Future<List<Map<String, dynamic>>> _fetchTimeSlotApplicants(
    int postId,
    int timeSlotId,
    String date,
  ) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/applicants',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load applicants');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // 신청자 상태 업데이트 메소드
  Future<void> _updateApplicantStatus(
    int timeSlotId,
    int appliedDonationIdx,
    bool approved,
  ) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse(
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/approve',
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청이 승인되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        final errorMessage = errorData['detail'] ?? '승인 처리에 실패했습니다.';
        if (mounted) {
          await AppDialog.notice(
            context,
            title: '승인 실패',
            message: errorMessage.toString(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 신청자 상태를 '대기'로 변경하는 메소드
  Future<void> _pendApplicantStatus(int appliedDonationIdx) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse(
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/pend',
        ),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청 상태가 \'대기\'로 변경되었습니다.'),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
      } else {
        String errorMessage = '상태 변경에 실패했습니다.';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // 에러 메시지 파싱 실패 시 기본 메시지 사용
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "헌혈 게시글 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: '날짜 범위 선택',
          ),
          if (startDate != null || endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateRange,
              tooltip: '날짜 범위 초기화',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: '새로고침',
            onPressed: () {
              _fetchDataForCurrentTab();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _tabController == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 검색창
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppSearchBar(
                      controller: searchController,
                      hintText: '게시글 제목, 병원명, 내용으로 검색...',
                      onChanged: _onSearchChanged,
                      onClear: () => _onSearchChanged(''),
                    ),
                  ),

                  // 슬라이딩 탭
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      tabs: const [
                        Tab(text: '모집대기'),
                        Tab(text: '헌혈모집'),
                        Tab(text: '헌혈마감'),
                        Tab(text: '헌혈완료'),
                      ],
                      indicatorColor: Colors.black,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 14),
                      indicatorWeight: 3.0,
                    ),
                  ),

                  // 날짜 범위 표시
                  if (startDate != null || endDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.date_range,
                              color: Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기간: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '시작일 미지정'} ~ ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '종료일 미지정'}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black,
                                size: 18,
                              ),
                              onPressed: _clearDateRange,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 콘텐츠
                  Expanded(child: _buildContent()),
                ],
              ),
    );
  }

  Widget _buildContent() {
    // Tab 0(모집대기)는 분리된 자식 위젯으로 위임. 검색/날짜 필터를 props로 전달.
    if (_currentTabIndex == 0) {
      return AdminPendingPostsTab(
        key: _pendingTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: (post) {
          final postStatus = _getPostStatus(post['status']);
          final postType = _getPostType(post);
          _openPostDetailSheet(post, postStatus, postType);
        },
      );
    }

    // Tab 1(헌혈모집)도 분리된 자식 위젯으로 위임. 행 탭 시 부모의 상세 시트를 연다.
    if (_currentTabIndex == 1) {
      return AdminActivePostsTab(
        key: _activeTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: (post) {
          final postStatus = _getPostStatus(post['status']);
          final postType = _getPostType(post);
          _openPostDetailSheet(post, postStatus, postType);
        },
      );
    }

    // Tab 3(헌혈완료)도 분리된 자식 위젯으로 위임. 행 탭 시 신청자 시트를 연다.
    if (_currentTabIndex == 3) {
      return AdminCompletedDonationsTab(
        key: _completedTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: _openCompletionApplicantSheet,
      );
    }

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('게시글 목록을 불러오고 있습니다...'),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.red[500]),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDataForCurrentTab,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredPosts.isEmpty) {
      // 탭 0/1/3은 위 early return 분기에서 자식 위젯이 처리하므로 여기 도달 불가.
      // 탭 2(헌혈마감)만 도달.
      const emptyMessage = '마감이 필요한 게시글이 없습니다.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // 모든 탭에서 페이지네이션 바 표시
    final int paginationBarCount = _totalPages > 1 ? 1 : 0;
    final int postCount = filteredPosts.length;

    return RefreshIndicator(
      onRefresh: () => _fetchDataForCurrentTab(),
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: postCount + 1 + paginationBarCount, // 헤더 + 아이템 + 페이지네이션
        itemBuilder: (context, index) {
          // 첫 번째 아이템은 헤더
          if (index == 0) {
            return const PostListHeader();
          }

          // 게시글 범위를 벗어나면 페이지네이션 바
          if (index > postCount) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          // 나머지는 게시글 아이템
          final post = filteredPosts[index - 1]; // 인덱스 조정
          String postStatus = _getPostStatus(post['status']);
          String postType = _getPostType(post);

          return _buildPostListItem(post, index - 1, postStatus, postType);
        },
      ),
    );
  }

  Widget _buildPostListItem(
    Map<String, dynamic> post,
    int index,
    String postStatus,
    String postType,
  ) {
    return PostListRow(
      badgeType: postType,
      title: post['title'] ?? '제목 없음',
      dateText: TimeFormatUtils.formatFlexibleShortDate(
        post['createdDate'] ?? post['created_date'] ?? post['created_at'],
      ),
      hospitalProfileImage: post['hospitalProfileImage'] ?? post['hospital_profile_image'],
      onTap: () {
        // 헌혈완료 탭 또는 완료대기는 바로 신청자 상세 표시
        if (_currentTabIndex == 3 || post['is_completion_pending'] == true) {
          _openCompletionApplicantSheet(post);
        } else {
          _openPostDetailSheet(
            post,
            postStatus,
            post['types'] == 0 ? '긴급' : '정기',
          );
        }
      },
    );
  }

  /// 게시글 상세 시트를 열기 위한 진입점.
  /// 시트 자체는 [showPostDetailBottomSheet] (lib/widgets/admin/post_detail_sheet.dart)에 있고,
  /// 여기서는 메뉴/시간대 빌더 + 액션 콜백을 본 화면 컨텍스트에 묶어 전달.
  void _openPostDetailSheet(
    Map<String, dynamic> post,
    String postStatus,
    String postType,
  ) {
    showPostDetailBottomSheet(
      context,
      post: post,
      postStatus: postStatus,
      postType: postType,
      currentTabIndex: _currentTabIndex,
      menuItems: (_currentTabIndex == 0 ||
              _currentTabIndex == 1 ||
              _currentTabIndex == 2)
          ? _buildPostDetailMenuItems(post)
          : null,
      timeSlotBuilder: (setState) => _buildDateTimeDropdown(post, setState),
      actions: PostDetailSheetActions(
        onApprovePostTap: (id, title) => _showConfirmDialog(id, true, title),
        onRejectPostTap: (id, title) => _showConfirmDialog(id, false, title),
        onFinalApproveCompletion: _finalApproveCompletion,
        onClosePost: (setState) =>
            _showClosePostConfirmationSheet(post, setState),
        onReopenPost: (setState) =>
            _showReopenPostConfirmationSheet(post, setState),
      ),
    );
  }

  /// 헌혈완료/취소 신청자 시트를 열기 위한 진입점.
  /// 시트 자체는 [showCompletionApplicantSheet]
  /// (lib/widgets/admin/completion_applicant_sheet.dart)에 있고,
  /// 여기서는 상태별 액션 콜백을 본 화면 컨텍스트에 묶어 전달.
  void _openCompletionApplicantSheet(Map<String, dynamic> post) {
    showCompletionApplicantSheet(
      context,
      post: post,
      actions: CompletionApplicantSheetActions(
        onFinalApproveCompletion: _finalApproveCompletion,
        onRequestDocuments: _requestDocuments,
      ),
    );
  }


  Widget _buildDateTimeDropdown(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    final isActive =
        post['status'] == 1 ||
        post['status'] == 3 ||
        post['status'] == 5; // 모집중, 마감, 대기 상태 모두 관리 가능

    if (timeRanges.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Text(
            '헌혈 날짜 정보가 없습니다',
            style: AppTheme.bodyMediumStyle.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // timeRanges를 날짜별로 그룹화 (중복 제거)
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    final Set<String> seenTimeSlots = {}; // 중복 체크용

    for (final timeRange in timeRanges) {
      final dateStr = timeRange['donation_date'] ?? timeRange['date'] ?? 'N/A';
      final time = timeRange['time'] ?? '';
      final team = timeRange['team'] ?? 0;

      // 날짜+시간+팀으로 고유키 생성하여 중복 체크
      final uniqueKey = '$dateStr-$time-$team';

      if (!seenTimeSlots.contains(uniqueKey)) {
        seenTimeSlots.add(uniqueKey);
        if (!groupedByDate.containsKey(dateStr)) {
          groupedByDate[dateStr] = [];
        }
        groupedByDate[dateStr]!.add(timeRange);
      }
    }

    return Column(
      children:
          groupedByDate.entries.map((entry) {
            final dateStr = entry.key;
            final timeSlots = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: Column(
                children: [
                  // 날짜 헤더
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.black, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          TimeFormatUtils.formatDateWithWeekday(dateStr),
                          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  // 시간대 목록
                  ...
                      timeSlots.map((timeSlot) {
                        final time = timeSlot['time'] ?? '';
                        final isSlotClosed = timeSlot['status'] == 1;

                        return InkWell(
                          onTap: () async {
                            // 헌혈마감 탭에서는 신청자 정보 표시, 다른 탭에서는 기존 로직
                            if (post['is_completion_pending'] == true) {
                              _openCompletionApplicantSheet(post);
                            } else if (_currentTabIndex == 3) {
                              // 헌혈완료 탭에서도 신청자 정보 표시
                              _openCompletionApplicantSheet(post);
                            } else if (isActive) {
                              await _showTimeSlotApplicants(
                                post['id'],
                                timeSlot['id'],
                                dateStr,
                                time,
                                timeSlot['status'],
                                post,
                                onUpdate,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isSlotClosed
                                      ? Colors.grey.shade100
                                      : Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color:
                                      isSlotClosed ? Colors.grey : Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  TimeFormatUtils.formatTime(time),
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color:
                                        isSlotClosed
                                            ? Colors.grey
                                            : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                if (_currentTabIndex != 0)
                                  _buildTimeSlotStatusBadge(
                                    timeSlot['status'] ?? 0,
                                    postStatus: post['status'] as int?,
                                  ),
                                if (isActive && !(_currentTabIndex == 0 && post['status'] != 5))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await _showTimeSlotApplicants(
                                          post['id'],
                                          timeSlot['id'],
                                          dateStr,
                                          time,
                                          timeSlot['status'],
                                          post,
                                          onUpdate,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.people_outline,
                                        size: 18,
                                        color:
                                            isSlotClosed
                                                ? Colors.grey
                                                : Colors
                                                    .black, // 마감된 경우 회색으로 표시
                                      ),
                                      label: Text(
                                        _currentTabIndex == 1 ? '신청자 관리' : '신청자 확인',
                                        style: TextStyle(
                                          color:
                                              isSlotClosed
                                                  ? Colors.grey
                                                  : Colors
                                                      .black, // 마감된 경우 회색으로 표시
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            isSlotClosed
                                                ? Colors.grey
                                                : Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                              if (!(_currentTabIndex == 0 && post['status'] != 5))
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: isSlotClosed ? Colors.grey : AppTheme.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                ],
              ),
            );
          }).toList(),
    );
  }

  Future<void> _showTimeSlotApplicants(
    dynamic postId,
    dynamic timeSlotId,
    String date,
    String time,
    dynamic status,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    // ID 값들을 정수형으로 변환
    final postIdInt =
        postId is int ? postId : int.tryParse(postId.toString()) ?? 0;
    final timeSlotIdInt =
        timeSlotId is int
            ? timeSlotId
            : int.tryParse(timeSlotId.toString()) ?? 0;
    final isSlotClosed = status == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (
                BuildContext context,
                ScrollController scrollController,
              ) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 핸들 바
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 헤더
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentTabIndex == 1 ? '신청자 관리' : '신청자 확인',
                                    style: AppTheme.h3Style.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${TimeFormatUtils.formatDateWithWeekday(date)} ${TimeFormatUtils.formatTime(time)}',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: '닫기',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // 신청자 목록
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchTimeSlotApplicants(
                            postIdInt,
                            timeSlotIdInt,
                            date,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  '신청자 정보를 불러오는데 실패했습니다.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            }
                            final applicants = snapshot.data ?? [];
                            if (applicants.isEmpty && isSlotClosed) {
                              return Center(
                                child: Text(
                                  '마감된 시간대입니다.',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            if (applicants.isEmpty) {
                              return Center(
                                child: Text(
                                  '아직 신청자가 없습니다.',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: applicants.length,
                                    separatorBuilder:
                                        (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final applicant = applicants[index];
                                      final petInfo = applicant['pet_info'] as Map<String, dynamic>? ?? {};
                                      final lastDonationDate = petInfo['last_donation_date'];
                                      final lastDonationText = (lastDonationDate == null || lastDonationDate.toString().isEmpty)
                                          ? '첫 헌혈을 기다리는 중'
                                          : TimeFormatUtils.formatFlexibleDate(lastDonationDate);

                                      final isApproved = applicant['status'] == 1;

                                      return GestureDetector(
                                        onTap: () => showApplicantDetailBottomSheet(context, applicant),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isApproved && _currentTabIndex != 1
                                                ? AppTheme.success.withValues(alpha: 0.08)
                                                : AppTheme.veryLightGray,
                                            borderRadius: BorderRadius.circular(AppTheme.radius8),
                                            border: isApproved && _currentTabIndex != 1
                                                ? Border.all(color: AppTheme.success.withValues(alpha: 0.3))
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              // 반려동물 프로필 사진
                                              PetProfileImage(
                                                profileImage: petInfo['profile_image'],
                                                species: petInfo['species'],
                                                radius: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              // 승인 표시 아이콘 (모집 탭 외)
                                              if (isApproved && _currentTabIndex != 1) ...[
                                                const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                                                const SizedBox(width: 4),
                                              ],
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      applicant['nickname'] ?? applicant['name'] ?? '이름 없음',
                                                      style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${petInfo['name'] ?? '이름 없음'} | ${petInfo['breed'] ?? ''} | ${petInfo['blood_type'] ?? ''}',
                                                      style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '직전 헌혈일: $lastDonationText',
                                                      style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textTertiary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // 승인/대기 토글 + 화살표
                                              const SizedBox(width: 8),
                                              if (_currentTabIndex == 1 && applicant['status'] != 2 && applicant['status'] != 4)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      height: 30,
                                                      child: OutlinedButton(
                                                        onPressed: applicant['status'] != 1
                                                            ? () async {
                                                                await _updateApplicantStatus(timeSlotIdInt, applicant['id'], true);
                                                                setState(() {});
                                                              }
                                                            : null,
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: applicant['status'] == 1 ? Colors.white : AppTheme.success,
                                                          backgroundColor: applicant['status'] == 1 ? AppTheme.success : null,
                                                          side: BorderSide(color: AppTheme.success),
                                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                        ),
                                                        child: const Text('승인', style: TextStyle(fontSize: 12)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    SizedBox(
                                                      height: 30,
                                                      child: OutlinedButton(
                                                        onPressed: applicant['status'] != 0
                                                            ? () async {
                                                                await _pendApplicantStatus(applicant['id']);
                                                                setState(() {});
                                                              }
                                                            : null,
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: applicant['status'] == 0 ? Colors.white : AppTheme.warning,
                                                          backgroundColor: applicant['status'] == 0 ? AppTheme.warning : null,
                                                          side: BorderSide(color: AppTheme.warning),
                                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                        ),
                                                        child: const Text('대기', style: TextStyle(fontSize: 12)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // 마감/마감해제 버튼 (헌혈모집 탭에서만 표시)
                                if (_currentTabIndex == 1)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    8.0,
                                    16.0,
                                    16.0,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!isSlotClosed) {
                                        // 승인된 신청자가 있는지 확인
                                        final hasApproved = applicants.any((a) => a['status'] == 1);
                                        if (!hasApproved) {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('알림'),
                                              content: const Text('승인된 신청자가 없습니다.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('확인'),
                                                ),
                                              ],
                                            ),
                                          );
                                          return;
                                        }
                                        // 마감 처리
                                        _showCloseConfirmationSheet(
                                          timeSlotIdInt,
                                          date,
                                          time,
                                          post,
                                          onUpdate,
                                        );
                                      } else {
                                        // 마감 해제 처리
                                        _showReopenConfirmationDialog(
                                          timeSlotIdInt,
                                          date,
                                          time,
                                          post,
                                          onUpdate,
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          isSlotClosed
                                              ? Colors.green
                                              : Colors.red,
                                      side: BorderSide(
                                        color: isSlotClosed
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      isSlotClosed ? '마감 해제' : '마감',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper method to build the status badge for a time slot
  Widget _buildTimeSlotStatusBadge(dynamic status, {int? postStatus}) {
    // 헌혈완료 탭인 경우 항상 "헌혈완료" 뱃지 표시
    if (_currentTabIndex == 3) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '헌혈완료',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 헌혈마감 탭인 경우 게시글 상태에 따라 뱃지 표시
    if (_currentTabIndex == 2 && postStatus != null) {
      // 모집마감(status=3)
      if (postStatus == 3) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '마감',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
      // 완료대기(postStatus == 5)
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '헌혈완료',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isClosed = (status == 1);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // 패딩 증가
      decoration: BoxDecoration(
        color: isClosed ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isClosed ? '모집마감' : '모집진행',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.0, // 텍스트 높이 조정
        ),
        textAlign: TextAlign.center, // 텍스트 중앙 정렬
      ),
    );
  }

  // Method to call the API to close a time slot
  Future<void> _closeTimeSlot(
    Map<String, dynamic> post,
    int timeSlotId,
    StateSetter onUpdate,
  ) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/close',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        // 1. 개선된 API 응답 파싱
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int postStatus = responseData['post_status'];
        final int postIdx = responseData['post_idx'];
        final updatedTimeSlot = responseData['updated_time_slot']; // 새로 추가된 정보

        // 2. 업데이트된 시간대 정보를 사용하여 효율적으로 상태 업데이트
        if (updatedTimeSlot != null) {
          final updatedTimeSlotId = updatedTimeSlot['post_times_idx'];
          final updatedStatus = updatedTimeSlot['status'];

          // 모달 내부 상태 업데이트
          final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];

          // id 또는 idx 필드로 매칭 시도
          int timeSlotIndex = timeRanges.indexWhere(
            (ts) => ts['id'] == updatedTimeSlotId,
          );
          if (timeSlotIndex == -1) {
            timeSlotIndex = timeRanges.indexWhere(
              (ts) => ts['idx'] == updatedTimeSlotId,
            );
          }

          if (timeSlotIndex != -1) {
            onUpdate(() {
              // status 필드가 없을 수도 있으므로 추가
              timeRanges[timeSlotIndex]['status'] = updatedStatus;
            });
          } else {
            for (int i = 0; i < timeRanges.length; i++) {}
          }

          // 메인 화면 상태 업데이트 (전체 목록 새로고침 없이 효율적으로 처리)
          if (mounted) {
            // mounted 체크 추가
            setState(() {
              final mainPostIndex = posts.indexWhere((p) => p['id'] == postIdx);
              if (mainPostIndex != -1) {
                final mainTimeRanges =
                    posts[mainPostIndex]['timeRanges'] as List<dynamic>? ?? [];

                // id 또는 idx 필드로 매칭 시도
                int mainTimeSlotIndex = mainTimeRanges.indexWhere(
                  (ts) => ts['id'] == updatedTimeSlotId,
                );
                if (mainTimeSlotIndex == -1) {
                  mainTimeSlotIndex = mainTimeRanges.indexWhere(
                    (ts) => ts['idx'] == updatedTimeSlotId,
                  );
                }

                if (mainTimeSlotIndex != -1) {
                  mainTimeRanges[mainTimeSlotIndex]['status'] = updatedStatus;
                } else {}
              }
            });
          }
        } else {}

        // 3. 서버에서 받은 게시글 상태를 메인 목록에 업데이트
        if (mounted) {
          setState(() {
            final mainPostIndex = posts.indexWhere((p) => p['id'] == postIdx);
            if (mainPostIndex != -1) {
              // 게시글의 status를 API 응답값으로 업데이트
              posts[mainPostIndex]['status'] = postStatus;
            }
          });

          // post 변수도 업데이트 (상세 화면 새로고침용)
          post['status'] = postStatus;
        }

        // 확인 창 닫기
        if (mounted) {
          Navigator.of(context).pop();

          // 신청자 관리 바텀시트도 닫기
          Navigator.of(context).pop();
        }

        // 상세 게시글 새로고침을 위해 잠깐 닫고 다시 열기
        if (mounted) {
          await _refreshAndReopenPostDetail(
            post,
            _getPostStatus(postStatus), // 업데이트된 postStatus 사용
            post['types'] == 0 ? '긴급' : '정기',
          );
        }

        // 마감 처리 후 전체 데이터 새로고침 (신청자 수 등 최신 정보 반영)
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // UI 업데이트 완료 대기
        if (mounted) {
          await _fetchDataForCurrentTab();
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(); // 오류 시에도 확인 창은 닫습니다.
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (response.statusCode == 400) {
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: const Text('알림'),
                    content: const Text('이미 마감된 시간대입니다.'),
                    actions: [
                      TextButton(
                        child: const Text('확인'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
            );
          }
        } else {
          throw Exception(
            'Failed to close time slot: ${errorData['message'] ?? response.statusCode}',
          );
        }
      }
    } catch (e) {
      // 오류 발생 시 로그만 출력
    }
  }

  // Method to show the confirmation dialog for closing a time slot
  void _showCloseConfirmationSheet(
    int timeSlotId,
    String date,
    String time,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTimeSlotApplicants(0, timeSlotId, date).then(
            (applicants) => applicants.where((a) => a['status'] == 1).toList(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 200,
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('오류: ${snapshot.error}')),
              );
            }

            final approvedApplicants = snapshot.data ?? [];
            bool isClosing = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '마감 확인',
                        style: AppTheme.h3Style.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${TimeFormatUtils.formatDateWithWeekday(date)} ${TimeFormatUtils.formatTime(time)}',
                        style: AppTheme.bodyLargeStyle,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('승인된 신청자 목록', style: AppTheme.h4Style),
                      const SizedBox(height: 8),
                      approvedApplicants.isEmpty
                          ? const Text('승인된 신청자가 없습니다.')
                          : ListView.builder(
                            shrinkWrap: true,
                            itemCount: approvedApplicants.length,
                            itemBuilder: (context, index) {
                              final applicant = approvedApplicants[index];
                              final petInfo =
                                  applicant['pet_info']
                                      as Map<String, dynamic>? ??
                                  {};
                              final lastDonationDate =
                                  petInfo['last_donation_date'];
                              String lastDonationText;
                              if (lastDonationDate == null ||
                                  lastDonationDate.toString().isEmpty) {
                                lastDonationText = '첫 헌혈';
                              } else {
                                lastDonationText = TimeFormatUtils.formatFlexibleDate(
                                  lastDonationDate.toString(),
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        applicant['nickname'] ?? '닉네임 없음',
                                        style: AppTheme.bodyLargeStyle.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatPhoneNumber(applicant['contact'] as String?, fallback: '연락처 없음'),
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Text(
                                        '반려동물: ${petInfo['name'] ?? ''} (${petInfo['breed'] ?? ''}, ${petInfo['age'] ?? '?'}세, ${petInfo['blood_type'] ?? ''})',
                                        style: AppTheme.bodyMediumStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '직전 헌혈일: $lastDonationText',
                                        style: AppTheme.bodyMediumStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed:
                            isClosing
                                ? null
                                : () async {
                                  setState(() {
                                    isClosing = true;
                                  });
                                  await _closeTimeSlot(
                                    post,
                                    timeSlotId,
                                    onUpdate,
                                  );
                                  // _closeTimeSlot이 Navigator.pop을 호출하므로
                                  // 이 시점에는 이미 다이얼로그가 닫혔을 수 있음
                                  // setState 호출하지 않음
                                },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isClosing
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.red,
                                    ),
                                  ),
                                )
                                : const Text('신청자 마감'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 시간대 마감 해제 확인 다이얼로그
  void _showReopenConfirmationDialog(
    int timeSlotId,
    String date,
    String time,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '마감 해제 확인',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${TimeFormatUtils.formatDateWithWeekday(date)} ${TimeFormatUtils.formatTime(time)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '이 시간대의 마감을 해제하시겠습니까?\n승인된 신청자가 대기 상태로 변경됩니다.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reopenTimeSlot(timeSlotId, post, onUpdate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('마감 해제'),
            ),
          ],
        );
      },
    );
  }

  // 시간대 마감 해제 API 호출
  Future<void> _reopenTimeSlot(
    int timeSlotId,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/reopen',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));

        final int? postStatus = responseData['post_status'];
        final int? postIdx = responseData['post_idx'];
        final updatedTimeSlot = responseData['updated_time_slot'];

        if (updatedTimeSlot != null) {
          final updatedTimeSlotId = updatedTimeSlot['post_times_idx'];
          final updatedStatus = updatedTimeSlot['status']; // 0: 다시 열림

          // 모달 내부 상태 업데이트
          final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
          final timeSlotIndex = timeRanges.indexWhere(
            (ts) => ts['id'] == updatedTimeSlotId,
          );
          if (timeSlotIndex != -1) {
            onUpdate(() {
              timeRanges[timeSlotIndex]['status'] = updatedStatus;
            });
          }

          // 메인 화면 상태 업데이트
          if (mounted) {
            setState(() {
              final mainPostIndex = posts.indexWhere((p) => p['id'] == postIdx);
              if (mainPostIndex != -1) {
                final mainTimeRanges =
                    posts[mainPostIndex]['timeRanges'] as List<dynamic>? ?? [];
                final mainTimeSlotIndex = mainTimeRanges.indexWhere(
                  (ts) => ts['id'] == updatedTimeSlotId,
                );
                if (mainTimeSlotIndex != -1) {
                  mainTimeRanges[mainTimeSlotIndex]['status'] = updatedStatus;
                }

                // 게시글 상태도 업데이트 (마감 해제 시 status 3 → 1)
                if (postStatus != null) {
                  posts[mainPostIndex]['status'] = postStatus;
                }
              }
            });
          }
        }

        // post 변수도 업데이트
        if (postStatus != null) {
          post['status'] = postStatus;
        }

        // 신청자 관리 바텀시트 닫기
        if (mounted) {
          Navigator.of(context).pop();
        }

        // 상세 게시글 새로고침을 위해 잠깐 닫고 다시 열기
        await _refreshAndReopenPostDetail(
          post,
          _getPostStatus(post['status']),
          post['types'] == 0 ? '긴급' : '정기',
        );

        // 마감해제 처리 후 전체 데이터 새로고침 (신청자 수 등 최신 정보 반영)
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // UI 업데이트 완료 대기
        await _fetchDataForCurrentTab();
      } else {
        // 마감 해제 실패 시 로그만 출력
      }
    } catch (e) {
      // 오류 발생 시 로그만 출력
    }
  }

  // 상세 게시글을 새로고침하고 다시 여는 메서드
  Future<void> _refreshAndReopenPostDetail(
    Map<String, dynamic> post,
    String postStatus,
    String postType,
  ) async {
    try {
      // 1. 상세 게시글 모달 닫기
      Navigator.of(context).pop();

      // 2. 잠깐 대기 (모달 닫기 완료)
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. 최신 데이터 가져오기
      await _fetchDataForCurrentTab();

      // 4. 업데이트된 게시글 찾기
      final postId = post['id'];
      final updatedPost = posts.firstWhere(
        (p) => p['id'] == postId,
        orElse: () => post, // 찾을 수 없으면 기존 데이터 사용
      );

      // 5. 업데이트된 게시글로 상세 모달 다시 열기
      _openPostDetailSheet(
        updatedPost,
        _getPostStatus(updatedPost['status']),
        updatedPost['types'] == 0 ? '긴급' : '정기',
      );
    } catch (e) {
      // 게시글 새로고침 실패 시 로그 출력
      debugPrint('Failed to refresh post detail: $e');
    }
  }

  // 헌혈마감 탭에서 신청자 및 반려견 정보 표시
  /// 헌혈 자료 요청
  Future<void> _requestDocuments(int applicationId) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse(
            '${Config.serverUrl}${ApiEndpoints.donationRequestDocuments}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'applicationId': applicationId}),
      );

      if (!mounted) return;

      String title;
      String message;
      if (response.statusCode == 200) {
        title = '자료 요청 완료';
        message = '자료 요청이 전송되었습니다.';
      } else if (response.statusCode == 409) {
        title = '자료 요청 안내';
        message = '이미 오늘 자료 요청을 보냈습니다.\n내일 다시 요청할 수 있습니다.';
      } else {
        final data = jsonDecode(response.body);
        title = '자료 요청 실패';
        message = data['detail'] ?? '자료 요청에 실패했습니다.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('오류'),
            content: const Text('자료 요청 중 오류가 발생했습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  // 게시글 타입 결정 (헬퍼 함수)
  String _getPostType(Map<String, dynamic> post) {
    if (_currentTabIndex == 2) {
      // 헌혈마감 탭: 게시글 모집마감(3)/applied_donation 완료대기(2) 구분
      return post['status'] == 2 ? '완료대기' : '마감';
    } else if (_currentTabIndex == 1) {
      // 헌혈모집 탭에서는 진행/마감 뱃지 표시
      // donation_posts.status: 1 = 진행, 3 = 마감
      return post['status'] == 1 ? '진행' : '마감';
    } else if (_currentTabIndex == 3) {
      // 헌혈완료 탭에서는 완료 뱃지 표시
      return '완료';
    } else {
      // 모집대기 탭: SUSPENDED(5)이면 [대기] 뱃지, 아니면 긴급/정기
      if (post['status'] == 5) return '대기';
      return post['types'] == 0 ? '긴급' : '정기';
    }
  }

  // 게시글 전체 마감 API 호출
  Future<void> _closeEntirePost(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final postIdx = post['id'];
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postIdx/close',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int newStatus = responseData['new_status'] ?? 3;

        // 메인 화면 상태 업데이트
        if (mounted) {
          setState(() {
            final mainPostIndex = posts.indexWhere((p) => p['id'] == postIdx);
            if (mainPostIndex != -1) {
              posts[mainPostIndex]['status'] = newStatus;
            }
          });

          // post 변수도 업데이트
          post['status'] = newStatus;
        }

        // 확인 바텀시트 닫기
        if (mounted) Navigator.of(context).pop();
        // 게시글 상세 바텀시트 닫기
        if (mounted) Navigator.of(context).pop();

        // 마감 처리 후 현재 탭 데이터 새로고침. _closeEntirePost는 Tab 1 시트에서만
        // 호출되므로 _activeTabKey로 위임.
        if (mounted) {
          await _activeTabKey.currentState?.refresh();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('헌혈 마감'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['detail'] ?? errorData['message'] ?? '마감 처리에 실패했습니다.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 게시글 전체 재오픈 API 호출
  Future<void> _reopenEntirePost(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final postIdx = post['id'];
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postIdx/reopen',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int newStatus = responseData['new_status'] ?? 1;

        // 메인 화면 상태 업데이트
        if (mounted) {
          setState(() {
            final mainPostIndex = posts.indexWhere((p) => p['id'] == postIdx);
            if (mainPostIndex != -1) {
              posts[mainPostIndex]['status'] = newStatus;
              // 모든 시간대 상태도 초기화 (0: 모집중)
              final timeRanges =
                  posts[mainPostIndex]['timeRanges'] as List<dynamic>? ?? [];
              for (var ts in timeRanges) {
                ts['status'] = 0;
              }
            }
          });

          post['status'] = newStatus;
          // post의 시간대 상태도 초기화
          final postTimeRanges = post['timeRanges'] as List<dynamic>? ?? [];
          for (var ts in postTimeRanges) {
            ts['status'] = 0;
          }
        }

        // 확인 창 닫기
        if (mounted) {
          Navigator.of(context).pop();
        }

        // 상세 게시글 새로고침
        if (mounted) {
          await _refreshAndReopenPostDetail(
            post,
            _getPostStatus(newStatus),
            post['types'] == 0 ? '긴급' : '정기',
          );
        }

        // 재오픈 처리 후 전체 데이터 새로고침
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _fetchDataForCurrentTab();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시글이 성공적으로 재오픈되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['detail'] ?? errorData['message'] ?? '재오픈 처리에 실패했습니다.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 게시글 전체 재오픈 확인 다이얼로그
  void _showReopenPostConfirmationSheet(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    bool isReopening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '게시글 전체 재오픈',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['title'] ?? '제목 없음',
                    style: AppTheme.bodyLargeStyle,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '게시글을 재오픈하면 모집중 상태로 변경되며, 승인된 신청자가 대기 상태로 변경됩니다.',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isReopening
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              isReopening
                                  ? null
                                  : () async {
                                    setState(() {
                                      isReopening = true;
                                    });
                                    await _reopenEntirePost(post, onUpdate);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              isReopening
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text('재오픈 확정'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 게시글 전체 마감 확인 다이얼로그
  void _showClosePostConfirmationSheet(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    bool isClosing = false;

    // 열린 시간대 정보 확인 (경고 표시용, 마감을 차단하지 않음)
    // 백엔드에서 실제 유효성 검증 수행 (1명이라도 승인된 신청자가 있으면 마감 허용)
    final hasOpenSlots = _hasOpenTimeSlots(post);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '모든 시간대 게시글 마감',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['title'] ?? '제목 없음',
                    style: AppTheme.bodyLargeStyle,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasOpenSlots ? Colors.orange.shade50 : AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasOpenSlots ? Colors.orange.shade300 : AppTheme.lightGray,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasOpenSlots ? Icons.warning_amber_rounded : Icons.info_outline,
                          color: hasOpenSlots ? Colors.orange.shade700 : AppTheme.primaryDarkBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasOpenSlots
                                ? '모든 시간대를 마감하고 게시글을 마감합니다.'
                                : '모든 시간대가 마감되었습니다. 게시글을 마감하시겠습니까?',
                            style: TextStyle(
                              color: hasOpenSlots ? Colors.orange.shade700 : AppTheme.primaryDarkBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isClosing
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isClosing
                                  ? null
                                  : () async {
                                    setState(() {
                                      isClosing = true;
                                    });
                                    await _closeEntirePost(post, onUpdate);
                                  },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              isClosing
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.red,
                                      ),
                                    ),
                                  )
                                  : const Text('마감 확정'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _hasOpenTimeSlots(Map<String, dynamic> post) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    return timeRanges.any((ts) => ts['status'] == 0 || ts['status'] == null);
  }
}
