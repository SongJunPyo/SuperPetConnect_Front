import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가

// 회원 가입 신청자 데이터 모델
class SignupUser {
  final int id; // Flutter 모델에서는 'id'로 사용
  final String email;
  final String name;
  final String phoneNumber;
  final String address;
  final int userType; // Flutter 모델에서는 'userType'으로 사용
  final DateTime createdTime; // String -> DateTime으로 변경
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
    final int parsedId =
        json['account_idx'] is int
            ? json['account_idx']
            : 0; // 'account_idx' 키를 사용
    final String parsedEmail = json['email'] is String ? json['email'] : '';
    final String parsedName = json['name'] is String ? json['name'] : '';
    final String parsedPhoneNumber =
        json['phone_number'] is String ? json['phone_number'] : '';
    final String parsedAddress =
        json['address'] is String ? json['address'] : '';
    final int parsedUserType =
        json['account_type'] is int
            ? json['account_type']
            : 3; // 'account_type' 키를 사용

    final String createdTimeStr =
        json['created_time'] is String ? json['created_time'] : '';
    final DateTime parsedCreatedTime =
        DateTime.tryParse(createdTimeStr) ?? DateTime.now();

    final bool approvedBool =
        json['approved'] is bool ? json['approved'] : false;

    return SignupUser(
      id: parsedId,
      email: parsedEmail,
      name: parsedName,
      phoneNumber: parsedPhoneNumber,
      address: parsedAddress,
      userType: parsedUserType,
      createdTime: parsedCreatedTime,
      status: approvedBool ? '승인' : '대기',
    );
  }
}

class AdminSignupManagement extends StatefulWidget {
  const AdminSignupManagement({super.key});

  @override
  _AdminSignupManagementState createState() => _AdminSignupManagementState();
}

class _AdminSignupManagementState extends State<AdminSignupManagement> {
  List<SignupUser> pendingUsers = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token;

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => fetchPendingUsers());
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    print(
      "불러온 토큰: ${storedToken?.substring(0, math.min(10, storedToken.length)) ?? '없음'}...",
    );
    setState(() {
      token = storedToken;
    });
  }

  Future<void> fetchPendingUsers() async {
    if (token == null || token!.isEmpty) {
      setState(() {
        errorMessage = '로그인이 필요합니다. (토큰 없음)';
        isLoading = false;
      });
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
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        print('Received raw data from server: $data');
        setState(() {
          pendingUsers =
              data
                  .map((userJson) {
                    try {
                      return SignupUser.fromJson(userJson);
                    } catch (e) {
                      print('SignupUser.fromJson 파싱 오류: $e, 데이터: $userJson');
                      return null;
                    }
                  })
                  .where((user) => user != null && user!.status == '대기')
                  .cast<SignupUser>()
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
      print('fetchPendingUsers Error: $e');
    }
  }

  Future<void> approveUser(
    SignupUser user,
    int selectedUserType,
    String? hospitalId,
  ) async {
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

      final Map<String, dynamic> requestBody = {'user_type': selectedUserType};

      if (selectedUserType == 2 &&
          hospitalId != null &&
          hospitalId.isNotEmpty) {
        requestBody['hospital_id'] = hospitalId;
      }

      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
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
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
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

  void showApprovalDialog(SignupUser user) {
    int selectedUserType = user.userType;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _hospitalIdController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('회원 유형 선택', style: textTheme.titleLarge),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      DropdownMenuItem(value: 1, child: Text('관리자')),
                      DropdownMenuItem(value: 2, child: Text('병원')),
                      DropdownMenuItem(value: 3, child: Text('일반 사용자')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedUserType = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
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
                  if (selectedUserType == 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: TextField(
                        controller: _hospitalIdController,
                        decoration: InputDecoration(
                          labelText: '요양기관기호',
                          hintText: '병원 고유 ID를 입력하세요.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    approveUser(
                      user,
                      selectedUserType,
                      _hospitalIdController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
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
        title: Text(
          "회원 가입 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: Colors.black87),
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
                    ),
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
                ),
                itemCount: pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = pendingUsers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${index + 1}. ${user.name}', // 번호 매기기 추가
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // ⚠️ 이 부분이 "대기" 라벨입니다. (주석 처리됨)
                              // Container(
                              //   padding: const EdgeInsets.symmetric(
                              //     horizontal: 8.0,
                              //     vertical: 4.0,
                              //   ),
                              //   decoration: BoxDecoration(
                              //     color: getStatusColor(
                              //       user.status,
                              //     ).withAlpha(38),
                              //     borderRadius: BorderRadius.circular(8.0),
                              //   ),
                              //   child: Text(
                              //     user.status,
                              //     style: textTheme.bodySmall?.copyWith(
                              //       fontWeight: FontWeight.bold,
                              //       color: getStatusColor(user.status),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                            user.createdTime.toIso8601String().split('T')[0],
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed:
                                        user.status == '대기'
                                            ? () => showApprovalDialog(user)
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed:
                                        user.status == '대기'
                                            ? () => rejectUser(user)
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.error,
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
