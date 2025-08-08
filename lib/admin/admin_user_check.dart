import 'package:flutter/material.dart';
import '../models/black_list_model.dart';
import '../services/black_list_service.dart';

// 사용자 데이터 모델은 그대로 유지합니다.
class User {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String registrationDate;
  final String petInfo;
  final int donationCount;
  String status; // 활성, 대기, 제한, 정지

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.registrationDate,
    required this.petInfo,
    required this.donationCount,
    required this.status,
  });
}

// 관리자용 사용자 관리 화면
class AdminUserCheck extends StatefulWidget {
  const AdminUserCheck({super.key}); // Key? key -> super.key로 변경

  @override
  _AdminUserCheckState createState() => _AdminUserCheckState();
}

class _AdminUserCheckState extends State<AdminUserCheck> {
  // 샘플 사용자 데이터
  final List<User> users = [
    User(
      id: '1',
      name: '유재석',
      email: 'yoo@example.com',
      phoneNumber: '010-1234-5678',
      registrationDate: '2024-06-15',
      petInfo: '초롱이(골든 리트리버), 혈액형 A',
      donationCount: 5,
      status: '활성',
    ),
    User(
      id: '2',
      name: '강호동',
      email: 'kang@example.com',
      phoneNumber: '010-2345-6789',
      registrationDate: '2024-07-10',
      petInfo: '뭉치(보더 콜리), 혈액형 B',
      donationCount: 3,
      status: '대기',
    ),
    User(
      id: '3',
      name: '안유진',
      email: 'ahn@example.com',
      phoneNumber: '010-3456-7890',
      registrationDate: '2024-08-20',
      petInfo: '아라(사모예드), 혈액형 A',
      donationCount: 7,
      status: '활성',
    ),
    User(
      id: '4',
      name: '송중기',
      email: 'song@example.com',
      phoneNumber: '010-4567-8901',
      registrationDate: '2024-09-05',
      petInfo: '초코(비숑), 혈액형 DEA 1.1 음성',
      donationCount: 0,
      status: '제한',
    ),
  ];

  // 검색 필터링 기능을 위한 변수
  String searchQuery = '';
  List<User> filteredUsers = [];

  @override
  void initState() {
    super.initState();
    filteredUsers = users;
  }

