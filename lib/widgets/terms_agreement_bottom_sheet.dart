import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// 헌혈 신청 직전에 띄우는 주의사항 + 개인정보 처리 동의 바텀시트.
///
/// 동의 체크 후 "확인"을 누르면 시트를 먼저 닫고, 다음 프레임에 [onConfirm]을
/// 호출. 이렇게 두 단계로 분리하는 이유는 [onConfirm]에서 또 다른 다이얼로그를
/// 띄울 때 현재 시트의 build 컨텍스트와 충돌하지 않게 하기 위함.
class TermsAgreementBottomSheet extends StatefulWidget {
  final VoidCallback onConfirm;

  const TermsAgreementBottomSheet({super.key, required this.onConfirm});

  @override
  State<TermsAgreementBottomSheet> createState() =>
      _TermsAgreementBottomSheetState();
}

class _TermsAgreementBottomSheetState extends State<TermsAgreementBottomSheet> {
  bool isAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  '헌혈 주의사항 및 동의',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 주의사항 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '헌혈 전 주의사항',
                    style: AppTheme.h4Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNoticeItem('• 헌혈 전 8시간 이상 금식이 필요합니다.'),
                  _buildNoticeItem('• 건강한 상태의 반려동물만 헌혈 가능합니다.'),
                  _buildNoticeItem('• 헌혈 후 충분한 휴식이 필요합니다.'),
                  _buildNoticeItem('• 예방접종이 완료된 반려동물만 참여 가능합니다.'),
                  _buildNoticeItem('• 헌혈량은 체중에 따라 결정됩니다.'),

                  const SizedBox(height: 24),

                  Text(
                    '개인정보 처리 동의',
                    style: AppTheme.h4Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNoticeItem('• 헌혈 신청을 위한 개인정보 수집에 동의합니다.'),
                  _buildNoticeItem('• 수집된 정보는 헌혈 관련 목적으로만 사용됩니다.'),
                  _buildNoticeItem('• 개인정보는 안전하게 보관되며 목적 달성 후 파기됩니다.'),
                ],
              ),
            ),
          ),

          // 동의 체크박스 및 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isAgreed,
                      onChanged: (value) {
                        setState(() {
                          isAgreed = value ?? false;
                        });
                      },
                      activeColor: AppTheme.success,
                    ),
                    Expanded(
                      child: Text(
                        '위의 주의사항을 숙지 및 개인정보 처리에 동의합니다.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          '취소',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            isAgreed
                                ? () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    widget.onConfirm();
                                  });
                                }
                                : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.success,
                          side: BorderSide(
                            color: isAgreed
                                ? AppTheme.success
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          '확인',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: isAgreed
                                ? AppTheme.success
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTheme.bodyMediumStyle.copyWith(height: 1.5)),
    );
  }
}
