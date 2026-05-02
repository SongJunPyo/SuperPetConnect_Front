import 'package:flutter/material.dart';

import '../models/applied_donation_model.dart';
import '../services/applied_donation_service.dart';
import '../utils/app_theme.dart';

/// 헌혈 신청 취소(또는 정보 확인) 바텀시트.
///
/// [application]의 `canCancel` 값에 따라 모드가 갈림:
/// - true: 빨간 "신청 취소" 버튼 노출. 누르면
///   `AppliedDonationService.cancelApplicationToServer`로 DELETE 호출 후
///   [onCancelSuccess]를 실행 (보통 부모가 `Navigator.pop(context, true)`로 처리).
/// - false: 단순 신청 정보 + 취소 불가 사유만 노출 (관리자/병원이 이미 처리한 케이스).
class CancelApplicationBottomSheet extends StatefulWidget {
  final MyApplicationInfo application;
  final VoidCallback onCancelSuccess;

  const CancelApplicationBottomSheet({
    super.key,
    required this.application,
    required this.onCancelSuccess,
  });

  @override
  State<CancelApplicationBottomSheet> createState() =>
      _CancelApplicationBottomSheetState();
}

class _CancelApplicationBottomSheetState
    extends State<CancelApplicationBottomSheet> {
  bool isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final canCancel = widget.application.canCancel;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들바
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          Row(
            children: [
              Icon(
                canCancel ? Icons.cancel_outlined : Icons.info_outline,
                color: canCancel ? Colors.red : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                canCancel ? '신청 취소' : '신청 정보',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 신청 정보 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('게시글', widget.application.postTitle),
                const SizedBox(height: 8),
                _buildInfoRow(
                  '반려동물',
                  '${widget.application.petName} (${widget.application.speciesText})',
                ),
                const SizedBox(height: 8),
                _buildInfoRow('헌혈 시간', widget.application.donationTime),
                const SizedBox(height: 8),
                _buildInfoRow(
                  '상태',
                  widget.application.status,
                  statusColor: _getStatusColor(widget.application.statusCode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 취소 가능/불가 메시지
          if (!canCancel) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.application.cancelBlockMessage,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('닫기'),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isCancelling ? null : _handleCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        isCancelling
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text('신청 취소'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: statusColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(int statusCode) {
    return AppliedDonationStatus.getStatusColorValue(statusCode);
  }

  Future<void> _handleCancel() async {
    setState(() {
      isCancelling = true;
    });

    try {
      await AppliedDonationService.cancelApplicationToServer(
        widget.application.applicationId,
      );

      if (mounted) {
        // 취소 성공 콜백 호출 (Navigator.pop(context, true) 포함)
        widget.onCancelSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isCancelling = false;
        });

        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('취소 실패'),
              ],
            ),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }
}
