// hospital/donation_completion_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../models/applied_donation_model.dart';
import '../models/completed_donation_model.dart';
import '../services/completed_donation_service.dart';

class DonationCompletionDialog extends StatefulWidget {
  final AppliedDonation appliedDonation;
  final Function(CompletedDonation) onCompleted;

  const DonationCompletionDialog({
    super.key,
    required this.appliedDonation,
    required this.onCompleted,
  });

  @override
  State<DonationCompletionDialog> createState() => _DonationCompletionDialogState();
}

class _DonationCompletionDialogState extends State<DonationCompletionDialog> {
  final TextEditingController _bloodVolumeController = TextEditingController();
  DateTime selectedCompletedDate = DateTime.now();
  TimeOfDay selectedCompletedTime = TimeOfDay.now();
  bool isSubmitting = false;
  String? validationMessage;
  String? validationLevel;

  @override
  void initState() {
    super.initState();
    _initializeRecommendedVolume();
    _validateBloodVolume();
  }

  void _initializeRecommendedVolume() {
    // 반려동물 체중이 있으면 권장 헌혈량으로 초기화
    if (widget.appliedDonation.pet?.weightKg != null && 
        widget.appliedDonation.pet!.weightKg! > 0) {
      final recommended = CompletedDonation.getRecommendedBloodVolume(
        widget.appliedDonation.pet!.weightKg!
      );
      _bloodVolumeController.text = recommended.toStringAsFixed(1);
    } else {
      // 기본값으로 200mL 설정
      _bloodVolumeController.text = '200.0';
    }
  }

  void _validateBloodVolume() {
    final volumeText = _bloodVolumeController.text.trim();
    if (volumeText.isEmpty) {
      setState(() {
        validationMessage = null;
        validationLevel = null;
      });
      return;
    }

    final volume = double.tryParse(volumeText);
    if (volume == null) {
      setState(() {
        validationMessage = '올바른 숫자를 입력해주세요.';
        validationLevel = 'error';
      });
      return;
    }

    final validation = CompletedDonationService.validateBloodVolume(
      volume, 
      widget.appliedDonation.pet?.weightKg
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
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: SingleChildScrollView(
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
                        '헌혈 완료 처리',
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
                color: AppTheme.lightBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: AppTheme.lightBlue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '반려동물 정보',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.pets, size: 20, color: AppTheme.primaryBlue),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          widget.appliedDonation.pet?.displayInfo ?? '반려동물 정보 없음',
                          style: AppTheme.bodyMediumStyle,
                        ),
                      ),
                    ],
                  ),
                  if (widget.appliedDonation.pet?.weightKg != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      '권장 헌혈량: ${CompletedDonation.getRecommendedBloodVolume(widget.appliedDonation.pet!.weightKg!).toStringAsFixed(1)}mL (체중 ${widget.appliedDonation.pet!.weightKg}kg 기준)',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: Colors.green.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing20),

            // 헌혈량 입력
            Text(
              '헌혈량 (mL)',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            TextField(
              controller: _bloodVolumeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                hintText: '헌혈량을 입력하세요 (mL)',
                suffixText: 'mL',
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
              onChanged: (value) => _validateBloodVolume(),
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

            const SizedBox(height: AppTheme.spacing20),

            // 완료 시간 설정
            Text(
              '헌혈 완료 시간',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            
            Row(
              children: [
                // 날짜 선택
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedCompletedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedCompletedDate = pickedDate;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      '${selectedCompletedDate.month}/${selectedCompletedDate.day}',
                      style: AppTheme.bodyMediumStyle,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                
                // 시간 선택
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedCompletedTime,
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedCompletedTime = pickedTime;
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      selectedCompletedTime.format(context),
                      style: AppTheme.bodyMediumStyle,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing20),

            // 완료 처리 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _completeBloodDonation : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                    : const Text('헌혈 완료 처리'),
              ),
            ),
            ],
          ),
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
    
    final volumeText = _bloodVolumeController.text.trim();
    if (volumeText.isEmpty) return false;
    
    final volume = double.tryParse(volumeText);
    return volume != null && volume > 0;
  }

  Future<void> _completeBloodDonation() async {
    if (!_canSubmit()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final volume = double.parse(_bloodVolumeController.text.trim());
      final completedAt = DateTime(
        selectedCompletedDate.year,
        selectedCompletedDate.month,
        selectedCompletedDate.day,
        selectedCompletedTime.hour,
        selectedCompletedTime.minute,
      );

      final request = CompleteDonationRequest(
        appliedDonationIdx: widget.appliedDonation.appliedDonationIdx!,
        bloodVolume: volume,
        completedAt: completedAt,
      );

      // 병원용 1차 헌혈 완료 처리 API 호출
      final result = await CompletedDonationService.hospitalCompleteBloodDonation(
        request,
      );

      if (mounted) {
        // 서버 응답에서 반환된 데이터로 CompletedDonation 객체 생성
        final tempCompletedDonation = CompletedDonation(
          appliedDonationIdx: widget.appliedDonation.appliedDonationIdx!,
          bloodVolume: volume,
          completedAt: completedAt,
          petName: widget.appliedDonation.pet?.name,
          postTitle: widget.appliedDonation.postTitle,
        );
        
        widget.onCompleted(tempCompletedDonation);
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? '1차 완료 처리되었습니다! 관리자 승인 후 최종 완료됩니다.\n헌혈량: ${volume.toStringAsFixed(1)}mL'
            ),
            backgroundColor: Colors.green,
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
            content: Text('헌혈 완료 처리 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _bloodVolumeController.dispose();
    super.dispose();
  }
}