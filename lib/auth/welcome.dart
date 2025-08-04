import 'package:flutter/material.dart';
import 'package:connect/auth/login.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // 탭 하나의 너비를 저장할 변수
  double _tabWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 탭 변경 리스너를 추가하여 탭이 변경될 때 UI를 다시 그리도록 합니다.
    _tabController.addListener(() {
      setState(() {});
    });
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
      body: Column(
        children: [
          Padding(
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
          // 커스텀 탭 바 구현
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            // LayoutBuilder를 사용하여 부모 위젯의 너비를 얻습니다.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // 탭 바의 총 너비에서 각 탭의 너비를 계산합니다.
                _tabWidth = constraints.maxWidth / _tabController.length;

                return Stack(
                  children: [
                    // 슬라이딩하는 파란색 인디케이터
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: _tabController.index * _tabWidth,
                      top: 0,
                      bottom: 0,
                      width: _tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                        ),
                      ),
                    ),
                    // 탭 라벨들 (GestureDetector로 클릭 가능하게)
                    Row(
                      children: [
                        // 헌혈 모집 게시판 탭
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(0); // 첫 번째 탭으로 이동
                            },
                            behavior:
                                HitTestBehavior
                                    .opaque, // 이 부분을 추가하여 전체 영역 클릭 가능하게 함
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacing12,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '헌혈 모집 게시판',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color:
                                      _tabController.index == 0
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 칼럼 게시판 탭
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(1); // 두 번째 탭으로 이동
                            },
                            behavior:
                                HitTestBehavior
                                    .opaque, // 이 부분을 추가하여 전체 영역 클릭 가능하게 함
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacing12,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '칼럼 게시판',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color:
                                      _tabController.index == 1
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // 탭 뷰 (실제 게시판 내용)
          Expanded(
            child: TabBarView(
              controller: _tabController, // 커스텀 탭 바와 TabBarView를 연결
              children: [
                // 헌혈 모집 게시판 내용
                _buildBloodDonationBoard(),
                // 칼럼 게시판 내용
                _buildColumnBoard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 헌혈 모집 게시판 위젯을 생성합니다.
  Widget _buildBloodDonationBoard() {
    // 임시 데이터 (나중에 DB에서 가져올 내용)
    final List<Map<String, String>> donationPosts = [
      {
        'title': '급구! A형 강아지 헌혈자 찾습니다',
        'hospital': '행복동물병원',
        'date': '2025-07-15',
      },
      {
        'title': 'B형 고양이 헌혈자 모집합니다',
        'hospital': '우리동네동물병원',
        'date': '2025-07-14',
      },
      {'title': 'AB형 강아지 헌혈 긴급 요청', 'hospital': '사랑동물병원', 'date': '2025-07-13'},
      {
        'title': 'O형 고양이 헌혈 희망자 찾아요',
        'hospital': '새싹동물병원',
        'date': '2025-07-12',
      },
      {'title': '모든 혈액형 강아지 헌혈 대기', 'hospital': '든든동물병원', 'date': '2025-07-11'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: donationPosts.length,
      itemBuilder: (context, index) {
        final post = donationPosts[index];
        return AppPostCard(
          title: post['title']!,
          subtitle: post['hospital']!,
          date: post['date']!,
        );
      },
    );
  }

  // 칼럼 게시판 위젯을 생성합니다.
  Widget _buildColumnBoard() {
    // 임시 데이터 (나중에 DB에서 가져올 내용)
    final List<Map<String, String>> columnPosts = [
      {'title': '반려동물 헌혈, 왜 중요할까요?', 'author': '수의사 김철수', 'date': '2025-07-10'},
      {
        'title': '우리 아이에게 헌혈이 필요한 순간',
        'author': '펫 칼럼니스트 이영희',
        'date': '2025-07-09',
      },
      {
        'title': '헌혈 전, 우리 반려동물 건강 체크리스트',
        'author': '수의학 박사 박민준',
        'date': '2025-07-08',
      },
      {'title': '헌혈 후 반려동물 관리 가이드', 'author': '수의사 최유리', 'date': '2025-07-07'},
      {
        'title': '헌혈을 통해 생명을 구한 감동 스토리',
        'author': '펫 스토리텔러 정수빈',
        'date': '2025-07-06',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: columnPosts.length,
      itemBuilder: (context, index) {
        final post = columnPosts[index];
        return AppPostCard(
          title: post['title']!,
          subtitle: post['author']!,
          date: post['date']!,
        );
      },
    );
  }
}
