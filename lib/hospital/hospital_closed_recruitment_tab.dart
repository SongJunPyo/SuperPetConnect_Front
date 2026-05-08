import 'package:flutter/material.dart';

import '../models/post_time_item_model.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/time_format_util.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';
import '../widgets/state_view.dart';

/// 병원 게시글 현황의 Tab 2(모집마감) 전용 위젯.
///
/// 시간대(PostTimeItem) 단위로 다음 세 그룹을 합쳐서 표시:
/// 1. `applicantStatus == 1` (APPROVED, 선정) 신청자 행
/// 2. `applicantStatus == 2` (PENDING_COMPLETION, 1차 완료 입력 대기) 신청자 행
/// 3. `postStatus == 3` (CLOSED) 게시글의 zero-applicant 시간대 — 신청자 0명
///    (admin이 신청자 ≥1명 게시글을 close → 신청자 모두 PENDING이었던 케이스 등)
///
/// 그룹(1)·(2)는 신청자 단위 N행. 그룹(3)은 신청자 정보 null인 시간대 1행만.
/// 행 탭은 시간대 단위 시트로 위임 — 부모가 `_showPostTimeBottomSheet`를 보유.
class HospitalClosedRecruitmentTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(PostTimeItem item) onTapItem;

  const HospitalClosedRecruitmentTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapItem,
  });

  @override
  State<HospitalClosedRecruitmentTab> createState() =>
      HospitalClosedRecruitmentTabState();
}

class HospitalClosedRecruitmentTabState
    extends State<HospitalClosedRecruitmentTab> {
  List<PostTimeItem> _allItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void didUpdateWidget(covariant HospitalClosedRecruitmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  Future<void> refresh() => _fetchItems();

  Future<void> _fetchItems() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 신청자 status=1/2 시간대 + 게시글 status=3 zero-applicant 시간대 합산.
      // applicantIdx == null 필터로 (1)·(2)와 중복 없이 신청자 0명 시간대만 추가.
      final approved =
          await HospitalPostService.getPostTimes(applicantStatus: 1);
      final pendingCompletion =
          await HospitalPostService.getPostTimes(applicantStatus: 2);
      final byPost = await HospitalPostService.getPostTimes(postStatus: 3);
      final zeroApplicantTimes =
          byPost.where((item) => item.applicantIdx == null).toList();
      if (!mounted) return;
      setState(() {
        _allItems = [...approved, ...pendingCompletion, ...zeroApplicantTimes];
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _isInDateRange(DateTime date) {
    if (widget.startDate == null || widget.endDate == null) return true;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      widget.startDate!.year,
      widget.startDate!.month,
      widget.startDate!.day,
    );
    final end = DateTime(
      widget.endDate!.year,
      widget.endDate!.month,
      widget.endDate!.day,
    );
    return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
  }

  List<PostTimeItem> get _filteredItems {
    var filtered = _allItems;

    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery.toLowerCase();
      filtered = filtered
          .where((item) => item.postTitle.toLowerCase().contains(q))
          .toList();
    }

    if (widget.startDate != null && widget.endDate != null) {
      filtered = filtered.where((item) {
        final parsed = DateTime.tryParse(item.date);
        if (parsed == null) return false;
        return _isInDateRange(parsed);
      }).toList();
    }

    return filtered;
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
    if (_isLoading) {
      return const StateView.loading();
    }

    if (_errorMessage != null) {
      return StateView.error(message: _errorMessage!, onRetry: _fetchItems);
    }

    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return const StateView.empty(
        icon: Icons.post_add_outlined,
        message: '모집 마감된 시간대가 없습니다.',
      );
    }

    const pageSize = AppConstants.detailListPageSize;
    final totalPages = (filtered.length / pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);

    final paginationBarCount = totalPages > 1 ? 1 : 0;
    final itemCount = pageItems.length;

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: itemCount + 1 + paginationBarCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const PostListHeader();
          }
          if (index > itemCount) {
            return PaginationBar(
              currentPage: safePage,
              totalPages: totalPages,
              onPageChanged: _onPageChanged,
            );
          }
          final item = pageItems[index - 1];
          // 완료대기(2)는 '완료대기' 뱃지, 그 외(=1, 선정)는 '마감'.
          final badgeType = item.applicantStatus == 2 ? '완료대기' : '마감';
          return PostListRow(
            badgeType: badgeType,
            title: item.postTitle,
            dateText: TimeFormatUtils.formatFlexibleShortDate(item.createdDate),
            hospitalProfileImage: item.hospitalProfileImage,
            onTap: () => widget.onTapItem(item),
          );
        },
      ),
    );
  }
}
