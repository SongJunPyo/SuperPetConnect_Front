import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/notice_model.dart';
import '../services/dashboard_service.dart';
import '../models/notice_post_model.dart';
import '../utils/app_theme.dart';
import '../utils/number_format_util.dart';
import '../widgets/app_app_bar.dart';
import '../utils/app_constants.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/search_date_filter_bar.dart';
import '../widgets/state_view.dart';
import '../widgets/post_list/board_list_row.dart';
import '../widgets/post_list/board_list_header.dart';
import '../widgets/post_list/author_avatar.dart';
import '../widgets/post_list/notice_styling.dart';

class HospitalNoticeListScreen extends StatefulWidget {
  const HospitalNoticeListScreen({super.key});

  @override
  State<HospitalNoticeListScreen> createState() =>
      _HospitalNoticeListScreenState();
}

class _HospitalNoticeListScreenState extends State<HospitalNoticeListScreen> {
  List<Notice> notices = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  final List<Notice> _allNotices = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      notices = _paginateFiltered(_applyFilters(_allNotices));
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  List<Notice> _paginateFiltered(List<Notice> filtered) {
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    final start = (_currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  Future<void> _loadNotices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _currentPage = 1;
      _allNotices.clear();
      notices = [];
    });

    try {
      // 서버 페이지네이션을 통해 모든 데이터를 순차적으로 가져옴
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await DashboardService.fetchAuthenticatedNoticesPage(page: page);

        final visibleNotices = response.notices.where(
          (noticePost) =>
              noticePost.targetAudience == AppConstants.noticeTargetAll || noticePost.targetAudience == AppConstants.noticeTargetHospital,
        );

        _allNotices.addAll(visibleNotices.map(_mapToNotice));
        hasMore = response.pagination.hasNext;
        page++;
      }

