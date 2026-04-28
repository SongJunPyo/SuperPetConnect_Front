// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hospital_column_service.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/error_display.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/rich_text_viewer.dart';
import '../widgets/post_list/board_list_row.dart';
import '../widgets/post_list/board_list_header.dart';
import '../hospital/hospital_column_edit.dart';
import 'package:intl/intl.dart';

class AdminColumnManagement extends StatefulWidget {
  const AdminColumnManagement({super.key});

  @override
  State createState() => _AdminColumnManagementState();
}

class _AdminColumnManagementState extends State<AdminColumnManagement> {
  final List<HospitalColumn> _allColumns = [];
  List<HospitalColumn> columns = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
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
    _loadAllColumns();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllColumns() async {
    setState(() {
      isLoading = true;
      hasError = false;
      _currentPage = 1;
      _allColumns.clear();
      columns = [];
    });

    try {
      // 서버 페이지네이션을 통해 모든 데이터를 순차적으로 가져옴
      int page = 1;
      bool hasMore = true;
      const fetchSize = 50;

      while (hasMore) {
        final response = await HospitalColumnService.getAllColumns(
          page: page,
          pageSize: fetchSize,
        );
        _allColumns.addAll(response.columns);
        hasMore = response.columns.length == fetchSize &&
            page * fetchSize < response.totalCount;
        page++;
      }

      if (!mounted) return;
      setState(() {
        columns = _paginateFiltered(_applyFilters(_allColumns));
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = formatErrorMessage(e);
      });
    }
  }

  List<HospitalColumn> _paginateFiltered(List<HospitalColumn> filtered) {
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    final start = (_currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  List<HospitalColumn> _applyFilters(List<HospitalColumn> source) {
    Iterable<HospitalColumn> filtered = source;

    if (searchQuery.isNotEmpty) {
      final lowered = searchQuery.toLowerCase();
      filtered = filtered.where((column) {
        final nickname = column.authorNickname ?? column.hospitalName;
        return column.title.toLowerCase().contains(lowered) ||
            column.content.toLowerCase().contains(lowered) ||
            nickname.toLowerCase().contains(lowered);
      });
    }

    if (startDate != null) {
      filtered = filtered.where((column) {
        return column.createdAt.isAfter(
          startDate!.subtract(const Duration(days: 1)),
        );
      });
    }

    if (endDate != null) {
      filtered = filtered.where((column) {
        return column.createdAt.isBefore(
          endDate!.add(const Duration(days: 1)),
        );
      });
    }

    final sorted = filtered.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted;
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

  Future<void> _togglePublishStatus(HospitalColumn column) async {
    try {
      await HospitalColumnService.adminTogglePublish(
        column.columnIdx,
      );

      await _loadAllColumns();
    } catch (e) {
      debugPrint('칼럼 공개 상태 변경 실패: $e');
    }
  }

  void _showEditColumnDialog(HospitalColumn column) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HospitalColumnEdit(column: column),
      ),
    );

    // 수정 완료 후 목록 새로고침
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('칼럼이 수정되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllColumns();
    }
  }

  void _showColumnDetail(HospitalColumn column) {
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
                  // 제목
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        tooltip: '닫기',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 메타 정보
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.authorNickname ?? column.hospitalName,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(column.createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                        textAlign: TextAlign.right,
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
                      child:
                          column.contentDelta != null &&
                                  column.contentDelta!.isNotEmpty
                              ? RichTextViewer(
                                contentDelta: column.contentDelta,
                                plainText: column.content,
                                padding: EdgeInsets.zero,
                              )
                              : Text(
                                column.content,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  height: 1.6,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // URL 링크 버튼
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
                              '조회수 ${column.viewCount}회',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            if (column.updatedAt != column.createdAt) ...[
                              Text(
                                '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(column.updatedAt)}',
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
                  const SizedBox(height: 16),
                  // 액션 버튼
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _togglePublishStatus(column);
                          },
                          icon: Icon(
                            column.isPublished
                                ? Icons.unpublished
                                : Icons.publish,
                            size: 16,
                            color: Colors.black,
                          ),
                          label: Text(column.isPublished ? '공개 해제' : '공개 승인'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: BorderSide(
                              color:
                                  column.isPublished
                                      ? Colors.red
                                      : Colors.green,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditColumnDialog(column);
                          },
                          icon: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.black,
                          ),
                          label: const Text('수정'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(
                              color: AppTheme.primaryBlue,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '칼럼 게시글 신청 관리',
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
            onPressed: _loadAllColumns,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AppSearchBar(
              controller: searchController,
              hintText: '제목, 닉네임으로 검색...',
              onChanged: _onSearchChanged,
              onClear: () => _onSearchChanged(''),
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
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '기간: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '시작일 미지정'} ~ ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '종료일 미지정'}',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
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
            Text('칼럼 목록을 불러오고 있습니다...'),
          ],
        ),
      );
    }

    if (hasError) {
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
                onPressed: _loadAllColumns,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (columns.isEmpty) {
      const String emptyMessage = '작성된 칼럼이 없습니다.';

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
          return _buildColumnItem(column, index);
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnItem(HospitalColumn column, int index) {
    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    column.isPublished ? Icons.unpublished : Icons.publish,
                    color: column.isPublished
                        ? AppTheme.textTertiary
                        : AppTheme.success,
                  ),
                  title: Text(column.isPublished ? '공개 해제' : '공개 승인'),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePublishStatus(column);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: BoardListRow(
        index: index + 1,
        title: column.title,
        // 미공개 칼럼은 회색으로 구분, 공개 칼럼은 기본 검정
        titleColor: column.isPublished ? null : AppTheme.textTertiary,
        authorName: column.authorNickname ?? column.hospitalName,
        authorProfileImage: column.hospitalProfileImage,
        createdAt: column.createdAt,
        onTap: () => _showColumnDetail(column),
      ),
    );
  }
}
