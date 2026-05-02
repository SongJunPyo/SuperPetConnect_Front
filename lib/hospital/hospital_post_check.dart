import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/applied_donation_model.dart';
import '../models/donation_application_model.dart';
import '../models/post_time_item_model.dart';
import '../models/unified_post_model.dart';
import '../services/donation_post_image_service.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_theme.dart';
import '../utils/error_display.dart';
import '../utils/pet_field_icons.dart';
import '../utils/pet_image_downloader.dart';
import '../utils/time_format_util.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/info_row.dart';
import '../widgets/pet_profile_image.dart';
import '../widgets/pet_status_row.dart';
import '../widgets/post_detail/post_detail_blood_type.dart';
import '../widgets/post_detail/post_detail_description.dart';
import '../widgets/post_detail/post_detail_handle_bar.dart';
import '../widgets/post_detail/post_detail_meta_section.dart';
import '../widgets/post_detail/post_detail_patient_info.dart';
import '../widgets/rich_text_viewer.dart';
import 'donation_completion_sheet.dart';
import 'hospital_active_posts_tab.dart';
import 'hospital_closed_recruitment_tab.dart';
import 'hospital_completed_donations_tab.dart';
import 'hospital_pending_posts_tab.dart';

class HospitalPostCheck extends StatefulWidget {
  /// 알림 탭 등 외부에서 진입 시 자동으로 열 게시글의 post_idx.
  /// null이면 일반 진입 (자동 오픈 없음).
  final int? initialPostIdx;

  const HospitalPostCheck({super.key, this.initialPostIdx});

  @override
  State createState() => _HospitalPostCheckState();
}

