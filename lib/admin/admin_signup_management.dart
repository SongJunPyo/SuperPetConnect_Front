import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../services/auth_http_client.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_constants.dart';
import '../models/pet_model.dart';
import '../utils/donation_eligibility.dart';
import '../widgets/pet_profile_image.dart';

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
  final List<Pet> pets; // 반려동물 목록

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
    this.pets = const [],
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
      pets: (json['pets'] as List<dynamic>?)
              ?.map((p) => Pet.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
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
      } else if (response.statusCode == 400) {
        // 반려동물 미심사 등 400 에러
        if (mounted) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('승인 불가'),
              content: Text(data['detail'] ?? '승인할 수 없습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
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
    Timer? hospitalSearchDebounce; // 입력 디바운스 (400ms)

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
                            // 병원 검색 필드 (400ms 디바운스)
                            TextField(
                              controller: hospitalSearchController,
                              onChanged: (value) {
                                hospitalSearchDebounce?.cancel();
                                final query = value.trim();
                                if (query.isEmpty) {
                                  setState(() {
                                    hospitalSearchResults = [];
                                    isHospitalSearching = false;
                                  });
                                  return;
                                }
                                setState(() => isHospitalSearching = true);
                                hospitalSearchDebounce = Timer(
                                  const Duration(milliseconds: 400),
                                  () async {
                                    try {
                                      final response =
                                          await AdminHospitalService
                                              .getHospitalMasterList(
                                        search: query,
                                        // 다이얼로그 검색은 첫 페이지만 미리보기
                                        // 충분한 매치를 위해 50건까지 요청
                                        pageSize: 50,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setState(() {
                                        hospitalSearchResults =
                                            response.hospitals;
                                        isHospitalSearching = false;
                                      });
                                    } catch (e) {
                                      if (!dialogContext.mounted) return;
                                      setState(
                                        () => isHospitalSearching = false,
                                      );
                                    }
                                  },
                                );
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
                                              hospitalSearchDebounce?.cancel();
                                              hospitalSearchController.clear();
                                              setState(() {
                                                hospitalSearchResults = [];
                                                selectedHospital = null;
                                                isHospitalSearching = false;
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
                    hospitalSearchDebounce?.cancel();
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
                    hospitalSearchDebounce?.cancel();
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

  Widget _buildApprovalBadge(int status) {
    Color bgColor;
    Color textColor;
    String text;
    switch (status) {
      case 0:
        bgColor = AppTheme.warning.withValues(alpha: 0.15);
        textColor = AppTheme.warning;
        text = '승인 대기';
        break;
      case 1:
        bgColor = AppTheme.success.withValues(alpha: 0.15);
        textColor = AppTheme.success;
        text = '승인됨';
        break;
      case 2:
        bgColor = AppTheme.error.withValues(alpha: 0.15);
        textColor = AppTheme.error;
        text = '거절됨';
        break;
      default:
        bgColor = AppTheme.veryLightGray;
        textColor = AppTheme.textSecondary;
        text = '알 수 없음';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _approvePet(int petIdx, {Pet? pet}) async {
    // 헌혈 조건 미충족 시 확인 다이얼로그
    if (pet != null) {
      final eligibility = DonationEligibility.checkEligibility(pet);
      if (!eligibility.isEligible) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('헌혈 조건 미충족'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eligibility.summaryMessage,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: eligibility.needsConsultation ? AppTheme.warning : AppTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (eligibility.failedConditions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...eligibility.failedConditions.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${c.conditionName}: ${c.message}',
                      style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.error),
                    ),
                  )),
                ],
                if (eligibility.consultConditions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...eligibility.consultConditions.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${c.conditionName}: ${c.message}',
                      style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.warning),
                    ),
                  )),
                ],
                const SizedBox(height: 12),
                const Text('그래도 승인하시겠습니까?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('승인', style: TextStyle(color: AppTheme.success)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    try {
      final url = Uri.parse('${Config.serverUrl}${ApiEndpoints.adminPetApprove(petIdx)}');
      final response = await AuthHttpClient.post(url);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려동물이 승인되었습니다.')),
          );
        }
        fetchPendingUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  void _showPetRejectDialog(int petIdx, String petName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 거절'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(petName, style: AppTheme.h4Style),
            const SizedBox(height: AppTheme.spacing12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '거절 사유를 입력해주세요',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('거절 사유를 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(context);
              try {
                final url = Uri.parse('${Config.serverUrl}${ApiEndpoints.adminPetReject(petIdx)}');
                final response = await AuthHttpClient.post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'rejection_reason': reason}),
                );
                if (response.statusCode == 200 && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('반려동물이 거절되었습니다.')),
                  );
                  fetchPendingUsers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('오류: $e')));
                }
              }
            },
            child: const Text('거절 확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupPetCard(Pet pet) {
    final eligibility = DonationEligibility.checkEligibility(pet);

    // ExpansionTile 타이틀: 이름 + 대표 + 배지
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: PetProfileImage(
            profileImage: pet.profileImage,
            species: pet.species,
            radius: 18,
          ),
          title: Row(
            children: [
              if (pet.isPrimary)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star, size: 16, color: AppTheme.warning),
                ),
              Expanded(
                child: Text(
                  pet.name,
                  style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (pet.approvalStatus == 1 || pet.approvalStatus == 2)
                _buildApprovalBadge(pet.approvalStatus),
            ],
          ),
          children: [
            // 기본 정보 (_buildDetailRow와 동일 스타일)
            _buildDetailRow(context, Icons.pets, '종류', pet.species),
            if (pet.breed != null && pet.breed!.isNotEmpty)
              _buildDetailRow(context, Icons.category_outlined, '품종', pet.breed!),
            if (pet.bloodType != null && pet.bloodType!.isNotEmpty)
              _buildDetailRow(context, Icons.bloodtype_outlined, '혈액형', pet.bloodType!),
            _buildDetailRow(context, Icons.cake_outlined, '생년월일', pet.birthDateWithAge),
            _buildDetailRow(context, Icons.monitor_weight_outlined, '체중', '${pet.weightKg}kg'),
            _buildDetailRow(context, Icons.vaccines_outlined, '접종', pet.vaccinated == true ? '완료' : '미완료'),
            _buildDetailRow(context, Icons.pregnant_woman_outlined, '임신', pet.pregnant ? 'O' : 'X'),
            _buildDetailRow(context, Icons.content_cut_outlined, '중성화', pet.isNeutered == true ? 'O' : 'X'),
            _buildDetailRow(context, Icons.local_hospital_outlined, '질병', pet.hasDisease == true ? '있음' : '없음'),
            _buildDetailRow(context, Icons.child_friendly_outlined, '출산', pet.hasBirthExperience == true ? '있음' : '없음'),
            _buildDetailRow(context, Icons.medication_outlined, '예방약', pet.hasPreventiveMedication == true ? '복용' : '미복용'),
            // 헌혈 조건 검증 결과
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: eligibility.isEligible
                    ? AppTheme.success.withValues(alpha: 0.08)
                    : eligibility.needsConsultation
                        ? AppTheme.warning.withValues(alpha: 0.08)
                        : AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        eligibility.isEligible
                            ? Icons.check_circle
                            : eligibility.needsConsultation
                                ? Icons.warning_amber
                                : Icons.cancel,
                        size: 18,
                        color: eligibility.isEligible
                            ? AppTheme.success
                            : eligibility.needsConsultation
                                ? AppTheme.warning
                                : AppTheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '헌혈 조건: ${eligibility.summaryMessage}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: eligibility.isEligible
                              ? AppTheme.success
                              : eligibility.needsConsultation
                                  ? AppTheme.warning
                                  : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  if (eligibility.failedConditions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...eligibility.failedConditions.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 2),
                      child: Text(
                        '${c.conditionName}: ${c.message}',
                        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.error),
                      ),
                    )),
                  ],
                  if (eligibility.consultConditions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...eligibility.consultConditions.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 2),
                      child: Text(
                        '${c.conditionName}: ${c.message}',
                        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.warning),
                      ),
                    )),
                  ],
                ],
              ),
            ),
            // 거절 사유
            if (pet.approvalStatus == 2 && pet.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '거절 사유: ${pet.rejectionReason}',
                  style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.error),
                ),
              ),
            ],
            // 승인/거절 버튼
            if (pet.approvalStatus == 0 && pet.petIdx != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _approvePet(pet.petIdx!, pet: pet),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.success,
                          side: const BorderSide(color: AppTheme.success),
                        ),
                        child: const Text('승인'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _showPetRejectDialog(pet.petIdx!, pet.name),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                        ),
                        child: const Text('거절'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
                                // 대표 반려동물 프로필 사진
                                PetProfileImage(
                                  profileImage: user.pets.isNotEmpty
                                      ? (user.pets.where((p) => p.isPrimary).firstOrNull?.profileImage
                                          ?? user.pets.first.profileImage)
                                      : null,
                                  species: user.pets.isNotEmpty ? user.pets.first.species : null,
                                  radius: 24,
                                ),
                                const SizedBox(width: 12),
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
                            // 반려동물 목록 (드롭다운)
                            if (user.pets.isNotEmpty) ...[
                              const SizedBox(height: AppTheme.spacing8),
                              const Divider(),
                              ...user.pets.map((pet) => _buildSignupPetCard(pet)),
                            ],
                            const SizedBox(height: AppTheme.spacing16),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed:
                                          user.status == '대기'
                                              ? () => showApprovalDialog(user)
                                              : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.success,
                                        side: BorderSide(color: AppTheme.success),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        "회원가입 승인",
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.success,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing12),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed:
                                          user.status == '대기'
                                              ? () => rejectUser(user)
                                              : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                        side: BorderSide(color: AppTheme.error),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        "회원가입 거절",
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.error,
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
