// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pet_management.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/unified_notification_page.dart';
import '../auth/profile_management.dart';
import 'user_notice_list.dart';
import 'user_donation_posts_list.dart';
import 'user_column_list.dart';
import 'donation_history_screen.dart';
import '../services/dashboard_service.dart';
import '../models/column_post_model.dart';
import '../models/notice_post_model.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import '../utils/preferences_manager.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/number_format_util.dart';
import '../utils/config.dart';
import '../widgets/dashboard/board_section.dart';
import '../widgets/post_list/board_list_row.dart';
import '../widgets/post_list/author_avatar.dart';
import '../widgets/post_list/notice_styling.dart';
import '../services/auth_http_client.dart';
import '../utils/text_personalization_util.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/notification_provider.dart';
import '../widgets/rich_text_viewer.dart';
import '../utils/app_constants.dart';
import '../widgets/association_footer.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String userName = "사용자"; // 실제 사용자 이름
  String userNickname = "사용자"; // 사용자 닉네임
  String currentDateTime = "";
  Timer? _timer;

  // 서버 데이터
  List<HospitalColumn> columns = [];
  List<Notice> notices = [];

  bool isLoadingColumns = false;
  bool isLoadingNotices = false;
  bool isLoadingDashboard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
    ); // 2개의 탭 (공지사항, 칼럼)
    _tabController.addListener(() {
      setState(() {}); // 탭이 변경될 때 UI를 다시 그리도록 강제
    });
    _updateDateTime();
    _startTimer();
    _initializeDashboard();

    // 알림 Provider 초기화 (페이지 새로고침 시에도 알림 수신 가능하도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });
  }

  void _updateDateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final formatter = DateFormat('yyyy년 M월 d일 (EEEE) HH:mm', 'ko_KR');
    setState(() {
      currentDateTime = formatter.format(now);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateDateTime();
    });
  }

  // 대시보드 초기화: 프로필 로드 → 데이터 로드
  Future<void> _initializeDashboard() async {
    await _loadUserProfile();
    await _loadDashboardData();
  }

  Future<void> _loadUserProfile() async {
    // 서버에서 프로필 정보 가져오기
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final userRealName = data['name'] ?? '사용자';
        final userRealNickname = data['nickname'] ?? userRealName;

        if (!mounted) return;
        setState(() {
          userName = userRealName;
          userNickname = userRealNickname;
        });

        // 로컬 저장소에도 업데이트
        await PreferencesManager.setUserName(userRealName);
        await PreferencesManager.setUserNickname(userRealNickname);
        return;
      }
    } catch (e) {
      // 웹 환경에서는 CORS 문제로 인해 로컬 데이터 사용
    }

    // 서버 실패 시 로컬에 저장된 이름과 닉네임 사용
    final savedName = await PreferencesManager.getUserName();
    final savedNickname = await PreferencesManager.getUserNickname();
    if (savedName != null && savedName.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        userName = savedName;
        userNickname = savedNickname ?? savedName;
      });
    } else {
      if (!mounted) return;
      setState(() {
        userName = '사용자';
        userNickname = '사용자';
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadUserProfile();
    _updateDateTime();
    await _loadDashboardData();
  }

  // 통합 대시보드 데이터 로드 (공지사항 + 칼럼)
  Future<void> _loadDashboardData() async {
    setState(() {
      isLoadingDashboard = true;
      isLoadingColumns = true;
      isLoadingNotices = true;
    });

    try {
      // 칼럼과 공지사항 병렬 로딩
      final futures = await Future.wait([
        DashboardService.getPublicColumns(
          limit: DashboardService.dashboardColumnLimit,
        ),
        // 사용자는 인증된 API 사용 (targetAudience 0, 3 포함)
        DashboardService.getAuthenticatedNotices(
          limit: DashboardService.dashboardNoticeLimit,
        ),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;

      // 칼럼 정렬 (중요 공지 우선, 그 다음 최신순)
      final sortedColumns =
          columnPosts.map((column) {
            return HospitalColumn(
              columnIdx: column.columnIdx,
              title: column.title,
              content: column.contentPreview,
              contentDelta: column.contentDelta,
              hospitalName: column.authorName, // 병원 실명
              hospitalIdx: 0,
              isPublished: true,
              viewCount: column.viewCount,
              createdAt: column.createdAt,
              updatedAt: column.updatedAt,
              authorNickname: column.authorNickname, // 병원 닉네임
              hospitalProfileImage: column.hospitalProfileImage,
              columnUrl: column.columnUrl,
            );
          }).toList();

      sortedColumns.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final topColumns =
          sortedColumns.take(DashboardService.dashboardColumnLimit).toList();

      // 공지사항 필터링 및 정렬 (청중 타겟이 전체(0) 또는 사용자(3)만)
      // 서버가 이미 noticeActive=True만 반환하므로 추가 필터링 불필요
      final sortedNotices =
          noticePosts
              .where(
                (notice) =>
                    notice.targetAudience == AppConstants.noticeTargetAll,
              )
              .map((notice) {
                return Notice(
                  noticeIdx: notice.noticeIdx,
                  accountIdx: 0, // DashboardService에서 제공하지 않는 필드
                  title: notice.title,
                  content: notice.contentPreview,
                  noticeImportant: notice.noticeImportant, // 0=뱃지 표시, 1=뱃지 숨김
                  noticeActive: true,
                  createdAt: notice.createdAt,
                  updatedAt: notice.updatedAt,
                  authorEmail: notice.authorEmail,
                  authorName: notice.authorName,
                  authorNickname: notice.authorNickname, // 작성자 닉네임
                  authorProfileImage: notice.authorProfileImage,
                  viewCount: notice.viewCount,
                  targetAudience: notice.targetAudience,
                  noticeUrl: notice.noticeUrl,
                );
              })
              .toList();

      sortedNotices.sort((a, b) {
        final ar = NoticeStyling.priorityRank(
          targetAudience: a.targetAudience,
          noticeImportant: a.noticeImportant,
        );
        final br = NoticeStyling.priorityRank(
          targetAudience: b.targetAudience,
          noticeImportant: b.noticeImportant,
        );
        if (ar != br) return ar - br;
        return b.createdAt.compareTo(a.createdAt);
      });

      final topNotices =
          sortedNotices.take(DashboardService.dashboardNoticeLimit).toList();

      if (!mounted) return;
      setState(() {
        columns = topColumns;
        notices = topNotices;
        isLoadingDashboard = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDashboard = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose(); // TabController 리소스 해제
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로가기 방지
      child: Scaffold(
        appBar: AppDashboardAppBar(
          onProfilePressed: () async {
            // 프로필 관리 페이지로 이동 후 돌아올 때 사용자 이름 새로고침
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileManagement(),
              ),
            );
            // 프로필 페이지에서 돌아온 후 사용자 정보 새로고침
            _loadUserProfile();
          },
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UnifiedNotificationPage(),
              ),
            );
          },
          additionalAction: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.pets, color: AppTheme.textPrimary, size: 20),
            label: const Text('반려동물 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PetManagementScreen(),
                ),
              );
            },
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryBlue,
          child: _buildDashboardContent(),
        ),
        bottomNavigationBar: const AssociationFooter(),
      ),
    );
  }

  // 사용자 대시보드의 메인 내용을 구성하는 위젯
  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 고정 컨텐츠
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            AppTheme.spacing24,
            AppTheme.spacing24,
            AppTheme.spacing12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안녕하세요,', style: AppTheme.h2Style),
              Text('$userNickname 님!', style: AppTheme.h2Style),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                currentDateTime,
                style: AppTheme.bodyLargeStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),

              // 퀵 액세스 메뉴
              _buildLongActionCard(
                icon: Icons.bloodtype_outlined,
                title: '헌혈 모집',
                subtitle: '진행 중인 헌혈 요청 모아보기',
                color: Colors.red.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const UserDonationPostsListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildLongActionCard(
                icon: Icons.bloodtype,
                title: '헌혈 이력',
                subtitle: '헌혈 신청 및 완료 내역',
                color: Colors.blue.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DonationHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // 탭바
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign, size: 20),
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
        // 탭 뷰 - 남은 공간을 모두 채움
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              bottom: AppTheme.spacing16,
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
                _buildNoticeBoard(), // 공지사항 게시판 내용
                _buildColumnBoard(), // 칼럼 게시판 내용
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 칼럼 게시판 위젯을 생성합니다.
  Widget _buildColumnBoard() {
    return BoardSection<HospitalColumn>(
      isLoading: isLoadingColumns,
      items: columns,
      emptyIcon: Icons.article_outlined,
      emptyMessage: '공개된 칼럼이 없습니다',
      onMoreTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserColumnListScreen(),
          ),
        );
      },
      itemBuilder: (context, index, column) => BoardListRow(
        index: index + 1,
        title: column.title,
        authorName: column.authorNickname!,
        authorProfileImage: column.hospitalProfileImage,
        createdAt: column.createdAt,
        onTap: () => _showColumnBottomSheet(column),
      ),
    );
  }

  void _showColumnBottomSheet(HospitalColumn column) {
    final String? columnUrl = column.columnUrl;
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
                          TextPersonalizationUtil.personalizeTitle(
                            title: column.title,
                            userName: userName,
                            userNickname: userNickname,
                          ),
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
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
                      AuthorAvatar(
                        profileImage: column.hospitalProfileImage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          column.authorNickname!,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(column.createdAt)}',
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
                      child:
                          column.contentDelta != null &&
                                  column.contentDelta!.isNotEmpty
                              ? RichTextViewer(
                                contentDelta: column.contentDelta,
                                plainText: column.content,
                                padding: EdgeInsets.zero,
                              )
                              : Text(
                                column.content,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  height: 1.6,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (columnUrl != null && columnUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(columnUrl);
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
                        label: const Text('관련 링크 열기'),
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
                          '조회수 ${NumberFormatUtil.formatViewCount(column.viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!column.updatedAt.isAtSameMomentAs(
                          column.createdAt,
                        ))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(column.updatedAt)}',
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

  // 공지사항 게시판 위젯을 생성합니다.
  Widget _buildNoticeBoard() {
    return BoardSection<Notice>(
      isLoading: isLoadingNotices,
      items: notices,
      emptyIcon: Icons.announcement_outlined,
      emptyMessage: '공지사항이 없습니다',
      onMoreTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserNoticeListScreen(),
          ),
        );
      },
      itemBuilder: (context, index, notice) => BoardListRow(
        index: index + 1,
        title: notice.title,
        titleColor: NoticeStyling.titleColor(
          targetAudience: notice.targetAudience,
          noticeImportant: notice.noticeImportant,
        ),
        titleFontWeight: NoticeStyling.titleFontWeight(
          targetAudience: notice.targetAudience,
          noticeImportant: notice.noticeImportant,
        ),
        authorName: notice.authorNickname!,
        authorProfileImage: notice.authorProfileImage,
        createdAt: notice.createdAt,
        onTap: () => _showNoticeBottomSheet(context, notice),
      ),
    );
  }

  // 가로 길게 생성하는 액션 카드 (관리자 스타일)
  Widget _buildLongActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.h4Style.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 퀵 액세스 카드를 생성하는 위젯

  // 공지사항 바텀시트 표시
  void _showNoticeBottomSheet(BuildContext context, Notice notice) async {
    // 상세 조회 API 호출 (조회수 자동 증가)
    final noticeDetail = await DashboardService.getNoticeDetail(
      notice.noticeIdx,
    );

    if (!mounted) return;

    final bool isImportant =
        (noticeDetail?.noticeImportant ?? notice.noticeImportant) ==
            AppConstants.noticeImportant;
    final String? authorProfileImage =
        noticeDetail?.authorProfileImage ?? notice.authorProfileImage;
    final DateTime createdAt = noticeDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = noticeDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = noticeDetail?.viewCount ?? notice.viewCount ?? 0;
    final String authorName =
        (noticeDetail?.authorNickname ?? notice.authorNickname)!;
    final String title = TextPersonalizationUtil.personalizeTitle(
      title: noticeDetail?.title ?? notice.title,
      userName: userName,
      userNickname: userNickname,
    );
    final String content = TextPersonalizationUtil.personalizeContent(
      content: noticeDetail?.contentPreview ?? notice.content,
      userName: userName,
      userNickname: userNickname,
    );
    final String? noticeUrl = noticeDetail?.noticeUrl ?? notice.noticeUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
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
                      AuthorAvatar(
                        profileImage: authorProfileImage,
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
