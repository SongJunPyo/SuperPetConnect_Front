import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/dashboard_service.dart';
import 'package:intl/intl.dart';

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
      final allColumns = await DashboardService.getPublicColumns(limit: 100);

      // 검색 필터링
      List<ColumnPost> filteredColumns = allColumns;
      if (searchQuery.isNotEmpty) {
        filteredColumns = allColumns.where((column) {
          return column.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 column.authorName.toLowerCase().contains(searchQuery.toLowerCase());
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadColumns,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '칼럼 제목, 작성자로 검색...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
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
          ),
          Expanded(
            child: _buildContent(),
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
      );
    }

    if (columns.isEmpty) {
      return Center(
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
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.lightGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              border: Border(
                bottom: BorderSide(color: AppTheme.lightGray.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.article, size: 20, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(
                  '칼럼',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  searchQuery.isNotEmpty 
                      ? '검색결과 ${columns.length}건' 
                      : '총 ${columns.length}건',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 목록
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadColumns,
              color: AppTheme.primaryBlue,
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
                          // 왼쪽: 순서 (3줄 높이에 맞춤)
                          Container(
                            width: 28,
                            height: 60,
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
                          // 중앙: 3줄 구조 콘텐츠
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 첫 번째 줄: 제목
                                Text(
                                  column.title,
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: isImportant ? AppTheme.error : AppTheme.textPrimary,
                                    fontWeight: isImportant ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // 두 번째 줄: 등록 날짜
                                Text(
                                  '등록: ${DateFormat('yy.MM.dd').format(column.createdAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // 세 번째 줄: 작성자
                                Text(
                                  column.authorName.length > 15
                                      ? '${column.authorName.substring(0, 15)}..'
                                      : column.authorName,
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 오른쪽: 조회수 박스 (3줄 높이)
                          Container(
                            height: 60,
                            width: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.mediumGray.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.lightGray.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 12,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${column.viewCount}',
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
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}