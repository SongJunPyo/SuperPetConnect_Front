import 'package:flutter/material.dart';
import '../services/hospital_column_service.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import 'hospital_column_create.dart';
import 'hospital_column_detail.dart';
import 'package:intl/intl.dart';

class HospitalColumnList extends StatefulWidget {
  const HospitalColumnList({super.key});

  @override
  _HospitalColumnListState createState() => _HospitalColumnListState();
}

class _HospitalColumnListState extends State<HospitalColumnList> with TickerProviderStateMixin {
  List<HospitalColumn> columns = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool? publishedFilter; // null = 전체, true = 공개, false = 공개안함
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  late TabController _tabController;
  DateTime? startDate;
  DateTime? endDate;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 초기 필터 설정: 0번 탭 = 전체 (null)
    publishedFilter = null;
    _loadMyColumns();
  }

  @override
  void dispose() {
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      // 0: 전체 (null), 1: 공개안함 (false), 2: 공개 (true)
      if (_tabController.index == 0) {
        publishedFilter = null;
      } else if (_tabController.index == 1) {
        publishedFilter = false;
      } else {
        publishedFilter = true;
      }
    });
    _loadMyColumns();
  }

  Future<void> _loadMyColumns() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      var allColumns = await HospitalColumnService.getMyColumns(
        page: 1,
        pageSize: 50,
      );
      
      var filteredColumns = allColumns.columns;
      
      // 발행 상태 필터링
      if (publishedFilter != null) {
        filteredColumns = filteredColumns.where((column) => column.isPublished == publishedFilter).toList();
      }
      
      // 검색 필터링
      if (searchQuery.isNotEmpty) {
        filteredColumns = filteredColumns.where((column) {
          return column.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 column.content.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }
      
      // 날짜 범위 필터링
      if (startDate != null) {
        filteredColumns = filteredColumns.where((column) {
          return column.createdAt.isAfter(startDate!.subtract(const Duration(days: 1)));
        }).toList();
      }
      
      if (endDate != null) {
        filteredColumns = filteredColumns.where((column) {
          return column.createdAt.isBefore(endDate!.add(const Duration(days: 1)));
        }).toList();
      }
      
      setState(() {
        columns = filteredColumns;
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _loadMyColumns();
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
        startDate = picked.start;
        endDate = picked.end;
      });
      _loadMyColumns();
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadMyColumns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '칼럼 목록',
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
            onPressed: _loadMyColumns,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final hasPermission = await HospitalColumnService.checkColumnPermission();
              if (hasPermission) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HospitalColumnCreate(),
                  ),
                ).then((_) => _loadMyColumns());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('관리자의 권한이 필요합니다.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            tooltip: '칼럼 작성',
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(text: '전체'),
              Tab(text: '공개안함'),
              Tab(text: '공개'),
            ],
          ),
          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '칼럼 제목, 내용으로 검색...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryBlue),
                ),
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
          
          // 날짜 범위 표시
          if (startDate != null || endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: AppTheme.primaryBlue, size: 18),
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
                      icon: const Icon(Icons.close, color: AppTheme.primaryBlue, size: 18),
                      onPressed: _clearDateRange,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          
          // 콘텐츠
          Expanded(
            child: _buildContent(),
          ),
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.red[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMyColumns,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (columns.isEmpty) {
      String emptyMessage;
      if (publishedFilter == null) {
        emptyMessage = searchQuery.isNotEmpty ? '검색 결과가 없습니다.' : '작성한 칼럼이 없습니다.';
      } else if (publishedFilter == true) {
        emptyMessage = searchQuery.isNotEmpty ? '공개된 칼럼 중 검색 결과가 없습니다.' : '공개된 칼럼이 없습니다.';
      } else {
        emptyMessage = searchQuery.isNotEmpty ? '공개 대기 중인 칼럼 중 검색 결과가 없습니다.' : '공개 대기 중인 칼럼이 없습니다.';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              if (publishedFilter == null && searchQuery.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '첫 번째 칼럼을 작성해보세요!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final hasPermission = await HospitalColumnService.checkColumnPermission();
                    if (hasPermission) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HospitalColumnCreate(),
                        ),
                      ).then((_) => _loadMyColumns());
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('관리자의 권한이 필요합니다.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('칼럼 작성하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: columns.length,
        separatorBuilder: (context, index) => Container(
          height: 1,
          color: AppTheme.lightGray.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        itemBuilder: (context, index) {
          final column = columns[index];
          return _buildColumnItem(column, index);
        },
      ),
    );
  }

  Widget _buildColumnItem(HospitalColumn column, int index) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HospitalColumnDetail(
              columnIdx: column.columnIdx,
            ),
          ),
        ).then((_) => _loadMyColumns());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 순서 번호
            Container(
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
            // 중앙: 메인 콘텐츠
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 번째 줄: 제목
                  Text(
                    column.title,
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 두 번째 줄: 병원명
                  Text(
                    column.hospitalName.length > 15
                        ? '${column.hospitalName.substring(0, 15)}..' 
                        : column.hospitalName,
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
            // 오른쪽: 날짜들 + 상태 표시
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
                // 상태 표시 (공개/대기)
                Container(
                  height: 36,
                  width: 40,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: column.isPublished
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: column.isPublished
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.warning.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        column.isPublished ? Icons.check_circle : Icons.pending,
                        size: 10,
                        color: column.isPublished ? AppTheme.success : AppTheme.warning,
                      ),
                      Text(
                        column.isPublished ? '공개' : '대기',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: column.isPublished ? AppTheme.success : AppTheme.warning,
                          fontSize: 8,
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
  }
}