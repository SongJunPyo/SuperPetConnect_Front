// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/hospital_column_service.dart';
import '../utils/preferences_manager.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/error_display.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/rich_text_viewer.dart';
import '../widgets/post_list/author_avatar.dart';
import '../widgets/post_list/board_list_row.dart';
import '../widgets/post_list/board_list_header.dart';
import 'hospital_column_create.dart';
import 'hospital_column_edit.dart';
import '../widgets/search_date_filter_bar.dart';
import '../widgets/state_view.dart';

class HospitalColumnManagementScreen extends StatefulWidget {
  /// 알림 진입 시 자동으로 상세 시트를 열 칼럼 column_idx.
  /// column_approved / column_rejected 알림에서 전달된 ID로 fetch 완료 후 자동 시트 오픈.
  final int? initialColumnIdx;

  const HospitalColumnManagementScreen({super.key, this.initialColumnIdx});

  @override
  State<HospitalColumnManagementScreen> createState() =>
      _HospitalColumnManagementScreenState();
}

class _HospitalColumnManagementScreenState
    extends State<HospitalColumnManagementScreen> {
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
    _loadAndMaybeAutoOpen();
  }

  /// _loadMyColumns 완료 후 알림 진입(initialColumnIdx)이 있으면
  /// 매칭 칼럼의 상세 시트 자동 오픈.
  Future<void> _loadAndMaybeAutoOpen() async {
    await _loadMyColumns();
    if (!mounted) return;
    final id = widget.initialColumnIdx;
    if (id == null) return;
    final column = _allColumns.where((c) => c.columnIdx == id).firstOrNull;
    if (column == null) return;
    _showColumnDetail(column);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyColumns() async {
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
        final response = await HospitalColumnService.getMyColumns(
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

  Future<void> _increaseViewCountIfNeeded(int columnIdx) async {
    try {
      final hasViewed = await PreferencesManager.isHospitalColumnViewed(columnIdx);

      if (!hasViewed) {
        await HospitalColumnService.increaseViewCount(columnIdx);
        await PreferencesManager.setHospitalColumnViewed(columnIdx);
      }
    } catch (_) {
      // 조회수 증가 실패는 무시
    }
  }

  Future<void> _showColumnDetail(HospitalColumn column) async {
    await _increaseViewCountIfNeeded(column.columnIdx);
    final detailFuture = HospitalColumnService.getColumnDetail(
      column.columnIdx,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<HospitalColumn>(
              future: detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '칼럼을 불러오지 못했습니다.',
                          style: AppTheme.h4Style.copyWith(
                            color: AppTheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error?.toString().replaceAll(
                                'Exception: ',
                                '',
                              ) ??
                              '잠시 후 다시 시도해주세요.',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final detailColumn = snapshot.data!;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
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
                              detailColumn.title,
                              style: AppTheme.h3Style.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await _confirmDeleteColumn(
                                sheetContext,
                                detailColumn,
                              );
                              if (!mounted || !confirmed) return;

                              try {
                                await HospitalColumnService.deleteColumn(
                                  detailColumn.columnIdx,
                                );
                                if (!mounted) return;
                                Navigator.of(sheetContext).pop();
                                _loadMyColumns();
                              } catch (e) {
                                debugPrint('칼럼 삭제 실패: $e');
                              }
                            },
                          ),
                          IconButton(
                            tooltip: '닫기',
                            icon: const Icon(
                              Icons.close,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AuthorAvatar(
                            profileImage: detailColumn.hospitalProfileImage,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (() {
                                final nickname =
                                    detailColumn.authorNickname ??
                                    detailColumn.hospitalName;
                                if (nickname.toLowerCase() == '닉네임 없음') {
                                  return detailColumn.hospitalName;
                                }
                                return nickname;
                              })(),
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(detailColumn.createdAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
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
                              detailColumn.contentDelta != null &&
                                      detailColumn.contentDelta!.isNotEmpty
                                  ? RichTextViewer(
                                    contentDelta: detailColumn.contentDelta,
                                    plainText: detailColumn.content,
                                    padding: EdgeInsets.zero,
                                  )
                                  : Text(
                                    detailColumn.content,
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      height: 1.6,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (detailColumn.columnUrl != null &&
                          detailColumn.columnUrl!.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final url = detailColumn.columnUrl!.trim();
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                if (!mounted) return;
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => HospitalColumnEdit(
                                      column: detailColumn,
                                    ),
                              ),
                            ).then((updated) {
                              if (updated == true) {
                                _loadMyColumns();
                              }
                            });
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
                      Container(
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
                              '조회수 ${detailColumn.viewCount}회',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            if (!detailColumn.updatedAt.isAtSameMomentAs(
                              detailColumn.createdAt,
                            ))
                              Text(
                                '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(detailColumn.updatedAt)}',
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
      },
    ).whenComplete(_loadMyColumns);
  }

  Future<bool> _confirmDeleteColumn(
    BuildContext sheetContext,
    HospitalColumn column,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: sheetContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                '칼럼 삭제',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '\'${column.title}\'을(를)\n',
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

    return result ?? false;
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
              final hasPermission =
                  await HospitalColumnService.checkColumnPermission();
              if (hasPermission) {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HospitalColumnCreate(),
                    ),
                  ).then((_) => _loadMyColumns());
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('관리자의 권한이 필요합니다.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            tooltip: '칼럼 작성',
          ),
        ],
      ),
      body: Column(
        children: [
          SearchAndDateFilterBar(
            searchController: searchController,
            hintText: '칼럼 제목, 내용으로 검색...',
            onSearchChanged: _onSearchChanged,
            startDate: startDate,
            endDate: endDate,
            onClearDateRange: _clearDateRange,
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const StateView.loading();
    }

    if (hasError) {
      return StateView.error(message: errorMessage, onRetry: _loadMyColumns);
    }

    if (columns.isEmpty) {
      final String emptyMessage = searchQuery.isNotEmpty
          ? '검색 결과가 없습니다.'
          : '작성한 칼럼이 없습니다.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              if (searchQuery.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '첫 번째 칼럼을 작성해보세요!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final hasPermission =
                        await HospitalColumnService.checkColumnPermission();
                    if (hasPermission) {
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HospitalColumnCreate(),
                          ),
                        ).then((_) => _loadMyColumns());
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('관리자의 권한이 필요합니다.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('칼럼 작성하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.black,
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
    final nickname = column.authorNickname ?? column.hospitalName;
    final displayNickname =
        nickname.toLowerCase() == '닉네임 없음' ? column.hospitalName : nickname;

    return BoardListRow(
      index: index + 1,
      title: column.title,
      // 미공개 칼럼은 주황으로 구분 (admin_column_management.dart와 톤 일치)
      titleColor: column.isPublished ? null : AppTheme.warning,
      authorName: displayNickname,
      authorProfileImage: column.hospitalProfileImage,
      createdAt: column.createdAt,
      onTap: () => _showColumnDetail(column),
    );
  }
}
