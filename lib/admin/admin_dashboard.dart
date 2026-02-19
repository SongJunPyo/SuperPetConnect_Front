import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/unified_notification_page.dart';
import 'package:connect/admin/admin_post_check.dart';
import 'package:connect/admin/admin_user_check.dart';
import 'package:connect/admin/admin_hospital_check.dart';
import 'package:connect/admin/admin_signup_management.dart';
import 'package:connect/admin/admin_notice_list.dart';
import 'package:connect/admin/admin_column_management.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';
import '../auth/profile_management.dart';
import '../utils/preferences_manager.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../providers/notification_provider.dart';
import '../services/dashboard_service.dart';
import '../models/column_post_model.dart';
import '../models/notice_post_model.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import '../utils/number_format_util.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/dashboard/dashboard_empty_state.dart';
import '../widgets/dashboard/dashboard_more_button.dart';
import '../widgets/dashboard/dashboard_list_item.dart';
import '../services/hospital_column_service.dart';

class AdminDashboard extends StatefulWidget {
  // StatelessWidget -> StatefulWidget으로 변경 (향후 상태관리 유연성 위해)
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String adminName = "관리자";
  String adminNickname = "관리자";
  String currentDateTime = "";
  Timer? _timer;
  int pendingPostsCount = 0;
  int pendingSignupsCount = 0;
  bool isLoadingData = true;

