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

/// 병원 게시글 현황의 Tab 3(헌혈완료) 전용 위젯.
///
/// 시간대 단위(PostTimeItem)로 다음 두 그룹을 합쳐서 표시:
/// 1. `applicantStatus == 3`(COMPLETED) 신청자 행 — 시간대당 신청자 N명이면 N행
/// 2. `postStatus == 4`(COMPLETED) 게시글의 zero-applicant 시간대 — 신청자 0명
///    (admin이 신청자 0명 게시글을 close하면 CLOSED 거치지 않고 COMPLETED 직행, 2026-05-08)
///
/// 신청자 여러 명 케이스(1)에선 신청자 단위 N행 표시 유지. 그룹(2)은 신청자
/// 정보가 모두 null인 시간대 행으로 1행만 추가.
/// 행 탭 시 부모의 시간대 시트로 위임.
class HospitalCompletedDonationsTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(PostTimeItem item) onTapItem;

  const HospitalCompletedDonationsTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapItem,
  });

  @override
  State<HospitalCompletedDonationsTab> createState() =>
      HospitalCompletedDonationsTabState();
}

class HospitalCompletedDonationsTabState
    extends State<HospitalCompletedDonationsTab> {
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
  void didUpdateWidget(covariant HospitalCompletedDonationsTab oldWidget) {
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
      // 1) 신청자 status=3 (COMPLETED, 관리자 최종 승인) 시간대 — 신청자 단위 N행.
      // 2) 게시글 status=4 (COMPLETED) 중 신청자 0명 시간대만 추가 (zero-applicant).
      //    백엔드가 LEFT OUTER JOIN으로 시간대당 신청자 행을 만들고 신청자 없으면 null 행.
      //    applicantIdx == null인 행만 골라야 (1)과 중복 안 되고 status=4 신청자도 제외.
      final byApplicant =
          await HospitalPostService.getPostTimes(applicantStatus: 3);
      final byPost = await HospitalPostService.getPostTimes(postStatus: 4);
      final zeroApplicantTimes =
          byPost.where((item) => item.applicantIdx == null).toList();
      if (!mounted) return;
      setState(() {
        _allItems = [...byApplicant, ...zeroApplicantTimes];
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
        message: '헌혈 완료된 시간대가 없습니다.',
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
          return PostListRow(
            badgeType: item.isUrgent ? '긴급' : '정기',
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