  // 검색 기능
  void filterUsers(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers =
            users
                .where(
                  (user) =>
                      user.name.toLowerCase().contains(query.toLowerCase()) ||
                      user.email.toLowerCase().contains(query.toLowerCase()) ||
                      user.phoneNumber.contains(query),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름 (배경색, 그림자 등)
        title: Text(
          "사용자 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 토스처럼 왼쪽 정렬 유지
      ),
      body: Column(
        children: [
          // 검색 필드
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ), // 여백 조정
            child: TextField(
              onChanged: filterUsers,
              decoration: InputDecoration(
                labelText: '사용자 검색 (이름, 이메일, 전화번호)',
                hintText: '검색어를 입력하세요',
                prefixIcon: const Icon(Icons.search_outlined), // 아웃라인 아이콘
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // 더 둥근 모서리
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ), // 포커스 시 테마 색상
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50, // 아주 연한 배경색
                labelStyle: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ),

          // 사용자 목록
          Expanded(
            child:
                filteredUsers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 60,
                            color: Colors.grey[300],
                          ), // 사용자 없음 아이콘
                          const SizedBox(height: 16),
                          Text(
                            '검색 결과가 없습니다.',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 0,
                      ), // 상하 여백 제거 또는 최소화
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0), // 카드 간격
                          elevation: 1, // 더 가벼운 그림자
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ), // 테두리 추가
                          ),
                          child: InkWell(
                            // 터치 피드백을 위해 InkWell 사용
                            borderRadius: BorderRadius.circular(12),
                            // 카드 탭 시 상세화면으로 이동
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          AdminUserDetailScreen(user: user),
                                ),
                              ).then((_) {
                                // 상세화면에서 돌아올 때 목록 갱신 (상태가 변경되었을 수 있으므로)
                                setState(() {
                                  // 실제 DB 연동 시에는 여기서 데이터를 다시 불러와야 함
                                  filterUsers(searchQuery); // 현재 검색 쿼리로 다시 필터링
                                });
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0), // 내부 패딩
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.name,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                          maxLines: 1, // 한 줄로 제한
                                          overflow:
                                              TextOverflow.ellipsis, // 넘치면 ...
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
                                          color: _getUserStatusColor(
                                            user.status,
                                          ).withAlpha(
                                            38,
                                          ), // withOpacity(0.15) 대체
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                        child: Text(
                                          user.status,
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _getUserStatusColor(
                                              user.status,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '이메일: ${user.email}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '연락처: ${user.phoneNumber}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '반려동물: ${user.petInfo}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
      // 새 사용자 추가 버튼
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary, // 테마의 주 색상 사용
        foregroundColor: colorScheme.onPrimary, // 테마의 주 색상에 대비되는 텍스트/아이콘 색상
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ), // 둥근 사각형 모양
        elevation: 4, // 그림자 추가
        onPressed: () {
          // 새 사용자 추가 화면으로 이동 (실제 구현 필요)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("새 사용자 추가 화면으로 이동합니다.")));
        },
        child: const Icon(
          Icons.person_add_alt_1_outlined,
          size: 28,
        ), // 아웃라인 아이콘
      ),
    );
  }

  // 사용자 상태별 색상 (그대로 유지)
  Color _getUserStatusColor(String status) {
    switch (status) {
      case '활성':
        return Colors.green;
      case '대기':
        return Colors.orange;
      case '제한':
        return Colors.blue;
      case '정지':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}

// User 모델은 AdminUserCheck 파일에 정의되어 있으므로 별도 import 필요 없음.

// 사용자 상세 화면
class AdminUserDetailScreen extends StatefulWidget {
  final User user;

  const AdminUserDetailScreen({
    super.key,
    required this.user,
  }); // Key? key -> super.key로 변경

  @override
  _AdminUserDetailScreenState createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late String userStatus;
  UserBlackListStatus? blackListStatus;
  bool isLoadingBlackListStatus = false;

  @override
  void initState() {
    super.initState();
    userStatus = widget.user.status;
    _loadBlackListStatus();
  }
  
  // 블랙리스트 상태 조회
  Future<void> _loadBlackListStatus() async {
    setState(() {
      isLoadingBlackListStatus = true;
    });
    
    try {
      // 예시로 User id를 account_idx로 사용
      final accountIdx = int.tryParse(widget.user.id) ?? 1;
      final status = await BlackListService.getUserBlackListStatus(accountIdx);
      
      setState(() {
        blackListStatus = status;
        isLoadingBlackListStatus = false;
      });
    } catch (e) {
      setState(() {
        blackListStatus = null;
        isLoadingBlackListStatus = false;
      });
      print('블랙리스트 상태 조회 실패: $e');
    }
  }

  // 사용자 상태별 색상 (AdminUserCheck에서 재활용)
  Color _getUserStatusColor(String status) {
    switch (status) {
      case '활성':
        return Colors.green;
      case '대기':
        return Colors.orange;
      case '제한':
        return Colors.blue;
      case '정지':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  // 사용자 상태 변경 함수
  void _changeUserStatus(String newStatus, String reason) {
    setState(() {
      userStatus = newStatus;
      widget.user.status = newStatus; // 부모 위젯의 데이터도 업데이트
    });

    // 알림 표시
    Navigator.pop(context); // 상태 변경 후 이전 화면으로 돌아가기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "사용자 '${widget.user.name}'의 상태가 '$newStatus'(으)로 변경되었습니다. 사유: $reason",
        ),
      ),
    );
  }

  // 블랙리스트 등록 다이얼로그
  void _showBlackListRegistrationDialog() {
    final TextEditingController contentController = TextEditingController();
    final TextEditingController dDayController = TextEditingController(text: '7');
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('블랙리스트 등록', style: textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '대상 사용자: ${widget.user.name}',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text('정지 사유를 입력해주세요.', style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    hintText: '블랙리스트 등록 사유',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 16),
                Text('정지 일수를 지정해주세요.', style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: dDayController,
                  decoration: InputDecoration(
                    hintText: '정지 일수',
                    suffix: const Text('일'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('정지 사유를 입력해주세요.')),
                  );
                  return;
                }
                
                final dDay = int.tryParse(dDayController.text);
                if (dDay == null || dDay < 1) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('올바른 정지 일수를 입력해주세요. (1일 이상)')),
                  );
                  return;
                }
                
                if (dDay > 365) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('정지 일수는 365일 이하로 입력해주세요.')),
                  );
                  return;
                }

                // 블랙리스트 등록 요청
                try {
                  // 예시로 account_idx를 User id로 사용 (실제로는 서버에서 받아와야 함)
                  final accountIdx = int.tryParse(widget.user.id) ?? 1;
                  
                  final request = BlackListCreateRequest(
                    accountIdx: accountIdx,
                    content: contentController.text.trim(),
                    dDay: dDay,
                  );

                  await BlackListService.createBlackList(request);

                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.user.name}님이 블랙리스트에 등록되었습니다.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // 사용자 상태를 '정지'로 업데이트
                  setState(() {
                    userStatus = '정지';
                    widget.user.status = '정지';
                  });
                  
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('블랙리스트 등록 실패: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('등록'),
            ),
          ],
        );
      },
    );
  }

  // 상태 변경 다이얼로그 표시
  void _showStatusChangeDialog(String newStatus) {
    final TextEditingController reasonController = TextEditingController();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // BuildContext 이름을 dialogContext로 변경하여 충돌 방지
        return AlertDialog(
          title: Text('$newStatus 상태로 변경', style: textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('상태 변경 사유를 입력해주세요.', style: textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: '사유 입력',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    // dialogContext 사용
                    const SnackBar(content: Text("사유를 입력해주세요.")),
                  );
                } else {
                  Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                  _changeUserStatus(
                    newStatus,
                    reasonController.text.trim(),
                  ); // 상태 변경 함수 호출
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getUserStatusColor(newStatus), // 새 상태의 색상 사용
                foregroundColor: Colors.white, // 흰색 텍스트
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 상세 정보 Row를 깔끔하게 보여주는 헬퍼 위젯 (다른 관리자 화면에서 재활용)
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

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름
        title: Text(
          "사용자 상세정보",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 왼쪽 정렬
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 정보 상단 카드
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.user.name,
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
                            color: _getUserStatusColor(
                              userStatus,
                            ).withAlpha(38), // withOpacity(0.15) 대체
                            borderRadius: BorderRadius.circular(12.0), // 더 둥글게
                          ),
                          child: Text(
                            userStatus,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getUserStatusColor(userStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      context,
                      Icons.email_outlined,
                      '이메일',
                      widget.user.email,
                    ),
                    _buildDetailRow(
                      context,
                      Icons.phone_outlined,
                      '연락처',
                      widget.user.phoneNumber,
                    ),
                    _buildDetailRow(
                      context,
                      Icons.calendar_today_outlined,
                      '가입일',
                      widget.user.registrationDate,
                    ),
                    
                    // 블랙리스트 상태 정보
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      '블랙리스트 상태',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingBlackListStatus)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('블랙리스트 상태 확인 중...'),
                        ],
                      )
                    else if (blackListStatus != null)
                      Column(
                        children: [
                          _buildDetailRow(
                            context,
                            blackListStatus!.isSuspended 
                                ? Icons.block 
                                : Icons.check_circle_outline,
                            '상태',
                            blackListStatus!.statusText,
                          ),
                          if (blackListStatus!.isSuspended) ...[
                            _buildDetailRow(
                              context,
                              Icons.timer_outlined,
                              '남은 일수',
                              blackListStatus!.remainingDaysText,
                            ),
                            if (blackListStatus!.content != null)
                              _buildDetailRow(
                                context,
                                Icons.description_outlined,
                                '정지 사유',
                                blackListStatus!.content!,
                              ),
                          ],
                        ],
                      )
                    else
                      _buildDetailRow(
                        context,
                        Icons.check_circle_outline,
                        '상태',
                        '정상 사용자',
                      ),
                  ],
                ),
              ),
            ),

            // 상태 변경 버튼들
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStatusChangeDialog('활성'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "활성화",
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStatusChangeDialog('대기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "대기",
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8), // 버튼 Row 간격
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStatusChangeDialog('제한'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "제한",
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStatusChangeDialog('정지'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error, // 테마 에러 색상
                        foregroundColor: colorScheme.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "정지",
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onError,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 블랙리스트 등록 버튼
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showBlackListRegistrationDialog(),
                  icon: const Icon(Icons.block),
                  label: const Text('블랙리스트 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 추가 정보 및 헌혈 실적 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                '반려동물 정보 및 헌혈 실적',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.all(20.0),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      context,
                      Icons.pets_outlined,
                      '반려동물 정보',
                      widget.user.petInfo,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      Icons.favorite_border_outlined,
                      '총 헌혈 횟수',
                      '${widget.user.donationCount}회',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '최근 헌혈 기록',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // TODO: 실제 헌혈 기록 데이터 연동 필요
                    _buildDetailRow(
                      context,
                      Icons.calendar_today_outlined,
                      '2025-06-01',
                      '행복동물병원 (A형)',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.calendar_today_outlined,
                      '2025-03-10',
                      '우리동물병원 (A형)',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.calendar_today_outlined,
                      '2024-11-20',
                      '사랑동물병원 (B형)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // 하단 여백
          ],
        ),
      ),
    );
  }
}
