import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/hospital_post_model.dart';
import '../models/donation_application_model.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/applied_donation_model.dart';
import 'donation_completion_dialog.dart';
import 'donation_cancellation_dialog.dart';

class HospitalPostCheck extends StatefulWidget {
  const HospitalPostCheck({super.key});

  @override
  State createState() => _HospitalPostCheckState();
}

class _HospitalPostCheckState extends State<HospitalPostCheck>
    with SingleTickerProviderStateMixin {
  List<HospitalPost> posts = [];
  List<HospitalPost> filteredPosts = [];
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
      _filterPosts();
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
      List<HospitalPost> filtered;

      // 탭별 필터링
      switch (_currentTabIndex) {
        case 0:
          // 모집대기: status가 0인 게시글
          filtered = posts.where((post) => post.status == 0).toList();
          break;
        case 1:
          // 모집진행: status가 1인 게시글
          filtered = posts.where((post) => post.status == 1).toList();
          break;
        case 2:
          // 모집마감: status가 3인 게시글
          filtered = posts.where((post) => post.status == 3).toList();
          break;
        case 3:
          // 모집거절: status가 2인 게시글
          filtered = posts.where((post) => post.status == 2).toList();
          break;
        case 4:
          // 헌혈완료: status가 4인 게시글 (완료된 게시글)
          filtered = posts.where((post) => post.status == 4).toList();
          break;
        default:
          filtered = [];
      }

      // 검색어 필터링
      if (_searchController.text.isNotEmpty) {
        filtered =
            filtered
                .where(
                  (post) => post.title.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ),
                )
                .toList();
      }

      // 날짜 필터링
      if (selectedDate != null) {
        filtered =
            filtered
                .where(
                  (post) => _isSameDay(
                    DateTime.parse(post.createdDate),
                    selectedDate!,
                  ),
                )
                .toList();
      }

      filteredPosts = filtered;
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

      final loadedPosts =
          await HospitalPostService.getHospitalPostsForCurrentUser();

      if (mounted) {
        setState(() {
          posts = loadedPosts;
          isLoading = false;
        });
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
      return DateFormat('yyyy.MM.dd').format(date);
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
                        Tab(text: '모집진행'),
                        Tab(text: '모집마감'),
                        Tab(text: '모집거절'),
                        Tab(text: '헌혈완료'),
                      ],
                      indicatorColor: Colors.black,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

    if (filteredPosts.isEmpty) {
      String emptyMessage;
      switch (_currentTabIndex) {
        case 0:
          emptyMessage = '승인 대기 중인 게시글이 없습니다.';
          break;
        case 1:
          emptyMessage = '모집 진행 중인 게시글이 없습니다.';
          break;
        case 2:
          emptyMessage = '모집 마감된 게시글이 없습니다.';
          break;
        case 3:
          emptyMessage = '거절된 게시글이 없습니다.';
          break;
        case 4:
          emptyMessage = '헌혈 완료된 게시글이 없습니다.';
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
        itemCount: filteredPosts.length + 1, // 헤더 포함
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
                      '작성일',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 70,
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

          // 나머지는 게시글 아이템
          final post = filteredPosts[index - 1];
          return _buildPostListItem(post);
        },
      ),
    );
  }

  Widget _buildPostListItem(HospitalPost post) {
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
                _formatDate(post.createdDate),
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
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
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

  void _showPostBottomSheet(HospitalPost post) {
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
}

// 바텀시트 위젯 - 사용자 헌혈 모집 게시글 페이지 스타일로 변경
class PostDetailBottomSheet extends StatefulWidget {
  final HospitalPost post;
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
        widget.post.postIdx.toString(),
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
        // await HospitalPostService.deletePost(widget.post.postIdx.toString());

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
              content: Text('삭제 중 오류가 발생했습니다: ${e.toString()}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  // 헌혈 완료 다이얼로그 표시
  void _showCompletionDialog(DonationApplication applicant) {
    // AppliedDonation 객체 생성
    final appliedDonation = AppliedDonation(
      appliedDonationIdx: applicant.appliedDonationIdx,
      petIdx: applicant.pet.petIdx,
      postTimesIdx: applicant.postTimesIdx,
      status: applicant.status,
      pet: Pet(
        petIdx: applicant.pet.petIdx,
        name: applicant.pet.name,
        bloodType: applicant.pet.bloodType,
        weightKg: applicant.pet.weightKg,
        age: applicant.pet.ageNumber,
      ),
      donationTime:
          applicant.selectedTime != null
              ? DateTime.parse(
                '${applicant.selectedDate} ${applicant.selectedTime}',
              )
              : null,
      postTitle: widget.post.title,
      hospitalName: widget.post.nickname,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => DonationCompletionDialog(
            appliedDonation: appliedDonation,
            onCompleted: (completedDonation) {
              // 완료 처리 후 목록 새로고침
              _loadApplicants();
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

  // 헌혈 중단 다이얼로그 표시
  void _showCancellationDialog(DonationApplication applicant) {
    // AppliedDonation 객체 생성
    final appliedDonation = AppliedDonation(
      appliedDonationIdx: applicant.appliedDonationIdx,
      petIdx: applicant.pet.petIdx,
      postTimesIdx: applicant.postTimesIdx,
      status: applicant.status,
      pet: Pet(
        petIdx: applicant.pet.petIdx,
        name: applicant.pet.name,
        bloodType: applicant.pet.bloodType,
        weightKg: applicant.pet.weightKg,
        age: applicant.pet.ageNumber,
      ),
      donationTime:
          applicant.selectedTime != null
              ? DateTime.parse(
                '${applicant.selectedDate} ${applicant.selectedTime}',
              )
              : null,
      postTitle: widget.post.title,
      hospitalName: widget.post.nickname,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => DonationCancellationDialog(
            appliedDonation: appliedDonation,
            onCancelled: (cancelledDonation) {
              // 중단 처리 후 목록 새로고침
              _loadApplicants();
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

              // 메타 정보
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 닉네임
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.post.nickname,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        // 상태 표시
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            _getStatusText(),
                            style: AppTheme.bodySmallStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 이름
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.post.name,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            fontWeight: FontWeight.w500,
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
                        Expanded(
                          child: Text(
                            widget.post.location,
                            style: AppTheme.bodyMediumStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 동물 종류
                    Row(
                      children: [
                        Icon(
                          widget.post.animalTypeString == "dog"
                              ? FontAwesomeIcons.dog
                              : FontAwesomeIcons.cat,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.post.animalTypeText,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            fontWeight: FontWeight.w500,
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
                          '${applicants.length}명',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    // 설명글 (있는 경우만)
                    if (widget.post.description != null &&
                        widget.post.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.veryLightGray,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.lightGray.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          widget.post.description!,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 상세 정보
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      // 작성일
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateWithWeekday(widget.post.createdDate),
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 헌혈 예정일
                      Text("헌혈 예정일", style: AppTheme.h4Style),
                      const SizedBox(height: 12),

                      // 드롭다운 형태의 날짜/시간 선택 UI
                      _buildDateTimeDropdown(),

                      const SizedBox(height: 24),

                      // 신청자 목록
                      Text(
                        '신청자 목록 (${applicants.length}명)',
                        style: AppTheme.h4Style,
                      ),
                      const SizedBox(height: 12),

                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (errorMessage != null)
                        Center(
                          child: Text(
                            '신청자 목록을 불러올 수 없습니다: $errorMessage',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else if (applicants.isEmpty)
                        Center(
                          child: Text(
                            '아직 신청자가 없습니다',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        )
                      else
                        ...applicants.map(
                          (applicant) => _buildApplicantCard(applicant),
                        ),
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
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  applicant.pet.name,
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: _getApplicantStatusColor(
                      applicant.status,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    _getApplicantStatusText(applicant.status),
                    style: AppTheme.bodySmallStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getApplicantStatusColor(applicant.status),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${applicant.pet.speciesKorean} • ${applicant.pet.bloodType ?? "미등록"} • ${applicant.pet.weightKg}kg • ${applicant.pet.age}',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            // 신청한 시간대 정보 표시
            if (applicant.selectedDate != null &&
                applicant.selectedTime != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '신청 시간: ${_formatDateWithWeekday(applicant.selectedDate!)} ${_formatTime(applicant.selectedTime!)} (${applicant.selectedTeam?.toString() ?? "A"}팀)',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 승인된 상태일 때만 완료/중단 버튼 표시
            if (applicant.status == 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 헌혈 중단 버튼
                  OutlinedButton.icon(
                    onPressed: () => _showCancellationDialog(applicant),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('헌혈 중단'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: AppTheme.bodySmallStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 헌혈 완료 버튼
                  ElevatedButton.icon(
                    onPressed: () => _showCompletionDialog(applicant),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('헌혈 완료'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: AppTheme.bodySmallStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // 완료대기/중단대기 상태 표시
            if (applicant.status == 5 || applicant.status == 6) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      applicant.status == 5
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        applicant.status == 5
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      applicant.status == 5
                          ? Icons.hourglass_top
                          : Icons.hourglass_bottom,
                      size: 14,
                      color:
                          applicant.status == 5
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      applicant.status == 5
                          ? '관리자 승인 대기 중 (완료)'
                          : '관리자 승인 대기 중 (중단)',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color:
                            applicant.status == 5
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (widget.post.status) {
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '취소';
      case 3:
        return '완료';
      default:
        return '알 수 없음';
    }
  }

  Color _getStatusColor() {
    switch (widget.post.status) {
      case 0:
        return AppTheme.warning;
      case 1:
        return AppTheme.primaryBlue;
      case 2:
        return AppTheme.error;
      case 3:
        return AppTheme.success;
      default:
        return AppTheme.textPrimary;
    }
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

  // 시간 포맷팅 메서드
  String _formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length == 2) {
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

  Widget _buildDateTimeDropdown() {
    if (widget.post.timeRanges.isEmpty) {
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

    for (final timeRange in widget.post.timeRanges) {
      final dateStr = timeRange.date ?? widget.post.createdDate;
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '헌혈 시간',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatTime(timeSlot.time)} (${timeSlot.team.toString()}팀)',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            );
          }).toList(),
    );
  }
}