  // 서버 데이터
  List<HospitalColumn> columns = [];
  List<Notice> notices = [];
  bool isLoadingColumns = false;
  bool isLoadingNotices = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, // 2개의 탭 (공지사항, 칼럼)
      vsync: this,
    );
    _tabController.addListener(() {
      setState(() {}); // 탭이 변경될 때 UI를 다시 그리도록 강제
    });
    _loadAdminName();
    _updateDateTime();
    _startTimer();
    _fetchPendingCounts();
    _loadTabData();

    // 알림 Provider 초기화 (페이지 새로고침 시에도 알림 수신 가능하도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAdminName() async {
    // 로컬에 저장된 이름과 닉네임 확인
    final savedName = await PreferencesManager.getAdminName();
    final savedNickname = await PreferencesManager.getAdminNickname();

    if (!mounted) return;
    setState(() {
      adminName = savedName ?? '관리자';
      adminNickname = savedNickname ?? adminName;
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
      _fetchPendingCounts(); // 1분마다 새로운 요청사항 확인
    });
  }

  Future<void> _fetchPendingCounts() async {
    try {
      // 동시에 두 API 호출
      await Future.wait([_fetchPendingPosts(), _fetchPendingSignups()]);

      if (!mounted) return;
      setState(() {
        isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingData = false;
      });
    }
  }

  Future<void> _fetchPendingPosts() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/admin/pending-posts-count'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          pendingPostsCount = data['count'] ?? 0;
        });
      }
    } catch (e) {
      // 에러 무시 (UI에 영향주지 않음)
    }
  }

  Future<void> _fetchPendingSignups() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/signup_management/pending-users'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          pendingSignupsCount = data.length;
        });
      }
    } catch (e) {
      // 에러 무시 (UI에 영향주지 않음)
    }
  }

  // 탭 데이터 로드 (공지사항, 칼럼)
  Future<void> _loadTabData() async {
    setState(() {
      isLoadingColumns = true;
      isLoadingNotices = true;
    });

    try {
      final futures = await Future.wait([
        DashboardService.getPublicColumns(
          limit: DashboardService.dashboardColumnLimit,
        ),
        // 관리자는 인증된 API 사용 (targetAudience 0, 1, 2, 3 모두 포함)
        DashboardService.getAuthenticatedNotices(
          limit: DashboardService.dashboardNoticeLimit,
        ),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;

      // 칼럼 정렬 (중요 공지 우선, 그 다음 최신순)
      final sortedColumns =
          columnPosts.map((column) {
            final displayNickname =
                (column.authorNickname.toLowerCase() != '닉네임 없음')
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
            );
          }).toList();

      sortedColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]');
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]');
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      final topColumns =
          sortedColumns.take(DashboardService.dashboardColumnLimit).toList();

      // 공지사항 정렬 (관리자는 모든 공지사항을 볼 수 있음)
      final sortedNotices =
          noticePosts.map((notice) {
            final displayNickname =
                (notice.authorNickname.toLowerCase() != '닉네임 없음')
                    ? notice.authorNickname
                    : notice.authorName;

            return Notice(
              noticeIdx: notice.noticeIdx,
              accountIdx: 0,
              title: notice.title,
              content: notice.contentPreview,
              noticeImportant: notice.noticeImportant,
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
          }).toList();

      sortedNotices.sort((a, b) {
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      final topNotices =
          sortedNotices.take(DashboardService.dashboardNoticeLimit).toList();

      if (!mounted) return;
      setState(() {
        columns = topColumns;
        notices = topNotices;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadAdminName();
    _updateDateTime();
    await _fetchPendingCounts();
    await _loadTabData();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로가기 방지
      child: Scaffold(
        appBar: AppDashboardAppBar(
          onProfilePressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileManagement(),
              ),
            );
          },
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UnifiedNotificationPage(),
              ),
            );
          },
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppTheme.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('안녕하세요, $adminNickname 님!', style: AppTheme.h2Style),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        currentDateTime,
                        style: AppTheme.bodyLargeStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing20),
                      // 동적 알림 카드들
                      if (!isLoadingData) ..._buildDynamicNotifications(),
                    ],
                  ),
                ),
                Padding(
                  padding: AppTheme.pageHorizontalPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("게시글 관리", style: AppTheme.h3Style),
                      const SizedBox(height: AppTheme.spacing16),
                      Column(
                        children: [
                          _buildPremiumFeatureCard(
                            icon: Icons.bloodtype_outlined,
                            title: "헌혈 게시글 관리",
                            subtitle: "게시글 승인 및 현황 통합 관리",
                            iconColor: Colors.red.shade600,
                            backgroundColor: Colors.red.shade50,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminPostCheck(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.list_alt_outlined,
                            title: "공지글 목록",
                            subtitle: "작성된 공지사항 조회 및 관리",
                            iconColor: Colors.orange,
                            backgroundColor: Colors.orange.withValues(
                              alpha: 0.1,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const AdminNoticeListScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.rate_review_outlined,
                            title: "칼럼 게시글 신청 관리",
                            subtitle: "병원 칼럼 승인 및 발행 관리",
                            iconColor: Colors.purple,
                            backgroundColor: Colors.purple.withValues(
                              alpha: 0.1,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const AdminColumnManagement(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing32),

                      Text("계정 관리", style: AppTheme.h3Style),
                      const SizedBox(height: AppTheme.spacing16),
                      Column(
                        children: [
                          _buildPremiumFeatureCard(
                            icon: Icons.person_outline,
                            title: "사용자 관리",
                            subtitle: "사용자 계정 및 활동 관리",
                            iconColor: AppTheme.primaryBlue,
                            backgroundColor: AppTheme.lightBlue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminUserCheck(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.local_hospital_outlined,
                            title: "병원 관리",
                            subtitle: "병원 계정 승인 및 현황 관리",
                            iconColor: AppTheme.success,
                            backgroundColor: AppTheme.success.withValues(
                              alpha: 0.1,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const AdminHospitalCheck(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.how_to_reg_outlined,
                            title: "회원 가입 관리",
                            subtitle: "신규 회원 가입 승인 관리",
                            iconColor: AppTheme.warning,
                            backgroundColor: AppTheme.warning.withValues(
                              alpha: 0.1,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const AdminSignupManagement(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacing32),

                // 탭바
                Container(
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

                // 탭 뷰
                Container(
                  margin: const EdgeInsets.only(
                    left: AppTheme.spacing16,
                    right: AppTheme.spacing16,
                    bottom: AppTheme.spacing16,
                  ),
                  height: 400, // 고정 높이
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicNotifications() {
    List<Widget> notifications = [];

    if (pendingSignupsCount > 0) {
      notifications.add(
        SizedBox(
          width: double.infinity,
          child: AppInfoCard(
            icon: Icons.person_add_outlined,
            title: '새로운 회원가입 승인 요청 $pendingSignupsCount건이 있습니다!',
            description: '승인 관리로 이동',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSignupManagement(),
                ),
              );
            },
          ),
        ),
      );
      notifications.add(const SizedBox(height: AppTheme.spacing12));
    }

    if (pendingPostsCount > 0) {
      notifications.add(
        SizedBox(
          width: double.infinity,
          child: AppInfoCard(
            icon: Icons.post_add_outlined,
            title: '새로운 게시글 승인 요청 $pendingPostsCount건이 있습니다!',
            description: '게시글 관리로 이동',
            iconColor: AppTheme.warning,
            backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminPostCheck()),
              );
            },
          ),
        ),
      );
      notifications.add(const SizedBox(height: AppTheme.spacing12));
    }

    // 알림이 없으면 빈 리스트 반환 (카드가 표시되지 않음)
    return notifications;
  }

  Widget _buildPremiumFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color backgroundColor,
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
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
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
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 공지사항 게시판 위젯을 생성합니다.
  Widget _buildNoticeBoard() {
    if (isLoadingNotices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notices.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.announcement_outlined,
        message: '공지사항이 없습니다',
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
                          builder: (context) => const AdminNoticeListScreen(),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (columns.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.article_outlined,
        message: '공개된 칼럼이 없습니다',
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
                          builder: (context) => const AdminColumnManagement(),
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
                  getAuthor: (c) => (c.authorNickname != null && c.authorNickname!.toLowerCase() != '닉네임 없음')
                      ? c.authorNickname!
                      : c.hospitalName,
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

  void _showColumnBottomSheet(HospitalColumn column) async {
    HospitalColumn detailColumn;
    try {
      detailColumn = await HospitalColumnService.getColumnDetail(
        column.columnIdx,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('칼럼을 불러오지 못했습니다: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      final idx = columns.indexWhere(
        (c) => c.columnIdx == detailColumn.columnIdx,
      );
      if (idx != -1) {
        columns[idx] = detailColumn;
      }
    });

    final displayNickname =
        (detailColumn.authorNickname != null &&
                detailColumn.authorNickname!.toLowerCase() != '닉네임 없음')
            ? detailColumn.authorNickname!
            : detailColumn.hospitalName;

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
                        tooltip: '닫기',
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
                      child: Text(
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
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('링크를 열 수 없습니다'),
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
  }

  // 공지사항 바텀시트 표시
  void _showNoticeBottomSheet(BuildContext context, Notice notice) async {
    // 상세 조회 API 호출 (조회수 자동 증가)
    NoticePost? noticeDetail;
    try {
      noticeDetail = await DashboardService.getNoticeDetail(notice.noticeIdx);
    } catch (e) {
      // ignore, fall back to existing data
    }

    final fetchedDetail = noticeDetail;
    if (fetchedDetail != null && mounted) {
      setState(() {
        final idx = notices.indexWhere((n) => n.noticeIdx == notice.noticeIdx);
        if (idx != -1) {
          final nickname = fetchedDetail.authorNickname;
          final displayNickname =
              (nickname.toLowerCase() != '닉네임 없음')
                  ? nickname
                  : fetchedDetail.authorName;

          notices[idx] = Notice(
            noticeIdx: notices[idx].noticeIdx,
            accountIdx: notices[idx].accountIdx,
            title: fetchedDetail.title,
            content: fetchedDetail.contentPreview,
            noticeImportant: fetchedDetail.noticeImportant,
            noticeActive: notices[idx].noticeActive,
            createdAt: fetchedDetail.createdAt,
            updatedAt: fetchedDetail.updatedAt,
            authorEmail: fetchedDetail.authorEmail,
            authorName: fetchedDetail.authorName,
            authorNickname: displayNickname,
            viewCount: fetchedDetail.viewCount,
            targetAudience: fetchedDetail.targetAudience,
            noticeUrl: fetchedDetail.noticeUrl,
          );
        }
      });
    }

    if (!mounted) return;

    final bool isImportant =
        (fetchedDetail?.noticeImportant ?? notice.noticeImportant) == 0;
    final DateTime createdAt = fetchedDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = fetchedDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = fetchedDetail?.viewCount ?? notice.viewCount ?? 0;
    final detailNickname = fetchedDetail?.authorNickname;
    final String authorName =
        (detailNickname != null && detailNickname.toLowerCase() != '닉네임 없음')
            ? detailNickname
            : notice.authorNickname ?? notice.authorName;
    final String title = fetchedDetail?.title ?? notice.title;
    final String content = fetchedDetail?.contentPreview ?? notice.content;
    final String? noticeUrl = fetchedDetail?.noticeUrl ?? notice.noticeUrl;

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
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
                          } else {
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
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
