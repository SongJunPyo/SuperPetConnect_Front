import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/time_format_util.dart';
import '../donation_history_sheet.dart';
import '../info_row.dart';

/// 관리자 화면에서 신청자 상세 정보를 시트로 표시.
///
/// 사용자 기본 정보 (이름/닉네임/연락처) + 반려동물 정보 (이름/품종/생년월일/혈액형/직전 헌혈일) +
/// [DonationHistorySection]을 한 시트에 묶어 보여줌.
void showApplicantDetailBottomSheet(
  BuildContext context,
  Map<String, dynamic> applicant,
) {
  final petInfo = applicant['pet_info'] as Map<String, dynamic>? ?? {};
  final petIdx = applicant['pet_idx'] as int?;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '신청자 정보',
                      style: AppTheme.h3Style.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _ApplicantInfoSection(applicant: applicant, petInfo: petInfo),
                  const SizedBox(height: 24),
                  DonationHistorySection(petIdx: petIdx),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ApplicantInfoSection extends StatelessWidget {
  final Map<String, dynamic> applicant;
  final Map<String, dynamic> petInfo;

  const _ApplicantInfoSection({
    required this.applicant,
    required this.petInfo,
  });

  @override
  Widget build(BuildContext context) {
    String birthDateText = '-';
    final birthDateRaw = petInfo['birth_date'];
    if (birthDateRaw != null && birthDateRaw.toString().isNotEmpty) {
      final birthDate = DateTime.tryParse(birthDateRaw.toString());
      birthDateText = birthDateRaw.toString().split('T')[0].replaceAll('-', '.');
      if (birthDate != null) {
        final months = (DateTime.now().year - birthDate.year) * 12 +
            (DateTime.now().month - birthDate.month);
        final ageText = months < 12 ? '$months개월' : '${months ~/ 12}살';
        birthDateText = '$birthDateText ($ageText)';
      }
    }

    final lastDonation = petInfo['last_donation_date'];
    final lastDonationText =
        (lastDonation == null || lastDonation.toString().isEmpty)
            ? '첫 헌혈을 기다리는 중'
            : TimeFormatUtils.formatFlexibleDate(lastDonation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (applicant['name'] != null &&
            applicant['name'].toString().isNotEmpty)
          _row('이름', applicant['name'].toString()),
        if (applicant['nickname'] != null &&
            applicant['nickname'].toString().isNotEmpty)
          _row('닉네임', applicant['nickname'].toString()),
        _row(
          '연락처',
          formatPhoneNumber(
            applicant['contact'] as String?,
            fallback: '연락처 없음',
          ),
        ),
        const Divider(height: 24),
        _row(
          '반려동물',
          '${petInfo['name'] ?? '-'} (${petInfo['breed'] ?? '-'})',
        ),
        _row('생년월일', birthDateText),
        _row('혈액형', petInfo['blood_type'] ?? '-'),
        _row('직전 헌혈일', lastDonationText),
      ],
    );
  }

  Widget _row(String label, String value) {
    return InfoRow(
      label: label,
      value: value,
      labelWidth: 100,
      padding: const EdgeInsets.symmetric(vertical: 6),
    );
  }
}
