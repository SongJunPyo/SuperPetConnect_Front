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
  bool showActiveOnly = true; // true: 보임(활성), false: 숨김(비활성)

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

      final allNotices = await NoticeService.getAdminNotices(
        activeOnly: false, // 관리자용 API - 모든 공지글 포함
      );

      // 클라이언트에서 활성/비활성 필터링
      // showActiveOnly가 true면 활성화된 공지만, false면 비활성화된 공지만
      print('DEBUG: 전체 공지글 수: ${allNotices.length}');

      // 각 공지글의 is_active 상태 출력
      for (int i = 0; i < allNotices.length; i++) {
        print(
          'DEBUG: 공지글 ${i + 1} (${allNotices[i].title}): notice_active = ${allNotices[i].noticeActive}',
        );
      }

      print(
        'DEBUG: 활성화된 공지글 수: ${allNotices.where((notice) => notice.noticeActive).length}',
      );
      print(
        'DEBUG: 비활성화된 공지글 수: ${allNotices.where((notice) => !notice.noticeActive).length}',
      );
      print('DEBUG: showActiveOnly 상태: $showActiveOnly');

      final loadedNotices =
          showActiveOnly
              ? allNotices.where((notice) => notice.noticeActive).toList()
              : allNotices.where((notice) => !notice.noticeActive).toList();

      print('DEBUG: 필터링 후 공지글 수: ${loadedNotices.length}');

      // 중요 공지는 상단에, 일반 공지는 최신순으로 정렬
      loadedNotices.sort((a, b) {
        // 중요 공지 우선 정렬
        if (a.noticeImportant && !b.noticeImportant) return -1;
        if (!a.noticeImportant && b.noticeImportant) return 1;

        // 같은 중요도면 최신순 정렬
        return b.createdAt.compareTo(a.createdAt);
      });

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

  Future<void> _toggleNoticeActive(Notice notice) async {
    try {
      final updatedNotice = await NoticeService.toggleNoticeActive(
        notice.noticeIdx,
      );

      if (mounted) {
        final statusText = updatedNotice.noticeActive ? '활성화' : '비활성화';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공지글이 ${statusText}되었습니다.'),
            backgroundColor:
                updatedNotice.noticeActive ? AppTheme.success : AppTheme.mediumGray,
          ),
        );
        _loadNotices(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상태 변경 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotice(Notice notice) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('공지글 삭제'),
          content: Text(
            '\'${notice.title}\'을(를) 삭제하시겠습니까?\n\n삭제된 공지글은 복구할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
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
                Text(notice.content, style: AppTheme.bodyMediumStyle),
                const SizedBox(height: 16),
                Text(
                  '작성자: ${notice.authorEmail}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '대상: ${_getTargetAudienceText(notice.targetAudience)}',
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
            icon: Icon(
              showActiveOnly ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                showActiveOnly = !showActiveOnly;
              });
              _loadNotices();
            },
            tooltip: showActiveOnly ? '숨김 공지 보기' : '보임 공지 보기',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNotices),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
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
            tooltip: '새 공지 작성',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
              : errorMessage != null
              ? Center(
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
              )
              : Column(
                children: [
                  Expanded(
                    child:
                        notices.isEmpty
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
                                  Text('공지사항이 없습니다', style: AppTheme.h4Style),
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
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: notice.noticeImportant 
                                            ? AppTheme.error
                                            : AppTheme.mediumGray.withOpacity(0.3),
                                        width: notice.noticeImportant ? 2 : 1,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showNoticeDetail(notice),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notice.title,
                                                    style: AppTheme.h4Style
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // 상태 표시
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getTargetAudienceColor(
                                                              notice
                                                                  .targetAudience,
                                                            ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _getTargetAudienceText(
                                                          notice.targetAudience,
                                                        ),
                                                        style: AppTheme
                                                            .bodySmallStyle
                                                            .copyWith(
                                                              color: _getTargetAudienceColor(
                                                                notice
                                                                    .targetAudience,
                                                              ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
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
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => AdminNoticeCreateScreen(
                                                                  editNotice:
                                                                      notice,
                                                                ),
                                                          ),
                                                        ).then((result) {
                                                          if (result == true) {
                                                            _loadNotices();
                                                          }
                                                        });
                                                        break;
                                                      case 'toggle':
                                                        _toggleNoticeActive(
                                                          notice,
                                                        );
                                                        break;
                                                      case 'delete':
                                                        _deleteNotice(notice);
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder:
                                                      (
                                                        BuildContext context,
                                                      ) => [
                                                        const PopupMenuItem(
                                                          value: 'edit',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.edit,
                                                                size: 20,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text('수정'),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'toggle',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                notice.noticeActive
                                                                    ? Icons
                                                                        .visibility_off
                                                                    : Icons
                                                                        .visibility,
                                                                size: 20,
                                                                color:
                                                                    notice.noticeActive
                                                                        ? AppTheme
                                                                            .mediumGray
                                                                        : AppTheme
                                                                            .success,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                notice.noticeActive
                                                                    ? '비활성화'
                                                                    : '활성화',
                                                                style: TextStyle(
                                                                  color:
                                                                      notice.noticeActive
                                                                          ? AppTheme
                                                                              .mediumGray
                                                                          : AppTheme
                                                                              .success,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.delete,
                                                                size: 20,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                '삭제',
                                                                style: TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                              ),
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
                                              style: AppTheme.bodyMediumStyle
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
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
                                                  DateFormat(
                                                    'yyyy-MM-dd HH:mm',
                                                  ).format(notice.createdAt),
                                                  style: AppTheme.bodySmallStyle
                                                      .copyWith(
                                                        color:
                                                            AppTheme
                                                                .textTertiary,
                                                      ),
                                                ),
                                                if (notice.updatedAt !=
                                                    notice.createdAt) ...[
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color:
                                                        AppTheme.textTertiary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    DateFormat(
                                                      'yyyy-MM-dd HH:mm',
                                                    ).format(notice.updatedAt),
                                                    style: AppTheme
                                                        .bodySmallStyle
                                                        .copyWith(
                                                          color:
                                                              AppTheme
                                                                  .textTertiary,
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
    );
  }

  String _getTargetAudienceText(int targetAudience) {
    switch (targetAudience) {
      case 0:
        return '전체';
      case 1:
        return '병원';
      case 2:
        return '사용자';
      default:
        return '전체';
    }
  }

  Color _getTargetAudienceColor(int targetAudience) {
    switch (targetAudience) {
      case 0:
        return AppTheme.primaryBlue; // 전체: 파란색
      case 1:
        return Colors.orange; // 병원: 주황색
      case 2:
        return AppTheme.success; // 사용자: 초록색
      default:
        return AppTheme.primaryBlue;
    }
  }
}
