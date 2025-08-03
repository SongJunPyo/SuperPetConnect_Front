import 'package:flutter/material.dart';
import 'package:connect/hospital/hospital_profile.dart';
import 'package:connect/hospital/hospital_post.dart';
import 'package:connect/hospital/hospital_alarm.dart';
import 'package:connect/hospital/hospital_post_check.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  // TODO: 실제 병원 이름은 서버/로컬에서 가져오도록 변경
  String hospitalName = "S동물메디컬센터";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDashboardAppBar(
        onBackPressed: () => Navigator.pop(context),
        onProfilePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HospitalProfile(),
            ),
          );
        },
        onNotificationPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HospitalAlarm()),
          );
        },
      ),
      body: SingleChildScrollView(
        // 전체 화면을 스크롤 가능하게
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppTheme.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요, $hospitalName 입니다!',
                    style: AppTheme.h2Style,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    '소중한 반려동물 생명 살리기에 함께해주세요.',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing20),
                  AppInfoCard(
                    icon: Icons.info_outline,
                    title: '새로운 헌혈 신청 2건이 도착했습니다!',
                    description: '신청 현황 보기',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HospitalPostCheck(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppTheme.pageHorizontalPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "주요 기능",
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
                        icon: Icons.edit_note_outlined,
                        title: "헌혈 게시판 작성",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPost(),
                            ),
                          );
                        },
                      ),
                      AppFeatureCard(
                        icon: Icons.check_circle_outline,
                        title: "헌혈 신청 현황",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPostCheck(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: AppTheme.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "최근 헌혈 신청 현황",
                        style: AppTheme.h3Style,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPostCheck(),
                            ),
                          );
                        },
                        child: Text(
                          '더보기',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildRecentApplicantList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // 최근 헌혈 신청 현황 목록을 구성하는 위젯
  Widget _buildRecentApplicantList() {
    // 임시 신청자 데이터 (최신순으로 정렬된 것으로 가정)
    final List<Map<String, String>> recentApplicants = [
      {
        'name': '김민준',
        'pet': '초롱 (강아지)',
        'appliedDate': '2025-07-18',
        'status': '대기',
      },
      {
        'name': '이지아',
        'pet': '나비 (고양이)',
        'appliedDate': '2025-07-17',
        'status': '승인',
      },
      {
        'name': '박서준',
        'pet': '메리 (강아지)',
        'appliedDate': '2025-07-16',
        'status': '거절',
      },
      {
        'name': '최유리',
        'pet': '레오 (고양이)',
        'appliedDate': '2025-07-15',
        'status': '승인',
      },
      // 데이터가 더 많아질 경우 스크롤이 자동으로 적용됩니다.
    ];

    if (recentApplicants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                '아직 새로운 헌혈 신청이 없습니다.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true, // Column 내에서 ListView 사용 시 필수
      physics:
          const NeverScrollableScrollPhysics(), // 부모 SingleChildScrollView와 충돌 방지
      itemCount:
          recentApplicants.length > 5
              ? 5
              : recentApplicants.length, // 최대 5개 항목만 표시 (미리보기)
      itemBuilder: (context, index) {
        final applicant = recentApplicants[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 1, // 더 가벼운 그림자
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200, width: 1), // 테두리 추가
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // TODO: 신청자 상세 정보 페이지로 이동 (승인/거절 등 액션 가능)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${applicant['name']}님의 신청 상세 보기')),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${applicant['name']} 님',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: _getApplicantStatusColor(
                            applicant['status']!,
                          ).withAlpha((255 * 0.1).round()),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          applicant['status']!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getApplicantStatusColor(
                              applicant['status']!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '반려동물: ${applicant['pet']!}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '신청일: ${applicant['appliedDate']!}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getApplicantStatusColor(String status) {
    switch (status) {
      case '승인':
        return AppTheme.success;
      case '대기':
        return AppTheme.warning;
      case '거절':
        return AppTheme.error;
      case '취소':
        return AppTheme.mediumGray;
      default:
        return AppTheme.textPrimary;
    }
  }
}
