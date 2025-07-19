import 'package:flutter/material.dart';
import 'package:connect/admin/admin_profile.dart'; // 관리자 프로필 화면
import 'package:connect/admin/admin_alarm.dart'; // 관리자 알림 화면
import 'package:connect/admin/admin_post_check.dart'; // 게시글 승인관리 화면
import 'package:connect/admin/admin_user_check.dart'; // 사용자 관리 화면
import 'package:connect/admin/admin_hospital_check.dart'; // 병원 관리 화면
import 'package:connect/admin/admin_signup_management.dart'; // 회원가입 관리 화면
import 'package:connect/admin/admin_approved_posts.dart'; // 게시글 현황 관리 화면

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기 (예: 로그인 페이지)
          },
        ),
        title: const SizedBox.shrink(), // 제목 없음 (사용자/병원 대시보드와 통일)
        actions: [
          // 알림 아이콘 버튼
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black87,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminAlarm()),
              );
            },
          ),
          // 관리자 프로필 아이콘 버튼 (사용자/병원 대시보드와 동일한 디자인)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent, // 주 색상 사용
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ), // 사람 아이콘
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProfile()),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        // 전체 화면 스크롤 가능하게
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 24.0,
        ), // 전체 여백 조정
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 환영 메시지 섹션 (사용자/병원 대시보드와 유사)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), // 내부 패딩
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요, $adminName님!', // 실제 관리자 이름 동적 표시
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '시스템 운영 현황을 확인하고 관리해주세요.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 주요 알림/공지 카드 (예시)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withAlpha(
                        13,
                      ), // Colors.blueAccent.withOpacity(0.05) 대체
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '새로운 회원가입 승인 요청 3건이 있습니다!', // TODO: 실제 알림 내용으로 변경
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32), // 섹션 간 간격
            // 게시글 관리 섹션
            Text(
              "게시글 관리",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.post_add_outlined, // 게시글 신청 관리 아이콘
                  label: "게시글 신청 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminPostCheck(),
                      ),
                    );
                  },
                  color: Colors.blueAccent.withAlpha(
                    26,
                  ), // Colors.blueAccent.withOpacity(0.1) 대체
                  iconColor: Colors.blueAccent,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.article_outlined, // 게시글 현황 관리 아이콘
                  label: "게시글 현황 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminApprovedPostsScreen(),
                      ),
                    );
                  },
                  color: Colors.blueAccent.withAlpha(26),
                  iconColor: Colors.blueAccent,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 계정 관리 섹션
            Text(
              "계정 관리",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.person_outline, // 사용자 관리 아이콘
                  label: "사용자 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminUserCheck(),
                      ),
                    );
                  },
                  color: Colors.blueAccent.withAlpha(26),
                  iconColor: Colors.blueAccent,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.local_hospital_outlined, // 병원 관리 아이콘
                  label: "병원 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminHospitalCheck(),
                      ),
                    );
                  },
                  color: Colors.blueAccent.withAlpha(26),
                  iconColor: Colors.blueAccent,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.how_to_reg_outlined, // 회원 가입 관리 아이콘
                  label: "회원 가입 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSignupManagement(),
                      ),
                    );
                  },
                  color: Colors.blueAccent.withAlpha(26),
                  iconColor: Colors.blueAccent,
                ),
              ],
            ),
            const SizedBox(height: 20), // 하단 여백
          ],
        ),
      ),
    );
  }

  // 재사용 가능한 기능 카드 위젯 (사용자/병원 대시보드와 동일)
  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