class _HospitalPostCheckState extends State<HospitalPostCheck>
    with SingleTickerProviderStateMixin {
  // 탭 컨트롤러 + 현재 인덱스 (시트 빌더 분기에 사용).
  TabController? _tabController;
  int _currentTabIndex = 0;

  // 검색 / 날짜 필터 (4개 탭 위젯이 props로 공유).
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // 탭 위젯 외부 refresh()용 키.
  final GlobalKey<HospitalPendingPostsTabState> _pendingTabKey = GlobalKey();
  final GlobalKey<HospitalActivePostsTabState> _activeTabKey = GlobalKey();
  final GlobalKey<HospitalClosedRecruitmentTabState> _closedTabKey =
      GlobalKey();
  final GlobalKey<HospitalCompletedDonationsTabState> _completedTabKey =
      GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) return;
      if (_tabController!.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController!.index;
        });
      }
    });
    _searchController.addListener(_onSearchTextChanged);

    // 알림 탭 진입 시 자동으로 해당 게시글 바텀시트 오픈.
    // 백엔드 단건 fetch API가 status 0~5 모두 지원하므로 어느 탭이든 무관.
    if (widget.initialPostIdx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final post = await HospitalPostService.getPostByIdx(
          widget.initialPostIdx!,
        );
        if (!mounted) return;
        if (post != null) {
          _showPostBottomSheet(post);
        }
      });
    }
  }

  void _onSearchTextChanged() {
    if (_searchController.text != _searchQuery) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 현재 탭 새로고침 — 게시글 삭제/상태 변경 후 호출.
  void _refreshCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        _pendingTabKey.currentState?.refresh();
        break;
      case 1:
        _activeTabKey.currentState?.refresh();
        break;
      case 2:
        _closedTabKey.currentState?.refresh();
        break;
      case 3:
        _completedTabKey.currentState?.refresh();
        break;
    }
  }

  // 날짜 범위 선택 함수
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange:
          _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
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
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.black),
            onPressed: () => _selectDateRange(context),
          ),
          if (_startDate != null && _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black),
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshCurrentTab,
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
                    child: AppSearchBar(
                      controller: _searchController,
                      hintText: '게시글 제목으로 검색...',
                      onClear: () {
                        // controller listener가 _searchQuery 동기화하므로 별도 처리 불필요.
                      },
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

                  // 탭별 콘텐츠
                  Expanded(child: _buildTabContent()),
                ],
              ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return HospitalPendingPostsTab(
          key: _pendingTabKey,
          searchQuery: _searchQuery,
          startDate: _startDate,
          endDate: _endDate,
          onTapPost: _showPostBottomSheet,
        );
      case 1:
        return HospitalActivePostsTab(
          key: _activeTabKey,
          searchQuery: _searchQuery,
          startDate: _startDate,
          endDate: _endDate,
          onTapPost: _showPostBottomSheet,
        );
      case 2:
        return HospitalClosedRecruitmentTab(
          key: _closedTabKey,
          searchQuery: _searchQuery,
          startDate: _startDate,
          endDate: _endDate,
          onTapItem: _showPostTimeBottomSheet,
        );
      case 3:
        return HospitalCompletedDonationsTab(
          key: _completedTabKey,
          searchQuery: _searchQuery,
          startDate: _startDate,
          endDate: _endDate,
          onTapItem: _showPostTimeBottomSheet,
        );
      default:
        return const SizedBox.shrink();
    }
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
              _refreshCurrentTab();
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
            onDeleted: _refreshCurrentTab,
            tabIndex: _currentTabIndex,
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
              // 승인(1) 상태일 때만 헌혈 완료 버튼 표시.
              // 완료대기(2)는 이미 처리된 상태이므로 버튼 숨김.
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
                          // 병원 프로필 사진
                          if (item.hospitalProfileImage != null) ...[
                            PetProfileImage(
                              profileImage: item.hospitalProfileImage,
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
                          ],
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
                                      PetFieldIcons.hospital,
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
                                  PetFieldIcons.postLocation,
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
                                  Icons.calendar_today_outlined,
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
                                    // 신청자 정보 + 프로필 사진
                                    if (item.applicantNickname != null && item.applicantNickname!.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          PetProfileImage(
                                            profileImage: item.applicantProfileImage,
                                            radius: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(PetFieldIcons.nickname, size: 16, color: AppTheme.textSecondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.applicantNickname!,
                                              style: AppTheme.bodyMediumStyle,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (item.applicantName != null && item.applicantName!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      InfoRow(
                                        icon: PetFieldIcons.userName,
                                        label: '이름',
                                        value: item.applicantName!,
                                      ),
                                    ],
                                    if (item.applicantPhone != null && item.applicantPhone!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      InfoRow(
                                        icon: PetFieldIcons.phone,
                                        label: '연락처',
                                        value: item.applicantPhone!,
                                      ),
                                    ],
                                    const Divider(height: 24),
                                    // 반려동물 정보 + 프로필 사진
                                    if (item.petName != null) ...[
                                      Row(
                                        children: [
                                          PetProfileImage(
                                            profileImage: item.petProfileImage,
                                            species: item.animalTypeText,
                                            radius: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.pets, size: 16, color: AppTheme.textSecondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${item.petName} (${item.animalTypeText ?? "정보없음"})',
                                              style: AppTheme.bodyMediumStyle,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // 모집마감 탭 + 펫 프로필 사진 있는 경우만 다운로드 버튼 노출
                                          if (_currentTabIndex == 2 &&
                                              item.petProfileImage != null &&
                                              item.petProfileImage!.isNotEmpty)
                                            TextButton.icon(
                                              onPressed: () => _downloadPetImage(item),
                                              icon: const Icon(
                                                Icons.download_outlined,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                '사진 다운로드',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppTheme.primaryBlue,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    // 펫 정보 표시 순서 (회원가입 관리 / 관리자 펫 관리와 정합):
                                    // (헤더에 펫 이름+종류 표시) 품종 → 성별 → 혈액형 → 체중 →
                                    // 생년월일 → 최근 헌혈일 → 접종 → 예방약 → 중성화 → 질병 → 임신/출산
                                    if (item.petBreed != null && item.petBreed!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      InfoRow(
                                        icon: PetFieldIcons.breed,
                                        label: '품종',
                                        value: item.petBreed!,
                                      ),
                                    ],
                                    if (item.petSex != null) ...[
                                      const SizedBox(height: 12),
                                      InfoRow(
                                        icon: PetFieldIcons.sex(item.petSex!),
                                        label: '성별',
                                        value: item.petSex == 0 ? '암컷' : '수컷',
                                      ),
                                    ],
                                    if (item.bloodType != null) ...[
                                      const SizedBox(height: 12),
                                      InfoRow(
                                        icon: PetFieldIcons.bloodType,
                                        label: '혈액형',
                                        value: item.bloodType!,
                                      ),
                                    ],
                                    if (item.petWeightKg != null) ...[
                                      const SizedBox(height: 12),
                                      InfoRow(
                                        icon: PetFieldIcons.weight,
                                        label: '체중',
                                        value: '${item.petWeightKg}kg',
                                      ),
                                    ],
                                    if (item.petBirthDate != null && item.petBirthDate!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      () {
                                        final birthDate = DateTime.tryParse(item.petBirthDate!);
                                        String birthText = item.petBirthDate!.split('T')[0].replaceAll('-', '.');
                                        if (birthDate != null) {
                                          final months = (DateTime.now().year - birthDate.year) * 12 + (DateTime.now().month - birthDate.month);
                                          final ageText = months < 12 ? '$months개월' : '${months ~/ 12}살';
                                          birthText = '$birthText ($ageText)';
                                        }
                                        return InfoRow(icon: PetFieldIcons.birthDate, label: '생년월일', value: birthText);
                                      }(),
                                    ],
                                    // 최근 헌혈일: 값 있으면 텍스트, 없으면 회색 — (첫 헌혈)
                                    if (item.petPrevDonationDate != null && item.petPrevDonationDate!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      InfoRow(
                                        icon: PetFieldIcons.prevDonationDate,
                                        label: '최근 헌혈일',
                                        value: item.petPrevDonationDate!.replaceAll('-', '.'),
                                      ),
                                    ] else if (item.applicantIdx != null) ...[
                                      const SizedBox(height: 12),
                                      const PetStatusRow(
                                        icon: PetFieldIcons.prevDonationDate,
                                        label: '최근 헌혈일',
                                        status: PetStatusType.neutral,
                                      ),
                                    ],
                                    // 접종: 완료 → 초록 ✓ / 미접종 → 빨강 ! (의료 행위 critical)
                                    if (item.petVaccinated != null) ...[
                                      const SizedBox(height: 12),
                                      PetStatusRow(
                                        icon: PetFieldIcons.vaccinated,
                                        label: '접종',
                                        status: item.petVaccinated == true
                                            ? PetStatusType.positive
                                            : PetStatusType.critical,
                                      ),
                                    ],
                                    // 예방약: 복용 → 초록 ✓ / 미복용 → 빨강 !
                                    if (item.petHasPreventiveMedication != null) ...[
                                      const SizedBox(height: 12),
                                      PetStatusRow(
                                        icon: PetFieldIcons.medication,
                                        label: '예방약',
                                        status: item.petHasPreventiveMedication == true
                                            ? PetStatusType.positive
                                            : PetStatusType.critical,
                                      ),
                                    ],
                                    // 중성화: 완료 → 초록 ✓ / 미시행 → 회색 — (자연스러운 부재)
                                    if (item.petIsNeutered != null) ...[
                                      const SizedBox(height: 12),
                                      PetStatusRow(
                                        icon: PetFieldIcons.isNeutered,
                                        label: '중성화',
                                        status: item.petIsNeutered == true
                                            ? PetStatusType.positive
                                            : PetStatusType.neutral,
                                      ),
                                    ],
                                    // 질병: 없음 → 회색 — / 있음 → 빨강 ! (적극적 위험)
                                    if (item.petHasDisease != null) ...[
                                      const SizedBox(height: 12),
                                      PetStatusRow(
                                        icon: PetFieldIcons.hasDisease,
                                        label: '질병',
                                        status: item.petHasDisease == true
                                            ? PetStatusType.critical
                                            : PetStatusType.neutral,
                                      ),
                                    ],
                                    // 임신/출산:
                                    //   status=0(해당없음) → 회색 — / status=1(임신중) → 주황 ⚠
                                    //   status=2 + 종료일 → 텍스트 "출산 YYYY.MM.DD"
                                    if (item.petPregnancyBirthStatus != null && item.petSex == 0) ...[
                                      const SizedBox(height: 12),
                                      if (item.petPregnancyBirthStatus == 2 &&
                                          item.petLastPregnancyEndDate != null &&
                                          item.petLastPregnancyEndDate!.isNotEmpty)
                                        InfoRow(
                                          icon: PetFieldIcons.pregnancyBirth,
                                          label: '임신/출산',
                                          value: '출산 ${item.petLastPregnancyEndDate!.replaceAll('-', '.')}',
                                        )
                                      else
                                        PetStatusRow(
                                          icon: PetFieldIcons.pregnancyBirth,
                                          label: '임신/출산',
                                          status: item.petPregnancyBirthStatus == 1
                                              ? PetStatusType.warning
                                              : PetStatusType.neutral,
                                        ),
                                    ],
                                    // 헌혈량 표시 (헌혈완료 시)
                                    if (item.bloodVolumeMl != null) ...[
                                      const SizedBox(height: 12),
                                      InfoRow(
                                        icon: Icons.water_drop,
                                        label: '헌혈량',
                                        value: '${item.bloodVolumeMl!.toStringAsFixed(item.bloodVolumeMl! == item.bloodVolumeMl!.roundToDouble() ? 0 : 1)} mL',
                                      ),
                                    ],
                                    // 상태 뱃지 (헌혈모집/모집마감 탭에서는 숨김 — 모집마감은 행 뱃지로 이미 표현됨)
                                    if (_currentTabIndex != 1 && _currentTabIndex != 2 && item.applicantStatus != null) ...[
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
                                              color: AppliedDonationStatus.getStatusColorValue(
                                                item.applicantStatus!,
                                              ).withAlpha(51),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.applicantStatusText ??
                                                  '알 수 없음',
                                              style: TextStyle(
                                                color: AppliedDonationStatus
                                                    .getStatusColorValue(
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
                            // 헌혈 완료 버튼 (스크롤 영역 안에 포함)
                            if (canPerformActions) ...[
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
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
                                    side: const BorderSide(color: Colors.green),
                                    backgroundColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
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

  /// 모집마감 시간대 시트의 펫 프로필 사진을 갤러리/디스크에 저장.
  /// 모바일은 사진 갤러리, 웹은 브라우저 다운로드 폴더로 떨어짐.
  Future<void> _downloadPetImage(PostTimeItem item) async {
    if (item.petProfileImage == null || item.petProfileImage!.isEmpty) return;

    final imageUrl = DonationPostImageService.getFullImageUrl(item.petProfileImage!);
    final filename = _buildPetImageFilename(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진을 받는 중...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final result = await PetImageDownloader.downloadFromUrl(
      imageUrl: imageUrl,
      filename: filename,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    switch (result) {
      case DownloadResult.success:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('사진을 저장했습니다.'),
            backgroundColor: AppTheme.success,
          ),
        );
        break;
      case DownloadResult.networkFailed:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('사진을 받지 못했습니다. 네트워크를 확인해주세요.'),
            backgroundColor: AppTheme.error,
          ),
        );
        break;
      case DownloadResult.permissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('갤러리 접근 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
        break;
      case DownloadResult.saveFailed:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('사진 저장에 실패했습니다.'),
            backgroundColor: AppTheme.error,
          ),
        );
        break;
    }
  }

  /// 다운로드 파일명: {헌혈날짜}_{시간}_{펫이름}.jpg
  /// 시간의 콜론(:)을 하이픈으로 치환 (Windows 파일명 호환).
  String _buildPetImageFilename(PostTimeItem item) {
    final date = item.date;
    final time = item.time.replaceAll(':', '-');
    final petName = item.petName ?? '펫';
    return '${date}_${time}_$petName.jpg';
  }
}

// 바텀시트 위젯 - 사용자 헌혈 모집 게시글 페이지 스타일로 변경
class PostDetailBottomSheet extends StatefulWidget {
  final UnifiedPostModel post;
  final VoidCallback onDeleted;
  final int tabIndex; // 현재 탭 인덱스 (1: 헌혈모집, 2: 모집마감 등)

  const PostDetailBottomSheet({
    super.key,
    required this.post,
    required this.onDeleted,
    required this.tabIndex,
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
    final confirm = await AppDialog.confirm(
      context,
      title: '게시글 삭제',
      message: '정말로 이 게시글을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.',
      confirmLabel: '삭제',
      isDestructive: true,
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
          showErrorToast(
            context,
            e,
            prefix: '삭제 실패',
            backgroundColor: AppTheme.error,
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
        birthDate: applicant.pet.birthDate,
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
              const PostDetailHandleBar(),

              // 헤더 (삭제 버튼 포함)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (widget.post.hospitalProfileImage != null) ...[
                      PetProfileImage(
                        profileImage: widget.post.hospitalProfileImage,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.post.title,
                        style: AppTheme.h3Style.copyWith(
                          color: widget.post.isUrgent
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
                      onPressed: () => Navigator.pop(context),
                      tooltip: '닫기',
                    ),
                    if (widget.post.status == 0)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                      // 메타 정보 (병원명, 주소, 동물 종류, 신청자 수)
                      PostDetailMetaSection(
                        hospitalName: widget.post.hospitalName,
                        hospitalNickname: widget.post.hospitalNickname,
                        hospitalProfileImage: widget.post.hospitalProfileImage,
                        location: widget.post.location,
                        animalType: widget.post.animalType,
                        applicantCount: applicants.length,
                        createdAt: widget.post.createdDate,
                      ),

                      const SizedBox(height: 8),

                      // 담당자 이름 (병원 전용 - 공통 위젯에 없음)
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
                              color: Colors.grey[700],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.post.hospitalNickname ?? widget.post.hospitalName,
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 설명글
                      PostDetailDescription(
                        contentDelta: widget.post.contentDelta,
                        plainText: widget.post.description,
                      ),

                      // 환자 정보 (긴급 헌혈만)
                      PostDetailPatientInfo(
                        isUrgent: widget.post.isUrgent,
                        patientName: widget.post.patientName,
                        breed: widget.post.breed,
                        age: widget.post.age,
                        diagnosis: widget.post.diagnosis,
                      ),

                      // 혈액형 정보
                      PostDetailBloodType(
                        bloodType: widget.post.bloodType,
                        isUrgent: widget.post.isUrgent,
                      ),

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

  Widget _buildApplicantCard(DonationApplication applicant, {bool showActions = true}) {
    final bool isApproved = applicant.status == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isApproved
            ? AppTheme.success.withValues(alpha: 0.08)
            : AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved ? AppTheme.success.withValues(alpha: 0.4) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 신청자 정보 + 프로필
          Row(
            children: [
              PetProfileImage(
                profileImage: applicant.userProfileImage,
                radius: 16,
              ),
              const SizedBox(width: 8),
              Icon(PetFieldIcons.nickname, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  applicant.userNickname ?? '닉네임 없음',
                  style: AppTheme.bodyMediumStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 상태 칩
              if (showActions && applicant.status >= 0 && applicant.status <= 4)
                _buildStatusChip(applicant.status),
            ],
          ),
          if (applicant.userName != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                '이름: ${applicant.userName}',
                style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
              ),
            ),
          ],
          const Divider(height: 20),
          // 반려동물 정보 + 프로필
          Row(
            children: [
              PetProfileImage(
                profileImage: applicant.pet.profileImage,
                species: applicant.pet.species,
                radius: 16,
              ),
              const SizedBox(width: 8),
              Icon(Icons.pets, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${applicant.pet.name} (${applicant.pet.species})',
                  style: AppTheme.bodyMediumStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              applicant.pet.summaryLine,
              style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
            ),
          ),

          // 신청 시간대 정보 (간소화)
          if (applicant.selectedDate != null &&
              applicant.selectedTime != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${TimeFormatUtils.formatDateWithWeekday(applicant.selectedDate!)} ${TimeFormatUtils.formatTime(applicant.selectedTime!)}',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: AppTheme.primaryDarkBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 액션 버튼 또는 상태 메시지 (showActions가 true일 때만)
          if (showActions && applicant.status == 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCompletionDialog(applicant),
                icon: const Icon(
                  Icons.check,
                  size: 18,
                  color: Colors.black,
                ),
                label: const Text('헌혈 완료'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
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
        return '미승인';
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            TimeFormatUtils.formatDateWithWeekday(dateStr),
                            style: AppTheme.bodyLargeStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...timeSlots.map<Widget>((timeSlot) {
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
                              onTap: widget.tabIndex == 0
                                  ? null
                                  : () => _showApplicantsBottomSheet(dateStr, timeSlot),
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
                                    const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        TimeFormatUtils.formatTime(timeSlot.time),
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (widget.tabIndex != 0) ...[
                                      Text(
                                        '${_getApplicantCountForTimeSlot(dateStr, timeSlot)}명 신청',
                                        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textTertiary),
                                      ),
                                      const SizedBox(width: 8),
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  const SizedBox(height: 12),
                ],
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
          String teamString = timeSlot.team.toString();
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
                                      '${TimeFormatUtils.formatDateWithWeekday(dateStr)} ${TimeFormatUtils.formatTime(timeSlot.time)}',
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
                                    // 헌혈모집 탭(1)에서는 액션 버튼/뱃지 숨김
                                    showActions: widget.tabIndex != 1,
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
      String teamString = timeSlot.team.toString();
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
