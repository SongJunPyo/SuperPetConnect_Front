import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/notice_model.dart';
import '../services/dashboard_service.dart';
import '../models/notice_post_model.dart';
import 'package:intl/intl.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_constants.dart';
import '../widgets/pagination_bar.dart';

class UserNoticeListScreen extends StatefulWidget {
  final bool isPublic; // true: 로그인 전 (공개 API 사용), false: 로그인 후 (인증 API 사용)

  const UserNoticeListScreen({super.key, this.isPublic = false});

  @override
  State<UserNoticeListScreen> createState() => _UserNoticeListScreenState();
}

class _UserNoticeListScreenState extends State<UserNoticeListScreen> {
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
        final response = widget.isPublic
            ? await DashboardService.fetchNoticesPage(page: page)
            : await DashboardService.fetchAuthenticatedNoticesPage(page: page);

        final visibleNoticePosts = response.notices.where(
          (noticePost) =>
              noticePost.targetAudience == AppConstants.noticeTargetAll || noticePost.targetAudience == AppConstants.noticeTargetUser,
        );

        _allNotices.addAll(visibleNoticePosts.map(_mapToNotice));
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
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primaryBlue,
            colorScheme: ColorScheme.light(primary: AppTheme.primaryBlue),
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

    final sorted =
        filtered.toList()..sort((a, b) {
          if (a.showBadge && !b.showBadge) return -1;
          if (!a.showBadge && b.showBadge) return 1;
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
      viewCount: noticePost.viewCount,
      targetAudience: noticePost.targetAudience,
      noticeUrl: noticePost.noticeUrl,
    );
  }

  void _showNoticeDetail(Notice notice) async {
    // 상세 조회 API 호출 (isPublic이면 공개 API 사용)
    final noticeDetail = widget.isPublic
        ? await DashboardService.getPublicNoticeDetail(notice.noticeIdx)
        : await DashboardService.getNoticeDetail(notice.noticeIdx);

    if (noticeDetail != null) {
      // 목록의 조회수를 업데이트된 값으로 반영
      setState(() {
        final index = notices.indexWhere(
          (n) => n.noticeIdx == notice.noticeIdx,
        );
        if (index != -1) {
          final displayNickname =
              (noticeDetail.authorNickname.toLowerCase() != '닉네임 없음')
                  ? noticeDetail.authorNickname
                  : noticeDetail.authorName;

          notices[index] = Notice(
            noticeIdx: notices[index].noticeIdx,
            accountIdx: notices[index].accountIdx,
            title: noticeDetail.title,
            content: noticeDetail.contentPreview,
            noticeImportant: noticeDetail.noticeImportant,
            noticeActive: notices[index].noticeActive,
            createdAt: noticeDetail.createdAt,
            updatedAt: noticeDetail.updatedAt,
            authorEmail: noticeDetail.authorEmail,
            authorName: noticeDetail.authorName,
            authorNickname: displayNickname,
            viewCount: noticeDetail.viewCount,
            targetAudience: noticeDetail.targetAudience,
            noticeUrl: noticeDetail.noticeUrl,
          );
        }
      });
    }

    if (!mounted) return;

    final bool isImportant =
        (noticeDetail?.noticeImportant ?? notice.noticeImportant) == 0;
    final DateTime createdAt = noticeDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = noticeDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = noticeDetail?.viewCount ?? notice.viewCount ?? 0;
    final String authorName =
        noticeDetail?.authorNickname ??
        notice.authorNickname ??
        notice.authorName;
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isImportant
                                  ? AppTheme.error
                                  : AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isImportant ? '공지' : '알림',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
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
                        label: const Text('링크 열기'),
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

  // 날짜/시간 표시 로직

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '공지사항',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
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
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadNotices(),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창 및 필터 표시
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '제목, 작성자로 검색...',
                    prefixIcon: const Icon(Icons.search, color: Colors.black87),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryBlue,
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
                // 날짜 범위 표시
                if (startDate != null && endDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range,
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('yyyy.MM.dd').format(startDate!)} - ${DateFormat('yyyy.MM.dd').format(endDate!)}',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.primaryBlue,
                            size: 18,
                          ),
                          onPressed: _clearDateRange,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
              onPressed: () => _loadNotices(),
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

    if (notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text('공지사항이 없습니다', style: AppTheme.h4Style),
          ],
        ),
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return Container(
      decoration: BoxDecoration(color: Colors.white),
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

          return InkWell(
            onTap: () => _showNoticeDetail(notice),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Text(
                                '${index + 1}',
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: AppTheme.textTertiary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (notice.showBadge) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  notice.badgeText,
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: MarqueeText(
                                text: notice.title,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color:
                                      notice.showBadge
                                          ? AppTheme.error
                                          : AppTheme.textPrimary,
                                  fontWeight:
                                      notice.showBadge
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                  fontSize: 14,
                                ),
                                animationDuration: const Duration(
                                  milliseconds: 4000,
                                ),
                                pauseDuration: const Duration(
                                  milliseconds: 1000,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(
                            (notice.authorNickname ?? notice.authorName)
                                        .length >
                                    15
                                ? '${(notice.authorNickname ?? notice.authorName).substring(0, 15)}..'
                                : (notice.authorNickname ?? notice.authorName),
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '작성: ${DateFormat('yy.MM.dd').format(notice.createdAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '수정: ${DateFormat('yy.MM.dd').format(notice.updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 36,
                        width: 40,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumGray.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.lightGray.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 10,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              NumberFormatUtil.formatViewCount(
                                notice.viewCount ?? 0,
                              ),
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
