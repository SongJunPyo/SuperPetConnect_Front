import 'package:flutter/material.dart';
import 'package:connect/auth/login.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../services/dashboard_service.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import 'package:intl/intl.dart';
import '../user/user_column_list.dart';
import '../user/user_notice_list.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 서버 데이터
  List<HospitalColumn> columns = [];
  List<Notice> notices = [];
  bool isLoadingColumns = false;
  bool isLoadingNotices = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 탭 변경 리스너를 추가하여 탭이 변경될 때 UI를 다시 그리도록 합니다.
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }
  
  // 데이터 로드
  Future<void> _loadData() async {
    print('DEBUG: Welcome 페이지 리프레시 - 데이터 로드 시작');
    setState(() {
      isLoadingColumns = true;
      isLoadingNotices = true;
    });

    try {
      print('DEBUG: API 호출 시작 - 칼럼 및 공지사항');
      final futures = await Future.wait([
        DashboardService.getPublicColumns(limit: 10),
        DashboardService.getPublicNotices(limit: 10),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;
      
      print('DEBUG: API 응답 - 칼럼: ${columnPosts.length}개, 공지사항: ${noticePosts.length}개');

      // 칼럼 변환
      final sortedColumns = columnPosts.map((column) {
        return HospitalColumn(
          columnIdx: column.columnIdx,
          title: column.title,
          content: column.contentPreview,
          hospitalName: column.authorName,
          hospitalIdx: 0,
          isPublished: true,
          viewCount: column.viewCount,
          createdAt: column.createdAt,
          updatedAt: column.updatedAt,
        );
      }).toList();

      // 중요도 우선 정렬
      sortedColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]');
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]');
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      // 공지사항 변환
      final sortedNotices = noticePosts.map((notice) {
        return Notice(
          noticeIdx: notice.noticeIdx,
          title: notice.title,
          content: notice.contentPreview,
          isImportant: notice.isImportant,
          isActive: true,
          createdAt: notice.createdAt,
          updatedAt: notice.updatedAt,
          authorEmail: notice.authorEmail,
          authorName: notice.authorName,
          viewCount: notice.viewCount,
          targetAudience: notice.targetAudience,
        );
      }).toList();

      // 중요 공지 우선 정렬
      sortedNotices.sort((a, b) {
        if (a.isImportant && !b.isImportant) return -1;
        if (!a.isImportant && b.isImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        columns = sortedColumns.take(10).toList();
        notices = sortedNotices.take(10).toList();
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
      
      print('DEBUG: Welcome 페이지 데이터 로드 완료 - 칼럼: ${columns.length}개, 공지사항: ${notices.length}개');
    } catch (e) {
      print('ERROR: Welcome 페이지 데이터 로드 실패: $e');
      setState(() {
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        showBackButton: false,
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryBlue,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: AppTheme.pagePadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/images/한국헌혈견협회 로고.png',
                      width: 60,
                      height: 60,
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            textAlign: TextAlign.left,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '한국헌혈견협회\n',
                                  style: AppTheme.h1Style,
                                ),
                                TextSpan(
                                  text: 'KCBDA-반려견 헌혈캠페인',
                                  style: AppTheme.bodyLargeStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.announcement, size: 20),
                          SizedBox(width: 8),
                          Text('공지사항'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article, size: 20),
                          SizedBox(width: 8),
                          Text('칼럼'),
                        ],
                      ),
                    ),
                  ],
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.black87,
                  dividerColor: Colors.transparent,
                ),
              ),
            ),
            SliverFillRemaining(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGray.withOpacity(0.3)),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 공지사항 내용
                    _buildNoticeBoard(),
                    // 칼럼 게시판 내용
                    _buildColumnBoard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공지사항 게시판 위젯을 생성합니다.
  Widget _buildNoticeBoard() {
    if (isLoadingNotices) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (notices.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
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
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 공지사항 목록
          Expanded(
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserNoticeListScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽: 순서 (카드 중앙 높이)
                        Container(
                          width: 28,
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
                              // 첫 번째 줄: 뱃지 + 제목
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (notice.isImportant) ...[
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
                                        '공지',
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
                                        color: notice.isImportant
                                            ? AppTheme.error
                                            : AppTheme.textPrimary,
                                        fontWeight: notice.isImportant
                                            ? FontWeight.w600
                                            : FontWeight.w500,
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
                              Row(
                                children: [
                                  Expanded(
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
          ),
          // 더보기 버튼 (가장 밑 가운데 정렬)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserNoticeListScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.veryLightGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.lightGray.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    '더보기',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 칼럼 게시판 위젯을 생성합니다.
  Widget _buildColumnBoard() {
    if (isLoadingColumns) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (columns.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: AppTheme.mediumGray),
                  const SizedBox(height: 16),
                  Text('공개된 칼럼이 없습니다', style: AppTheme.h4Style),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 칼럼 목록
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
                    column.title.contains('[공지]');

                return InkWell(
                  onTap: () {
                    // TODO: 칼럼 상세 페이지로 이동
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('칼럼 ${column.columnIdx} 상세 페이지 (준비 중)'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽: 순서 (카드 중앙 높이)
                        Container(
                          width: 28,
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
                        // 중앙: 메인 콘텐츠
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 첫 번째 줄: 뱃지 + 제목
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
                                        color: isImportant
                                            ? AppTheme.error
                                            : AppTheme.textPrimary,
                                        fontWeight: isImportant
                                            ? FontWeight.w600
                                            : FontWeight.w500,
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
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
                                  ),
                                ],
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
          // 더보기 버튼 (가장 밑 가운데 정렬)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserColumnListScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.veryLightGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.lightGray.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    '더보기',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
