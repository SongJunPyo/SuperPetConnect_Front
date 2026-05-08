import 'package:flutter/material.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import '../utils/error_display.dart';
import '../utils/pet_field_icons.dart';
import '../utils/phone_formatter.dart';
import '../widgets/app_dialog.dart';
import 'package:intl/intl.dart';

class AdminHospitalDetailScreen extends StatefulWidget {
  final HospitalInfo hospital;

  const AdminHospitalDetailScreen({super.key, required this.hospital});

  @override
  State<AdminHospitalDetailScreen> createState() =>
      _AdminHospitalDetailScreenState();
}

class _AdminHospitalDetailScreenState extends State<AdminHospitalDetailScreen> {
  late HospitalInfo hospitalInfo;
  bool isLoading = false;

  // hospital_code 수정 UI는 2026-05-08 Q3 라운드에 폐기.
  // 운영 정책: 이직/퇴사 시 admin이 계정 삭제 → 새 병원에서 신규 가입 흐름.
  // 비상 시 hospital_code 변경은 admin DB 직접 수정만 허용 (audit log 없음).

  @override
  void initState() {
    super.initState();
    hospitalInfo = widget.hospital;
  }

  Future<void> _toggleColumnActive() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final updateRequest = HospitalUpdateRequest(
        columnActive: !hospitalInfo.columnActive,
      );

      final updatedHospital = await AdminHospitalService.updateHospital(
        hospitalInfo.accountIdx,
        updateRequest,
      );

      setState(() {
        hospitalInfo = updatedHospital;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hospitalInfo.columnActive
                  ? '칼럼 작성 권한이 부여되었습니다.'
                  : '칼럼 작성 권한이 취소되었습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        showErrorToast(
          context,
          e,
          prefix: '권한 변경 실패',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _deleteHospital() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '병원 탈퇴',
      message:
          '정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.\n\n병원명: ${hospitalInfo.nickname?.isNotEmpty == true ? hospitalInfo.nickname! : hospitalInfo.name}',
      confirmLabel: '삭제',
      isDestructive: true,
    );

    if (confirmed != true || isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      await AdminHospitalService.deleteHospital(hospitalInfo.accountIdx);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('병원 "${hospitalInfo.name}"이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        showErrorToast(
          context,
          e,
          prefix: '삭제 실패',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
              maxLines: 3,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "병원 상세정보",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              _deleteHospital();
            },
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 24),
            tooltip: '병원 탈퇴',
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('처리 중...'),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 병원 기본 정보 카드
                    Card(
                      margin: const EdgeInsets.all(20.0),
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 아이콘은 PetFieldIcons 단일 진실에서 가져옴.
                            if (hospitalInfo.nickname?.isNotEmpty == true)
                              _buildDetailRow(
                                context,
                                PetFieldIcons.nickname,
                                '닉네임',
                                hospitalInfo.nickname!,
                              ),
                            _buildDetailRow(
                              context,
                              PetFieldIcons.userName,
                              '이름',
                              hospitalInfo.name,
                            ),
                            _buildDetailRow(
                              context,
                              PetFieldIcons.email,
                              '이메일',
                              hospitalInfo.email,
                            ),
                            if (hospitalInfo.phoneNumber != null &&
                                hospitalInfo.phoneNumber!.isNotEmpty)
                              _buildDetailRow(
                                context,
                                PetFieldIcons.phone,
                                '전화번호',
                                formatPhoneNumber(hospitalInfo.phoneNumber!),
                              ),
                            if (hospitalInfo.address != null &&
                                hospitalInfo.address!.isNotEmpty)
                              _buildDetailRow(
                                context,
                                PetFieldIcons.address,
                                '주소',
                                hospitalInfo.address!,
                              ),
                            _buildDetailRow(
                              context,
                              PetFieldIcons.hospital,
                              '병원 코드',
                              hospitalInfo.hospitalCode ?? '미등록',
                            ),
                            _buildDetailRow(
                              context,
                              PetFieldIcons.userCreatedAt,
                              '가입일',
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(hospitalInfo.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 칼럼 작성 권한 카드
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      elevation: 2,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '칼럼 작성 권한',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            //const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hospitalInfo.columnActive
                                            ? '칼럼 작성 권한이 부여되었습니다.'
                                            : '칼럼 작성 권한이 없습니다.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: hospitalInfo.columnActive,
                                  onChanged:
                                      isLoading
                                          ? null
                                          : (value) => _toggleColumnActive(),
                                  activeThumbColor: Colors.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    //const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }
}
