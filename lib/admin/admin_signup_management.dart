import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_constants.dart';

// 회원 가입 신청자 데이터 모델
class SignupUser {
  final int id; // Flutter 모델에서는 'id'로 사용
  final String email;
  final String name;
  final String nickname;
  final String phoneNumber;
  final String address;
  final double latitude;
  final double longitude;
  final int userType; // Flutter 모델에서는 'userType'으로 사용
  final String loginType; // 가입 방식: "email" 또는 "naver"
  final DateTime createdTime; // String -> DateTime으로 변경
  String status; // 승인 상태: '대기', '승인', '거절'

  SignupUser({
    required this.id,
    required this.email,
    required this.name,
    required this.nickname,
    required this.phoneNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.userType,
    required this.loginType,
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
    final String parsedNickname =
        json['nickname'] is String ? json['nickname'] : '';
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
    final String parsedLoginType =
        json['login_type'] is String ? json['login_type'] : 'email';

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
      nickname: parsedNickname,
      phoneNumber: parsedPhoneNumber,
      address: parsedAddress,
      latitude: parsedLatitude,
      longitude: parsedLongitude,
      userType: parsedUserType,
      loginType: parsedLoginType,
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

  @override
  void initState() {
    super.initState();
    fetchPendingUsers();
  }

  Future<void> fetchPendingUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/signup_management/pending-users',
      );
      final response = await AuthHttpClient.get(url);

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
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/signup_management/approve-user/${user.id}',
      );

      final Map<String, dynamic> requestBody = {'user_type': selectedUserType};

      if (selectedUserType == AppConstants.accountTypeHospital &&
          hospitalId != null &&
          hospitalId.isNotEmpty) {
        requestBody['hospital_id'] = hospitalId;
      }

      final response = await AuthHttpClient.post(
        url,
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
    try {
      final response = await AuthHttpClient.post(
        Uri.parse(
          '${Config.serverUrl}/api/signup_management/reject-user/${user.id}',
        ),
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
    return AppConstants.getAccountTypeText(userType);
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

    // 병원 검색/선택 관련 상태
    final hospitalSearchController = TextEditingController();
    List<HospitalMaster> hospitalSearchResults = [];
    HospitalMaster? selectedHospital;
    bool isHospitalSearching = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('회원 유형 선택', style: textTheme.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.name}님의 회원 유형을 선택해주세요.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedUserType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: AppConstants.accountTypeAdmin, child: Text('관리자')),
                        DropdownMenuItem(value: AppConstants.accountTypeHospital, child: Text('병원')),
                        DropdownMenuItem(value: AppConstants.accountTypeUser, child: Text('일반 사용자')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedUserType = value;
                            // 병원 외 선택 시 초기화
                            if (value != AppConstants.accountTypeHospital) {
                              selectedHospital = null;
                              hospitalSearchResults = [];
                              hospitalSearchController.clear();
                            }
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
                    if (selectedUserType == AppConstants.accountTypeHospital)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 병원 검색 필드
                            TextField(
                              controller: hospitalSearchController,
                              onChanged: (value) async {
                                if (value.trim().isEmpty) {
                                  setState(() {
                                    hospitalSearchResults = [];
                                  });
                                  return;
                                }
                                setState(() => isHospitalSearching = true);
                                try {
                                  final response = await AdminHospitalService.getHospitalMasterList(
                                    search: value.trim(),
                                  );
                                  setState(() {
                                    hospitalSearchResults = response.hospitals;
                                    isHospitalSearching = false;
                                  });
                                } catch (e) {
                                  setState(() => isHospitalSearching = false);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: '병원 검색',
                                hintText: '병원명 또는 코드로 검색',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: isHospitalSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : hospitalSearchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              hospitalSearchController.clear();
                                              setState(() {
                                                hospitalSearchResults = [];
                                                selectedHospital = null;
                                              });
                                            },
                                          )
                                        : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            // 검색 결과 리스트
                            if (hospitalSearchResults.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 150),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(hospitalSearchResults.length, (i) {
                                      final hospital = hospitalSearchResults[i];
                                      final isSelected = selectedHospital?.hospitalCode == hospital.hospitalCode;
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (i > 0)
                                            Divider(height: 1, color: Colors.grey.shade200),
                                          ListTile(
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                            selected: isSelected,
                                            selectedTileColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                            title: Text(
                                              '[${hospital.hospitalCode}] ${hospital.hospitalName}',
                                              style: AppTheme.bodyMediumStyle.copyWith(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                            subtitle: hospital.hospitalAddress != null && hospital.hospitalAddress!.isNotEmpty
                                                ? Text(
                                                    hospital.hospitalAddress!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: AppTheme.bodySmallStyle.copyWith(color: Colors.grey[600]),
                                                  )
                                                : null,
                                            onTap: () {
                                              setState(() {
                                                selectedHospital = hospital;
                                                hospitalSearchController.text = hospital.hospitalName;
                                              });
                                              // 다음 프레임에서 리스트 제거 (InkResponse 애니메이션 완료 후)
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                setState(() {
                                                  hospitalSearchResults = [];
                                                });
                                              });
                                            },
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            // 선택된 병원 표시
                            if (selectedHospital != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '[${selectedHospital!.hospitalCode}] ${selectedHospital!.hospitalName}',
                                        style: AppTheme.bodySmallStyle.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedHospital = null;
                                          hospitalSearchController.clear();
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            // 검색 결과 없을 때 새 병원 등록 안내
                            if (hospitalSearchController.text.isNotEmpty &&
                                hospitalSearchResults.isEmpty &&
                                !isHospitalSearching &&
                                selectedHospital == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '검색 결과가 없습니다. 병원 관리에서 먼저 병원을 등록해주세요.',
                                  style: AppTheme.bodySmallStyle.copyWith(color: Colors.orange[700]),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
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
                    // 병원 유형인데 병원 미선택 시 경고
                    if (selectedUserType == AppConstants.accountTypeHospital &&
                        selectedHospital == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('병원을 검색하여 선택해주세요.')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    approveUser(
                      user,
                      selectedUserType,
                      selectedHospital?.hospitalCode,
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          border: Border.all(
                            color: AppTheme.lightGray.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${user.name}',
                                    style: AppTheme.h4Style.copyWith(
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        user.loginType == 'naver'
                                            ? const Color(
                                              0xFF03C75A,
                                            ).withValues(alpha: 0.1)
                                            : AppTheme.primaryBlue.withValues(
                                              alpha: 0.1,
                                            ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    user.loginType == 'naver' ? '네이버' : '이메일',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color:
                                          user.loginType == 'naver'
                                              ? const Color(0xFF03C75A)
                                              : AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacing12),
                            _buildDetailRow(
                              context,
                              Icons.email_outlined,
                              '이메일',
                              user.email,
                            ),
                            if (user.nickname.isNotEmpty)
                              _buildDetailRow(
                                context,
                                Icons.person_outline,
                                '닉네임',
                                user.nickname,
                              ),
                            _buildDetailRow(
                              context,
                              Icons.phone_outlined,
                              '연락처',
                              user.phoneNumber.isNotEmpty
                                  ? user.phoneNumber
                                  : '미제공',
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
                                      onPressed:
                                          user.status == '대기'
                                              ? () => showApprovalDialog(user)
                                              : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        "승인",
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(
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
                                      onPressed:
                                          user.status == '대기'
                                              ? () => rejectUser(user)
                                              : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.error,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        "거절",
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(
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
