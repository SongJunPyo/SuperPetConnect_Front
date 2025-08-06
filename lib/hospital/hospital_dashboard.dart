import 'package:flutter/material.dart';
import 'package:connect/hospital/hospital_post.dart';
import 'package:connect/hospital/hospital_alarm.dart';
import 'package:connect/hospital/hospital_post_check.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';
import '../auth/profile_management.dart';
import 'hospital_column_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  String hospitalName = "S동물메디컬센터";
  String currentDateTime = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadHospitalName();
    _updateDateTime();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    });
  }

  Future<void> _loadHospitalName() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // 먼저 로컬에 저장된 이름 확인
    final savedName = prefs.getString('hospital_name');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        hospitalName = savedName;
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
          final userName = data['name'] ?? 'S동물메디컬센터';

          setState(() {
            hospitalName = userName;
          });

          // 로컬 저장소에도 업데이트
          await prefs.setString('hospital_name', userName);
        }
      } catch (e) {
        // 오류 발생 시 기본값 유지
        print('병원 이름 로드 실패: $e');
      }
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
                  Text('안녕하세요, $hospitalName 님!', style: AppTheme.h2Style),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    currentDateTime,
                    style: AppTheme.bodyLargeStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing20),
                  SizedBox(
                    width: double.infinity,
                    child: AppInfoCard(
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
                  ),
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
                        icon: Icons.edit_note_outlined,
                        title: "헌혈 게시판 작성",
                        subtitle: "새로운 헌혈 요청 게시글 작성",
                        iconColor: AppTheme.primaryBlue,
                        backgroundColor: AppTheme.lightBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPost(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      _buildPremiumFeatureCard(
                        icon: Icons.check_circle_outline,
                        title: "헌혈 신청 현황",
                        subtitle: "헌혈 신청자 관리 및 승인 처리",
                        iconColor: AppTheme.success,
                        backgroundColor: AppTheme.success.withOpacity(0.1),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalPostCheck(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      _buildPremiumFeatureCard(
                        icon: Icons.article_outlined,
                        title: "칼럼 게시글 작성",
                        subtitle: "반려동물 헌혈 관련 정보 공유",
                        iconColor: AppTheme.warning,
                        backgroundColor: AppTheme.warning.withOpacity(0.1),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HospitalColumnList(),
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
                      Text("최근 헌혈 신청 현황", style: AppTheme.h3Style),
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

            // 최근 칼럼 섹션 추가
            Padding(
              padding: AppTheme.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("최근 칼럼", style: AppTheme.h3Style),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('칼럼 더보기 (미구현)')),
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
                  _buildRecentColumnList(),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentApplicants.length > 5 ? 5 : recentApplicants.length,
      itemBuilder: (context, index) {
        final applicant = recentApplicants[index];
        return AppPostCard(
          title: '${applicant['name']} 님의 헌혈 신청',
          subtitle: '반려동물: ${applicant['pet']!}',
          date: applicant['appliedDate']!,
          status: applicant['status']!,
          statusColor: _getApplicantStatusColor(applicant['status']!),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${applicant['name']}님의 신청 상세 보기')),
            );
          },
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
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1.5),
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

  // 최근 칼럼 목록을 구성하는 위젯
  Widget _buildRecentColumnList() {
    // 가데이터 칼럼 목록
    final List<Map<String, dynamic>> recentColumns = [
      {
        'title': '칼럼 테스트 1',
        'content': '테스트 내용입니다. 반려동물 헌혈의 중요성에 대한 내용이 들어갈 예정입니다.',
        'author': '김수의사',
        'date': '2025-08-01',
        'views': 156,
      },
      {
        'title': '칼럼 테스트 2',
        'content': '테스트 내용입니다. 헌혈 전 준비사항에 대한 안내가 들어갈 예정입니다.',
        'author': '박수의사',
        'date': '2025-07-30',
        'views': 203,
      },
      {
        'title': '칼럼 테스트 3',
        'content': '테스트 내용입니다. 헌혈 후 관리방법에 대한 정보가 들어갈 예정입니다.',
        'author': '이수의사',
        'date': '2025-07-28',
        'views': 89,
      },
    ];

    if (recentColumns.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.veryLightGray,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.article_outlined,
                size: 48,
                color: AppTheme.mediumGray,
              ),
              const SizedBox(height: 16),
              Text(
                '작성된 칼럼이 없습니다.',
                style: AppTheme.bodyLargeStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children:
          recentColumns.map((column) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(
                  color: AppTheme.lightGray.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${column['title']} 상세보기 (미구현)')),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                column['title'],
                                style: AppTheme.h4Style.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: AppTheme.spacing4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.lightBlue,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Text(
                                '조회 ${column['views']}',
                                style: AppTheme.captionStyle.copyWith(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          column['content'],
                          style: AppTheme.bodyMediumStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Text(
                              column['author'],
                              style: AppTheme.bodySmallStyle,
                            ),
                            const SizedBox(width: AppTheme.spacing16),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Text(
                              column['date'],
                              style: AppTheme.bodySmallStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
