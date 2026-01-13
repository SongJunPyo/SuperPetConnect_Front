import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../services/user_management_service.dart';
import 'package:intl/intl.dart';

// 정지된 사용자용 바텀시트
class SuspendedUserBottomSheet extends StatefulWidget {
  final User user;

  const SuspendedUserBottomSheet({super.key, required this.user});

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 활성화'),
        content: Text('${widget.user.name}님의 계정을 활성화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('활성화'),
          ),
        ],
      ),
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
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 사용자 기본 정보
          _buildInfoRow('이름', widget.user.name),
          if (widget.user.nickname?.isNotEmpty == true)
            _buildInfoRow('닉네임', widget.user.nickname!),
          _buildInfoRow('이메일', widget.user.email),
          _buildInfoRow('전화번호', widget.user.phoneNumber),
          _buildInfoRow('사용자 유형', widget.user.userTypeText),

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
              child: _isActivating
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
                const Text(
                  '정지 사유',
                  style: AppTheme.bodyMediumStyle,
                ),
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
                const Text(
                  '정지 일수',
                  style: AppTheme.bodyMediumStyle,
                ),
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
                    child: _isUpdating
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 활성 사용자용 바텀시트
class ActiveUserBottomSheet extends StatelessWidget {
  final User user;
  final VoidCallback? onBlacklistPressed;

  const ActiveUserBottomSheet({
    super.key, 
    required this.user,
    this.onBlacklistPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '사용자 정보',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('이름', user.name),
          if (user.nickname?.isNotEmpty == true)
            _buildInfoRow('닉네임', user.nickname!),
          _buildInfoRow('이메일', user.email),
          _buildInfoRow('전화번호', user.phoneNumber),
          _buildInfoRow('주소', user.address),
          _buildInfoRow('사용자 유형', user.userTypeText),
          _buildInfoRow('상태', user.statusText),
          if (user.createdAt != null)
            _buildInfoRow(
              '가입일',
              DateFormat('yyyy-MM-dd HH:mm:ss').format(user.createdAt!),
            ),
          const SizedBox(height: 24),
          if (onBlacklistPressed != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBlacklistPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('블랙리스트 지정'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}