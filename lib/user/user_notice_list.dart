import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/notice_model.dart';
import '../services/dashboard_service.dart';
import 'package:intl/intl.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';

class UserNoticeListScreen extends StatefulWidget {
  const UserNoticeListScreen({super.key});

  @override
  State<UserNoticeListScreen> createState() => _UserNoticeListScreenState();
}

class _UserNoticeListScreenState extends State<UserNoticeListScreen> {
  List<Notice> notices = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 대시보드와 동일한 API 사용 (서버 제한: 최대 50)
      final noticesData = await DashboardService.getPublicNotices(limit: 50);
      
      // NoticePost를 Notice로 변환
      List<Notice> allNotices = noticesData.map((noticePost) {
        return Notice(
          noticeIdx: noticePost.noticeIdx,
          accountIdx: 0, // DashboardService에서 제공하지 않는 필드
          title: noticePost.title,
          content: noticePost.contentPreview,
          noticeImportant: noticePost.noticeImportant,
          noticeActive: true,
          createdAt: noticePost.createdAt,
          updatedAt: noticePost.createdAt,
          authorEmail: noticePost.authorEmail,
          authorName: noticePost.authorName,
          authorNickname: noticePost.authorName, // authorName을 nickname으로 사용
          viewCount: noticePost.viewCount,
          targetAudience: noticePost.targetAudience,
        );
      }).toList();

      // 검색 필터링 적용
      if (searchQuery.isNotEmpty) {
        allNotices = allNotices.where((notice) {
          final titleMatch = notice.title.toLowerCase().contains(searchQuery.toLowerCase());
          final authorMatch = notice.authorName.toLowerCase().contains(searchQuery.toLowerCase());
          return titleMatch || authorMatch;
        }).toList();
      }

      // 날짜 범위 필터
      if (startDate != null && endDate != null) {
        allNotices = allNotices.where((notice) {
          final createdAt = notice.createdAt;
          return !createdAt.isBefore(startDate!) && !createdAt.isAfter(endDate!.add(const Duration(days: 1)));
        }).toList();
      }

      // 뱃지가 있는 공지를 상단에, 그 다음 최신순으로 정렬
      allNotices.sort((a, b) {
        // 뱃지가 있는 공지 우선 정렬
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;

        // 같은 조건이면 최신순 정렬
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        notices = allNotices;
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
    _loadNotices();
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
      _loadNotices();
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadNotices();
  }

  void _showNoticeDetail(Notice notice) async {
    // 상세 조회 API 호출 (조회수 자동 증가)
    final noticeDetail = await DashboardService.getNoticeDetail(notice.noticeIdx);
    
    if (noticeDetail != null) {
      // 목록의 조회수를 업데이트된 값으로 반영
      setState(() {
        final index = notices.indexWhere((n) => n.noticeIdx == notice.noticeIdx);
        if (index != -1) {
          notices[index] = Notice(
            noticeIdx: notices[index].noticeIdx,
            accountIdx: notices[index].accountIdx,
            title: notices[index].title,
            content: notices[index].content,
            noticeImportant: notices[index].noticeImportant,
            noticeActive: notices[index].noticeActive,
            createdAt: notices[index].createdAt,
            updatedAt: notices[index].updatedAt,
            authorEmail: notices[index].authorEmail,
            authorName: notices[index].authorName,
            authorNickname: notices[index].authorNickname,
            viewCount: noticeDetail.viewCount, // 업데이트된 조회수 반영
            targetAudience: notices[index].targetAudience,
          );
        }
      });
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              if (notice.showBadge) ...[
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
                    notice.badgeText,
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
                child: Text(
                  noticeDetail?.title ?? notice.title,
                  style: AppTheme.h4Style.copyWith(
                    color: notice.showBadge ? AppTheme.error : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(noticeDetail?.contentPreview ?? notice.content, style: AppTheme.bodyMediumStyle),
                const SizedBox(height: 16),
                Text(
                  '작성일: ${DateFormat('yyyy-MM-dd HH:mm').format(noticeDetail?.createdAt ?? notice.createdAt)}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if ((noticeDetail?.createdAt ?? notice.updatedAt) != (noticeDetail?.createdAt ?? notice.createdAt))
                  Text(
                    '수정일: ${DateFormat('yyyy-MM-dd HH:mm').format(notice.updatedAt)}',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                Text(
                  '조회수: ${NumberFormatUtil.formatViewCount(noticeDetail?.viewCount ?? notice.viewCount ?? 0)}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '대상: ${_getTargetAudienceText(noticeDetail?.targetAudience ?? notice.targetAudience)}',
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

  String _getTargetAudienceText(int targetAudience) {
    switch (targetAudience) {
      case 0:
        return '전체';
      case 2:
        return '병원';
      case 3:
        return '사용자';
      default:
        return '전체';
    }
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
          '공지사항',
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
            onPressed: _loadNotices,
            tooltip: '새로고침',
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
                TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '제목, 작성자로 검색...',
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

    if (notices.isEmpty) {
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: notices.length,
        separatorBuilder: (context, index) => Container(
          height: 1,
          color: AppTheme.lightGray.withOpacity(0.2),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        itemBuilder: (context, index) {
                  final notice = notices[index];
                  
                  return InkWell(
                    onTap: () => _showNoticeDetail(notice),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    if (notice.showBadge) ...[
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
                                          notice.badgeText,
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
                                        text: notice.title,
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          color: notice.showBadge ? AppTheme.error : AppTheme.textPrimary,
                                          fontWeight: notice.showBadge ? FontWeight.w600 : FontWeight.w500,
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
                                    notice.authorName.length > 15
                                        ? '${notice.authorName.substring(0, 15)}..'
                                        : notice.authorName,
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
                                    '작성: ${DateFormat('yy.MM.dd').format(notice.createdAt)}',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '수정: ${DateFormat('yy.MM.dd').format(notice.updatedAt)}',
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
                                      NumberFormatUtil.formatViewCount(notice.viewCount ?? 0),
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
    );
  }

  Color _getTargetAudienceColor(int targetAudience) {
    switch (targetAudience) {
      case 2:
        return Colors.orange; // 병원: 주황색
      case 3:
        return AppTheme.success; // 사용자: 초록색
      default:
        return AppTheme.primaryBlue; // 전체: 파란색
    }
  }
}