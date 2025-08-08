// hospital/donation_cancellation_dialog.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/applied_donation_model.dart';
import '../models/cancelled_donation_model.dart';
import '../services/cancelled_donation_service.dart';
import '../services/applied_donation_service.dart';

class DonationCancellationDialog extends StatefulWidget {
  final AppliedDonation appliedDonation;
  final Function(CancelledDonation) onCancelled;

  const DonationCancellationDialog({
    super.key,
    required this.appliedDonation,
    required this.onCancelled,
  });

  @override
  State<DonationCancellationDialog> createState() => _DonationCancellationDialogState();
}

class _DonationCancellationDialogState extends State<DonationCancellationDialog> {
  final TextEditingController _reasonController = TextEditingController();
  List<String> reasonTemplates = [];
  bool isSubmitting = false;
  String? validationMessage;
  String? validationLevel;
  bool isLoadingTemplates = true;

  @override
  void initState() {
    super.initState();
    _loadReasonTemplates();
  }

  Future<void> _loadReasonTemplates() async {
    try {
      final templates = await CancelledDonationService.getReasonTemplatesForSubject(
        CancelledSubject.hospital
      );
      setState(() {
        reasonTemplates = templates;
        isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        isLoadingTemplates = false;
      });
      print('취소 사유 템플릿 로드 실패: $e');
    }
  }

  void _validateReason() {
    final validation = CancelledDonationService.validateCancellationReason(
      _reasonController.text
    );
    
    setState(() {
      validationMessage = validation['message'];
      validationLevel = validation['level'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 중지 처리',
                        style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.appliedDonation.postTitle ?? '헌혈 요청',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing20),

            // 반려동물 정보
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        '헌혈 중지 알림',
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    '해당 헌혈 신청을 중지하시겠습니까?\n반려동물: ${widget.appliedDonation.pet?.displayInfo ?? '정보 없음'}',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: Colors.orange.shade800,
                    ),
                  ),
                  if (widget.appliedDonation.donationTime != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '예정 시간: ${widget.appliedDonation.formattedDateTime}',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing20),

            // 취소 사유 템플릿 선택
            if (!isLoadingTemplates && reasonTemplates.isNotEmpty) ...[
              Text(
                '자주 사용하는 중지 사유',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.lightGray),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: ListView.builder(
                  itemCount: reasonTemplates.length,
                  itemBuilder: (context, index) {
                    final template = reasonTemplates[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        template,
                        style: AppTheme.bodySmallStyle,
                      ),
                      onTap: () {
                        setState(() {
                          _reasonController.text = template;
                        });
                        _validateReason();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
            ],

            // 취소 사유 입력
            Text(
              '중지 사유 *',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '헌혈을 중지하는 사유를 입력해주세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(
                    color: AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) => _validateReason(),
            ),

            // 유효성 검사 메시지
            if (validationMessage != null) ...[
              const SizedBox(height: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: _getValidationColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(color: _getValidationColor()),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getValidationIcon(),
                      size: 16,
                      color: _getValidationColor(),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        validationMessage!,
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: _getValidationColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppTheme.spacing20),

            // 주의사항
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade600, size: 16),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      '중지 후 관리자 승인이 필요하며, 사용자에게 알림이 발송됩니다.',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 버튼 영역
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canSubmit() ? _cancelBloodDonation : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                    child: isSubmitting 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('헌혈 중지'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getValidationColor() {
    switch (validationLevel) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getValidationIcon() {
    switch (validationLevel) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  bool _canSubmit() {
    if (isSubmitting) return false;
    if (validationLevel == 'error') return false;
    
    final reasonText = _reasonController.text.trim();
    return reasonText.isNotEmpty && reasonText.length >= 2;
  }

  Future<void> _cancelBloodDonation() async {
    if (!_canSubmit()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final reason = _reasonController.text.trim();
      
      // 실제 취소 처리 대신 상태만 pendingCancellation으로 변경
      await AppliedDonationService.updateApplicationStatus(
        widget.appliedDonation.appliedDonationIdx!,
        AppliedDonationStatus.pendingCancellation,
      );

      if (mounted) {
        // 임시로 CancelledDonation 객체 생성 (실제로는 관리자 승인 후에 생성됨)
        final tempCancelledDonation = CancelledDonation(
          appliedDonationIdx: widget.appliedDonation.appliedDonationIdx!,
          cancelledSubject: CancelledSubject.hospital,
          cancelledReason: reason,
          cancelledAt: DateTime.now(),
          petName: widget.appliedDonation.pet?.name,
          postTitle: widget.appliedDonation.postTitle,
        );
        
        widget.onCancelled(tempCancelledDonation);
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '헌혈이 중지 처리되었습니다.\n관리자 승인 후 최종 취소됩니다.'
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('헌혈 중지 처리 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}