import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/dashboard_service.dart';
import '../models/column_post_model.dart';
import '../utils/app_theme.dart';
import '../utils/number_format_util.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/marquee_text.dart';
import '../widgets/rich_text_viewer.dart';
import '../utils/app_constants.dart';
import '../widgets/pagination_bar.dart';

class HospitalColumnList extends StatefulWidget {
  const HospitalColumnList({super.key});

  @override
  State<HospitalColumnList> createState() => _HospitalColumnListState();
}

class _HospitalColumnListState extends State<HospitalColumnList> {
  List<ColumnPost> columns = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  final List<ColumnPost> _allColumns = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadColumns();
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
      columns = _paginateFiltered(_applyFilters(_allColumns));
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  List<ColumnPost> _paginateFiltered(List<ColumnPost> filtered) {
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    final start = (_currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _currentPage = 1;
      columns = _paginateFiltered(_applyFilters(_allColumns));
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
        columns = _paginateFiltered(_applyFilters(_allColumns));
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
      _currentPage = 1;
      columns = _paginateFiltered(_applyFilters(_allColumns));
    });
  }

  void _showColumnBottomSheet(ColumnPost column) {
    final displayNickname =
        column.authorNickname.toLowerCase() != '닉네임 없음'
            ? column.authorNickname
            : column.authorName;

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
                          column.title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                column.isImportant
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
                              column.isImportant
                                  ? AppTheme.error
                                  : AppTheme.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          column.isImportant ? '중요' : '칼럼',
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
                          displayNickname,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(column.createdAt)}',
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
                      child:
                          column.contentDelta != null &&
                                  column.contentDelta!.isNotEmpty
                              ? RichTextViewer(
                                contentDelta: column.contentDelta,
                                plainText: column.contentPreview,
                                padding: EdgeInsets.zero,
                              )
                              : Text(
                                column.contentPreview,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  height: 1.6,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (column.columnUrl != null &&
                      column.columnUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(column.columnUrl!);
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
                          '조회수 ${NumberFormatUtil.formatViewCount(column.viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!column.updatedAt.isAtSameMomentAs(
                          column.createdAt,
                        ))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(column.updatedAt)}',
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

  Widget _buildContent() {
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          ),
        ],
      );
    }

    if (errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
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
                    onPressed: () => _loadColumns(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (columns.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: AppTheme.mediumGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '공개된 칼럼이 없습니다',
                    style: AppTheme.h4Style,
                  ),
                  if (searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('다른 검색어를 시도해보세요', style: AppTheme.bodyMediumStyle),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: columns.length + paginationBarCount,
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                if (index >= columns.length) {
                  return PaginationBar(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    onPageChanged: _onPageChanged,
                  );
                }

                final column = columns[index];
                final isImportant =
                    column.title.contains('[중요]') ||
                    column.title.contains('[공지]') ||
                    column.isImportant;
                final displayNickname =
                    column.authorNickname.toLowerCase() != '닉네임 없음'
                        ? column.authorNickname
                        : column.authorName;

                return InkWell(
                  onTap: () => _showColumnBottomSheet(column),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 50,
                          child: Center(
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isImportant) ...[
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
                                        '중요',
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
                                      text: column.title,
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color:
                                            isImportant
                                                ? AppTheme.error
                                                : AppTheme.textPrimary,
                                        fontWeight:
                                            isImportant
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
                              Text(
                                displayNickname.length > 15
                                    ? '${displayNickname.substring(0, 15)}..'
                                    : displayNickname,
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                  '작성: ${DateFormat('yy.MM.dd').format(column.createdAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '수정: ${DateFormat('yy.MM.dd').format(column.updatedAt)}',
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
                                color: AppTheme.mediumGray.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withValues(
                                    alpha: 0.3,
                                  ),
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
                                      column.viewCount,
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '칼럼',
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
            onPressed: () => _loadColumns(),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '칼럼 제목, 작성자로 검색...',
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
              onRefresh: () => _loadColumns(),
              color: AppTheme.primaryBlue,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadColumns() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _currentPage = 1;
      _allColumns.clear();
      columns = [];
    });

    try {
      // 서버 페이지네이션을 통해 모든 데이터를 순차적으로 가져옴
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await DashboardService.fetchColumnsPage(page: page);
        _allColumns.addAll(response.columns);
        hasMore = response.pagination.hasNext;
        page++;
      }

      if (!mounted) return;
      setState(() {
        columns = _paginateFiltered(_applyFilters(_allColumns));
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

  List<ColumnPost> _applyFilters(List<ColumnPost> source) {
    Iterable<ColumnPost> filtered = source;

    if (searchQuery.isNotEmpty) {
      final lowered = searchQuery.toLowerCase();
      filtered = filtered.where((column) {
        final nickname =
            column.authorNickname.toLowerCase() != '닉네임 없음'
                ? column.authorNickname.toLowerCase()
                : column.authorName.toLowerCase();
        return column.title.toLowerCase().contains(lowered) ||
            column.authorName.toLowerCase().contains(lowered) ||
            nickname.contains(lowered);
      });
    }

    if (startDate != null && endDate != null) {
      filtered = filtered.where((column) {
        final createdAt = column.createdAt;
        return !createdAt.isBefore(startDate!) &&
            !createdAt.isAfter(endDate!.add(const Duration(days: 1)));
      });
    }

    final sorted =
        filtered.toList()..sort((a, b) {
          final aImportant =
              a.title.contains('[중요]') ||
              a.title.contains('[공지]') ||
              a.isImportant;
          final bImportant =
              b.title.contains('[중요]') ||
              b.title.contains('[공지]') ||
              b.isImportant;
          if (aImportant && !bImportant) return -1;
          if (!aImportant && bImportant) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

    return sorted;
  }
}
