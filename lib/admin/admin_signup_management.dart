import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가
// TODO: Config 파일 임포트 추가 (서버 URL 사용)
// import '../utils/config.dart';

// 회원 가입 신청자 데이터 모델
class SignupUser {
  final int id;
  final String email;
  final String name;
  final String phoneNumber;
  final String address;
  int userType; // 1: 관리자, 2: 병원, 3: 일반 사용자
  final String createdTime;
  String status; // 승인 상태: '대기', '승인', '거절'

  SignupUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phoneNumber,
    required this.address,
    required this.userType,
    required this.createdTime,
    required this.status,
  });

  factory SignupUser.fromJson(Map<String, dynamic> json) {
    return SignupUser(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      userType: json['user_type'],
      createdTime: json['created_time'],
      status:
          json['approved'] == 1
              ? '승인'
              : (json['approved'] == 0
                  ? '거절'
                  : '대기'), // 'approved'가 0이면 거절, 1이면 승인, 그 외 대기
    );
  }
}

class AdminSignupManagement extends StatefulWidget {
  const AdminSignupManagement({super.key}); // Key? key -> super.key로 변경

  @override
  _AdminSignupManagementState createState() => _AdminSignupManagementState();
}

class _AdminSignupManagementState extends State<AdminSignupManagement> {
  List<SignupUser> pendingUsers = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token; // JWT 토큰을 저장할 변수

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => fetchPendingUsers()); // 토큰 로드 후 사용자 목록 가져오기
  }

  // SharedPreferences에서 토큰 로드
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    print(
      "불러온 토큰: ${storedToken?.substring(0, math.min(10, storedToken.length)) ?? '없음'}...",
    ); // 디버그 출력 간결화
    setState(() {
      token = storedToken;
    });
  }

  // API에서 승인 대기 중인 사용자 목록 가져오기
  Future<void> fetchPendingUsers() async {
    if (token == null || token!.isEmpty) {
      setState(() {
        errorMessage = '로그인이 필요합니다. (토큰 없음)';
        isLoading = false;
      });
      // TODO: 로그인 페이지로 강제 이동 로직 추가 (필요 시)
      // Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // TODO: Config.serverUrl 사용으로 변경
      final url = Uri.parse(
        'http://10.100.54.176:8002/api/signup_management/pending-users',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // JWT 토큰 포함
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          // '대기' 상태인 사용자만 필터링하여 보여줌 (서버 응답 'approved' 필드에 따라)
          pendingUsers =
              data
                  .map((user) => SignupUser.fromJson(user))
                  .where((user) => user.status == '대기')
                  .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              '사용자 목록을 불러오는데 실패했습니다: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '오류가 발생했습니다: $e';
        isLoading = false;
      });
      print('fetchPendingUsers Error: $e'); // 자세한 오류 로깅
    }
  }

  // 사용자 승인 처리
  Future<void> approveUser(SignupUser user, int selectedUserType) async {
    if (token == null || token!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다.")));
      return;
    }

    try {
      // TODO: Config.serverUrl 사용으로 변경
      final url = Uri.parse(
        'http://10.100.54.176:8002/api/signup_management/approve-user/${user.id}',
      );
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token', // JWT 토큰 포함
        },
        body: jsonEncode({'user_type': selectedUserType}),
      );

      if (response.statusCode == 200) {
        // 승인 성공: 목록에서 해당 사용자 제거
        setState(() {
          pendingUsers.removeWhere((u) => u.id == user.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${user.name} 회원 가입 승인 완료")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "승인 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      print('approveUser Error: $e');
    }
  }

  // 사용자 거절 처리
  Future<void> rejectUser(SignupUser user) async {
    if (token == null || token!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다.")));
      return;
    }

    try {
      // TODO: Config.serverUrl 사용으로 변경
      final response = await http.post(
        Uri.parse(
          'http://10.100.54.176:8002/api/signup_management/reject-user/${user.id}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token', // JWT 토큰 포함
        },
      );

      if (response.statusCode == 200) {
        // 거절 성공: 목록에서 해당 사용자 제거
        setState(() {
          pendingUsers.removeWhere((u) => u.id == user.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${user.name} 회원 가입 거절 완료")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "거절 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      print('rejectUser Error: $e');
    }
  }

  // 사용자 유형에 따른 텍스트 반환
  String getUserTypeText(int userType) {
    switch (userType) {
      case 1:
        return '관리자';
      case 2:
        return '병원';
      case 3:
        return '일반 사용자';
      default:
        return '알 수 없음';
    }
  }

  // 상태에 따른 색상 반환
  Color getStatusColor(String status) {
    switch (status) {
      case '승인':
        return Colors.green;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  // 승인 다이얼로그 표시
  void showApprovalDialog(SignupUser user) {
    int selectedUserType = user.userType; // 기본값은 현재 유저 타입 (대부분 3)
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // BuildContext 이름을 dialogContext로 변경하여 충돌 방지
        return StatefulBuilder(
          builder: (context, setState) {
            // StatefulBuilder의 setState는 다이얼로그 내부만 업데이트
            return AlertDialog(
              title: Text('회원 유형 선택', style: textTheme.titleLarge),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 왼쪽 정렬
                children: [
                  Text(
                    '${user.name}님의 회원 유형을 선택해주세요.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedUserType,
                    isExpanded: true,
                    items: const [
                      // const 추가
                      DropdownMenuItem(value: 1, child: Text('관리자')),
                      DropdownMenuItem(value: 2, child: Text('병원')),
                      DropdownMenuItem(value: 3, child: Text('일반 사용자')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          // StatefulBuilder의 setState 사용
                          selectedUserType = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      // 드롭다운 필드 디자인 통일
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                    approveUser(user, selectedUserType); // 승인 처리 함수 호출
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary, // 테마 주 색상
                    foregroundColor: colorScheme.onPrimary,
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
          "회원 가입 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 왼쪽 정렬
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_outlined,
              color: Colors.black87,
            ), // 아웃라인 아이콘
            tooltip: '새로고침',
            onPressed: fetchPendingUsers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
              : errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '데이터를 불러오는데 실패했습니다.',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : pendingUsers.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_disabled_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ), // 대기 회원 없음 아이콘
                    const SizedBox(height: 16),
                    Text(
                      '승인 대기 중인 회원이 없습니다.',
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
                  vertical: 16.0,
                ), // 여백 통일
                itemCount: pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = pendingUsers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0), // 카드 간격
                    elevation: 1, // 더 가벼운 그림자
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // 둥근 모서리
                      side: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ), // 테두리 추가
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // 내부 패딩
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 사용자 이름 및 상태 태그
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: getStatusColor(
                                    user.status,
                                  ).withAlpha(38), // withOpacity(0.15) 대체
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  user.status,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: getStatusColor(user.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 사용자 상세 정보
                          _buildDetailRow(
                            context,
                            Icons.email_outlined,
                            '이메일',
                            user.email,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.phone_outlined,
                            '연락처',
                            user.phoneNumber,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.location_on_outlined,
                            '주소',
                            user.address,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.badge_outlined,
                            '신청 유형',
                            getUserTypeText(user.userType),
                          ),
                          _buildDetailRow(
                            context,
                            Icons.calendar_today_outlined,
                            '신청일',
                            user.createdTime,
                          ),

                          const SizedBox(height: 16), // 정보와 버튼 사이 간격
                          // 승인/거절 버튼
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround, // 버튼 간격 균등 분배
                            children: [
                              Expanded(
                                child: SizedBox(
                                  // 버튼 높이 고정
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed:
                                        user.status == '대기'
                                            ? () => showApprovalDialog(user)
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          colorScheme.primary, // 테마 주 색상
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      "승인",
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12), // 버튼 사이 간격
                              Expanded(
                                child: SizedBox(
                                  // 버튼 높이 고정
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed:
                                        user.status == '대기'
                                            ? () => rejectUser(user)
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          colorScheme.error, // 테마 에러 색상
                                      foregroundColor: colorScheme.onError,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      "거절",
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
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
    );
  }
}
