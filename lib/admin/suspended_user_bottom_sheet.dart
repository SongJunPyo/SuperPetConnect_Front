import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_management_service.dart';
import '../utils/app_theme.dart';
import '../utils/pet_field_icons.dart';
import '../utils/phone_formatter.dart';
import '../widgets/app_dialog.dart';
import '../widgets/info_row.dart';

/// 정지 상태(blacklist) 사용자의 정보를 띄우고 정지 해제(=활성화)와 정지 사유/일수
/// 수정을 한 화면에서 처리하는 바텀시트.
///
/// 호출부([AdminUserCheck])가 활성/정지 상태에 따라 [SuspendedUserBottomSheet]
/// 또는 [ActiveUserBottomSheet] 중 하나를 띄우며, 닫힐 때 `pop(true)`이 오면
/// 목록을 새로고침. [onDeletePressed]는 헤더 우측 휴지통 아이콘에 연결되어
/// 시트를 닫고 호출부의 삭제 다이얼로그를 띄우는 용도.
class SuspendedUserBottomSheet extends StatefulWidget {
  final User user;
  final VoidCallback? onDeletePressed;

  const SuspendedUserBottomSheet({super.key, required this.user, this.onDeletePressed});

  @override
  State<SuspendedUserBottomSheet> createState() =>
      _SuspendedUserBottomSheetState();
}

class _SuspendedUserBottomSheetState extends State<SuspendedUserBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _daysController = TextEditingController();
  bool _isActivating = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _reasonController.text = widget.user.blacklistReason ?? '';
    _daysController.text = widget.user.remainingDays?.toString() ?? '7';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _activateUser() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '계정 활성화',
      message: '${widget.user.name}님의 계정을 활성화하시겠습니까?',
      confirmLabel: '활성화',
    );

    if (confirmed != true) return;

    setState(() {
      _isActivating = true;
    });

    try {
      // Status 1 for 'Active'
      await UserManagementService.updateUserStatus(widget.user.accountIdx, 1);

      if (mounted) {
        Navigator.of(context).pop(true); // Pop bottom sheet and signal success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정이 활성화되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('활성화 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivating = false;
        });
      }
    }
  }

  Future<void> _updateBlacklist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final request = BlacklistRequest(
        accountIdx: widget.user.accountIdx,
        reason: _reasonController.text.trim(),
        suspensionDays: int.parse(_daysController.text),
      );

      await UserManagementService.blacklistUser(request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정지 정보가 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수정 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '정지된 사용자',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.onDeletePressed != null)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDeletePressed!();
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '계정 삭제',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 사용자 기본 정보 — 아이콘은 PetFieldIcons 단일 진실에서 가져옴.
          InfoRow(
            icon: PetFieldIcons.userName,
            label: '이름',
            value: widget.user.name,
            padding: const EdgeInsets.only(bottom: 8),
          ),
          if (widget.user.nickname?.isNotEmpty == true)
            InfoRow(
              icon: PetFieldIcons.nickname,
              label: '닉네임',
              value: widget.user.nickname!,
              padding: const EdgeInsets.only(bottom: 8),
            ),
          InfoRow(
            icon: PetFieldIcons.email,
            label: '이메일',
            value: widget.user.email,
            padding: const EdgeInsets.only(bottom: 8),
          ),
          InfoRow(
            icon: PetFieldIcons.phone,
            label: '전화번호',
            value: formatPhoneNumber(widget.user.phoneNumber),
            padding: const EdgeInsets.only(bottom: 8),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActivating || _isUpdating ? null : _activateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isActivating
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('계정 활성화'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            '정지 정보 수정',
            style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('정지 사유', style: AppTheme.bodyMediumStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: '정지 사유를 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '정지 사유를 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('정지 일수', style: AppTheme.bodyMediumStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _daysController,
                  decoration: InputDecoration(
                    hintText: '정지할 일수를 입력하세요',
                    suffix: const Text('일'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '정지 일수를 입력하세요';
                    }
                    final days = int.tryParse(value);
                    if (days == null || days < 1) {
                      return '1일 이상 입력하세요';
                    }
                    if (days > 365) {
                      return '365일 이하로 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isActivating || _isUpdating ? null : _updateBlacklist,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isUpdating
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('수정'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
