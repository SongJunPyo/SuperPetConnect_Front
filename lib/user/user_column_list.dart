import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/dashboard_service.dart';
import 'package:intl/intl.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';

class UserColumnListScreen extends StatefulWidget {
  const UserColumnListScreen({super.key});

  @override
  State<UserColumnListScreen> createState() => _UserColumnListScreenState();
}

class _UserColumnListScreenState extends State<UserColumnListScreen> {
  List<ColumnPost> columns = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadColumns();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadColumns() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // API에서 데이터 로드 (개별 API 사용)
      final allColumns = await DashboardService.getPublicColumns(limit: 50);

      // 검색 필터링
      List<ColumnPost> filteredColumns = allColumns;
      if (searchQuery.isNotEmpty) {
        filteredColumns = allColumns.where((column) {
          return column.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 column.authorName.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }

      // 날짜 범위 필터
      if (startDate != null && endDate != null) {
        filteredColumns = filteredColumns.where((column) {
          final createdAt = column.createdAt;
          return !createdAt.isBefore(startDate!) && !createdAt.isAfter(endDate!.add(const Duration(days: 1)));
        }).toList();
      }

      // 정렬: 중요/공지 우선, 그 다음 최신순
      filteredColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]') || a.isImportant;
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]') || b.isImportant;
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        columns = filteredColumns;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _loadColumns();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
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
      });
      _loadColumns();
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadColumns();
  }

  // 날짜/시간 표시 로직
  String _getTimeDisplay(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      // 하루 이상 지나면 날짜로 표시
      return DateFormat('yyyy.MM.dd').format(dateTime);
    } else {
      // 하루 안에는 시간으로 표시
      return DateFormat('HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '칼럼',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
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
            onPressed: _loadColumns,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창 및 날짜 필터 표시
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
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: searchQuery.isNotEmpty
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, size: 16, color: AppTheme.primaryBlue),
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
                          icon: const Icon(Icons.close, color: AppTheme.primaryBlue, size: 18),
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
              onRefresh: _loadColumns,
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
      return ListView(
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
                    onPressed: _loadColumns,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.lightGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // 목록
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: columns.length,
              separatorBuilder: (context, index) => Container(
                height: 1,
                color: AppTheme.lightGray.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              itemBuilder: (context, index) {
                  final column = columns[index];
                  final isImportant = column.title.contains('[중요]') || 
                                     column.title.contains('[공지]') || 
                                     column.isImportant;
                  
                  return InkWell(
                    onTap: () {
                      // TODO: 칼럼 상세 페이지로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('칼럼 ${column.columnIdx} 상세 페이지 (준비 중)')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 중앙: 메인 콘텐츠
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 첫 번째 줄: 순서 번호 + 뱃지 + 제목
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 순서 번호
                                    Container(
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
                                          color: isImportant ? AppTheme.error : AppTheme.textPrimary,
                                          fontWeight: isImportant ? FontWeight.w600 : FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                        animationDuration: const Duration(milliseconds: 4000),
                                        pauseDuration: const Duration(milliseconds: 1000),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // 두 번째 줄: 작성자 이름
                                Padding(
                                  padding: const EdgeInsets.only(left: 28), // 순서 번호만큼 들여쓰기
                                  child: Text(
                                    column.authorName.length > 15
                                        ? '${column.authorName.substring(0, 15)}..'
                                        : column.authorName,
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
                          // 오른쪽: 날짜들 + 2줄 높이의 조회수 박스
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 날짜 컬럼 (작성/수정일 세로 배치)
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
                              // 2줄 높이의 조회수 박스
                              Container(
                                height: 36,
                                width: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.mediumGray.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.lightGray.withOpacity(0.3),
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
                                      NumberFormatUtil.formatViewCount(column.viewCount),
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
}