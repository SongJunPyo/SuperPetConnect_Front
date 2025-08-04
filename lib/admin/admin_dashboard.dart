import 'package:flutter/material.dart';
import 'package:connect/admin/admin_alarm.dart';
import 'package:connect/admin/admin_post_check.dart';
import 'package:connect/admin/admin_user_check.dart';
import 'package:connect/admin/admin_hospital_check.dart';
import 'package:connect/admin/admin_signup_management.dart';
import 'package:connect/admin/admin_approved_posts.dart';
import 'package:connect/admin/admin_notice_create.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';
import '../auth/profile_management.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';

class AdminDashboard extends StatefulWidget {
  // StatelessWidget -> StatefulWidget으로 변경 (향후 상태관리 유연성 위해)
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String adminName = "관리자";
  String currentDateTime = "";
  Timer? _timer;
  int pendingPostsCount = 0;
  int pendingSignupsCount = 0;
  bool isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _updateDateTime();
    _startTimer();
    _fetchPendingCounts();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAdminName() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    // 먼저 로컬에 저장된 이름 확인
    final savedName = prefs.getString('admin_name');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        adminName = savedName;
      });
    }
    
    // 서버에서 최신 이름 가져오기
    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('http://10.100.54.176:8002/api/auth/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final userName = data['name'] ?? '관리자';
          
          setState(() {
            adminName = userName;
          });
          
          // 로컬 저장소에도 업데이트
          await prefs.setString('admin_name', userName);
        }
      } catch (e) {
        // 오류 발생 시 기본값 유지
        print('관리자 이름 로드 실패: $e');
      }
    }
  }

  void _updateDateTime() {
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) return;

      // 동시에 두 API 호출
      final futures = await Future.wait([
        _fetchPendingPosts(token),
        _fetchPendingSignups(token),
      ]);

      setState(() {
        isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        isLoadingData = false;
      });
    }
  }

  Future<void> _fetchPendingPosts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.100.54.176:8002/api/admin/pending-posts-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          pendingPostsCount = data['count'] ?? 0;
        });
      }
    } catch (e) {
      // 에러 무시 (UI에 영향주지 않음)
    }
  }

  Future<void> _fetchPendingSignups(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.100.54.176:8002/api/signup_management/pending-users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          pendingSignupsCount = data.length;
        });
      }
    } catch (e) {
      // 에러 무시 (UI에 영향주지 않음)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDashboardAppBar(
        onBackPressed: () => Navigator.pop(context),
        onProfilePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileManagement()),
          );
        },
        onNotificationPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminAlarm()),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: AppTheme.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요, $adminName님!',
                  style: AppTheme.h2Style,
                ),
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
            const SizedBox(height: AppTheme.spacing32),
            Text(
              "게시글 관리",
              style: AppTheme.h3Style,
            ),
            const SizedBox(height: AppTheme.spacing16),
            Column(
              children: [
                _buildPremiumFeatureCard(
                  icon: Icons.post_add_outlined,
                  title: "게시글 신청 관리",
                  subtitle: "새로운 게시글 승인 및 검토",
                  iconColor: AppTheme.warning,
                  backgroundColor: AppTheme.warning.withOpacity(0.1),
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
                  icon: Icons.article_outlined,
                  title: "게시글 현황 관리",
                  subtitle: "승인된 게시글 현황 및 관리",
                  iconColor: AppTheme.success,
                  backgroundColor: AppTheme.success.withOpacity(0.1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminApprovedPostsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing16),
                _buildPremiumFeatureCard(
                  icon: Icons.campaign_outlined,
                  title: "공지글 작성",
                  subtitle: "시스템 공지사항 작성 및 관리",
                  iconColor: AppTheme.primaryBlue,
                  backgroundColor: AppTheme.lightBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminNoticeCreateScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing32),

            Text(
              "계정 관리",
              style: AppTheme.h3Style,
            ),
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
                  backgroundColor: AppTheme.success.withOpacity(0.1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminHospitalCheck(),
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
                  backgroundColor: AppTheme.warning.withOpacity(0.1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSignupManagement(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing20),
          ],
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
            title: '새로운 회원가입 승인 요청 ${pendingSignupsCount}건이 있습니다!',
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
            title: '새로운 게시글 승인 요청 ${pendingPostsCount}건이 있습니다!',
            description: '게시글 관리로 이동',
            iconColor: AppTheme.warning,
            backgroundColor: AppTheme.warning.withOpacity(0.1),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPostCheck(),
                ),
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
              color: iconColor.withOpacity(0.2),
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
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor,
                ),
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
                  color: iconColor.withOpacity(0.1),
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

}
