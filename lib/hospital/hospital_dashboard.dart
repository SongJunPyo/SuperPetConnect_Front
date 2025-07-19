import 'package:flutter/material.dart';
import 'package:connect/hospital/hospital_profile.dart'; // 병원 프로필 페이지로 이동
import 'package:connect/hospital/hospital_post.dart'; // 게시글 작성 페이지로 이동
import 'package:connect/hospital/hospital_alarm.dart'; // 알림 페이지로 이동
import 'package:connect/hospital/hospital_post_check.dart'; // 게시글 상태 확인 페이지로 이동

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
        title: const SizedBox.shrink(), // 제목 없음 (사용자 대시보드와 통일)
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
                MaterialPageRoute(builder: (context) => const HospitalAlarm()),
              );
            },
          ),
          // 병원 프로필 아이콘 버튼 (사용자 메인 화면과 동일한 디자인으로 변경)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor:
                    Colors.blueAccent, // 사용자 메인화면과 동일하게 Colors.blueAccent
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ), // 사용자 아이콘과 동일하게 Icons.person
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HospitalProfile(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        // 전체 화면을 스크롤 가능하게
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 환영 메시지 섹션 (사용자 대시보드와 유사)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요, $hospitalName 입니다!', // 실제 병원 이름 동적 표시
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '소중한 반려동물 생명 살리기에 함께해주세요.',
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
                        (255 * 0.1).round(),
                      ), // Colors.blueAccent 사용
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withAlpha(
                          (255 * 0.1).round(),
                        ), // Colors.blueAccent 사용
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent,
                        ), // Colors.blueAccent 사용
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '새로운 헌혈 신청 2건이 도착했습니다!', // TODO: 실제 알림 내용으로 변경
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.blueAccent, // Colors.blueAccent 사용
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.blueAccent, // Colors.blueAccent 사용
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ---
            // 기능 버튼 그리드 (기존 버튼 복원 및 색상 통일)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "주요 기능",
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true, // GridView가 Column 내에서 공간을 차지하도록
                    physics:
                        const NeverScrollableScrollPhysics(), // GridView 자체 스크롤 방지
                    crossAxisCount: 2, // 한 줄에 2개의 버튼
                    crossAxisSpacing: 16, // 가로 간격
                    mainAxisSpacing: 16, // 세로 간격
                    childAspectRatio: 1.5, // 버튼의 가로/세로 비율 (조정 가능)
                    children: [
                      _buildFeatureCard(
                        context,
                        icon: Icons.edit_note_outlined, // 게시글 작성 아이콘
                        label: "헌혈 게시판 작성",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPost(),
                            ),
                          );
                        },
                        color: Colors.blueAccent.withAlpha((255 * 0.1).round()),
                        iconColor: Colors.blueAccent,
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.check_circle_outline, // 상태 확인 아이콘
                        label: "헌혈 신청 현황",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPostCheck(),
                            ),
                          );
                        },
                        color: Colors.blueAccent.withAlpha((255 * 0.1).round()),
                        iconColor: Colors.blueAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 헌혈 신청 현황 섹션 (새로 분리된 구역)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "최근 헌혈 신청 현황", // 섹션 제목
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: 헌혈 신청 현황 전체 보기 페이지로 이동
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('헌혈 신청 현황 전체 보기 페이지로 이동 (준비 중)'),
                            ),
                          );
                        },
                        child: Text(
                          '더보기',
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ), // Colors.blueAccent 사용
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRecentApplicantList(), // 신청자 목록 위젯 호출
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 재사용 가능한 기능 카드 위젯 (색상 테마 적용)
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
        elevation: 2, // 카드 그림자
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color, // 배경색
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40, // 아이콘 크기
              color: iconColor,
            ),
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

  // 신청자 상태에 따른 색상 반환 (재활용)
  Color _getApplicantStatusColor(String status) {
    switch (status) {
      case '승인':
        return Colors.green;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      case '취소':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }
}
