// hospital/donation_completion_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_theme.dart';
import '../models/applied_donation_model.dart';
import '../models/completed_donation_model.dart';
import '../services/completed_donation_service.dart';

class DonationCompletionSheet extends StatefulWidget {
  final AppliedDonation appliedDonation;
  final Function(CompletedDonation) onCompleted;

  const DonationCompletionSheet({
    super.key,
    required this.appliedDonation,
    required this.onCompleted,
  });

  @override
  State<DonationCompletionSheet> createState() => _DonationCompletionSheetState();
}

class _DonationCompletionSheetState extends State<DonationCompletionSheet> {
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
      // 기본값으로 0.0 설정
      _bloodVolumeController.text = '0.0';
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
                        '헌혈 완료 처리',
                        style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.appliedDonation.formattedDate} ${widget.appliedDonation.formattedTime}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
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
            
            // 구분선
            Container(
              height: 1,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.only(bottom: AppTheme.spacing20),
            ),

            // 반려동물 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    '반려동물 정보',
                    textAlign: TextAlign.left,
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 신청자
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.user,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '신청자: ${widget.appliedDonation.userNickname ?? "정보 없음"}',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 반려동물
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: FaIcon(
                            (widget.appliedDonation.pet?.animalTypeKr == '강아지') 
                              ? FontAwesomeIcons.dog 
                              : FontAwesomeIcons.cat,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '반려동물: ${widget.appliedDonation.pet?.name ?? "정보 없음"}(${widget.appliedDonation.pet?.breed ?? "품종 정보 없음"})',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 혈액형
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.droplet,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '혈액형: ${widget.appliedDonation.pet?.bloodType ?? "미등록"}',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 몸무게
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.weightScale,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '몸무게: ${widget.appliedDonation.pet?.weightKg ?? 0.0}kg',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 나이
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.cakeCandles,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '나이: ${widget.appliedDonation.pet?.age ?? 0}살',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacing20),

            // 헌혈량 입력
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '헌혈량 (mL)',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bloodVolumeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
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
                ),
              ],
            ),


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
                      '${selectedCompletedTime.hour.toString().padLeft(2, '0')}:${selectedCompletedTime.minute.toString().padLeft(2, '0')}',
                      style: AppTheme.bodyMediumStyle,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing24),

            // 완료 처리 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canSubmit() ? _completeBloodDonation : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade400),
                  backgroundColor: Colors.green.shade50,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                ),
                child: isSubmitting 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.green.shade700,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('헌혈 완료 처리', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
          ],
        ),
      ),
    );
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