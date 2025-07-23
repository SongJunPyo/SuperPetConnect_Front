import 'package:flutter/material.dart';

// 기존 모델들은 그대로 사용합니다.
// 게시물 데이터 모델
class Post {
  final String id;
  final String title;
  final String dateTime;
  final String location;
  final String hospital;
  final String registrationDate;
  final String manager;
  final bool isUrgent;
  final String status; // 대기, 거절, 모집 중, 모집 마감

  const Post({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.hospital,
    required this.registrationDate,
    required this.manager,
    required this.isUrgent,
    required this.status,
  });
}

// 신청자 데이터 모델
class Applicant {
  final String id;
  final String name;
  final String contact;
  final String dogInfo;
  final String lastDonationDate;
  final String status; // 승인, 대기, 거절, 취소
  final int approvalCount;

  const Applicant({
    required this.id,
    required this.name,
    required this.contact,
    required this.dogInfo,
    required this.lastDonationDate,
    required this.status,
    required this.approvalCount,
  });
}

class HospitalPostCheck extends StatefulWidget {
  const HospitalPostCheck({super.key});

  @override
  _HospitalPostCheckState createState() => _HospitalPostCheckState();
}

class _HospitalPostCheckState extends State<HospitalPostCheck> {
  // 샘플 게시물 데이터
  final List<Post> posts = const [
    Post(
      id: '1',
      title: '[긴급] 울산 A형 헌혈견 모집',
      dateTime: '2025-03-10 10:00',
      location: '울산',
      hospital: 'S동물메디컬센터',
      registrationDate: '2025-03-10',
      manager: '차은우',
      isUrgent: true,
      status: '모집중',
    ),
    Post(
      id: '2',
      title: '[정기] 울산 헌혈견, 헌혈묘 모집',
      dateTime: '2025-03-17, 14:30',
      location: '울산',
      hospital: 'S동물메디컬센터',
      registrationDate: '2025-02-27',
      manager: '장원영',
      isUrgent: false,
      status: '거절',
    ),
    Post(
      id: '3',
      title: '[긴급] 울산 A형, B형 헌혈견 모집',
      dateTime: '2025-03-21 09:00',
      location: '울산',
      hospital: 'S동물메디컬센터',
      registrationDate: '2025-03-20',
      manager: '차은우',
      isUrgent: true,
      status: '대기',
    ),
    Post(
      id: '4',
      title: '[정기] 울산 헌혈견, 헌혈묘 모집',
      dateTime: '2025-03-24, 14:30',
      location: '울산',
      hospital: 'S동물메디컬센터',
      registrationDate: '2025-02-27',
      manager: '장원영',
      isUrgent: false,
      status: '모집마감',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름
        title: Text(
          "나의 모집글 현황", // 제목을 더 직관적으로 변경
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 토스처럼 왼쪽 정렬 유지
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 16.0,
        ), // 좌우 여백 20, 상하 여백 16
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12.0), // 카드 간격
            elevation: 2, // 카드 그림자
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // 둥근 모서리
            ),
            child: InkWell(
              // 터치 피드백을 위해 InkWell 사용
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post),
                  ),
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
                        Expanded(
                          child: Text(
                            post.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2, // 두 줄까지 표시
                            overflow: TextOverflow.ellipsis, // 넘치면 ...
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 상태 태그
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              post.status,
                            ).withOpacity(0.15), // 배경색 투명도 조절
                            borderRadius: BorderRadius.circular(8.0), // 둥근 모서리
                          ),
                          child: Text(
                            post.status,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(post.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 긴급 여부 태그
                    if (post.isUrgent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100, // 빨간색 계열의 연한 배경
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            '긴급',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      '날짜: ${post.dateTime}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '장소: ${post.location}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '등록일: ${post.registrationDate}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '담당: ${post.manager}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 상태에 따른 색상 반환 함수는 그대로 유지
  Color _getStatusColor(String status) {
    switch (status) {
      case '모집중':
        return Colors.blue;
      case '모집마감':
        return Colors.grey;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post}); // const 생성자 추가

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // 샘플 신청자 데이터
  final List<Applicant> applicants = const [
    Applicant(
      id: '1',
      name: '유재석',
      contact: '010-1234-5678',
      dogInfo: '반려견: 초롱 (A형)', // 혈액형 정보 추가 예시
      lastDonationDate: '2024-12-31',
      status: '승인',
      approvalCount: 2,
    ),
    Applicant(
      id: '2',
      name: '안유진',
      contact: '010-1234-5555',
      dogInfo: '반려견: 아라 (B형)',
      lastDonationDate: '2024-06-10',
      status: '대기',
      approvalCount: 5,
    ),
    Applicant(
      id: '3',
      name: '송중기',
      contact: '010-1111-2222',
      dogInfo: '반려견: 초코 (AB형)',
      lastDonationDate: '2024-01-10',
      status: '거절',
      approvalCount: 10,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "모집글 상세", // 제목 변경
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 왼쪽 정렬
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게시물 정보 섹션 (Card 위젯으로 변경)
          Card(
            margin: const EdgeInsets.all(20.0), // 여백
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0), // 내부 패딩
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.post.title,
                          style: textTheme.headlineSmall?.copyWith(
                            // 더 큰 제목 스타일
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 상태 태그
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            widget.post.status,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.0), // 더 둥글게
                        ),
                        child: Text(
                          widget.post.status,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(widget.post.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 긴급 여부 태그
                  if (widget.post.isUrgent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          '긴급',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                  _buildDetailRow(
                    context,
                    Icons.calendar_today_outlined,
                    '날짜',
                    widget.post.dateTime,
                  ),
                  _buildDetailRow(
                    context,
                    Icons.location_on_outlined,
                    '장소',
                    widget.post.location,
                  ),
                  _buildDetailRow(
                    context,
                    Icons.local_hospital_outlined,
                    '병원',
                    widget.post.hospital,
                  ),
                  _buildDetailRow(
                    context,
                    Icons.event_note_outlined,
                    '등록일',
                    widget.post.registrationDate,
                  ),
                  _buildDetailRow(
                    context,
                    Icons.person_outline,
                    '담당',
                    widget.post.manager,
                  ),
                ],
              ),
            ),
          ),

          // 신청자 목록 제목
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
            child: Text(
              '신청자 목록',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // 신청자 목록 (Expanded 대신 Flexible 사용)
          Expanded(
            // Expanded 사용으로 남은 공간 채우기
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 0,
              ), // 상하 패딩 제거 또는 조절
              itemCount: applicants.length,
              itemBuilder: (context, index) {
                final applicant = applicants[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  elevation: 1, // 더 가벼운 그림자
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ), // 테두리 추가
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // 신청자 상세 정보 또는 승인/거절 로직 추가
                      _showApplicantActionDialog(context, applicant);
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
                                '신청 #${applicant.id}',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              // 신청자 상태 태그
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: _getApplicantStatusColor(
                                    applicant.status,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  applicant.status,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getApplicantStatusColor(
                                      applicant.status,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            context,
                            Icons.account_circle_outlined,
                            '이름',
                            applicant.name,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.call_outlined,
                            '연락처',
                            applicant.contact,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.pets_outlined,
                            '반려견',
                            applicant.dogInfo,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.history,
                            '직전 헌혈',
                            '${applicant.lastDonationDate} / 횟수: ${applicant.approvalCount}회',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 게시물 상태에 따른 색상 반환 함수 (재사용)
  Color _getStatusColor(String status) {
    switch (status) {
      case '모집중':
        return Colors.blue;
      case '모집마감':
        return Colors.grey;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  // 신청자 상태에 따른 색상 반환 함수 (재사용)
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

  // 상세 정보 Row를 깔끔하게 보여주는 헬퍼 위젯
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 신청자 승인/거절 다이얼로그 예시
  void _showApplicantActionDialog(BuildContext context, Applicant applicant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${applicant.name} (${applicant.dogInfo})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('연락처: ${applicant.contact}'),
              Text('직전 헌혈: ${applicant.lastDonationDate}'),
              Text('총 승인 횟수: ${applicant.approvalCount}회'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 신청 거절 로직 (DB 업데이트 등)
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${applicant.name}님의 신청을 거절했습니다.')),
                );
              },
              child: const Text('거절', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                // 신청 승인 로직 (DB 업데이트 등)
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${applicant.name}님의 신청을 승인했습니다.')),
                );
              },
              child: const Text('승인', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}
