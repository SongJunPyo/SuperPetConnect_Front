// hospital/donation_cancellation_sheet.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    // 텍스트 변경 감지를 위한 리스너 추가
    _reasonController.addListener(() {
      setState(() {});
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
            ),


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
                  child: OutlinedButton(
                    onPressed: _canSubmit() ? _cancelBloodDonation : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
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
                              color: Colors.red.shade700,
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


  bool _canSubmit() {
    if (isSubmitting) return false;
    
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