import 'package:flutter/material.dart';
import 'package:connect/auth/login.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent,
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '생명을 살리는 소중한 헌혈에',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '동참해주세요.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '반려동물의 건강을 함께 지켜나가요!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 커스텀 탭 바 구현
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey[200], // 탭 바 전체 배경색
              borderRadius: BorderRadius.circular(10), // 둥근 모서리
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
                      duration: const Duration(
                        milliseconds: 300,
                      ), // 애니메이션 지속 시간
                      curve: Curves.easeInOut, // 애니메이션 곡선
                      left: _tabController.index * _tabWidth, // 현재 선택된 탭의 위치 계산
                      top: 0,
                      bottom: 0,
                      width: _tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent, // 인디케이터 색상
                          borderRadius: BorderRadius.circular(
                            10,
                          ), // 항상 둥근 모서리 유지
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
                                vertical: 12.0,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '헌혈 모집 게시판',
                                style: TextStyle(
                                  // 선택 여부에 따른 글자색 변경
                                  color:
                                      _tabController.index == 0
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight: FontWeight.bold,
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
                                vertical: 12.0,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '칼럼 게시판',
                                style: TextStyle(
                                  // 선택 여부에 따른 글자색 변경
                                  color:
                                      _tabController.index == 1
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.all(16.0),
      itemCount: donationPosts.length,
      itemBuilder: (context, index) {
        final post = donationPosts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2, // 카드 그림자
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // 둥근 모서리
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      post['hospital']!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      post['date']!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.all(16.0),
      itemCount: columnPosts.length,
      itemBuilder: (context, index) {
        final post = columnPosts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      post['author']!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      post['date']!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
