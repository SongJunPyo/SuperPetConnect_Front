import 'package:flutter/material.dart';

import '../../admin/admin_donation_survey_detail.dart';
import '../../models/donation_survey_model.dart';
import '../../services/donation_post_image_service.dart';
import '../../services/donation_survey_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pet_field_icons.dart';
import '../../utils/pet_image_downloader.dart';
import '../../utils/phone_formatter.dart';
import '../donation_history_sheet.dart';
import '../info_row.dart';
import '../pet/profile_vertical_card.dart';
import '../pet_status_row.dart';

/// 관리자 화면에서 신청자 상세 정보를 시트로 표시.
///
/// 사용자 기본 정보 (이름/닉네임/연락처) + 반려동물 정보 (이름/품종/생년월일/혈액형/최근 헌혈일) +
/// [DonationHistorySection]을 한 시트에 묶어 보여줌.
///
/// [postIdx] / [postStatus]를 함께 전달하면 모집마감(3) / 헌혈완료(4) 시점에
/// '사전 설문 보기' 버튼이 노출됨. 미전달 시 버튼 숨김 (backward compat).
void showApplicantDetailBottomSheet(
  BuildContext context,
  Map<String, dynamic> applicant, {
  int? postIdx,
  int? postStatus,
}) {
  final petInfo = applicant['pet_info'] as Map<String, dynamic>? ?? {};
  final petIdx = applicant['pet_idx'] as int?;
  final applicationIdRaw = applicant['id'];
  final applicationId = applicationIdRaw is int ? applicationIdRaw : null;
  final showSurveyButton = postIdx != null &&
      applicationId != null &&
      (postStatus == 3 || postStatus == 4);

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
                  if (showSurveyButton)
                    _SurveyButton(
                      postIdx: postIdx,
                      applicationId: applicationId,
                    ),
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

/// 사전 설문 보기 버튼 — 모집마감/헌혈완료에서만 노출.
/// `getByPost`로 게시글의 설문 list를 받아 `application_id` 매칭 후 단건 detail로 push.
/// 매칭 실패 시 SnackBar.
class _SurveyButton extends StatefulWidget {
  final int postIdx;
  final int applicationId;

  const _SurveyButton({
    required this.postIdx,
    required this.applicationId,
  });

  @override
  State<_SurveyButton> createState() => _SurveyButtonState();
}

class _SurveyButtonState extends State<_SurveyButton> {
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final list = await AdminSurveyService.getByPost(widget.postIdx);
      if (!mounted) return;
      DonationSurveyListItem? matched;
      for (final e in list.items) {
        if (e.appliedDonationIdx == widget.applicationId) {
          matched = e;
          break;
        }
      }
      if (matched == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('제출된 사전 설문이 없습니다')),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              AdminDonationSurveyDetail(surveyIdx: matched!.surveyIdx),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '설문 조회 실패: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _loading ? null : _open,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('사전 설문 보기'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryBlue,
            side: const BorderSide(color: AppTheme.primaryBlue),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
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
    final applicantNickname = applicant['nickname']?.toString();
    // BE 응답 키 (병원 측과 통일): applicant_profile_image — 보호자 본인의 대표 펫 사진.
    // GET /api/admin/time-slots/{id}/applicants → ApplicantResponse.applicant_profile_image.
    final applicantProfileImage =
        applicant['applicant_profile_image']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === 보호자 닉네임 헤더 (가운데 사진 + 닉네임) ===
        if (applicantNickname != null && applicantNickname.isNotEmpty)
          Center(
            child: ProfileVerticalCard(
              profileImage: applicantProfileImage,
              name: applicantNickname,
              avatarRadius: 28,
            ),
          ),
        // === 사용자 정보 (이름/연락처) ===
        if (applicant['name'] != null &&
            applicant['name'].toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          _row(PetFieldIcons.userName, '이름', applicant['name'].toString()),
        ],
        _row(
          PetFieldIcons.phone,
          '연락처',
          formatPhoneNumber(
            applicant['contact'] as String?,
            fallback: '연락처 없음',
          ),
        ),
        const Divider(height: 24),
        // === 펫 헤더 (가운데 큰 사진 + 이름) ===
        // 종/품종은 별도 InfoRow로 표시. 사진 다운로드는 사진 오른쪽에 imageTrailing.
        if (petInfo['name'] != null)
          Center(
            child: ProfileVerticalCard(
              profileImage: petInfo['profile_image']?.toString(),
              species: petInfo['species']?.toString(),
              name: petInfo['name'].toString(),
              imageTrailing: (petInfo['profile_image']?.toString().isNotEmpty ?? false)
                  ? IconButton(
                      onPressed: () => _onDownloadPet(context),
                      icon: const Icon(Icons.download_outlined),
                      tooltip: '사진 다운로드',
                      color: AppTheme.primaryBlue,
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
          ),
        // === 펫 정보 (13필드 통일 set — CLAUDE.md 통일 패턴) ===
        // 백엔드 admin/time-slots/applicants 응답이 19필드 nested pet_info를 보냄 (2026-05-08).
        // hospital_post_check / donation_completion_sheet / applicant_card와 같은 분기 패턴.
        ..._buildPetInfoRows(),
      ],
    );
  }

  /// 펫 프로필 사진 다운로드 — SnackBar UX 포함 헬퍼 위임.
  Future<void> _onDownloadPet(BuildContext context) async {
    final raw = petInfo['profile_image']?.toString();
    if (raw == null || raw.isEmpty) return;
    final imageUrl = DonationPostImageService.getFullImageUrl(raw);
    final petName = petInfo['name']?.toString() ?? 'pet';
    final filename = '${petName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.jpg';
    await downloadPetImageWithFeedback(
      context: context,
      imageUrl: imageUrl,
      filename: filename,
    );
  }

  /// 펫 13필드 통일 패턴 (date row OR critical/warning/neutral status row).
  /// petInfo Map 직접 read — ApplicantPetInfo 모델 변환 없이 light-weight 처리.
  /// 이름은 ProfileVerticalCard 헤더, 종/품종은 InfoRow 첫 항목으로 분리.
  List<Widget> _buildPetInfoRows() {
    final rows = <Widget>[];

    // 종 (animalType / species)
    final species = petInfo['species']?.toString();
    if (species != null && species.isNotEmpty) {
      rows.add(_row(PetFieldIcons.species, '종', species));
    }

    // 품종 (breed)
    final breed = petInfo['breed']?.toString();
    if (breed != null && breed.isNotEmpty) {
      rows.add(_row(PetFieldIcons.breed, '품종', breed));
    }

    // 성별
    final sex = petInfo['sex'] as int?;
    if (sex != null) {
      rows.add(_row(
        PetFieldIcons.sex(sex),
        '성별',
        sex == 0 ? '암컷' : '수컷',
      ));
    }

    // 혈액형
    final bloodType = petInfo['blood_type']?.toString();
    if (bloodType != null && bloodType.isNotEmpty) {
      rows.add(_row(PetFieldIcons.bloodType, '혈액형', bloodType));
    }

    // 체중
    final weightKg = petInfo['weight_kg'];
    if (weightKg != null) {
      rows.add(_row(PetFieldIcons.weight, '체중', '${weightKg}kg'));
    }

    // 생년월일 + 나이
    final birthDateRaw = petInfo['birth_date']?.toString();
    if (birthDateRaw != null && birthDateRaw.isNotEmpty) {
      rows.add(_row(PetFieldIcons.birthDate, '생년월일',
          _formatBirthDate(birthDateRaw)));
    }

    // 최근 헌혈일
    final lastDonation = petInfo['last_donation_date']?.toString();
    if (lastDonation != null && lastDonation.isNotEmpty) {
      rows.add(_row(PetFieldIcons.prevDonationDate, '최근 헌혈일',
          lastDonation.replaceAll('-', '.')));
    } else {
      rows.add(_status(PetFieldIcons.prevDonationDate, '최근 헌혈일',
          PetStatusType.neutral));
    }

    // 종합백신
    final vaccinated = petInfo['vaccinated'] as bool?;
    final lastVaccDate = petInfo['last_vaccination_date']?.toString();
    if (vaccinated == true && lastVaccDate != null && lastVaccDate.isNotEmpty) {
      rows.add(_row(PetFieldIcons.vaccinated, '종합백신',
          lastVaccDate.replaceAll('-', '.')));
    } else if (vaccinated != null) {
      rows.add(_status(PetFieldIcons.vaccinated, '종합백신',
          PetStatusType.critical));
    }

    // 항체검사 (값 있을 때만)
    final antibodyDate = petInfo['last_antibody_test_date']?.toString();
    if (vaccinated == true &&
        antibodyDate != null &&
        antibodyDate.isNotEmpty) {
      rows.add(_row(PetFieldIcons.antibodyTestDate, '항체검사',
          antibodyDate.replaceAll('-', '.')));
    }

    // 예방약
    final hasMed = petInfo['has_preventive_medication'] as bool?;
    final lastMedDate = petInfo['last_preventive_medication_date']?.toString();
    if (hasMed == true && lastMedDate != null && lastMedDate.isNotEmpty) {
      rows.add(_row(PetFieldIcons.medication, '예방약',
          lastMedDate.replaceAll('-', '.')));
    } else if (hasMed != null) {
      rows.add(_status(PetFieldIcons.medication, '예방약',
          PetStatusType.critical));
    }

    // 중성화
    final isNeutered = petInfo['is_neutered'] as bool?;
    final neuteredDate = petInfo['neutered_date']?.toString();
    if (isNeutered == true &&
        neuteredDate != null &&
        neuteredDate.isNotEmpty) {
      rows.add(_row(PetFieldIcons.isNeutered, '중성화',
          neuteredDate.replaceAll('-', '.')));
    } else if (isNeutered != null) {
      rows.add(_status(
        PetFieldIcons.isNeutered,
        '중성화',
        isNeutered == true ? PetStatusType.warning : PetStatusType.neutral,
      ));
    }

    // 질병
    final hasDisease = petInfo['has_disease'] as bool?;
    if (hasDisease != null) {
      rows.add(_status(
        PetFieldIcons.hasDisease,
        '질병',
        hasDisease == true ? PetStatusType.critical : PetStatusType.neutral,
      ));
    }

    // 임신/출산 (수컷이면 hidden)
    final pregnancyStatus = petInfo['pregnancy_birth_status'] as int?;
    final lastPregEnd = petInfo['last_pregnancy_end_date']?.toString();
    if (sex == 0) {
      if (pregnancyStatus == 2 &&
          lastPregEnd != null &&
          lastPregEnd.isNotEmpty) {
        rows.add(_row(PetFieldIcons.pregnancyBirth, '임신/출산',
            '출산 ${lastPregEnd.replaceAll('-', '.')}'));
      } else {
        rows.add(_status(
          PetFieldIcons.pregnancyBirth,
          '임신/출산',
          pregnancyStatus == 1
              ? PetStatusType.warning
              : PetStatusType.neutral,
        ));
      }
    }

    // 외부 헌혈 횟수
    final priorCount = petInfo['prior_donation_count'] as int?;
    if (priorCount != null && priorCount > 0) {
      rows.add(_row(
          PetFieldIcons.prevDonationDate, '외부 헌혈', '$priorCount회'));
    }

    return rows;
  }

  String _formatBirthDate(String birthDateRaw) {
    final birthDate = DateTime.tryParse(birthDateRaw);
    String text = birthDateRaw.split('T')[0].replaceAll('-', '.');
    if (birthDate != null) {
      final months = (DateTime.now().year - birthDate.year) * 12 +
          (DateTime.now().month - birthDate.month);
      final ageText = months < 12 ? '$months개월' : '${months ~/ 12}살';
      text = '$text ($ageText)';
    }
    return text;
  }

  Widget _row(IconData icon, String label, String value) {
    return InfoRow(
      icon: icon,
      label: label,
      value: value,
      labelWidth: 100,
      padding: const EdgeInsets.symmetric(vertical: 6),
    );
  }

  Widget _status(IconData icon, String label, PetStatusType status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PetStatusRow(icon: icon, label: label, status: status),
    );
  }
}
