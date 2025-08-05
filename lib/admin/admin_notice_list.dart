import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../models/notice_model.dart';
import '../services/notice_service.dart';
import 'admin_notice_create.dart';
import 'package:intl/intl.dart';

class AdminNoticeListScreen extends StatefulWidget {
  const AdminNoticeListScreen({super.key});

  @override
  State<AdminNoticeListScreen> createState() => _AdminNoticeListScreenState();
}

class _AdminNoticeListScreenState extends State<AdminNoticeListScreen> {
  List<Notice> notices = [];
  bool isLoading = true;
  String? errorMessage;
  bool showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final loadedNotices = await NoticeService.getNotices(
        activeOnly: showActiveOnly,
      );

      // 최신순으로 정렬
      loadedNotices.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        notices = loadedNotices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteNotice(Notice notice) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('공지글 삭제'),
          content: Text('\'${notice.title}\'을(를) 삭제하시겠습니까?\n\n삭제된 공지글은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await NoticeService.deleteNotice(notice.noticeIdx);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공지글이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(notice.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.content,
                  style: AppTheme.bodyMediumStyle,
                ),
                const SizedBox(height: 16),
                Text(
                  '작성자: ${notice.authorEmail}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '작성일: ${DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt)}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (notice.updatedAt != notice.createdAt)
                  Text(
                    '수정일: ${DateFormat('yyyy-MM-dd HH:mm').format(notice.updatedAt)}',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '공지사항 관리',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(showActiveOnly ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                showActiveOnly = !showActiveOnly;
              });
              _loadNotices();
            },
            tooltip: showActiveOnly ? '전체 보기' : '활성 공지만 보기',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotices,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '오류가 발생했습니다',
                        style: AppTheme.h4Style,
                      ),
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
                )
              : Column(
                  children: [
                    // 필터 상태 표시
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      color: AppTheme.lightGray,
                      child: Row(
                        children: [
                          Icon(
                            showActiveOnly ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            showActiveOnly ? '활성 공지만 표시' : '모든 공지 표시',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '총 ${notices.length}개',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 공지글 목록
                    Expanded(
                      child: notices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.announcement_outlined,
                                    size: 64,
                                    color: AppTheme.mediumGray,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '공지사항이 없습니다',
                                    style: AppTheme.h4Style,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '새로운 공지사항을 작성해보세요',
                                    style: AppTheme.bodyMediumStyle,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadNotices,
                              color: AppTheme.primaryBlue,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: notices.length,
                                itemBuilder: (context, index) {
                                  final notice = notices[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12.0),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showNoticeDetail(notice),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notice.title,
                                                    style: AppTheme.h4Style.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // 상태 표시
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (notice.isImportant)
                                                      Container(
                                                        margin: const EdgeInsets.only(right: 8),
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.error.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '중요',
                                                          style: AppTheme.bodySmallStyle.copyWith(
                                                            color: AppTheme.error,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: notice.isActive
                                                            ? AppTheme.success.withOpacity(0.1)
                                                            : AppTheme.mediumGray.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        notice.isActive ? '활성' : '비활성',
                                                        style: AppTheme.bodySmallStyle.copyWith(
                                                          color: notice.isActive
                                                              ? AppTheme.success
                                                              : AppTheme.mediumGray,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // 메뉴 버튼
                                                PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    switch (value) {
                                                      case 'edit':
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => AdminNoticeCreateScreen(
                                                              editNotice: notice,
                                                            ),
                                                          ),
                                                        ).then((result) {
                                                          if (result == true) {
                                                            _loadNotices();
                                                          }
                                                        });
                                                        break;
                                                      case 'delete':
                                                        _deleteNotice(notice);
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder: (BuildContext context) => [
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.edit, size: 20),
                                                          SizedBox(width: 8),
                                                          Text('수정'),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                                          SizedBox(width: 8),
                                                          Text('삭제', style: TextStyle(color: Colors.red)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              notice.content,
                                              style: AppTheme.bodyMediumStyle.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: AppTheme.textTertiary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt),
                                                  style: AppTheme.bodySmallStyle.copyWith(
                                                    color: AppTheme.textTertiary,
                                                  ),
                                                ),
                                                if (notice.updatedAt != notice.createdAt) ...[
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: AppTheme.textTertiary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    DateFormat('yyyy-MM-dd HH:mm').format(notice.updatedAt),
                                                    style: AppTheme.bodySmallStyle.copyWith(
                                                      color: AppTheme.textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminNoticeCreateScreen(),
            ),
          ).then((result) {
            if (result == true) {
              _loadNotices();
            }
          });
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}