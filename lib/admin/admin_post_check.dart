import 'package:flutter/material.dart';
import 'dart:convert';

import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/marquee_text.dart';
import 'package:intl/intl.dart';
import '../services/admin_completed_donation_service.dart';
import '../services/dashboard_service.dart';
import '../services/donation_history_service.dart';
import '../models/donation_history_model.dart';
import '../widgets/post_detail/post_detail_handle_bar.dart';
import '../widgets/post_detail/post_detail_header.dart';
import '../widgets/post_detail/post_detail_meta_section.dart';
import '../widgets/post_detail/post_detail_blood_type.dart';
import '../widgets/post_detail/post_detail_description.dart';
import '../widgets/post_detail/post_detail_patient_info.dart';
import '../widgets/blinking_icon.dart';
import '../utils/time_format_util.dart';
import 'admin_post_edit.dart';
import '../widgets/pagination_bar.dart';

class AdminPostCheck extends StatefulWidget {
  const AdminPostCheck({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController!.addListener(_handleTabChange);
    fetchPosts();
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
        // 헌혈모집 탭 - applied_donation 기반 조회 (Status 0, 1)
        fetchAppliedDonations();
      } else if (_currentTabIndex == 2) {
        // 헌혈마감 탭 - 병원에서 1차 완료/중단한 것들 조회 (Status 5, 6)
        fetchPendingCompletions();
      } else if (_currentTabIndex == 3) {
        // 헌혈완료 탭 - 최종 승인된 헌혈들 조회 (Status 7)
        fetchCompletedDonations();
      } else if (_currentTabIndex == 4) {
        // 헌혈취소 탭 - 거절/취소된 헌혈들 조회 (Status 2, 4)
        fetchCancelledDonations();
      } else {
        // 모집대기(0) 탭 - donation_posts 기반 조회
        fetchPosts();
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

  /// 페이지 변경 핸들러 (전체 탭 공용)
  void _onPageChanged(int page) {
    _currentPage = page;
    if (_currentTabIndex == 0) {
      // 탭 0: 서버 페이지네이션
      fetchPosts();
    } else {
      // 탭 1~4: 클라이언트 페이지네이션 (setState로 filteredPosts 재계산)
      setState(() {});
    }
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

  // 헌혈 완료 반려
  Future<void> _rejectCompletion(int applicationId) async {
    final reasonController = TextEditingController();

    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                    '헌혈 중단',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 내용
                  Text(
                    '헌혈 완료를 반려하시겠습니까?',
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
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text('헌혈 중단'),
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
        await AdminCompletedDonationService.rejectCompletion(
          applicationId,
          '', // 빈 사유로 전송
        );
        // 데이터 새로고침 - 현재 탭에 있을 때만 새로고침
        if (_currentTabIndex == 2) {
          fetchPendingCompletions(); // 헌혈마감 탭 (현재 탭)
        }
        // 헌혈취소 탭은 나중에 탭 이동 시 자동으로 로드됨
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('반려 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  // 게시글 필터링 함수
  List<dynamic> get filteredPosts {
    List<dynamic> filtered;
    switch (_currentTabIndex) {
      case 0:
        // 모집대기 탭: 서버에서 status=대기로 이미 필터링 + 페이지네이션됨
        filtered = posts;
        break;
      case 1:
        // 헌혈모집 탭: 관리자 승인 후 (status 0 = 진행, status 1 = 마감)
        filtered = posts;
        break;
      case 2:
        // 헌혈마감 탭: status가 5(완료대기) 또는 6(중단대기)인 게시글 표시
        filtered = posts;
        break;
      case 3:
        // 헌혈완료 탭: status가 7인 게시글만 표시 (완료된 헌혈)
        filtered = posts;
        break;
      case 4:
        // 헌혈취소 탭: status가 2(거절) 또는 4(취소)인 게시글 표시
        filtered = posts;
        break;
      default:
        filtered = [];
    }

    // 검색어 필터링 (탭 1~4에서 클라이언트 필터)
    if (_currentTabIndex != 0 && searchQuery.isNotEmpty) {
      filtered =
          filtered.where((post) {
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

    // 날짜 필터링 (탭 1~4에서 클라이언트 필터)
    if (_currentTabIndex != 0 && startDate != null && endDate != null) {
      filtered =
          filtered.where((post) {
            final createdAt = DateTime.tryParse(post['created_at'] ?? '');
            if (createdAt == null) return false;

            return createdAt.isAfter(startDate!) &&
                createdAt.isBefore(endDate!.add(const Duration(days: 1)));
          }).toList();
    }

    // 탭 0: 서버 페이지네이션 → 그대로 반환
    if (_currentTabIndex == 0) return filtered;

    // 탭 1~4: 클라이언트 측 페이지네이션
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);

    return filtered.sublist(startIndex, endIndex);
  }

  // 헌혈완료 목록 조회 (탭 3) - 최종 승인된 헌혈들 (Status 7)
  Future<void> fetchCompletedDonations() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // Status 7 (최종 헌혈완료) 조회
      String apiUrl =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/7';

      final response = await AuthHttpClient.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List<Map<String, dynamic>> completedDonations = [];

        if (data is List) {
          completedDonations = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['donations'] != null) {
          completedDonations = List<Map<String, dynamic>>.from(
            data['donations'],
          );
        }

        if (mounted) {
          setState(() {
            // applied_donation 데이터를 posts 형태로 변환
            posts =
                completedDonations.map((app) {
                  // 날짜 포맷 처리 - 시간 제거
                  String createdAt = app['created_at'] ?? '';
                  if (createdAt.contains('T')) {
                    createdAt = createdAt.split('T')[0];
                  } else if (createdAt.length > 10) {
                    createdAt = createdAt.substring(0, 10);
                  }

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
                      app['hospital_location'] ??
                      '${app['hospital_name'] ?? '병원'} (병원 코드: ${app['hospital_code'] ?? ''})';

                  return {
                    'id': app['applied_donation_idx'],
                    'application_id': app['applied_donation_idx'],
                    'title': app['post_title'] ?? '헌혈 완료',
                    'nickname': app['hospital_nickname'] ?? app['hospital_name'] ?? '병원',
                    'location': location,
                    'created_date': createdAt,
                    'animalType': animalType,
                    'types': types, // 긴급/정기 구분
                    // 게시글 필요 혈액형 (긴급 헌혈 시 서버에서 제공)
                    'blood_type':
                        app['emergency_blood_type'] ??
                        '상관없음',
                    // 신청자 반려동물 혈액형
                    'pet_blood_type': app['pet']?['blood_type'],
                    'applicantCount': 1, // 완료된 헌혈은 1건
                    'description': app['description'],
                    'contentDelta': app['content_delta'] ?? app['contentDelta'],
                    'blood_volume': app['blood_volume'],
                    'status': 7, // 헌혈완료 상태
                    'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
                    'pet_breed': app['pet']?['breed'] ?? app['pet_breed'],
                    'pet_idx': app['pet']?['pet_idx'] ?? app['pet_idx'],
                    'user_name': app['user_name'] ?? app['name'],
                    'user_nickname': app['user_nickname'] ?? '',
                    'completed_at': app['completed_at'],
                    // 헌혈 예정일 정보
                    'donation_date':
                        app['donation_time'] ?? app['donation_date'] ?? '',
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
                              (app['donation_time']?.substring(0, 10) ?? ''): [
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
                    'applications': [
                      {
                        'applied_donation_idx': app['applied_donation_idx'],
                        'status': 7,
                        'user_email': app['user_email'],
                        'user_nickname':
                            app['user_nickname'] ?? app['nickname'] ?? '',
                        'pet_name':
                            app['pet']?['name'] ?? app['pet_name'] ?? '',
                        'donation_time': app['donation_time'] ?? '',
                      },
                    ],
                  };
                }).toList();

            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = '헌혈완료 목록을 불러오는데 실패했습니다: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '헌혈완료 데이터 로드 실패: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  // 헌혈취소 목록 조회 (탭 4) - 거절/취소된 헌혈들 (Status 2, 4)
  Future<void> fetchCancelledDonations() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      List<Map<String, dynamic>> allCancelled = [];

      // Status 2 (모집거절 - posts 테이블)와 Status 4 (헌혈취소 - applied_donation 테이블) 조회
      // 먼저 posts API에서 Status 2 가져오기
      String postsApiUrl = '${Config.serverUrl}/api/admin/posts?status=거절&page_size=100';

      // 검색 필터
      if (searchQuery.isNotEmpty) {
        postsApiUrl += '&search=${Uri.encodeComponent(searchQuery)}';
      }
      if (startDate != null) {
        postsApiUrl += '&start_date=${DateFormat('yyyy-MM-dd').format(startDate!)}';
      }
      if (endDate != null) {
        postsApiUrl += '&end_date=${DateFormat('yyyy-MM-dd').format(endDate!)}';
      }

      final postsResponse = await AuthHttpClient.get(Uri.parse(postsApiUrl));

      if (postsResponse.statusCode == 200) {
        final postsData = json.decode(utf8.decode(postsResponse.bodyBytes));
        List postsList;
        if (postsData is Map) {
          postsList = (postsData['items'] ?? postsData['posts'] ?? []) as List;
        } else if (postsData is List) {
          postsList = postsData;
        } else {
          postsList = [];
        }
        allCancelled.addAll(List<Map<String, dynamic>>.from(postsList));
      }

      // Status 4 (헌혈취소) 조회 - applied_donation 테이블
      String apiUrl4 =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/4';
      final response4 = await AuthHttpClient.get(Uri.parse(apiUrl4));

      if (response4.statusCode == 200) {
        final data4 = json.decode(utf8.decode(response4.bodyBytes));
        List<Map<String, dynamic>> cancelledDonations = [];

        if (data4 is List) {
          cancelledDonations = List<Map<String, dynamic>>.from(data4);
        } else if (data4 is Map && data4['donations'] != null) {
          cancelledDonations = List<Map<String, dynamic>>.from(
            data4['donations'],
          );
        }

        // Status 4 데이터를 posts 형태로 변환하여 추가
        for (var app in cancelledDonations) {
          // 날짜 포맷 처리 - 시간 제거
          String createdAt = app['created_at'] ?? '';
          if (createdAt.contains('T')) {
            createdAt = createdAt.split('T')[0];
          } else if (createdAt.length > 10) {
            createdAt = createdAt.substring(0, 10);
          }

          // 제목에서 동물 종류 추출
          String animalType = 'unknown';
          String title = app['post_title']?.toString() ?? '';
          if (title.contains('강아지')) {
            animalType = 'dog';
          } else if (title.contains('고양이')) {
            animalType = 'cat';
          }

          // 제목에서 긴급/정기 구분 추출
          int types = 1; // 기본값 정기
          if (title.contains('긴급')) {
            types = 0; // 긴급
          }

          // 주소 정보 설정 (hospital_address 필드 사용)
          String location =
              app['hospital_address'] ??
              app['hospital_location'] ??
              '${app['hospital_name'] ?? '병원'} (병원 코드: ${app['hospital_code'] ?? ''})';

          allCancelled.add({
            'id': app['applied_donation_idx'],
            'application_id': app['applied_donation_idx'],
            'title': app['post_title'] ?? '헌혈 취소',
            'nickname': app['hospital_nickname'] ?? app['hospital_name'] ?? '병원',
            'location': location,
            'created_date': createdAt,
            'animalType': animalType,
            'types': types, // 긴급/정기 구분
            // 게시글 필요 혈액형 (긴급 헌혈 시 서버에서 제공)
            'blood_type':
                app['emergency_blood_type'] ??
                '상관없음',
            // 신청자 반려동물 혈액형
            'pet_blood_type': app['pet']?['blood_type'],
            'applicantCount': 1, // 취소된 헌혈은 1건
            'description': app['description'],
            'contentDelta': app['content_delta'] ?? app['contentDelta'],
            'blood_volume': app['blood_volume'],
            'status': 4, // 헌혈취소 상태
            'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
            'pet_breed': app['pet']?['breed'] ?? app['pet_breed'],
            'pet_idx': app['pet']?['pet_idx'] ?? app['pet_idx'],
            'user_name': app['user_name'] ?? app['name'],
            'user_nickname': app['user_nickname'] ?? '',
            'cancelled_at': app['cancelled_at'] ?? '',
            'cancelled_by': app['cancelled_by'] ?? '',
            'cancelled_reason': app['cancelled_reason'] ?? '',
            // 헌혈 예정일 정보
            'donation_date': app['donation_time'] ?? app['donation_date'] ?? '',
            // 단일 시간대 정보를 timeRanges 형식으로 변환
            'timeRanges':
                app['donation_time'] != null
                    ? [
                      {
                        'id': app['applied_donation_idx'],
                        'donation_date':
                            app['donation_time']?.substring(0, 10) ?? '',
                        'time': app['donation_time']?.substring(11, 16) ?? '',
                        'status': 0, // 활성 상태
                      },
                    ]
                    : [],
            'availableDates':
                app['donation_time'] != null
                    ? {
                      (app['donation_time']?.substring(0, 10) ?? ''): [
                        {
                          'post_times_idx': app['applied_donation_idx'],
                          'time': app['donation_time']?.substring(11, 16) ?? '',
                          'datetime': app['donation_time'],
                        },
                      ],
                    }
                    : {},
            'applications': [
              {
                'applied_donation_idx': app['applied_donation_idx'],
                'status': 4,
                'user_email': app['user_email'],
                'user_nickname': app['user_nickname'] ?? app['nickname'] ?? '',
                'pet_name': app['pet']?['name'] ?? app['pet_name'] ?? '',
                'donation_time': app['donation_time'] ?? '',
              },
            ],
          });
        }
      }

      if (mounted) {
        setState(() {
          posts = allCancelled;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '헌혈취소 데이터 로드 실패: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  // 헌혈 마감 목록 조회 (탭 2) - 병원에서 1차 완료/중단한 것들
  Future<void> fetchPendingCompletions() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // 서버에서 추가한 새로운 API 엔드포인트 사용 (완료 대기 + 중단 대기 + 모집마감)
      List<Map<String, dynamic>> allApplications = [];

      // 상태 5 (완료 대기) 조회
      String apiUrl5 =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/5';

      final response5 = await AuthHttpClient.get(Uri.parse(apiUrl5));

      // 상태 6 (중단 대기) 조회
      String apiUrl6 =
          '${Config.serverUrl}/api/applied_donation/admin/by-status/6';
      final response6 = await AuthHttpClient.get(Uri.parse(apiUrl6));

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

      if (response5.statusCode == 200 ||
          response6.statusCode == 200 ||
          response3.statusCode == 200) {
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

        // 상태 6 데이터 처리
        if (response6.statusCode == 200) {
          final data6 = json.decode(utf8.decode(response6.bodyBytes));
          if (data6 is List) {
            allApplications.addAll(List<Map<String, dynamic>>.from(data6));
          } else if (data6 is Map && data6['donations'] != null) {
            allApplications.addAll(
              List<Map<String, dynamic>>.from(data6['donations']),
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
                        app['status'] == 5
                            ? (app['description'] ?? '병원에서 1차 완료 처리된 헌혈입니다.')
                            : (app['description'] ?? '병원에서 1차 중단 처리된 헌혈입니다.'),
                    'status':
                        app['status'], // 5 (pendingCompletion) 또는 6 (pendingCancellation)
                    'pet_name': app['pet']?['name'] ?? '',
                    'pet_idx': app['pet']?['pet_idx'] ?? app['pet_idx'],
                    'user_nickname': app['user_nickname'] ?? '',
                    'completed_at': app['completed_at'],
                    // 중단 관련 정보 (상태 6인 경우)
                    'cancelled_reason': app['cancelled_reason'],
                    'cancelled_at': app['cancelled_at'],
                    'cancelled_by': app['cancelled_by'],
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
          response6.statusCode == 401 ||
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
                '헌혈 마감 목록을 불러오는데 실패했습니다. 상태 5: ${response5.statusCode}, 상태 6: ${response6.statusCode}, 상태 3: ${response3.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '헌혈 완룼/중단 데이터 로드 실패: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  // 헌혈모집 탭: donation_posts 기반 조회 (status 1, 3)
  Future<void> fetchAppliedDonations() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // 서버에서 제공하는 헌혈모집 API 호출
      // donation_posts.status IN (1, 3) & applied_donation.status NOT IN (5, 6)
      String apiUrl = '${Config.serverUrl}/api/admin/posts';
      List<String> queryParams = ['status=모집중', 'page_size=100'];

      // 날짜 필터
      if (startDate != null) {
        queryParams.add(
          'start_date=${DateFormat('yyyy-MM-dd').format(startDate!)}',
        );
      }

      if (endDate != null) {
        queryParams.add(
          'end_date=${DateFormat('yyyy-MM-dd').format(endDate!)}',
        );
      }

      // 검색 필터
      if (searchQuery.isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(searchQuery)}');
      }

      if (queryParams.isNotEmpty) {
        apiUrl += '?${queryParams.join('&')}';
      }

      final response = await AuthHttpClient.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (mounted) {
          setState(() {
            if (data is Map) {
              posts = (data['items'] ?? data['posts'] ?? []) as List;
            } else if (data is List) {
              posts = data;
            } else {
              posts = [];
            }
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = '헌혈모집 목록을 불러오는데 실패했습니다: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '오류가 발생했습니다: $e';
          isLoading = false;
        });
      }
    }
  }

  // 모집대기 탭: donation_posts 기반 조회 (페이징)
  Future<void> fetchPosts({int? page}) async {
    final targetPage = page ?? _currentPage;
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
      }

      final result = await DashboardService.fetchAdminPostsPageRaw(
        page: targetPage,
        pageSize: AppConstants.detailListPageSize,
        status: '대기',
        search: searchQuery.isNotEmpty ? searchQuery : null,
        startDate: startDate != null
            ? DateFormat('yyyy-MM-dd').format(startDate!)
            : null,
        endDate: endDate != null
            ? DateFormat('yyyy-MM-dd').format(endDate!)
            : null,
      );

      final pagination = result.pagination;

      if (mounted) {
        setState(() {
          posts = List.from(result.posts);
          isLoading = false;
          _currentPage = pagination.currentPage;
          _totalPages = pagination.totalPages;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '오류가 발생했습니다: $e';
          isLoading = false;
        });
      }
    }
  }

  // 현재 탭에 맞는 데이터 조회 함수 호출
  Future<void> _fetchDataForCurrentTab() async {
    if (_currentTabIndex == 1) {
      await fetchAppliedDonations();
    } else if (_currentTabIndex == 2) {
      await fetchPendingCompletions();
    } else if (_currentTabIndex == 3) {
      await fetchCompletedDonations();
    } else if (_currentTabIndex == 4) {
      await fetchCancelledDonations();
    } else {
      await fetchPosts();
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

  String _getPostStatus(dynamic status) {
    // 상태값이 숫자로 전달됨: 0=대기, 1=승인/모집중, 2=거절, 3=모집마감
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
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/${approved ? "approve" : "reject"}',
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved ? '신청이 승인되었습니다.' : '신청이 거절되었습니다.'),
              backgroundColor: approved ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')));
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
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '게시글 제목, 병원명, 내용으로 검색...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        suffixIcon:
                            searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                                : null,
                      ),
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
                        Tab(text: '헌혈취소'),
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
      String emptyMessage;
      switch (_currentTabIndex) {
        case 0:
          emptyMessage = '승인 대기 중인 게시글이 없습니다.';
          break;
        case 1:
          emptyMessage = '헌혈 모집 게시글이 없습니다.';
          break;
        case 2:
          emptyMessage = '마감이 필요한 게시글이 없습니다.';
          break;
        case 3:
          emptyMessage = '완료된 헌혈이 없습니다.';
          break;
        case 4:
          emptyMessage = '취소된 헌혈이 없습니다.';
          break;
        default:
          emptyMessage = '게시글이 없습니다.';
      }

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
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        '구분',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '제목',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '작성일',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '신청자',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildPostListItem(post, index - 1, postStatus, postType),
          );
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
    return InkWell(
      onTap: () {
        // 헌혈완료/취소 탭에서는 바로 상세 정보 표시 (병원 측과 동일)
        if (_currentTabIndex == 3 || _currentTabIndex == 4) {
          _showCompletionApplicantInfo(post);
        } else {
          _showPostDetail(
            post,
            postStatus,
            post['types'] == 0 ? '긴급' : '정기',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 0,
        ), // 패딩 증가
        margin: const EdgeInsets.symmetric(vertical: 1.0), // 마진 추가로 공간 확보
        decoration: BoxDecoration(
          color: Colors.white, // 배경색 명시
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 구분 (뱃지)
            Container(
              width: 70,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: _getBadgeBackgroundColor(postType),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child:
                    _currentTabIndex == 2 &&
                            (postType == '완료대기' || postType == '중단대기')
                        ? Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              postType == '완료대기' ? '완료' : '중단',
                              style: AppTheme.bodySmallStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _getBadgeTextColor(postType),
                                fontSize: 10,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '대기',
                              style: AppTheme.bodySmallStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _getBadgeTextColor(postType),
                                fontSize: 10,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                        : Text(
                          postType,
                          style: AppTheme.bodySmallStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getBadgeTextColor(postType),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
              ),
            ),
            // 제목
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                alignment: Alignment.centerLeft,
                child: MarqueeText(
                  text: post['title'] ?? '제목 없음',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  animationDuration: const Duration(milliseconds: 5000),
                  pauseDuration: const Duration(milliseconds: 2000),
                ),
              ),
            ),
            // 작성일
            Container(
              width: 80,
              alignment: Alignment.center,
              child: Text(
                _formatDate(post['createdDate'] ?? post['created_date'] ?? post['created_at'] ?? ''),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 신청자
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                '${post['applicantCount'] ?? post['applicant_count'] ?? 0}',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostDetail(
    Map<String, dynamic> post,
    String postStatus,
    String postType,
  ) {
    // 동물 종류 표시를 위한 변환 (int 0/1 또는 String 'dog'/'cat')
    final animalTypeRaw = post['animalType'];
    final animalType = animalTypeRaw == 0 || animalTypeRaw == '0' ? 0 :
                       animalTypeRaw == 1 || animalTypeRaw == '1' ? 1 : 0;

    // 생성일 파싱
    final createdAt = TimeFormatUtils.parseFlexibleDate(
      post['createdDate'] ?? post['created_date'] ?? post['created_at'],
    ) ?? DateTime.now();

    // 혈액형 추출
    final bloodType = post['bloodType'] ?? post['blood_type'] ?? post['emergency_blood_type'];

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
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
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
                      const PostDetailHandleBar(),

                      // 헤더 (탭 0/1에서 수정 아이콘 표시)
                      PostDetailHeader(
                        title: post['title'] ?? '제목 없음',
                        isUrgent: postType == '긴급',
                        typeText: postType,
                        onClose: () => Navigator.pop(context),
                        onEdit: (_currentTabIndex == 0 || _currentTabIndex == 1)
                            ? () async {
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
                              }
                            : null,
                      ),

                      const Divider(height: 1),

                      // 상세 정보 (스크롤 가능)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 메타 정보 (병원명, 주소, 동물 종류, 신청자 수)
                              PostDetailMetaSection(
                                hospitalName: _extractHospitalName(post['title'] ?? ''),
                                hospitalNickname: null,
                                location: post['location'] ?? '주소 정보 없음',
                                animalType: animalType,
                                applicantCount: post['applicantCount'] ?? post['applicant_count'] ?? 0,
                                createdAt: createdAt,
                              ),

                              // 설명글
                              PostDetailDescription(
                                contentDelta: (post['contentDelta'] ?? post['content_delta'])?.toString(),
                                plainText: post['description']?.toString(),
                              ),

                              // 중단 사유 (상태 6 또는 4인 경우에 표시)
                              if ((post['status'] == 6 ||
                                      post['status'] == 4) &&
                                  post['cancelled_reason'] != null &&
                                  post['cancelled_reason']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '중단 사유',
                                          style: AppTheme.bodyLargeStyle
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade700,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post['cancelled_reason'],
                                            style: AppTheme.bodyMediumStyle
                                                .copyWith(
                                                  color: AppTheme.textPrimary,
                                                  height: 1.4,
                                                ),
                                          ),
                                          if (post['cancelled_at'] != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              '중단 처리 시간: ${_formatCancellationTime(post['cancelled_at'])}',
                                              style: AppTheme.bodySmallStyle
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],

                              // 환자 정보 (긴급 헌혈만)
                              PostDetailPatientInfo(
                                isUrgent: post['types'] == 0,
                                patientName: post['patientName']?.toString() ?? post['patient_name']?.toString(),
                                breed: post['breed']?.toString(),
                                age: post['age'] is int ? post['age'] : (int.tryParse(post['age']?.toString() ?? '')),
                                diagnosis: post['diagnosis']?.toString(),
                              ),

                              // 혈액형 정보
                              if (post['types'] == 0) PostDetailBloodType(
                                bloodType: bloodType?.toString(),
                                isUrgent: postType == '긴급',
                              ),

                              // 헌혈 일정
                              Text("헌혈 일정", style: AppTheme.h4Style),
                              const SizedBox(height: 12),

                              // 드롭다운 형태의 날짜/시간 선택 UI
                              _buildDateTimeDropdown(post, setState),

                              const SizedBox(height: 16),

                              // 전체 마감 버튼 (모집중 상태이거나 일부 시간대가 열려있는 경우 표시)
                              // status: 0=대기, 1=모집중, 2=거절, 3=마감
                              if ((post['status'] == 1 ||
                                      (post['status'] == 3 &&
                                          _hasOpenTimeSlots(post))) &&
                                  post['is_completion_pending'] != true &&
                                  _currentTabIndex != 3 &&
                                  _currentTabIndex != 4)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _showClosePostConfirmationSheet(
                                        post,
                                        setState,
                                      );
                                    },
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('게시글 전체 마감'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),

                              // 게시글 전체 재오픈 버튼 (마감 상태이고 열린 시간대가 없을 때 표시)
                              if (post['status'] == 3 &&
                                  !_hasOpenTimeSlots(post) &&
                                  post['is_completion_pending'] != true &&
                                  _currentTabIndex != 3 &&
                                  _currentTabIndex != 4)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _showReopenPostConfirmationSheet(
                                          post,
                                          setState,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.refresh,
                                        size: 18,
                                      ),
                                      label: const Text('게시글 전체 재오픈'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 24),

                              // 헌혈마감 탭에서는 상태에 따라 버튼 구분 표시
                              if (post['is_completion_pending'] == true) ...[
                                // 완료대기(status==5)는 헌혈마감 버튼만, 중단대기(status==6)는 헌혈중단 버튼만
                                if (post['status'] == 5) ...[
                                  // 완료대기 - 헌혈마감 버튼만 표시
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _finalApproveCompletion(
                                          post['application_id'] ??
                                              post['id'] ??
                                              0,
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(
                                          color: Colors.green,
                                        ),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text('헌혈 마감'),
                                    ),
                                  ),
                                ] else if (post['status'] == 6) ...[
                                  // 중단대기 - 헌혈중단 버튼만 표시
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _rejectCompletion(
                                          post['application_id'] ??
                                              post['id'] ??
                                              0,
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text('헌혈 중단'),
                                    ),
                                  ),
                                ],
                              ]
                              // 승인/거절 버튼 (대기 상태일 때만 표시, 헌혈완료/취소 탭에서는 표시하지 않음)
                              else if (postStatus == '승인 대기' &&
                                  _currentTabIndex != 3 &&
                                  _currentTabIndex != 4) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          final postId = post['id'];
                                          if (postId != null) {
                                            _showConfirmDialog(
                                              postId is int
                                                  ? postId
                                                  : int.tryParse(
                                                        postId.toString(),
                                                      ) ??
                                                      0,
                                              true,
                                              post['title'] ?? '제목 없음',
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green,
                                          side: const BorderSide(
                                            color: Colors.green,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text('승인'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          final postId = post['id'];
                                          if (postId != null) {
                                            _showConfirmDialog(
                                              postId is int
                                                  ? postId
                                                  : int.tryParse(
                                                        postId.toString(),
                                                      ) ??
                                                      0,
                                              false,
                                              post['title'] ?? '제목 없음',
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text('거절'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '연락처 없음';

    // 숫자만 추출
    String numbers = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (numbers.length != 11) return phone; // 휴대폰 번호가 아닌 경우 원본 반환

    // 000-0000-0000 형식으로 변환
    return '${numbers.substring(0, 3)}-${numbers.substring(3, 7)}-${numbers.substring(7)}';
  }

  String _formatDate(String dateTime) {
    try {
      if (dateTime.isEmpty || dateTime == 'N/A') return '-';

      // ISO 8601, YYYY-MM-DD HH:mm:ss, YYYY-MM-DD 모두 처리
      final parsed = DateTime.parse(dateTime);
      return DateFormat('MM.dd').format(parsed);
    } catch (e) {
      // 파싱 실패 시 기존 로직 시도
      try {
        final datePart = dateTime.split(' ')[0].split('T')[0];
        final parts = datePart.split('-');
        if (parts.length == 3) {
          return '${parts[1]}.${parts[2]}';
        }
      } catch (_) {}
      return '-';
    }
  }

  /// 직전 헌혈일 포맷 (YYYY.MM.DD 형식)
  String _formatLastDonationDate(String dateTime) {
    try {
      if (dateTime.isEmpty) return '-';

      // ISO 8601 형식 (2025-01-27T00:00:00) 또는 YYYY-MM-DD 형식 처리
      final date = DateTime.parse(dateTime);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }

  // 날짜를 요일로 변환하는 함수
  String _getWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      return weekdays[date.weekday - 1];
    } catch (e) {
      return '';
    }
  }

  // 날짜를 "YYYY년 MM월 DD일 O요일" 형태로 포맷팅
  String _formatDateWithWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final weekday = _getWeekday(dateStr);
      return '${date.year}년 ${date.month}월 ${date.day}일 $weekday요일';
    } catch (e) {
      return dateStr;
    }
  }

  // 시간 포맷팅 메서드
  String _formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        if (hour == 0) {
          return '오전 12:$minute';
        } else if (hour < 12) {
          return '오전 ${hour.toString().padLeft(2, '0')}:$minute';
        } else if (hour == 12) {
          return '오후 12:$minute';
        } else {
          return '오후 ${(hour - 12).toString().padLeft(2, '0')}:$minute';
        }
      }
    } catch (e) {
      return time24;
    }
    return '시간 미정';
  }

  // 제목에서 병원 이름 추출하는 메서드
  String _extractHospitalName(String title) {
    // [병원이름] 형식에서 병원 이름 추출
    final match = RegExp(r'\[(.*?)\]').firstMatch(title);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }
    return '병원 이름 없음';
  }

  Widget _buildDateTimeDropdown(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    final isActive =
        post['status'] == 1 ||
        post['status'] == 3; // 모집 진행중이거나 마감된 게시글 모두 관리 가능

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
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: const Icon(
                    Icons.calendar_month,
                    color: Colors.black,
                    size: 24,
                  ),
                  title: Text(
                    _formatDateWithWeekday(dateStr),
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: BlinkingIcon(
                    icon: Icons.keyboard_arrow_down,
                    color: Colors.black,
                    size: 24,
                    duration: Duration(milliseconds: 1500),
                  ),
                  children:
                      timeSlots.map((timeSlot) {
                        final time = timeSlot['time'] ?? '';
                        final isSlotClosed = timeSlot['status'] == 1;

                        return InkWell(
                          onTap: () async {
                            // 헌혈마감 탭에서는 신청자 정보 표시, 다른 탭에서는 기존 로직
                            if (post['is_completion_pending'] == true) {
                              _showCompletionApplicantInfo(post);
                            } else if (_currentTabIndex == 3 ||
                                _currentTabIndex == 4) {
                              // 헌혈완료/취소 탭에서도 신청자 정보 표시
                              _showCompletionApplicantInfo(post);
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
                                  _formatTime(time),
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color:
                                        isSlotClosed
                                            ? Colors.grey
                                            : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                _buildTimeSlotStatusBadge(
                                  timeSlot['status'] ?? 0,
                                  postStatus: post['status'] as int?,
                                ), // 기본값 0(모집중)
                                if (isActive) // 마감된 시간대도 신청자 관리 버튼 표시
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
                                        '신청자 관리',
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
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
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
                                    '신청자 목록',
                                    style: AppTheme.h3Style.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDateWithWeekday(date)} ${_formatTime(time)}',
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
                                        (context, index) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final applicant = applicants[index];
                                      return ListTile(
                                        onTap:
                                            () =>
                                                _showApplicantDetailBottomSheet(
                                                  context,
                                                  applicant,
                                                ),
                                        title: Text(
                                          '${applicant['nickname'] ?? '닉네임 없음'} (${applicant['name'] ?? '이름 없음'}) ${_formatPhoneNumber(applicant['contact'])}',
                                          style: AppTheme.bodyLargeStyle
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '반려동물: ${(applicant['pet_info'] as Map<String, dynamic>)['name'] ?? '이름 없음'} (${(applicant['pet_info'] as Map<String, dynamic>)['breed'] ?? '품종 정보 없음'})',
                                              style: AppTheme.bodySmallStyle,
                                            ),
                                            Text(
                                              '나이: ${(applicant['pet_info'] as Map<String, dynamic>)['age'] ?? '?'}세, 혈액형: ${(applicant['pet_info'] as Map<String, dynamic>)['blood_type'] ?? '정보 없음'}',
                                              style: AppTheme.bodySmallStyle,
                                            ),
                                            () {
                                              final petInfo =
                                                  applicant['pet_info']
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >? ??
                                                  {};
                                              final lastDonationDate =
                                                  petInfo['last_donation_date'];
                                              String lastDonationText;
                                              if (lastDonationDate == null ||
                                                  lastDonationDate
                                                      .toString()
                                                      .isEmpty) {
                                                lastDonationText =
                                                    '첫 헌혈을 기다리는 중';
                                              } else {
                                                lastDonationText =
                                                    _formatLastDonationDate(
                                                      lastDonationDate
                                                          .toString(),
                                                    );
                                              }
                                              return Text(
                                                '직전 헌혈일: $lastDonationText',
                                                style: AppTheme.bodySmallStyle,
                                              );
                                            }(),
                                          ],
                                        ),
                                        trailing: SizedBox(
                                          width: 150,
                                          child: ToggleButtons(
                                            isSelected: [
                                              applicant['status'] ==
                                                  1, // Approve
                                              applicant['status'] ==
                                                  0, // Pending
                                              applicant['status'] ==
                                                  2, // Reject
                                            ],
                                            onPressed: (int index) async {
                                              final appliedDonationIdx =
                                                  applicant['id'];
                                              final currentStatus =
                                                  applicant['status']; // 0: Pending, 1: Approved, 2: Rejected
                                              final targetIndex =
                                                  index; // 0: Approve, 1: Pending, 2: Reject

                                              // 승인(1) -> 거절(2)
                                              if (currentStatus == 1 &&
                                                  targetIndex == 2) {
                                                await _pendApplicantStatus(
                                                  appliedDonationIdx,
                                                );
                                                await _updateApplicantStatus(
                                                  timeSlotIdInt,
                                                  appliedDonationIdx,
                                                  false,
                                                );
                                              }
                                              // 거절(2) -> 승인(1)
                                              else if (currentStatus == 2 &&
                                                  targetIndex == 0) {
                                                await _pendApplicantStatus(
                                                  appliedDonationIdx,
                                                );
                                                await _updateApplicantStatus(
                                                  timeSlotIdInt,
                                                  appliedDonationIdx,
                                                  true,
                                                );
                                              }
                                              // 다른 모든 경우
                                              else {
                                                if (targetIndex == 1) {
                                                  // 대기
                                                  await _pendApplicantStatus(
                                                    appliedDonationIdx,
                                                  );
                                                } else {
                                                  // 승인 또는 거절
                                                  final newStatus =
                                                      targetIndex == 0;
                                                  await _updateApplicantStatus(
                                                    timeSlotIdInt,
                                                    appliedDonationIdx,
                                                    newStatus,
                                                  );
                                                }
                                              }

                                              setState(() {
                                                // 상태 변경 후 UI를 다시 그리도록 setState 호출
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                            selectedBorderColor: Colors.black,
                                            selectedColor: Colors.white,
                                            fillColor: Colors.black,
                                            color: Colors.black,
                                            constraints: const BoxConstraints(
                                              minHeight: 32.0,
                                              minWidth: 48.0,
                                            ),
                                            children: const <Widget>[
                                              Text('승인'),
                                              Text('대기'),
                                              Text('거절'),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // 마감/마감해제 버튼 (항상 표시)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    8.0,
                                    16.0,
                                    16.0,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!isSlotClosed) {
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isSlotClosed
                                              ? Colors.green
                                              : Colors.black,
                                      foregroundColor: Colors.white,
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
      final isCompletion = (postStatus == 5); // 완료대기
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isCompletion ? AppTheme.primaryBlue : Colors.pink,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isCompletion ? '헌혈완료' : '헌혈중단',
          style: const TextStyle(
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
              debugPrint('=== 시간대 마감 후 상태 업데이트 ===');
              debugPrint('이전 status: ${posts[mainPostIndex]['status']}');
              debugPrint('새로운 status: $postStatus');
              posts[mainPostIndex]['status'] = postStatus;
              debugPrint('업데이트 완료! 뱃지: ${_getPostType(posts[mainPostIndex])}');
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
                        '${_formatDateWithWeekday(date)} ${_formatTime(time)}',
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
                                lastDonationText = _formatDate(
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
                                        '${applicant['nickname'] ?? '닉네임 없음'} (${applicant['name'] ?? '이름 없음'}) - ${_formatPhoneNumber(applicant['contact'])}',
                                        style: AppTheme.bodyLargeStyle.copyWith(
                                          fontWeight: FontWeight.bold,
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
                      ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text('최종 마감 확인'),
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
                '${_formatDateWithWeekday(date)} ${_formatTime(time)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '이 시간대의 마감을 해제하시겠습니까?\n마감 해제 후 다시 신청을 받을 수 있습니다.',
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
      _showPostDetail(
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
  void _showCompletionApplicantInfo(Map<String, dynamic> post) {
    // applications 배열에서 첫 번째 신청자 정보 가져오기 (헌혈완료/취소는 1건)
    final applications = post['applications'] as List<dynamic>? ?? [];
    final applicant =
        applications.isNotEmpty
            ? applications.first as Map<String, dynamic>? ?? {}
            : <String, dynamic>{};

    // pet_idx 가져오기 (post 또는 applicant에서) - 타입 변환 처리
    int? petIdx;
    final postPetIdx = post['pet_idx'];
    final applicantPetIdx = applicant['pet_idx'];

    if (postPetIdx != null) {
      petIdx =
          postPetIdx is int ? postPetIdx : int.tryParse(postPetIdx.toString());
    } else if (applicantPetIdx != null) {
      petIdx =
          applicantPetIdx is int
              ? applicantPetIdx
              : int.tryParse(applicantPetIdx.toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => Container(
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
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            // 긴급/정기 뱃지
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: post['types'] == 0
                                    ? Colors.red.withAlpha(38)
                                    : AppTheme.primaryBlue.withAlpha(38),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                post['types'] == 0 ? '긴급' : '정기',
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: post['types'] == 0
                                      ? Colors.red
                                      : AppTheme.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                post['title'] ?? '제목 없음',
                                style: AppTheme.h3Style.copyWith(
                                  color: post['types'] == 0
                                      ? Colors.red
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.black),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: '닫기',
                            ),
                          ],
                        ),
                      ),

                      const Divider(),

                      // 내용
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 병원명과 등록일
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 16,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '병원명: ',
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        post['nickname'] ?? '병원',
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    post['created_date'] ?? '',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 주소
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '주소: ',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      post['location'] ?? '주소 정보 없음',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 헌혈 날짜
                              if (post['donation_date'] != null &&
                                  post['donation_date'].toString().isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '헌혈 일정: ',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatCompletionDateTime(
                                          post['donation_date'] ?? '',
                                        ),
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // 게시글 내용 (리치텍스트)
                              PostDetailDescription(
                                contentDelta: post['contentDelta']?.toString(),
                                plainText: post['description']?.toString(),
                              ),

                              // 신청자 정보
                              if (post['user_nickname'] != null &&
                                  post['user_nickname'].toString().isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text('신청자 정보', style: AppTheme.h4Style),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildCompletionInfoRow(
                                        Icons.person,
                                        '신청자',
                                        post['user_name'] != null && post['user_name'].toString().isNotEmpty
                                            ? '${post['user_name']}(${post['user_nickname'] ?? ''})'
                                            : post['user_nickname'] ?? '',
                                      ),
                                      if (post['pet_name'] != null &&
                                          post['pet_name'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _buildCompletionInfoRow(
                                          Icons.pets,
                                          '반려동물',
                                          post['pet_breed'] != null && post['pet_breed'].toString().isNotEmpty
                                              ? '${post['pet_name']}(${post['pet_breed']})'
                                              : post['pet_name'],
                                        ),
                                      ],
                                      if ((post['pet_blood_type'] ?? post['bloodType'] ?? post['blood_type']) != null) ...[
                                        const SizedBox(height: 12),
                                        _buildCompletionInfoRow(
                                          Icons.bloodtype,
                                          '혈액형',
                                          (post['pet_blood_type'] ?? post['bloodType'] ?? post['blood_type']).toString(),
                                        ),
                                      ],
                                      // 헌혈량 표시 (헌혈완료 시)
                                      if (post['blood_volume'] != null) ...[
                                        const SizedBox(height: 12),
                                        _buildCompletionInfoRow(
                                          Icons.water_drop,
                                          '헌혈량',
                                          '${post['blood_volume']} mL',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // 중단 사유 표시 (Status 4 또는 6인 경우)
                              if ((post['status'] == 4 ||
                                      post['status'] == 6) &&
                                  post['cancelled_reason'] != null &&
                                  post['cancelled_reason']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text('중단 사유', style: AppTheme.h4Style),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post['cancelled_reason'],
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(height: 1.4),
                                      ),
                                      if (post['cancelled_at'] != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '중단 시간: ${_formatCancellationTime(post['cancelled_at'])}',
                                          style: AppTheme.bodySmallStyle
                                              .copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // 헌혈 이력 섹션
                              const SizedBox(height: 24),
                              _buildDonationHistorySection(petIdx),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // 헌혈완료/취소 상세 정보 행 빌더
  Widget _buildCompletionInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(child: Text(value, style: AppTheme.bodyMediumStyle)),
      ],
    );
  }

  // 헌혈마감 날짜/시간 포맷팅
  String _formatCompletionDateTime(String dateTime) {
    if (dateTime.isEmpty) return '일정 정보 없음';

    try {
      final date = DateTime.parse(dateTime);
      return DateFormat('yyyy년 MM월 dd일 (E) HH:mm', 'ko_KR').format(date);
    } catch (e) {
      return dateTime;
    }
  }

  // 뱃지 배경색 결정
  Color _getBadgeBackgroundColor(String postType) {
    switch (postType) {
      case '완료대기':
        return Colors.green.withAlpha(38);
      case '중단대기':
        return Colors.pink.withAlpha(38);
      case '진행':
        return Colors.green.withAlpha(38);
      case '마감':
        return Colors.orange.withAlpha(38);
      case '완료':
        return AppTheme.primaryBlue.withAlpha(38);
      case '중단':
        return Colors.grey.withAlpha(38); // 회색으로 변경
      case '거절':
        return Colors.red.withAlpha(38);
      case '긴급':
        return Colors.red.withAlpha(38);
      case '정기':
      default:
        return AppTheme.primaryBlue.withAlpha(38);
    }
  }

  // 뱃지 텍스트 색상 결정
  Color _getBadgeTextColor(String postType) {
    switch (postType) {
      case '완료대기':
        return Colors.green;
      case '중단대기':
        return Colors.pink;
      case '진행':
        return Colors.green;
      case '마감':
        return Colors.orange.shade700;
      case '완료':
        return AppTheme.primaryBlue;
      case '중단':
        return Colors.grey.shade700;
      case '거절':
        return Colors.red;
      case '긴급':
        return Colors.red;
      case '정기':
      default:
        return AppTheme.primaryBlue;
    }
  }

  // 게시글 타입 결정 (헬퍼 함수)
  String _getPostType(Map<String, dynamic> post) {
    if (_currentTabIndex == 2) {
      // 헌혈마감 탭에서는 상태에 따라 뱃지 표시
      if (post['status'] == 3) return '마감';
      return post['status'] == 5 ? '완료대기' : '중단대기';
    } else if (_currentTabIndex == 1) {
      // 헌혈모집 탭에서는 진행/마감 뱃지 표시
      // donation_posts.status: 1 = 진행, 3 = 마감
      return post['status'] == 1 ? '진행' : '마감';
    } else if (_currentTabIndex == 3) {
      // 헌혈완료 탭에서는 완료 뱃지 표시
      return '완료';
    } else if (_currentTabIndex == 4) {
      // 헌혈취소 탭에서는 중단/거절 뱃지 표시
      return post['status'] == 4 ? '중단' : '거절';
    } else {
      // 다른 탭에서는 긴급/정기 뱃지 표시
      return post['types'] == 0 ? '긴급' : '정기';
    }
  }

  // 중단 처리 시간 포맷팅
  String _formatCancellationTime(String? cancelledAt) {
    if (cancelledAt == null || cancelledAt.isEmpty) return '';

    try {
      final date = DateTime.parse(cancelledAt);
      return DateFormat('yyyy년 MM월 dd일 HH:mm', 'ko_KR').format(date);
    } catch (e) {
      return cancelledAt;
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

        // 확인 창 닫기
        if (mounted) {
          Navigator.of(context).pop();
        }

        // 상세 게시글 새로고침을 위해 잠깐 닫고 다시 열기
        if (mounted) {
          await _refreshAndReopenPostDetail(
            post,
            _getPostStatus(newStatus),
            post['types'] == 0 ? '긴급' : '정기',
          );
        }

        // 마감 처리 후 전체 데이터 새로고침
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _fetchDataForCurrentTab();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시글이 성공적으로 마감되었습니다.'),
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
                            '게시글을 재오픈하면 모집중 상태로 변경되며, 모든 시간대의 승인/취소된 신청자가 대기 상태로 초기화됩니다.',
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
                    '게시글 전체 마감',
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

                  // 마감되지 않은 시간대가 있는 경우 경고 표시 (차단하지 않음)
                  if (hasOpenSlots)
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
                              '아직 마감되지 않은 시간대가 있습니다. 전체 마감 시 모든 시간대가 함께 마감됩니다.',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    )
                  // 모든 시간대가 마감된 경우 안내 표시
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.lightGray),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primaryDarkBlue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '모든 시간대가 마감되었습니다. 전체 마감을 진행하시겠습니까?',
                              style: TextStyle(color: AppTheme.primaryDarkBlue),
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
                          // 백엔드에서 유효성 검증 (승인된 신청자 1명 이상 필요)
                          onPressed:
                              isClosing
                                  ? null
                                  : () async {
                                    setState(() {
                                      isClosing = true;
                                    });
                                    await _closeEntirePost(post, onUpdate);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
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
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text('전체 마감 확정'),
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

  // 열린 시간대가 있는지 확인
  bool _hasOpenTimeSlots(Map<String, dynamic> post) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    // status 0 = 열림, status 1 = 마감
    return timeRanges.any((ts) => ts['status'] == 0 || ts['status'] == null);
  }

  // 신청자 상세 정보 바텀시트 표시
  void _showApplicantDetailBottomSheet(
    BuildContext context,
    Map<String, dynamic> applicant,
  ) {
    final petInfo = applicant['pet_info'] as Map<String, dynamic>? ?? {};
    final petIdx = applicant['pet_idx'] as int?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${applicant['nickname'] ?? ''} (${applicant['name'] ?? ''})',
                                    style: AppTheme.h3Style.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    petInfo['name'] ?? '반려동물 정보 없음',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),
                      // 내용
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            // 기본 정보
                            _buildApplicantInfoSection(applicant, petInfo),
                            const SizedBox(height: 24),
                            // 헌혈 이력 섹션
                            _buildDonationHistorySection(petIdx),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // 신청자 정보 섹션
  Widget _buildApplicantInfoSection(
    Map<String, dynamic> applicant,
    Map<String, dynamic> petInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '신청자 정보',
          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildApplicantInfoRow('연락처', _formatPhoneNumber(applicant['contact'])),
        _buildApplicantInfoRow(
          '반려동물',
          '${petInfo['name'] ?? '-'} (${petInfo['breed'] ?? '-'})',
        ),
        _buildApplicantInfoRow(
          '나이 / 혈액형',
          '${petInfo['age'] ?? '-'}세 / ${petInfo['blood_type'] ?? '-'}',
        ),
        _buildApplicantInfoRow('직전 헌혈일', () {
          final lastDonation = petInfo['last_donation_date'];
          if (lastDonation == null || lastDonation.toString().isEmpty) {
            return '첫 헌혈을 기다리는 중';
          }
          return _formatLastDonationDate(lastDonation.toString());
        }()),
      ],
    );
  }

  // 정보 행
  Widget _buildApplicantInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMediumStyle)),
        ],
      ),
    );
  }

  // 헌혈 이력 섹션
  Widget _buildDonationHistorySection(int? petIdx) {
    if (petIdx == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '헌혈 이력',
            style: AppTheme.bodyLargeStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '헌혈 이력 조회 기능 준비 중입니다.',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '헌혈 이력',
          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        FutureBuilder<DonationHistoryResponse?>(
          future: DonationHistoryService.getHistory(petIdx: petIdx, limit: 50),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '이력을 불러오지 못했습니다.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final historyResponse = snapshot.data;
            if (historyResponse == null) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                // 통계 요약
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHistoryStatItem(
                        '총 헌혈 횟수',
                        '${historyResponse.totalCount}회',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),
                      _buildHistoryStatItem(
                        '총 헌혈량',
                        historyResponse.totalBloodVolumeText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 이력 목록
                if (historyResponse.histories.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '헌혈 이력이 없습니다.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...historyResponse.histories.map(
                    (history) => _buildHistoryItem(history),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // 통계 항목
  Widget _buildHistoryStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.h4Style.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmallStyle.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // 헌혈 이력 항목
  Widget _buildHistoryItem(DonationHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                history.dateText,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      history.isSystemRecord
                          ? AppTheme.lightBlue
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  history.isSystemRecord ? '자동' : '수동',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color:
                        history.isSystemRecord
                            ? AppTheme.primaryBlue
                            : Colors.green.shade600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_hospital,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                history.displayHospitalName ?? '정보 없음',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
              Icon(Icons.water_drop, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                history.bloodVolumeMl != null
                    ? '${history.bloodVolumeMl}ml'
                    : '정보 없음',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (history.notes != null && history.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              history.notes!,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
