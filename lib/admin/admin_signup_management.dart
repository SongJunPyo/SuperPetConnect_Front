import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';

// 회원 가입 신청자 데이터 모델
class SignupUser {
  final int id; // Flutter 모델에서는 'id'로 사용
  final String email;
  final String name;
  final String phoneNumber;
  final String address;
  final double latitude;
  final double longitude;
  final int userType; // Flutter 모델에서는 'userType'으로 사용
  final DateTime createdTime; // String -> DateTime으로 변경
  String status; // 승인 상태: '대기', '승인', '거절'

  SignupUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phoneNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
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
    final double parsedLatitude =
        json['latitude'] is num ? json['latitude'].toDouble() : 37.5665;
    final double parsedLongitude =
        json['longitude'] is num ? json['longitude'].toDouble() : 126.9780;
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
      latitude: parsedLatitude,
      longitude: parsedLongitude,
      userType: parsedUserType,
      createdTime: parsedCreatedTime,
      status: approvedBool ? '승인' : '대기',
    );
  }
}

class AdminSignupManagement extends StatefulWidget {
  const AdminSignupManagement({super.key});

  @override
  State createState() => _AdminSignupManagementState();
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
      final url = Uri.parse(
        '${Config.serverUrl}/api/signup_management/pending-users',
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
        setState(() {
          pendingUsers =
              data
                  .map((userJson) {
                    try {
                      return SignupUser.fromJson(userJson);
                    } catch (e) {
                      return null;
                    }
                  })
                  .where((user) => user != null && user.status == '대기')
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
      final url = Uri.parse(
        '${Config.serverUrl}/api/signup_management/approve-user/${user.id}',
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("${user.name} 회원 가입 승인 완료")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "승인 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
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
      final response = await http.post(
        Uri.parse(
          '${Config.serverUrl}/api/signup_management/reject-user/${user.id}',
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("${user.name} 회원 가입 거절 완료")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "거절 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
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
    final hospitalIdController = TextEditingController();

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
                        controller: hospitalIdController,
                        decoration: InputDecoration(
                          labelText: '요양기관기호',
                          hintText: '병원 코드를 입력하세요.',
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
                    foregroundColor: AppTheme.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    approveUser(
                      user,
                      selectedUserType,
                      hospitalIdController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '확인',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            '$label: ',
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textPrimary,
              ),
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
          style: AppTheme.h3Style.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: AppTheme.textPrimary),
            tooltip: '새로고침',
            onPressed: fetchPendingUsers,
          ),
          const SizedBox(width: AppTheme.spacing8),
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
                padding: AppTheme.pagePadding,
                itemCount: pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = pendingUsers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radius12),
                          border: Border.all(
                            color: AppTheme.lightGray.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${user.name}',
                              style: AppTheme.h4Style.copyWith(
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppTheme.spacing12),
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
                              Icons.gps_fixed_outlined,
                              '위치',
                              '위도: ${user.latitude.toStringAsFixed(4)}, 경도: ${user.longitude.toStringAsFixed(4)}',
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
                            const SizedBox(height: AppTheme.spacing16),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: user.status == '대기'
                                          ? () => showApprovalDialog(user)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radius12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        "승인",
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing12),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: user.status == '대기'
                                          ? () => rejectUser(user)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.error,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radius12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        "거절",
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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
                    ),
                  );
                },
              ),
    );
  }
}
