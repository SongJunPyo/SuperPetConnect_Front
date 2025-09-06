// hospital/donation_cancellation_sheet.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/applied_donation_model.dart';
import '../models/cancelled_donation_model.dart';
import '../services/cancelled_donation_service.dart';

class DonationCancellationSheet extends StatefulWidget {
  final AppliedDonation appliedDonation;
  final Function(CancelledDonation) onCancelled;

  const DonationCancellationSheet({
    super.key,
    required this.appliedDonation,
    required this.onCancelled,
  });

  @override
  State<DonationCancellationSheet> createState() => _DonationCancellationSheetState();
}

class _DonationCancellationSheetState extends State<DonationCancellationSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool isSubmitting = false;
  String? validationMessage;
  String? validationLevel;
  List<String> reasonTemplates = [];
  String? selectedTemplate;

  @override
  void initState() {
    super.initState();
    _loadReasonTemplates();
  }

  Future<void> _loadReasonTemplates() async {
    try {
      final templates = await CancelledDonationService.getReasonTemplatesForSubject(
        CancelledSubject.hospital,
      );
      setState(() {
        reasonTemplates = templates;
      });
    } catch (e) {
      // 템플릿 로드 실패 시 무시
    }
  }

  void _validateReason() {
    final reason = _reasonController.text.trim();
    final validation = CancelledDonationService.validateCancellationReason(reason);
    
    setState(() {
      validationMessage = validation['message'];
      validationLevel = validation['level'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들 바
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.spacing20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 중단 처리',
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
                  Text(
                    '중단 대상 정보',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.pets, size: 20, color: Colors.orange.shade600),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          widget.appliedDonation.pet?.displayInfo ?? '반려동물 정보 없음',
                          style: AppTheme.bodyMediumStyle,
                        ),
                      ),
                    ],
                  ),
                  if (widget.appliedDonation.donationTime != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 20, color: Colors.orange.shade600),
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          '예정 시간: ${widget.appliedDonation.donationTime?.toString().substring(0, 16)}',
                          style: AppTheme.bodySmallStyle,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing20),

            // 템플릿 선택 (있는 경우)
            if (reasonTemplates.isNotEmpty) ...[
              Text(
                '빠른 선택',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: reasonTemplates.map((template) {
                  final isSelected = selectedTemplate == template;
                  return ChoiceChip(
                    label: Text(template),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedTemplate = selected ? template : null;
                        if (selected) {
                          _reasonController.text = template;
                          _validateReason();
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacing20),
            ],

            // 중단 사유 입력
            Text(
              '중지 사유',
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
                  color: _getValidationColor().withValues(alpha: 0.1),
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

            const SizedBox(height: AppTheme.spacing24),

            // 버튼 영역
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                      side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
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
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
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
                        : const Text('헌혈 중단', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
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
    
    final reason = _reasonController.text.trim();
    return reason.isNotEmpty && reason.length >= 2;
  }

  Future<void> _cancelBloodDonation() async {
    if (!_canSubmit()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final request = CancelDonationRequest(
        appliedDonationIdx: widget.appliedDonation.appliedDonationIdx!,
        cancelledSubject: CancelledSubject.hospital,
        cancelledReason: _reasonController.text.trim(),
        cancelledAt: DateTime.now(),
      );

      // 병원용 1차 헌혈 중단 처리 API 호출
      final result = await CancelledDonationService.hospitalCancelBloodDonation(
        request,
      );

      if (mounted) {
        // 서버 응답에서 반환된 데이터로 CancelledDonation 객체 생성 (임시)
        final tempCancelledDonation = CancelledDonation(
          appliedDonationIdx: widget.appliedDonation.appliedDonationIdx!,
          cancelledSubject: CancelledSubject.hospital,
          cancelledReason: _reasonController.text.trim(),
          cancelledAt: DateTime.now(),
          petName: widget.appliedDonation.pet?.name,
          postTitle: widget.appliedDonation.postTitle,
        );
        
        widget.onCancelled(tempCancelledDonation);
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? '1차 중단 처리되었습니다! 관리자 승인 후 최종 취소됩니다.'
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
            content: Text('헌혈 중단 처리 실패: $e'),
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