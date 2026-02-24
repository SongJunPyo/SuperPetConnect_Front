// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:connect/auth/login.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/rich_text_viewer.dart';
import '../services/dashboard_service.dart';
import '../models/notice_post_model.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import 'package:intl/intl.dart';
import '../user/user_column_list.dart';
import '../user/user_notice_list.dart';
import '../utils/number_format_util.dart';
import '../services/hospital_column_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_constants.dart';
import '../widgets/dashboard/dashboard_list_item.dart';
import '../widgets/dashboard/dashboard_more_button.dart';
import '../widgets/dashboard/dashboard_empty_state.dart';

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

  void _showColumnBottomSheet(HospitalColumn column) {
    // 웰컴 페이지는 로그인 전 상태이므로 공개 API 사용 (인증 불필요)
    final detailFuture = HospitalColumnService.getPublicColumnDetail(
      column.columnIdx,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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

                final displayNickname =
                    (detailColumn.authorNickname != null &&
                            detailColumn.authorNickname!.toLowerCase() !=
                                '닉네임 없음')
                        ? detailColumn.authorNickname!
                        : detailColumn.hospitalName;

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
                            icon: const Icon(
                              Icons.close,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '칼럼',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayNickname,
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
                              final uri = Uri.parse(detailColumn.columnUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else if (mounted) {
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
                      Container(
                        width: double.infinity,
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
                              '조회수 ${NumberFormatUtil.formatViewCount(detailColumn.viewCount)}회',
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
    );
  }

  // 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      isLoadingColumns = true;
      isLoadingNotices = true;
    });

    try {
      // 통합 대시보드 API 사용 (인증 불필요)
      final dashboardData = await DashboardService.getDashboardData(
        donationLimit: 0, // 헌혈 글은 필요 없음
        columnLimit: DashboardService.dashboardColumnLimit,
        noticeLimit: DashboardService.dashboardNoticeLimit,
      );

      final columnPosts = dashboardData.data.columns;
      final noticePosts = dashboardData.data.notices;

      // 칼럼 변환 (칼럼에는 target_audience 필드 없음 - 필터링 불필요)
      final sortedColumns =
          columnPosts.map((column) {
                final displayNickname =
                    column.authorNickname.toLowerCase() != '닉네임 없음'
                        ? column.authorNickname
                        : column.authorName;

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
                  authorNickname: displayNickname,
                  columnUrl: column.columnUrl,
                  targetAudience: column.targetAudience,
                );
              })
              .toList();

      // 중요도 우선 정렬
      sortedColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]');
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]');
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      final topColumns =
          sortedColumns.take(DashboardService.dashboardColumnLimit).toList();

      // 공지사항 변환 (전체(0) 또는 사용자(3) 공지만 필터링)
      // 서버가 이미 noticeActive=True만 반환하므로 추가 필터링 불필요
      final sortedNotices =
          noticePosts
              .where(
                (notice) =>
                    notice.targetAudience == AppConstants.noticeTargetAll ||
                    notice.targetAudience == AppConstants.noticeTargetUser,
              )
              .map((notice) {
                final displayNickname =
                    notice.authorNickname.toLowerCase() != '닉네임 없음'
                        ? notice.authorNickname
                        : notice.authorName;

                return Notice(
                  noticeIdx: notice.noticeIdx,
                  accountIdx: 0, // DashboardService에서 제공하지 않는 필드
                  title: notice.title,
                  content: notice.contentPreview,
                  noticeImportant: notice.noticeImportant, // 0=일반, 1=긴급(뱃지 표시)
                  noticeActive: true,
                  createdAt: notice.createdAt,
                  updatedAt: notice.updatedAt,
                  authorEmail: notice.authorEmail,
                  authorName: notice.authorName,
                  authorNickname: displayNickname,
                  viewCount: notice.viewCount,
                  targetAudience: notice.targetAudience,
                  noticeUrl: notice.noticeUrl,
                );
              })
              .toList();

      // 뱃지가 있는 공지를 상단에 정렬
      sortedNotices.sort((a, b) {
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (!mounted) return;
      setState(() {
        columns = topColumns;
        notices = List<Notice>.from(
          sortedNotices.take(DashboardService.dashboardNoticeLimit),
        );
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
      // 사용자에게 에러 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터를 불러오는 중 오류가 발생했습니다.'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
            icon: const Icon(Icons.key, color: Colors.black87, size: 24),
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
                margin: const EdgeInsets.only(
                  left: AppTheme.spacing16,
                  right: AppTheme.spacing16,
                  bottom: AppTheme.spacing16, // 하단 여백 추가
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.lightGray.withValues(alpha: 0.3),
                  ),
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
            child: const DashboardEmptyState(
              icon: Icons.announcement_outlined,
              message: '공지사항이 없습니다',
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
              itemCount: notices.length + 1, // ... 아이템 추가를 위해 +1
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == notices.length) {
                  return DashboardMoreButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserNoticeListScreen(isPublic: true),
                        ),
                      );
                    },
                  );
                }

                final notice = notices[index];

                return DashboardListItem<Notice>(
                  item: notice,
                  index: index + 1,
                  onTap: () => _showNoticeBottomSheet(context, notice),
                  getTitle: (n) => n.title,
                  getAuthor: (n) => n.authorNickname ?? n.authorName,
                  getCreatedAt: (n) => n.createdAt,
                  getUpdatedAt: (n) => n.updatedAt,
                  getViewCount: (n) => n.viewCount ?? 0,
                  shouldShowBadge: (n) => n.showBadge,
                  getBadgeText: (n) => n.badgeText,
                  enableTextPersonalization: false,
                );
              },
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
            child: const DashboardEmptyState(
              icon: Icons.article_outlined,
              message: '공개된 칼럼이 없습니다',
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
              itemCount: columns.length + 1, // ... 아이템 추가를 위해 +1
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == columns.length) {
                  return DashboardMoreButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserColumnListScreen(),
                        ),
                      );
                    },
                  );
                }

                final column = columns[index];

                return DashboardListItem<HospitalColumn>(
                  item: column,
                  index: index + 1,
                  onTap: () => _showColumnBottomSheet(column),
                  getTitle: (c) => c.title,
                  getAuthor: (c) => c.authorNickname ?? c.hospitalName,
                  getCreatedAt: (c) => c.createdAt,
                  getUpdatedAt: (c) => c.updatedAt,
                  getViewCount: (c) => c.viewCount,
                  shouldShowBadge: (c) => c.title.contains('[중요]') || c.title.contains('[공지]'),
                  getBadgeText: (c) => '중요',
                  enableTextPersonalization: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 공지사항 바텀시트 표시
  void _showNoticeBottomSheet(BuildContext context, Notice notice) async {
    NoticePost? noticeDetail;
    try {
      noticeDetail = await DashboardService.getPublicNoticeDetail(notice.noticeIdx);
    } catch (_) {}

    if (noticeDetail != null && mounted) {
      setState(() {
        final idx = notices.indexWhere((n) => n.noticeIdx == notice.noticeIdx);
        if (idx != -1) {
          final detailNickname = noticeDetail!.authorNickname;
          final displayNickname =
              (detailNickname.toLowerCase() != '닉네임 없음')
                  ? detailNickname
                  : noticeDetail.authorName;

          notices[idx] = Notice(
            noticeIdx: notices[idx].noticeIdx,
            accountIdx: notices[idx].accountIdx,
            title: noticeDetail.title,
            content: noticeDetail.contentPreview,
            noticeImportant: noticeDetail.noticeImportant,
            noticeActive: notices[idx].noticeActive,
            createdAt: noticeDetail.createdAt,
            updatedAt: noticeDetail.updatedAt,
            authorEmail: noticeDetail.authorEmail,
            authorName: noticeDetail.authorName,
            authorNickname: displayNickname,
            viewCount: noticeDetail.viewCount,
            targetAudience: noticeDetail.targetAudience,
            noticeUrl: noticeDetail.noticeUrl,
          );
        }
      });
    }

    if (!mounted) return;

    final bool isImportant =
        (noticeDetail?.noticeImportant ?? notice.noticeImportant) == 0;
    final DateTime createdAt = noticeDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = noticeDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = noticeDetail?.viewCount ?? notice.viewCount ?? 0;
    final detailNickname = noticeDetail?.authorNickname;
    final String authorName =
        (detailNickname != null && detailNickname.toLowerCase() != '닉네임 없음')
            ? detailNickname
            : noticeDetail?.authorName ??
                notice.authorNickname ??
                notice.authorName;
    final String title = noticeDetail?.title ?? notice.title;
    final String content = noticeDetail?.contentPreview ?? notice.content;
    final String? noticeUrl = noticeDetail?.noticeUrl ?? notice.noticeUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isImportant
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isImportant
                                  ? AppTheme.error
                                  : AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isImportant ? '공지' : '알림',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (noticeUrl != null && noticeUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(noticeUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else if (mounted) {
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
                  Container(
                    width: double.infinity,
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
                          '조회수 ${NumberFormatUtil.formatViewCount(viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!updatedAt.isAtSameMomentAs(createdAt))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(updatedAt)}',
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
  }
}
