import 'package:flutter/material.dart';
import 'package:connect/admin/admin_profile.dart';
import 'package:connect/admin/admin_alarm.dart';
import 'package:connect/admin/admin_post_check.dart';
import 'package:connect/admin/admin_user_check.dart';
import 'package:connect/admin/admin_hospital_check.dart';
import 'package:connect/admin/admin_signup_management.dart';
import 'package:connect/admin/admin_approved_posts.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';

class AdminDashboard extends StatefulWidget {
  // StatelessWidget -> StatefulWidget으로 변경 (향후 상태관리 유연성 위해)
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // TODO: 실제 관리자 이름은 서버/로컬에서 가져오도록 변경
  String adminName = "관리자"; // 기본값

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDashboardAppBar(
        onBackPressed: () => Navigator.pop(context),
        onProfilePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminProfile()),
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
                  '시스템 운영 현황을 확인하고 관리해주세요.',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                AppInfoCard(
                  icon: Icons.info_outline,
                  title: '새로운 회원가입 승인 요청 3건이 있습니다!',
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
              ],
            ),
            const SizedBox(height: AppTheme.spacing32),
            Text(
              "게시글 관리",
              style: AppTheme.h3Style,
            ),
            const SizedBox(height: AppTheme.spacing16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppTheme.spacing16,
              mainAxisSpacing: AppTheme.spacing16,
              childAspectRatio: 1.5,
              children: [
                AppFeatureCard(
                  icon: Icons.post_add_outlined,
                  title: "게시글 신청 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminPostCheck(),
                      ),
                    );
                  },
                ),
                AppFeatureCard(
                  icon: Icons.article_outlined,
                  title: "게시글 현황 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminApprovedPostsScreen(),
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
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppTheme.spacing16,
              mainAxisSpacing: AppTheme.spacing16,
              childAspectRatio: 1.5,
              children: [
                AppFeatureCard(
                  icon: Icons.person_outline,
                  title: "사용자 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminUserCheck(),
                      ),
                    );
                  },
                ),
                AppFeatureCard(
                  icon: Icons.local_hospital_outlined,
                  title: "병원 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminHospitalCheck(),
                      ),
                    );
                  },
                ),
                AppFeatureCard(
                  icon: Icons.how_to_reg_outlined,
                  title: "회원 가입 관리",
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

}
