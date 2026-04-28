import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../models/notice_model.dart';
import '../services/notice_service.dart';
import 'admin_notice_create.dart';
import 'package:intl/intl.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/pagination_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/post_list/board_list_row.dart';
import '../widgets/post_list/board_list_header.dart';
import '../widgets/post_list/notice_styling.dart';

class AdminNoticeListScreen extends StatefulWidget {
  const AdminNoticeListScreen({super.key});

  @override
  State<AdminNoticeListScreen> createState() => _AdminNoticeListScreenState();
}

class _AdminNoticeListScreenState extends State<AdminNoticeListScreen> {
  final List<Notice> _allNotices = [];
  List<Notice> filteredNotices = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
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

  Future<void> _loadNotices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _currentPage = 1;
      _allNotices.clear();
      filteredNotices = [];
    });

    try {
      final allNotices = await NoticeService.getAdminNotices(
        activeOnly: false, // 관리자용 API - 모든 공지글 포함
      );

      if (!mounted) return;
      setState(() {
        _allNotices.addAll(allNotices);
        filteredNotices = _paginateFiltered(_applyFilters(_allNotices));
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

  List<Notice> _paginateFiltered(List<Notice> filtered) {
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    final start = (_currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  List<Notice> _applyFilters(List<Notice> source) {
    Iterable<Notice> filtered = source;

    if (searchQuery.isNotEmpty) {
      final lowered = searchQuery.toLowerCase();
      filtered = filtered.where((notice) {
        final titleMatch = notice.title.toLowerCase().contains(lowered);
        final authorMatch = (notice.authorNickname ?? notice.authorName)
            .toLowerCase()
            .contains(lowered);
        return titleMatch || authorMatch;
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

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      filteredNotices = _paginateFiltered(_applyFilters(_allNotices));
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
      _currentPage = 1;
      filteredNotices = _paginateFiltered(_applyFilters(_allNotices));
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          (startDate != null && endDate != null)
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
        filteredNotices = _paginateFiltered(_applyFilters(_allNotices));
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
      _currentPage = 1;
      filteredNotices = _paginateFiltered(_applyFilters(_allNotices));
    });
  }

  Future<void> _deleteNotice(Notice notice) async {
    // 확인 다이얼로그
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text(
                '공지글 삭제',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '\'${notice.title}\'을(를)\n',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '삭제하면 복구할 수 없습니다. 정말 삭제하시겠습니까?',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w500,
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
                      onPressed: () => Navigator.pop(context, false),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await NoticeService.deleteNotice(notice.noticeIdx);

      if (mounted) {
        _loadNotices(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showNoticeDetail(Notice notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들 바
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 제목 + 닫기 버튼
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notice.title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: AppTheme.error,
                        tooltip: '삭제',
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteNotice(notice);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: AppTheme.textSecondary,
                        tooltip: '닫기',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 메타 정보
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTargetAudienceColor(notice.targetAudience),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTargetAudienceText(notice.targetAudience),
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notice.authorNickname ?? notice.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt)}',
                        textAlign: TextAlign.right,
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // 내용
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        notice.content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // URL 버튼 (URL이 있을 경우에만 표시)
                  if (notice.noticeUrl != null &&
                      notice.noticeUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = notice.noticeUrl!;
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('링크를 열 수 없습니다'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
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
                  // 수정 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // 바텀시트 닫기
                        _navigateToEditNotice(notice); // 수정 페이지로 이동
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text('수정하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 하단 정보
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '조회수 ${notice.viewCount ?? 0}회',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            if (notice.updatedAt != notice.createdAt) ...[
                              Text(
                                '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(notice.updatedAt)}',
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
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

  // 공지사항 수정 페이지로 이동
  void _navigateToEditNotice(Notice notice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AdminNoticeCreateScreen(
              editNotice: notice, // 수정할 공지사항 전달
            ),
      ),
    ).then((_) {
      _loadNotices(); // 수정 후 목록 새로고침
    });
  }

  String _getTargetAudienceText(int targetAudience) {
    switch (targetAudience) {
      case 0:
        return '전체';
      case 1:
        return '관리자';
      case 2:
        return '병원';
      default:
        return '전체';
    }
  }

  Color _getTargetAudienceColor(int targetAudience) {
    switch (targetAudience) {
      case 1:
        return AppTheme.primaryBlue; // 관리자
      case 2:
        return AppTheme.success; // 병원
      default:
        return AppTheme.textPrimary; // 전체
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '공지사항 관리',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.black87),
            onPressed: _selectDateRange,
            tooltip: '날짜 범위 선택',
          ),
          if (startDate != null || endDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black87),
              onPressed: _clearDateRange,
              tooltip: '날짜 범위 초기화',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadNotices,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminNoticeCreateScreen(),
                ),
              ).then((_) {
                _loadNotices(); // 공지글 작성 후 목록 새로고침
              });
            },
            tooltip: '공지글 작성',
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
                AppSearchBar(
                  controller: searchController,
                  hintText: '제목, 닉네임으로 검색...',
                  onChanged: _onSearchChanged,
                  onClear: () => _onSearchChanged(''),
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
              onRefresh: _loadNotices,
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
              onPressed: _loadNotices,
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

    if (filteredNotices.isEmpty) {
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
      child: Column(
        children: [
          const BoardListHeader(),
          Expanded(
            child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: filteredNotices.length + paginationBarCount,
        separatorBuilder:
            (context, index) => Container(
              height: 1,
              color: AppTheme.lightGray.withValues(alpha: 0.2),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
        itemBuilder: (context, index) {
          if (index >= filteredNotices.length) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          final notice = filteredNotices[index];

          return GestureDetector(
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('수정'),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToEditNotice(notice);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text(
                          '삭제',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteNotice(notice);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            child: BoardListRow(
              index: index + 1,
              title: notice.title,
              titleColor: NoticeStyling.titleColor(
                targetAudience: notice.targetAudience,
                noticeImportant: notice.noticeImportant,
              ),
              authorName: notice.authorNickname ?? notice.authorName,
              authorProfileImage: notice.authorProfileImage,
              createdAt: notice.createdAt,
              onTap: () => _showNoticeDetail(notice),
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}
