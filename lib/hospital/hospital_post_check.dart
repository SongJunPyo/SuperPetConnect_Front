import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/unified_post_model.dart';
import '../models/donation_application_model.dart';
import '../models/post_time_item_model.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/applied_donation_model.dart';
import 'donation_completion_sheet.dart';
import 'donation_cancellation_sheet.dart';
import '../widgets/rich_text_viewer.dart';

class HospitalPostCheck extends StatefulWidget {
  const HospitalPostCheck({super.key});

  @override
  State createState() => _HospitalPostCheckState();
}

class _HospitalPostCheckState extends State<HospitalPostCheck>
    with SingleTickerProviderStateMixin {
  List<UnifiedPostModel> posts = [];
  List<UnifiedPostModel> filteredPosts = [];
  List<PostTimeItem> postTimeItems = [];
  List<PostTimeItem> filteredPostTimeItems = [];
  List<RejectedPost> rejectedPosts = [];
  List<RejectedPost> filteredRejectedPosts = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  DateTime? selectedDate;

  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _searchController.addListener(_onSearchChanged);
    _loadPosts();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
      });
      // 탭이 변경되면 해당 탭의 데이터를 로드
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterPosts();
  }

  void _filterPosts() {
    setState(() {
      // 탭별 필터링
      switch (_currentTabIndex) {
        case 0:
          // 모집대기: status가 0인 게시글
          filteredPosts = posts.where((post) => post.status == 0).toList();

          // 검색어 필터링
          if (_searchController.text.isNotEmpty) {
            filteredPosts =
                filteredPosts
                    .where(
                      (post) => post.title.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();
          }

          // 날짜 필터링
          if (selectedDate != null) {
            filteredPosts =
                filteredPosts
                    .where(
                      (post) => _isSameDay(
                        post.createdDate,
                        selectedDate!,
                      ),
                    )
                    .toList();
          }
          break;

        case 1:
          // 헌혈모집: status가 1인 게시글 (모집 진행 중)
          filteredPosts = posts.where((post) => post.status == 1).toList();

          // 검색어 필터링
          if (_searchController.text.isNotEmpty) {
            filteredPosts =
                filteredPosts
                    .where(
                      (post) => post.title.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();
          }

          // 날짜 필터링
          if (selectedDate != null) {
            filteredPosts =
                filteredPosts
                    .where(
                      (post) => _isSameDay(
                        post.createdDate,
                        selectedDate!,
                      ),
                    )
                    .toList();
          }
          break;

        case 2:
          // 모집마감: 시간대별로 분해하여 applicant_status=1(승인)인 시간대만 표시
          filteredPostTimeItems =
              postTimeItems.where((item) => item.applicantStatus == 1).toList();
          debugPrint(
            '[HospitalPostCheck] 모집마감 탭 filter result count: '
            '${filteredPostTimeItems.length}',
          );

          // 검색어 필터링
          if (_searchController.text.isNotEmpty) {
            filteredPostTimeItems =
                filteredPostTimeItems
                    .where(
                      (item) => item.postTitle.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();
          }

          // 날짜 필터링
          if (selectedDate != null) {
            filteredPostTimeItems =
                filteredPostTimeItems
                    .where(
                      (item) =>
                          _isSameDay(DateTime.parse(item.date), selectedDate!),
                    )
                    .toList();
          }
          break;

        case 3:
          // 헌혈완료: 시간대별로 분해하여 applicant_status=7인 시간대만 표시
          filteredPostTimeItems = postTimeItems.toList();

          // 검색어 필터링
          if (_searchController.text.isNotEmpty) {
            filteredPostTimeItems =
                filteredPostTimeItems
                    .where(
                      (item) => item.postTitle.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();
          }

          // 날짜 필터링
          if (selectedDate != null) {
            filteredPostTimeItems =
                filteredPostTimeItems
                    .where(
                      (item) =>
                          _isSameDay(DateTime.parse(item.date), selectedDate!),
                    )
                    .toList();
          }
          break;

        case 4:
          // 헌혈취소: 모집거절 게시글 + 시간대별 취소/거절 항목
          filteredRejectedPosts = rejectedPosts.toList();
          filteredPostTimeItems = postTimeItems.toList();

          // 검색어 필터링 - 모집거절 게시글
          if (_searchController.text.isNotEmpty) {
            filteredRejectedPosts =
                filteredRejectedPosts
                    .where(
                      (post) => post.title.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();

            filteredPostTimeItems =
                filteredPostTimeItems
                    .where(
                      (item) => item.postTitle.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();
          }

          // 날짜 필터링
          if (selectedDate != null) {
            filteredRejectedPosts =
                filteredRejectedPosts
                    .where(
                      (post) => _isSameDay(
                        DateTime.parse(post.createdDate),
                        selectedDate!,
                      ),
                    )
                    .toList();

            filteredPostTimeItems =
                filteredPostTimeItems
                    .where(
                      (item) =>
                          _isSameDay(DateTime.parse(item.date), selectedDate!),
                    )
                    .toList();
          }
          break;

        default:
          filteredPosts = [];
          filteredPostTimeItems = [];
          filteredRejectedPosts = [];
      }
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _loadPosts() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      // 탭에 따라 다른 API 호출
      switch (_currentTabIndex) {
        case 0:
        case 1:
          // 모집대기, 헌혈모집: 기존 게시글 API 사용
          final loadedPosts =
              await HospitalPostService.getUnifiedPostModelsForCurrentUser();
          if (mounted) {
            setState(() {
              posts = loadedPosts;
              isLoading = false;
            });
          }
          break;

        case 2:
          // 모집마감: 승인된 신청자(applicant_status=1)만 조회
          final approvedClosedItems = await HospitalPostService.getPostTimes(
            applicantStatus: 1,
            postStatus: 3,
          );
          debugPrint(
            '[HospitalPostCheck] 모집마감 탭 fetch - applicant=1 count: '
            '${approvedClosedItems.length}',
          );

          if (mounted) {
            setState(() {
              postTimeItems = approvedClosedItems;
              isLoading = false;
            });
          }
          break;

        case 3:
          // 헌혈완료: applicant_status=7, post_status=3
          final loadedPostTimes = await HospitalPostService.getPostTimes(
            applicantStatus: 7,
            postStatus: 3,
          );
          if (mounted) {
            setState(() {
              postTimeItems = loadedPostTimes;
              isLoading = false;
            });
          }
          break;

        case 4:
          // 헌혈취소: 모집거절 게시글 + 취소/거절된 시간대
          // 모집거절 게시글 조회 (서비스 계층에서 422 에러 시 자동으로 대체 방법 사용)
          final loadedRejectedPosts =
              await HospitalPostService.getRejectedPosts();

          // applicant_status=2 (거절) 또는 4 (취소)인 시간대
          final rejectedTimeItems = await HospitalPostService.getPostTimes(
            applicantStatus: 2,
          );
          final cancelledTimeItems = await HospitalPostService.getPostTimes(
            applicantStatus: 4,
          );

          if (mounted) {
            setState(() {
              rejectedPosts = loadedRejectedPosts;
              // 거절과 취소 시간대 합치기
              postTimeItems = [...rejectedTimeItems, ...cancelledTimeItems];
              isLoading = false;
            });
          }
          break;

        default:
          // 기본적으로 전체 게시글 로드
          final loadedPosts =
              await HospitalPostService.getUnifiedPostModelsForCurrentUser();
          if (mounted) {
            setState(() {
              posts = loadedPosts;
              isLoading = false;
            });
          }
      }

      if (mounted) {
        _filterPosts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  // 날짜 선택 함수
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _filterPosts();
    }
  }

  // 날짜 포맷팅 함수
  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('MM.dd').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "헌혈 게시글 현황",
          style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.black),
            onPressed: () => _selectDate(context),
          ),
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black),
              onPressed: () {
                setState(() {
                  selectedDate = null;
                });
                _filterPosts();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadPosts,
          ),
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
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '게시글 제목으로 검색...',
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
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged();
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
                        Tab(text: '모집마감'),
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

                  // 게시글 목록
                  Expanded(child: _buildContent()),
                ],
              ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('오류가 발생했습니다', style: AppTheme.h4Style),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: AppTheme.bodyMediumStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // 탭에 따라 다른 데이터 소스 확인
    bool isEmpty = false;
    int itemCount = 0;

    if (_currentTabIndex == 0 || _currentTabIndex == 1) {
      isEmpty = filteredPosts.isEmpty;
      itemCount = filteredPosts.length;
    } else if (_currentTabIndex == 4) {
      isEmpty = filteredPostTimeItems.isEmpty && filteredRejectedPosts.isEmpty;
      itemCount = filteredPostTimeItems.length + filteredRejectedPosts.length;
    } else {
      isEmpty = filteredPostTimeItems.isEmpty;
      itemCount = filteredPostTimeItems.length;
    }

    if (isEmpty) {
      String emptyMessage;
      switch (_currentTabIndex) {
        case 0:
          emptyMessage = '승인 대기 중인 게시글이 없습니다.';
          break;
        case 1:
          emptyMessage = '헌혈 모집 중인 게시글이 없습니다.';
          break;
        case 2:
          emptyMessage = '모집 마감된 시간대가 없습니다.';
          break;
        case 3:
          emptyMessage = '헌혈 완료된 시간대가 없습니다.';
          break;
        case 4:
          emptyMessage = '헌혈 취소된 시간대가 없습니다.';
          break;
        default:
          emptyMessage = '게시글이 없습니다.';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add_outlined, size: 64, color: AppTheme.mediumGray),
            const SizedBox(height: 16),
            Text(emptyMessage, style: AppTheme.h4Style),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: itemCount + 1, // 헤더 포함
        itemBuilder: (context, index) {
          // 첫 번째 아이템은 헤더
          if (index == 0) {
            return _buildHeaderRow();
          }

          // 나머지는 게시글 아이템
          if (_currentTabIndex == 0 || _currentTabIndex == 1) {
            // 일반 게시글
            final post = filteredPosts[index - 1];
            return _buildPostListItem(post);
          } else if (_currentTabIndex == 4) {
            // 헌혈취소: 모집거절 게시글 + 시간대별 항목
            final rejectedCount = filteredRejectedPosts.length;
            if (index - 1 < rejectedCount) {
              // 모집거절 게시글
              final rejectedPost = filteredRejectedPosts[index - 1];
              return _buildRejectedPostListItem(rejectedPost);
            } else {
              // 시간대별 취소/거절 항목
              final timeItem = filteredPostTimeItems[index - 1 - rejectedCount];
              return _buildPostTimeListItem(timeItem);
            }
          } else {
            // 시간대별 게시글 (모집마감, 헌혈완료)
            final timeItem = filteredPostTimeItems[index - 1];
            return _buildPostTimeListItem(timeItem);
          }
        },
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '구분',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
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
              _currentTabIndex == 2 || _currentTabIndex == 3 ? '시간대' : '작성일',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _currentTabIndex >= 2 ? '신청자' : '신청자',
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

  Widget _buildPostListItem(UnifiedPostModel post) {
    return InkWell(
      onTap: () => _showPostBottomSheet(post),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
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
                  color:
                      post.isUrgent
                          ? Colors.red.withAlpha(38)
                          : Colors.blue.withAlpha(38),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  post.isUrgent ? '긴급' : '정기',
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: post.isUrgent ? Colors.red : Colors.blue,
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
                child: _buildMarqueeText(post.title),
              ),
            ),
            // 작성일
            Container(
              width: 80,
              alignment: Alignment.center,
              child: Text(
                DateFormat('MM.dd').format(post.createdDate),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 신청자 수
            Container(
              width: 70,
              alignment: Alignment.center,
              child: Text(
                '${post.applicantCount > 99 ? '99+' : post.applicantCount}명',
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

  AppliedDonation? _buildAppliedDonationFromPostTime(PostTimeItem item) {
    if (item.applicantIdx == null || item.petIdx == null) {
      return null;
    }

    DateTime? donationDate;
    DateTime? donationDateTime;

    try {
      donationDate = DateTime.parse(item.date);
    } catch (_) {
      donationDate = null;
    }

    if (donationDate != null) {
      final parts = item.time.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          donationDateTime = DateTime(
            donationDate.year,
            donationDate.month,
            donationDate.day,
            hour,
            minute,
          );
        }
      }
    }

    donationDateTime ??= DateTime.tryParse('${item.date} ${item.time}');
    donationDate ??= donationDateTime;

    final species = _mapAnimalTypeToSpecies(item.animalType);

    final pet = Pet(
      petIdx: item.petIdx,
      name: item.petName ?? '반려동물',
      bloodType: item.bloodType,
      animalType: species,
      species: species,
      breed: null,
    );

    return AppliedDonation(
      appliedDonationIdx: item.applicantIdx,
      petIdx: item.petIdx!,
      postTimesIdx: item.postTimesIdx,
      status: item.applicantStatus ?? AppliedDonationStatus.approved,
      donationTime: donationDateTime,
      donationDate: donationDate,
      postTitle: item.postTitle,
      hospitalName:
          item.hospitalName.isNotEmpty
              ? item.hospitalName
              : item.hospitalNickname,
      userNickname: item.applicantNickname,
      pet: pet,
    );
  }

  String? _mapAnimalTypeToSpecies(int? animalType) {
    if (animalType == null) return null;
    return animalType == 0 ? 'dog' : 'cat';
  }

  void _showClosedCompletionSheet(PostTimeItem item) {
    final appliedDonation = _buildAppliedDonationFromPostTime(item);
    if (appliedDonation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신청자 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DonationCompletionSheet(
            appliedDonation: appliedDonation,
            onCompleted: (_) {
              if (!mounted) return;
              _loadPosts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('1차 헌혈 완료 처리되었습니다. 관리자 승인을 기다리고 있습니다.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
    );
  }

  void _showClosedCancellationSheet(PostTimeItem item) {
    final appliedDonation = _buildAppliedDonationFromPostTime(item);
    if (appliedDonation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신청자 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DonationCancellationSheet(
            appliedDonation: appliedDonation,
            onCancelled: (_) {
              if (!mounted) return;
              _loadPosts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('1차 헌혈 중단 처리되었습니다. 관리자 승인을 기다리고 있습니다.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
    );
  }

  Widget _buildPostTimeListItem(PostTimeItem item) {
    // 헌혈취소 탭에서는 상태에 따라 뱃지 표시
    final bool isCancellationTab = _currentTabIndex == 4;
    String badgeText;
    Color badgeColor;
    Color badgeBgColor;

    if (isCancellationTab) {
      // 헌혈취소 탭: applicant_status에 따라 뱃지 표시
      if (item.applicantStatus == 4) {
        badgeText = '취소';
        badgeColor = Colors.grey;
        badgeBgColor = Colors.grey.withAlpha(51);
      } else if (item.applicantStatus == 2) {
        badgeText = '거절';
        badgeColor = Colors.red;
        badgeBgColor = Colors.red.withAlpha(51);
      } else {
        badgeText = item.typeText;
        badgeColor = item.isUrgent ? Colors.red : Colors.blue;
        badgeBgColor =
            item.isUrgent
                ? Colors.red.withAlpha(38)
                : Colors.blue.withAlpha(38);
      }
    } else {
      // 다른 탭: 긴급/정기 표시
      badgeText = item.typeText;
      badgeColor = item.isUrgent ? Colors.red : Colors.blue;
      badgeBgColor =
          item.isUrgent ? Colors.red.withAlpha(38) : Colors.blue.withAlpha(38);
    }

    // 헌혈취소 탭에서는 작성일, 다른 탭에서는 시간대
    final String dateDisplay =
        isCancellationTab
            ? _formatDate(item.createdDate)
            : '${_formatDate(item.date)} ${item.time}';
    final String applicantDisplay = item.applicantNickname != null ? '1명' : '-';

    return InkWell(
      onTap: () => _showPostTimeBottomSheet(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      badgeText,
                      style: AppTheme.bodySmallStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
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
                    child: _buildMarqueeText(item.postTitle),
                  ),
                ),
                // 시간대 또는 작성일
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: Text(
                    dateDisplay,
                    style: AppTheme.bodySmallStyle.copyWith(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // 신청자 수
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  child: Text(
                    applicantDisplay,
                    style: AppTheme.bodySmallStyle.copyWith(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedPostListItem(RejectedPost post) {
    return InkWell(
      onTap: () => _showRejectedPostBottomSheet(post),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
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
                  color: Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  '거절',
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
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
                child: _buildMarqueeText(post.title),
              ),
            ),
            // 작성일
            Container(
              width: 80,
              alignment: Alignment.center,
              child: Text(
                DateFormat('MM.dd').format(DateTime.parse(post.createdDate)),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 빈 칸
            Container(
              width: 70,
              alignment: Alignment.center,
              child: Text(
                '-',
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

  Widget _buildMarqueeText(String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = AppTheme.bodyMediumStyle.copyWith(
          fontWeight: FontWeight.w500,
        );

        final textSpan = TextSpan(text: text, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();

        if (textPainter.size.width <= constraints.maxWidth) {
          return Text(
            text,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(text, style: textStyle, maxLines: 1),
          );
        }
      },
    );
  }

  void _showPostBottomSheet(UnifiedPostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => PostDetailBottomSheet(
            post: post,
            onDeleted: () {
              _loadPosts(); // 삭제 후 목록 새로고침
            },
          ),
    );
  }

  void _showPostTimeBottomSheet(PostTimeItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              final bool canPerformActions =
                  _currentTabIndex == 2 &&
                  item.applicantStatus == 1 &&
                  item.applicantIdx != null &&
                  item.petIdx != null;

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                              color:
                                  item.isUrgent
                                      ? Colors.red.withAlpha(38)
                                      : Colors.blue.withAlpha(38),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.typeText,
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: item.isUrgent ? Colors.red : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.postTitle,
                                  style: AppTheme.h3Style.copyWith(
                                    color:
                                        item.isUrgent
                                            ? Colors.red
                                            : AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // X 버튼
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.pop(context),
                            tooltip: '닫기',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 메타 정보 + 신청자 정보 (스크롤 가능)
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
                                // 병원명
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
                                      item.hospitalNickname,
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                // 등록일 (가장 오른쪽)
                                Text(
                                  DateFormat(
                                    'yy.MM.dd',
                                  ).format(DateTime.parse(item.createdDate)),
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
                                    item.location,
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 헌혈 날짜
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '헌혈 날짜: ',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.date,
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 헌혈 시간
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '헌혈 시간: ',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.time,
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // 설명글 (리치 텍스트)
                            if ((item.contentDelta != null &&
                                    item.contentDelta!.isNotEmpty) ||
                                (item.postDescription != null &&
                                    item.postDescription!.isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.veryLightGray,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.lightGray.withAlpha(128),
                                  ),
                                ),
                                child: RichTextViewer(
                                  contentDelta: item.contentDelta,
                                  plainText: item.postDescription,
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                            // 신청자 정보 (있는 경우)
                            if (item.applicantNickname != null) ...[
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
                                    _buildInfoRow(
                                      Icons.person,
                                      '신청자',
                                      item.applicantNickname!,
                                    ),
                                    if (item.petName != null) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        Icons.pets,
                                        '반려동물',
                                        '${item.petName} (${item.animalTypeText ?? "정보없음"})',
                                      ),
                                    ],
                                    if (item.bloodType != null) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        Icons.bloodtype,
                                        '혈액형',
                                        item.bloodType!,
                                      ),
                                    ],
                                    if (item.applicantStatus != null) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('상태: '),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                item.applicantStatus!,
                                              ).withAlpha(51),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.applicantStatusText ??
                                                  '알 수 없음',
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                  item.applicantStatus!,
                                                ),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            // 헌혈 중단/완료 버튼 (스크롤 영역 안에 포함)
                            if (canPerformActions) ...[
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _showClosedCancellationSheet(item);
                                      },
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      label: const Text('헌혈 중단'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _showClosedCompletionSheet(item);
                                      },
                                      icon: const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      label: const Text('헌혈 완료'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(
                                          color: Colors.green,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
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
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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

  Color _getStatusColor(int status) {
    return AppliedDonationStatus.getStatusColorValue(status);
  }

  void _showRejectedPostBottomSheet(RejectedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          // 거절 뱃지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '모집거절',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  style: AppTheme.h3Style.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // X 버튼
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.pop(context),
                            tooltip: '닫기',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 메타 정보
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 작성일과 거절일
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '작성일: ',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('yy.MM.dd').format(
                                        DateTime.parse(post.createdDate),
                                      ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (post.rejectedDate != null)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.block,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '거절: ${DateFormat('yy.MM.dd').format(DateTime.parse(post.rejectedDate!))}',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if ((post.contentDelta != null &&
                                    post.contentDelta!.isNotEmpty) ||
                                (post.description != null &&
                                    post.description!.isNotEmpty)) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.veryLightGray,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.lightGray.withAlpha(128),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        top: 12,
                                        right: 12,
                                      ),
                                      child: Text(
                                        '게시글 설명',
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    RichTextViewer(
                                      contentDelta: post.contentDelta,
                                      plainText: post.description,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (post.rejectionReason != null &&
                                post.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 20,
                                          color: Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '거절 사유',
                                          style: AppTheme.bodyMediumStyle
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.red.shade700,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      post.rejectionReason!,
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: Colors.red.shade900,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
    );
  }
}

// 바텀시트 위젯 - 사용자 헌혈 모집 게시글 페이지 스타일로 변경
class PostDetailBottomSheet extends StatefulWidget {
  final UnifiedPostModel post;
  final VoidCallback onDeleted;

  const PostDetailBottomSheet({
    super.key,
    required this.post,
    required this.onDeleted,
  });

  @override
  State createState() => _PostDetailBottomSheetState();
}

class _PostDetailBottomSheetState extends State<PostDetailBottomSheet> {
  List<DonationApplication> applicants = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await HospitalPostService.getApplicants(
        widget.post.id.toString(),
      );
      setState(() {
        applicants = response.applications;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('게시글 삭제'),
            content: const Text('정말로 이 게시글을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await HospitalPostService.deletePost(widget.post.id.toString());

        if (mounted) {
          Navigator.of(context).pop(); // 바텀시트 닫기
          widget.onDeleted(); // 목록 새로고침 콜백 호출
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '삭제 실패: ${e.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  // 헌혈 완료 바텀시트 표시
  void _showCompletionDialog(DonationApplication applicant) {
    // AppliedDonation 객체 생성
    final appliedDonation = AppliedDonation(
      appliedDonationIdx: applicant.appliedDonationIdx,
      petIdx: applicant.pet.petIdx,
      postTimesIdx: applicant.postTimesIdx,
      status: applicant.status,
      userNickname: applicant.userNickname,
      pet: Pet(
        petIdx: applicant.pet.petIdx,
        name: applicant.pet.name,
        bloodType: applicant.pet.bloodType,
        weightKg: applicant.pet.weightKg,
        age: applicant.pet.ageNumber,
        species: applicant.pet.species,
        animalType: applicant.pet.species,
        breed: applicant.pet.breed,
      ),
      donationTime:
          applicant.selectedTime != null
              ? DateTime.parse(
                '${applicant.selectedDate} ${applicant.selectedTime}',
              )
              : null,
      postTitle: widget.post.title,
      hospitalName: widget.post.hospitalNickname ?? widget.post.hospitalName,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DonationCompletionSheet(
            appliedDonation: appliedDonation,
            onCompleted: (completedDonation) {
              // 완료 처리 후 목록 새로고침
              _loadApplicants();
              Navigator.pop(context); // 바텀시트 닫기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('1차 헌혈 완료 처리되었습니다. 관리자 승인을 기다리고 있습니다.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
    );
  }

  // 헌혈 중단 바텀시트 표시
  void _showCancellationDialog(DonationApplication applicant) {
    // AppliedDonation 객체 생성
    final appliedDonation = AppliedDonation(
      appliedDonationIdx: applicant.appliedDonationIdx,
      petIdx: applicant.pet.petIdx,
      postTimesIdx: applicant.postTimesIdx,
      status: applicant.status,
      userNickname: applicant.userNickname,
      pet: Pet(
        petIdx: applicant.pet.petIdx,
        name: applicant.pet.name,
        bloodType: applicant.pet.bloodType,
        weightKg: applicant.pet.weightKg,
        age: applicant.pet.ageNumber,
        species: applicant.pet.species,
        animalType: applicant.pet.species,
        breed: applicant.pet.breed,
      ),
      donationTime:
          applicant.selectedTime != null
              ? DateTime.parse(
                '${applicant.selectedDate} ${applicant.selectedTime}',
              )
              : null,
      postTitle: widget.post.title,
      hospitalName: widget.post.hospitalNickname ?? widget.post.hospitalName,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DonationCancellationSheet(
            appliedDonation: appliedDonation,
            onCancelled: (cancelledDonation) {
              // 중단 처리 후 목록 새로고침
              _loadApplicants();
              Navigator.pop(context); // 바텀시트 닫기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('1차 헌혈 중단 처리되었습니다. 관리자 승인을 기다리고 있습니다.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        color:
                            widget.post.isUrgent
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.post.isUrgent ? '긴급' : '정기',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color:
                              widget.post.isUrgent ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.title,
                            style: AppTheme.h3Style.copyWith(
                              color:
                                  widget.post.isUrgent
                                      ? Colors.red
                                      : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // X 버튼
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '닫기',
                    ),
                    // 휴지통 버튼 (대기 상태일 때만 표시)
                    if (widget.post.status == 0)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: _deletePost,
                        tooltip: '게시글 삭제',
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 전체 콘텐츠 (스크롤 가능)
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 메타 정보
                      // 병원명과 등록일
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 병원명
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
                                widget.post.hospitalNickname ?? widget.post.hospitalName,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          // 등록일 (가장 오른쪽)
                          Text(
                            DateFormat(
                              'yy.MM.dd',
                            ).format(widget.post.createdDate),
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 담당자 이름
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '담당자: ',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.post.hospitalNickname ?? widget.post.hospitalName,
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
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
                              widget.post.location,
                              style: AppTheme.bodyMediumStyle.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 동물 종류
                      Row(
                        children: [
                          Icon(
                            widget.post.animalType == 0
                                ? FontAwesomeIcons.dog
                                : FontAwesomeIcons.cat,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '동물 종류: ',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.post.animalTypeKorean,
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 신청자 수
                      Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '신청자 수: ',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${applicants.length}명',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 설명글 (있는 경우만)
                      if ((widget.post.contentDelta != null &&
                              widget.post.contentDelta!.isNotEmpty) ||
                          widget.post.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.veryLightGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.lightGray.withValues(alpha: 0.5),
                            ),
                          ),
                          child: RichTextViewer(
                            contentDelta: widget.post.contentDelta,
                            plainText: widget.post.description,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      // 혈액형 정보
                      if (widget.post.bloodType != null &&
                          widget.post.bloodType!.isNotEmpty) ...[
                        Text('필요 혈액형', style: AppTheme.h4Style),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                widget.post.isUrgent
                                    ? Colors.red.shade50
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  widget.post.isUrgent
                                      ? Colors.red.shade200
                                      : Colors.blue.shade200,
                            ),
                          ),
                          child: Text(
                            widget.post.displayBloodType,
                            style: AppTheme.h3Style.copyWith(
                              color:
                                  widget.post.isUrgent
                                      ? Colors.red
                                      : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      const SizedBox(height: 24),

                      // 헌혈 예정일
                      Text("헌혈 예정일", style: AppTheme.h4Style),
                      const SizedBox(height: 12),

                      // 드롭다운 형태의 날짜/시간 선택 UI
                      _buildDateTimeDropdown(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplicantCard(DonationApplication applicant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 반려동물 정보와 상태
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 반려동물 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  applicant.pet.species == '강아지' || applicant.pet.species == '개'
                      ? FontAwesomeIcons.dog
                      : FontAwesomeIcons.cat,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // 반려동물 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 신청자 닉네임
                              Text(
                                '신청자: ${applicant.userNickname ?? "정보 없음"}',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // 반려동물 이름
                              Text(
                                '반려동물: ${applicant.pet.name}',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // status가 유효한 경우에만 칩 표시 (0-6)
                        if (applicant.status >= 0 && applicant.status <= 6)
                          _buildStatusChip(applicant.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${applicant.pet.breed ?? applicant.pet.speciesKorean} • ${applicant.pet.bloodType ?? "미등록"} • ${applicant.pet.weightKg}kg',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 신청 시간대 정보 (간소화)
          if (applicant.selectedDate != null &&
              applicant.selectedTime != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDateWithWeekday(applicant.selectedDate!)} ${_formatTime(applicant.selectedTime!)}',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 액션 버튼 또는 상태 메시지
          if (applicant.status == 1) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancellationDialog(applicant),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black,
                    ),
                    label: const Text('헌혈 중단'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
                      backgroundColor: Colors.red.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCompletionDialog(applicant),
                    icon: const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.black,
                    ),
                    label: const Text('헌혈 완료'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                      backgroundColor: Colors.green.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(int status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getApplicantStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getApplicantStatusColor(status).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        _getApplicantStatusText(status),
        style: TextStyle(
          color: _getApplicantStatusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getApplicantStatusText(int status) {
    switch (status) {
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '거절';
      case 3:
        return '완료';
      case 4:
        return '취소';
      case 5:
        return '완료대기';
      case 6:
        return '취소대기';
      default:
        return '알 수 없음';
    }
  }

  Color _getApplicantStatusColor(int status) {
    switch (status) {
      case 0:
        return AppTheme.warning;
      case 1:
        return AppTheme.success;
      case 2:
        return AppTheme.error;
      case 3:
        return AppTheme.primaryBlue;
      case 4:
        return Colors.grey;
      case 5:
        return Colors.green;
      case 6:
        return Colors.orange;
      default:
        return AppTheme.textPrimary;
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

  // 시간 포맷팅 메서드 - 24시간제
  String _formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        return '${hour.toString().padLeft(2, '0')}:$minute';
      }
    } catch (e) {
      return time24;
    }
    return '시간 미정';
  }

  Widget _buildDateTimeDropdown() {
    if (widget.post.timeRanges == null || widget.post.timeRanges!.isEmpty) {
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
    final Map<String, List<TimeRange>> groupedByDate = {};
    final Set<String> seenTimeSlots = {}; // 중복 체크용

    for (final timeRange in widget.post.timeRanges!) {
      final dateStr = timeRange.date ?? widget.post.createdDate.toString().split(' ')[0];
      // 날짜+시간+팀으로 고유키 생성하여 중복 체크
      final uniqueKey = '$dateStr-${timeRange.time}-${timeRange.team}';

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
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  leading: Icon(
                    Icons.calendar_today,
                    color: Colors.black,
                    size: 20,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 날짜',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateWithWeekday(dateStr),
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.black,
                    size: 24,
                  ),
                  children:
                      timeSlots.map<Widget>((timeSlot) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Material(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap:
                                  () => _showApplicantsBottomSheet(
                                    dateStr,
                                    timeSlot,
                                  ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '헌혈 시간',
                                            style: AppTheme.bodySmallStyle
                                                .copyWith(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_formatTime(timeSlot.time)} (${_getApplicantCountForTimeSlot(dateStr, timeSlot)}명 신청)',
                                            style: AppTheme.bodyMediumStyle
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.people_outline,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                              ),
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

  // 특정 시간대의 신청자 목록을 보여주는 바텀시트
  void _showApplicantsBottomSheet(String dateStr, TimeRange timeSlot) {
    // 해당 시간대에 신청한 지원자들 필터링
    List<DonationApplication> filteredApplicants =
        applicants.where((applicant) {
          final dateMatch = applicant.selectedDate == dateStr;
          final timeMatch = applicant.selectedTime == timeSlot.time;

          // 팀 매칭: timeSlot.team이 "1", "2" 형태인 경우 "A", "B"로 변환
          String teamString = timeSlot.team;
          if (RegExp(r'^\d+$').hasMatch(teamString)) {
            // 숫자 문자열인 경우 (예: "1", "2")
            final teamNum = int.tryParse(teamString);
            if (teamNum != null && teamNum > 0) {
              teamString = String.fromCharCode(64 + teamNum); // 1=A, 2=B, ...
            }
          }
          final teamMatch = applicant.selectedTeam == teamString;

          return dateMatch && timeMatch && teamMatch;
        }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // 헤더
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 드래그 핸들
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
                          Row(
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
                                      '${_formatDateWithWeekday(dateStr)} ${_formatTime(timeSlot.time)}',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 신청자 목록
                    Expanded(
                      child:
                          filteredApplicants.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '이 시간대에 신청한 사용자가 없습니다',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(20),
                                itemCount: filteredApplicants.length,
                                itemBuilder: (context, index) {
                                  return _buildApplicantCard(
                                    filteredApplicants[index],
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // 특정 시간대의 신청자 수를 계산하는 함수
  int _getApplicantCountForTimeSlot(String dateStr, TimeRange timeSlot) {
    var filtered = applicants.where((applicant) {
      final dateMatch = applicant.selectedDate == dateStr;
      final timeMatch = applicant.selectedTime == timeSlot.time;

      // 팀 매칭 로직 (showApplicantsBottomSheet와 동일)
      String teamString = timeSlot.team;
      if (RegExp(r'^\d+$').hasMatch(teamString)) {
        final teamNum = int.tryParse(teamString);
        if (teamNum != null && teamNum > 0) {
          teamString = String.fromCharCode(64 + teamNum);
        }
      }
      final teamMatch = applicant.selectedTeam == teamString;

      return dateMatch && timeMatch && teamMatch;
    });

    return filtered.length;
  }
}