      if (!mounted) return;
      setState(() {
        notices = _paginateFiltered(_applyFilters(_allNotices));
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _currentPage = 1;
      notices = _paginateFiltered(_applyFilters(_allNotices));
    });
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
        notices = _paginateFiltered(_applyFilters(_allNotices));
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
      _currentPage = 1;
      notices = _paginateFiltered(_applyFilters(_allNotices));
    });
  }

  List<Notice> _applyFilters(List<Notice> source) {
    Iterable<Notice> filtered = source;

    if (searchQuery.isNotEmpty) {
      final lowered = searchQuery.toLowerCase();
      filtered = filtered.where((notice) {
        final nickname =
            (notice.authorNickname ?? notice.authorName).toLowerCase();
        return notice.title.toLowerCase().contains(lowered) ||
            notice.authorName.toLowerCase().contains(lowered) ||
            nickname.contains(lowered);
      });
    }

    if (startDate != null && endDate != null) {
      filtered = filtered.where((notice) {
        final createdAt = notice.createdAt;
        return !createdAt.isBefore(startDate!) &&
            !createdAt.isAfter(endDate!.add(const Duration(days: 1)));
      });
    }

    final sorted = filtered.toList()
      ..sort((a, b) {
        final ar = NoticeStyling.priorityRank(
          targetAudience: a.targetAudience,
          noticeImportant: a.noticeImportant,
        );
        final br = NoticeStyling.priorityRank(
          targetAudience: b.targetAudience,
          noticeImportant: b.noticeImportant,
        );
        if (ar != br) return ar - br;
        return b.createdAt.compareTo(a.createdAt);
      });

    return sorted;
  }

  Notice _mapToNotice(NoticePost noticePost) {
    final displayNickname =
        (noticePost.authorNickname.isNotEmpty &&
                noticePost.authorNickname.toLowerCase() != '닉네임 없음')
            ? noticePost.authorNickname
            : noticePost.authorName;

    return Notice(
      noticeIdx: noticePost.noticeIdx,
      accountIdx: 0,
      title: noticePost.title,
      content: noticePost.contentPreview,
      noticeImportant: noticePost.noticeImportant,
      noticeActive: true,
      createdAt: noticePost.createdAt,
      updatedAt: noticePost.updatedAt,
      authorEmail: noticePost.authorEmail,
      authorName: noticePost.authorName,
      authorNickname: displayNickname,
      authorProfileImage: noticePost.authorProfileImage,
      viewCount: noticePost.viewCount,
      targetAudience: noticePost.targetAudience,
      noticeUrl: noticePost.noticeUrl,
    );
  }

  Future<void> _showNoticeDetail(Notice notice) async {
    NoticePost? noticeDetail;
    try {
      noticeDetail = await DashboardService.getNoticeDetail(notice.noticeIdx);
    } catch (_) {}

    if (noticeDetail != null && mounted) {
      setState(() {
        final updatedNotice = _mapToNotice(noticeDetail!);
        final idx = notices.indexWhere((n) => n.noticeIdx == notice.noticeIdx);
        if (idx != -1) {
          notices[idx] = updatedNotice;
        }
        final allIdx = _allNotices.indexWhere(
          (n) => n.noticeIdx == notice.noticeIdx,
        );
        if (allIdx != -1) {
          _allNotices[allIdx] = updatedNotice;
        }
        notices = _applyFilters(_allNotices);
      });
    }

    if (!mounted) return;

    final bool isImportant =
        (noticeDetail?.noticeImportant ?? notice.noticeImportant) ==
            AppConstants.noticeImportant;
    final DateTime createdAt = noticeDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = noticeDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = noticeDetail?.viewCount ?? notice.viewCount ?? 0;
    final detailNickname = noticeDetail?.authorNickname;
    final String authorName =
        (detailNickname != null && detailNickname.toLowerCase() != '닉네임 없음')
            ? detailNickname
            : noticeDetail?.authorName ??
                notice.authorNickname ??
                notice.authorName;
    final String? authorProfileImage =
        noticeDetail?.authorProfileImage ?? notice.authorProfileImage;
    final String title = noticeDetail?.title ?? notice.title;
    final String content = noticeDetail?.contentPreview ?? notice.content;
    final String? noticeUrl = noticeDetail?.noticeUrl ?? notice.noticeUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isImportant
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AuthorAvatar(
                        profileImage: authorProfileImage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (noticeUrl != null && noticeUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(noticeUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('링크를 열 수 없습니다.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.black,
                        ),
                        label: const Text('관련 링크 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '조회수 ${NumberFormatUtil.formatViewCount(viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!updatedAt.isAtSameMomentAs(createdAt))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '공지사항',
        showBackButton: true,
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
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadNotices(),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          SearchAndDateFilterBar(
            searchController: searchController,
            hintText: '제목, 닉네임으로 검색...',
            onSearchChanged: _onSearchChanged,
            startDate: startDate,
            endDate: endDate,
            onClearDateRange: _clearDateRange,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadNotices(),
              color: AppTheme.primaryBlue,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const StateView.loading();
    }

    if (errorMessage != null) {
      return StateView.error(message: errorMessage!, onRetry: _loadNotices);
    }

    if (notices.isEmpty) {
      return const StateView.empty(
        icon: Icons.announcement_outlined,
        message: '공지사항이 없습니다',
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          const BoardListHeader(),
          Expanded(
            child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: notices.length + paginationBarCount,
        separatorBuilder:
            (context, index) => Container(
              height: 1,
              color: AppTheme.lightGray.withValues(alpha: 0.2),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
        itemBuilder: (context, index) {
          if (index >= notices.length) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          final notice = notices[index];

          return BoardListRow(
            index: index + 1,
            title: notice.title,
            titleColor: NoticeStyling.titleColor(
              targetAudience: notice.targetAudience,
              noticeImportant: notice.noticeImportant,
            ),
            titleFontWeight: NoticeStyling.titleFontWeight(
              targetAudience: notice.targetAudience,
              noticeImportant: notice.noticeImportant,
            ),
            authorName: notice.authorNickname ?? notice.authorName,
            authorProfileImage: notice.authorProfileImage,
            createdAt: notice.createdAt,
            onTap: () => _showNoticeDetail(notice),
          );
        },
            ),
          ),
        ],
      ),
    );
  }

}
