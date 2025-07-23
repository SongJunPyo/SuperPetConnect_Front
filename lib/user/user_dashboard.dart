import 'package:flutter/material.dart';
import 'pet_management.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _tabWidth = 0.0; // 탭 하나의 너비를 저장할 변수

  // 지역 필터링을 위한 선택된 값들을 저장할 Set (여러 개 선택 가능)
  Set<String> _selectedRegions = {'전체'}; // 초기 선택값 '전체'
  final List<String> _regions = [
    '전체',
    '서울특별시',
    '부산광역시',
    '대구광역시',
    '인천광역시',
    '광주광역시',
    '대전광역시',
    '울산광역시',
    '세종특별자치시',
    '경기도',
    '강원특별자치도',
    '충청북도',
    '충청남도',
    '전라북도',
    '전라남도',
    '경상북도',
    '경상남도',
    '제주특별자치도',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2개의 탭 (헌혈 모집, 칼럼)
    _tabController.addListener(() {
      setState(() {}); // 탭이 변경될 때 UI를 다시 그리도록 강제
    });
  }

  @override
  void dispose() {
    _tabController.dispose(); // TabController 리소스 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기 (로그인 페이지)
          },
        ),
        title: const SizedBox.shrink(), // 제목 없음
        actions: [
          // 마이페이지 (내 정보) 버튼
          IconButton(
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey, // 임시 프로필 색상
              child: Icon(
                Icons.person_outline,
                color: Colors.black87,
                size: 20,
              ),
            ),
            onPressed: () {
              // TODO: 마이페이지로 이동하는 로직 추가
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('마이페이지로 이동 (준비 중)')));
            },
          ),
          // 알림 버튼
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black87,
            ),
            onPressed: () {
              // TODO: 알림 페이지로 이동하는 로직 추가
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림 페이지로 이동 (준비 중)')),
              );
            },
          ),
          // 펫 페이지 이미지 버튼
          IconButton(
            icon: const Icon(Icons.pets, color: Colors.black87), // 펫 아이콘
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PetManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8), // 아이콘과 AppBar 끝 사이 간격
        ],
      ),
      body: _buildDashboardContent(), // 항상 대시보드 메인 내용 표시
    );
  }

  // 사용자 대시보드의 메인 내용을 구성하는 위젯
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 환영 메시지 및 프로필 요약 섹션
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '안녕하세요, 사용자님!', // TODO: 실제 사용자 이름으로 변경
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '오늘도 소중한 생명을 살리는 일에 동참해주세요.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                // 주요 알림/공지 (예시)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '새로운 헌혈 요청 5건이 도착했습니다!',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
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
          // 탭 바 (헌혈 모집 게시판, 칼럼 게시판)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey[200], // 탭 바 전체 배경색
              borderRadius: BorderRadius.circular(10), // 둥근 모서리
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
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
                            behavior: HitTestBehavior.opaque, // 전체 영역 클릭 가능하게 함
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '헌혈 모집 게시판',
                                style: TextStyle(
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
                            behavior: HitTestBehavior.opaque, // 전체 영역 클릭 가능하게 함
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '칼럼 게시판',
                                style: TextStyle(
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
          SizedBox(
            height:
                MediaQuery.of(context).size.height *
                0.6, // 화면 높이의 60% 정도를 할당 (조정 가능)
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBloodDonationBoard(), // 헌혈 모집 게시판 내용
                _buildColumnBoard(), // 칼럼 게시판 내용
              ],
            ),
          ),
          // TODO: 내 헌혈 활동 섹션 (나중에 추가)
          // TODO: 마이페이지/설정 섹션 (나중에 추가)
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
        'region': '서울특별시',
      },
      {
        'title': 'B형 고양이 헌혈자 모집합니다',
        'hospital': '우리동네동물병원',
        'date': '2025-07-14',
        'region': '경기도',
      },
      {
        'title': 'AB형 강아지 헌혈 긴급 요청',
        'hospital': '사랑동물병원',
        'date': '2025-07-13',
        'region': '부산광역시',
      },
      {
        'title': 'O형 고양이 헌혈 희망자 찾아요',
        'hospital': '새싹동물병원',
        'date': '2025-07-12',
        'region': '서울특별시',
      },
      {
        'title': '모든 혈액형 강아지 헌혈 대기',
        'hospital': '든든동물병원',
        'date': '2025-07-11',
        'region': '경상남도',
      },
      {
        'title': '긴급! Rh- 고양이 헌혈자',
        'hospital': '굿닥터 동물병원',
        'date': '2025-07-10',
        'region': '대전광역시',
      },
      {
        'title': 'A형 강아지 혈액 구해요',
        'hospital': '미래동물병원',
        'date': '2025-07-09',
        'region': '경기도',
      },
      {
        'title': 'B형 고양이 긴급 수혈',
        'hospital': '건강한동물병원',
        'date': '2025-07-08',
        'region': '인천광역시',
      },
    ];

    // 선택된 지역에 따라 게시글 필터링
    final filteredPosts =
        _selectedRegions.contains('전체')
            ? donationPosts
            : donationPosts
                .where((post) => _selectedRegions.contains(post['region']))
                .toList();

    return Column(
      children: [
        // 지역 선택 버튼 목록 (슬라이딩 가능)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // 가로 스크롤 가능
            child: Row(
              children:
                  _regions.map((region) {
                    final isSelected = _selectedRegions.contains(region);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(region),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (region == '전체') {
                              // '전체' 선택 시 다른 모든 선택 해제
                              _selectedRegions.clear();
                              _selectedRegions.add('전체');
                            } else {
                              // '전체'가 선택된 상태에서 다른 지역 선택 시 '전체' 해제
                              if (_selectedRegions.contains('전체')) {
                                _selectedRegions.remove('전체');
                              }
                              if (selected) {
                                _selectedRegions.add(region);
                              } else {
                                _selectedRegions.remove(region);
                              }
                              // 모든 선택이 해제되면 '전체'를 다시 선택
                              if (_selectedRegions.isEmpty) {
                                _selectedRegions.add('전체');
                              }
                            }
                          });
                        },
                        selectedColor: Colors.blueAccent, // 선택 시 색상
                        labelStyle: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : Colors.black87, // 선택 시 글자색
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Colors.grey[100], // 기본 배경색
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20), // 둥근 모서리
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Colors.blueAccent
                                    : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        elevation: 1, // 약간의 그림자
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
        // 필터링된 게시글 목록
        Expanded(
          child:
              filteredPosts.isEmpty
                  ? Center(
                    child: Text(
                      '선택된 지역에 헌혈 모집 게시글이 없습니다.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = filteredPosts[index];
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${post['hospital']!} (${post['region']!})', // 병원명 옆에 지역 표시
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    post['date']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
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
      {
        'title': '헌혈, 반려동물에게도 안전한가요?',
        'author': '수의사 이지은',
        'date': '2025-07-05',
      },
      {
        'title': '반려동물 헌혈, 오해와 진실',
        'author': '펫 칼럼니스트 박선우',
        'date': '2025-07-04',
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
