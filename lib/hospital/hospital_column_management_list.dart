// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/hospital_column_service.dart';
import '../utils/preferences_manager.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/error_display.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/rich_text_viewer.dart';
import '../widgets/post_list/board_list_row.dart';
import 'hospital_column_create.dart';
import 'hospital_column_edit.dart';
import '../widgets/app_search_bar.dart';

class HospitalColumnManagementScreen extends StatefulWidget {
  const HospitalColumnManagementScreen({super.key});

  @override
  State<HospitalColumnManagementScreen> createState() =>
      _HospitalColumnManagementScreenState();
}

class _HospitalColumnManagementScreenState
    extends State<HospitalColumnManagementScreen> {
  List<HospitalColumn> columns = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadMyColumns();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

      // 검색 필터링
      if (searchQuery.isNotEmpty) {
        filteredColumns =
            filteredColumns.where((column) {
              final nickname = column.authorNickname ?? column.hospitalName;
              return column.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  column.content.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  nickname.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();
      }

      // 날짜 범위 필터링
      if (startDate != null) {
        filteredColumns =
            filteredColumns.where((column) {
              return column.createdAt.isAfter(
                startDate!.subtract(const Duration(days: 1)),
              );
            }).toList();
      }

      if (endDate != null) {
        filteredColumns =
            filteredColumns.where((column) {
              return column.createdAt.isBefore(
                endDate!.add(const Duration(days: 1)),
              );
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
        errorMessage = formatErrorMessage(e);
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
                          if (detailColumn.hospitalProfileImage != null)
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(
                                detailColumn.hospitalProfileImage!.startsWith('http')
                                    ? detailColumn.hospitalProfileImage!
                                    : '${Config.serverUrl}${detailColumn.hospitalProfileImage}',
                              ),
                              backgroundColor: AppTheme.veryLightGray,
                              onBackgroundImageError: (_, __) {},
                            )
                          else
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.veryLightGray,
                              child: Icon(Icons.business, size: 16, color: AppTheme.textTertiary),
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
          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: AppSearchBar(
              controller: searchController,
              hintText: '칼럼 제목, 내용으로 검색...',
              onChanged: _onSearchChanged,
              onClear: () {
                _onSearchChanged('');
              },
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
                onPressed: _loadMyColumns,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
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

    return Container(
      decoration: BoxDecoration(color: Colors.white),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: columns.length,
        separatorBuilder:
            (context, index) => Container(
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
    final nickname = column.authorNickname ?? column.hospitalName;
    final displayNickname =
        nickname.toLowerCase() == '닉네임 없음' ? column.hospitalName : nickname;

    return BoardListRow(
      index: index + 1,
      title: column.title,
      // 미공개 칼럼은 회색으로 구분
      titleColor: column.isPublished ? null : AppTheme.textTertiary,
      authorName: displayNickname,
      authorProfileImage: column.hospitalProfileImage,
      createdAt: column.createdAt,
      onTap: () => _showColumnDetail(column),
    );
  }
}
