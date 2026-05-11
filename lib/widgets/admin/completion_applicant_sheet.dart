import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/donation_post_image_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pet_field_icons.dart';
import '../../utils/pet_image_downloader.dart';
import '../../utils/time_format_util.dart';
import '../donation_history_sheet.dart';
import '../info_row.dart';
import '../pet/profile_vertical_card.dart';
import '../pet_profile_image.dart';
import '../pet_status_row.dart';
import '../post_detail/post_detail_description.dart';

/// 헌혈마감 / 헌혈완료 탭에서 확정 신청자 1명의 정보를 표시할 때
/// 호출되는 액션 묶음. 모든 콜백 nullable — 해당 status에서 보일 버튼 콜백만 채움.
class CompletionApplicantSheetActions {
  /// status 2 (PENDING_COMPLETION) — "헌혈 마감" 버튼.
  final void Function(int applicationId)? onFinalApproveCompletion;

  /// status 3 (COMPLETED) — "헌혈 자료 요청" 버튼.
  final void Function(int applicationId)? onRequestDocuments;

  const CompletionApplicantSheetActions({
    this.onFinalApproveCompletion,
    this.onRequestDocuments,
  });
}

/// 헌혈완료/취소된 게시글의 **확정 신청자 1명**에 대한 모든 정보를 시트로 표시.
///
/// 게시글 정보 + 신청자 + 펫 정보 + 헌혈 이력 ([DonationHistorySection]) +
/// status별 액션 버튼을 한 시트에 묶어서 보여줌.
///
/// applications 배열에서 첫 번째 신청자를 자동으로 펼침
/// (헌혈완료/취소는 신청자가 1명으로 확정된 상태이므로 1건 가정).
void showCompletionApplicantSheet(
  BuildContext context, {
  required Map<String, dynamic> post,
  CompletionApplicantSheetActions actions =
      const CompletionApplicantSheetActions(),
}) {
  final applications = post['applications'] as List<dynamic>? ?? [];
  final applicant = applications.isNotEmpty
      ? applications.first as Map<String, dynamic>? ?? {}
      : <String, dynamic>{};

  int? petIdx;
  final postPetIdx = post['pet_idx'];
  final applicantPetIdx = applicant['pet_idx'];

  if (postPetIdx != null) {
    petIdx =
        postPetIdx is int ? postPetIdx : int.tryParse(postPetIdx.toString());
  } else if (applicantPetIdx != null) {
    petIdx = applicantPetIdx is int
        ? applicantPetIdx
        : int.tryParse(applicantPetIdx.toString());
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
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
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (post['hospitalProfileImage'] != null ||
                      post['hospital_profile_image'] != null) ...[
                    PetProfileImage(
                      profileImage: post['hospitalProfileImage'] ??
                          post['hospital_profile_image'],
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      post['title'] ?? '제목 없음',
                      style: AppTheme.h3Style.copyWith(
                        color: post['types'] == 0
                            ? Colors.red
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '닫기',
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaSection(post: post),
                    PostDetailDescription(
                      contentDelta: post['contentDelta']?.toString(),
                      plainText: post['description']?.toString(),
                    ),
                    if (post['user_nickname'] != null &&
                        post['user_nickname'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('신청자 정보', style: AppTheme.h4Style),
                      const SizedBox(height: 12),
                      _ApplicantInfoCard(post: post),
                    ],
                    if (post['status'] != 2) ...[
                      const SizedBox(height: 24),
                      DonationHistorySection(petIdx: petIdx),
                    ],
                    if (post['status'] == 2 &&
                        actions.onFinalApproveCompletion != null) ...[
                      const SizedBox(height: 24),
                      _ActionButton(
                        label: '헌혈 마감',
                        color: Colors.green,
                        onPressed: () {
                          Navigator.of(context).pop();
                          actions.onFinalApproveCompletion!(
                            post['application_id'] ?? post['id'] ?? 0,
                          );
                        },
                      ),
                    ],
                    if (post['status'] == 3 &&
                        actions.onRequestDocuments != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => actions.onRequestDocuments!(
                            applicant['applied_donation_idx'] as int? ??
                                post['applied_donation_idx'] as int? ??
                                0,
                          ),
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: const Text('헌혈 자료 요청'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: BorderSide(color: AppTheme.mediumGray),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetaSection extends StatelessWidget {
  final Map<String, dynamic> post;

  const _MetaSection({required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  PetFieldIcons.hospital,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '병원명: ',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  post['nickname'] ?? '병원',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              post['created_date'] ?? '',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              PetFieldIcons.postLocation,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '주소: ',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Expanded(
              child: Text(
                post['location'] ?? '주소 정보 없음',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (post['donation_date'] != null &&
            post['donation_date'].toString().isNotEmpty)
          Row(
            children: [
              Icon(
                PetFieldIcons.donationDate,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '헌혈 일정: ',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  TimeFormatUtils.formatKoreanDateTimeWithWeekday(
                    post['donation_date'],
                  ),
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ApplicantInfoCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _ApplicantInfoCard({required this.post});

  /// 평면 키(`pet_sex`)와 nested 키(`pet.sex`) 양쪽에서 펫 필드를 읽음.
  /// admin/posts 응답이 어느 형태로 보내는지 확정 안 돼 양쪽 fallback.
  /// 둘 다 null이면 화면에서 hidden 또는 critical 처리.
  T? _petField<T>(String key) {
    final flat = post['pet_$key'];
    if (flat is T) return flat;
    final nested = post['pet'];
    if (nested is Map) {
      final v = nested[key];
      if (v is T) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 진단 로그 — admin/posts 응답에 어떤 펫 필드들이 들어오는지 1회 확인용.
    // 사용자 검증 후 평면/nested 확정되면 제거.
    if (kDebugMode) {
      final keysWithPet =
          post.keys.where((k) => k.toString().startsWith('pet')).toList();
      debugPrint(
        '[CompletionApplicantSheet] post keys with "pet": $keysWithPet',
      );
      if (post['pet'] is Map) {
        debugPrint(
          '[CompletionApplicantSheet] nested pet keys: ${(post['pet'] as Map).keys.toList()}',
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildRows(context),
      ),
    );
  }

  List<Widget> _buildRows(BuildContext context) {
    final rows = <Widget>[];

    // === 보호자 닉네임 헤더 (가운데 사진 + 닉네임) ===
    // BE 응답 키 통일: applicant_profile_image (병원/admin 두 시트 동일).
    // PendingApplicationItem 응답에 추가됨 — GET /api/admin/pending-donations 류.
    final userNickname = post['user_nickname']?.toString();
    final userProfileImage = post['applicant_profile_image']?.toString();
    if (userNickname != null && userNickname.isNotEmpty) {
      rows.add(Center(
        child: ProfileVerticalCard(
          profileImage: userProfileImage,
          name: userNickname,
          avatarRadius: 28,
        ),
      ));
      rows.add(const SizedBox(height: 12));
    }

    // === 사용자 이름 ===
    if (post['user_name'] != null &&
        post['user_name'].toString().isNotEmpty) {
      rows.add(InfoRow(
        icon: PetFieldIcons.userName,
        label: '이름',
        value: post['user_name'].toString(),
      ));
    }

    // === 펫 헤더 (가운데 큰 사진 + 이름) ===
    // 종/품종은 별도 InfoRow로 표시. 사진 다운로드는 사진 오른쪽에 imageTrailing.
    final petName = _petField<String>('name') ?? post['pet_name']?.toString();
    final petProfileImage = _petField<String>('profile_image') ??
        post['pet_profile_image']?.toString();
    final petSpecies = _petField<String>('species') ??
        post['pet_species']?.toString();
    if (petName != null && petName.isNotEmpty) {
      rows.add(const SizedBox(height: 16));
      rows.add(Center(
        child: ProfileVerticalCard(
          profileImage: petProfileImage,
          species: petSpecies,
          name: petName,
          imageTrailing: (petProfileImage != null && petProfileImage.isNotEmpty)
              ? IconButton(
                  onPressed: () => _onDownloadPet(context, petProfileImage, petName),
                  icon: const Icon(Icons.download_outlined),
                  tooltip: '사진 다운로드',
                  color: AppTheme.primaryBlue,
                  visualDensity: VisualDensity.compact,
                )
              : null,
        ),
      ));
    }

    // === 펫 정보 (13필드 통일 set — date row OR critical status row) ===
    // 이름은 ProfileVerticalCard 헤더, 종/품종은 InfoRow 첫 항목.

    // 종 (animalType / species)
    if (petSpecies != null && petSpecies.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.species,
        label: '종',
        value: petSpecies,
      ));
    }

    // 품종 (breed)
    final petBreed =
        _petField<String>('breed') ?? post['pet_breed']?.toString();
    if (petBreed != null && petBreed.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.breed,
        label: '품종',
        value: petBreed,
      ));
    }

    // 성별
    final sex = _petField<int>('sex');
    if (sex != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.sex(sex),
        label: '성별',
        value: sex == 0 ? '암컷' : '수컷',
      ));
    }

    // 혈액형
    final bloodType = _petField<String>('blood_type') ??
        post['pet_blood_type']?.toString();
    if (bloodType != null && bloodType.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.bloodType,
        label: '혈액형',
        value: bloodType,
      ));
    }

    // 체중
    final weightKg = _petField<num>('weight_kg');
    if (weightKg != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.weight,
        label: '체중',
        value: '${weightKg}kg',
      ));
    }

    // 생년월일
    final birthDateRaw = _petField<String>('birth_date') ??
        post['pet_birth_date']?.toString();
    if (birthDateRaw != null && birthDateRaw.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(_buildBirthDateRow(birthDateRaw));
    }

    // 최근 헌혈일
    final lastDonation = _petField<String>('prev_donation_date') ??
        _petField<String>('last_donation_date');
    if (lastDonation != null && lastDonation.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.prevDonationDate,
        label: '최근 헌혈일',
        value: lastDonation.replaceAll('-', '.'),
      ));
    } else {
      rows.add(const SizedBox(height: 12));
      rows.add(_status(
          PetFieldIcons.prevDonationDate, '최근 헌혈일', PetStatusType.neutral));
    }

    // 종합백신
    final vaccinated = _petField<bool>('vaccinated');
    final lastVaccDate = _petField<String>('last_vaccination_date');
    if (vaccinated == true &&
        lastVaccDate != null &&
        lastVaccDate.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.vaccinated,
        label: '종합백신',
        value: lastVaccDate.replaceAll('-', '.'),
      ));
    } else if (vaccinated != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(_status(
          PetFieldIcons.vaccinated, '종합백신', PetStatusType.critical));
    }

    // 항체검사 (값 있을 때만)
    final antibodyDate = _petField<String>('last_antibody_test_date');
    if (vaccinated == true &&
        antibodyDate != null &&
        antibodyDate.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.antibodyTestDate,
        label: '항체검사',
        value: antibodyDate.replaceAll('-', '.'),
      ));
    }

    // 예방약
    final hasMed = _petField<bool>('has_preventive_medication');
    final lastMedDate =
        _petField<String>('last_preventive_medication_date');
    if (hasMed == true && lastMedDate != null && lastMedDate.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.medication,
        label: '예방약',
        value: lastMedDate.replaceAll('-', '.'),
      ));
    } else if (hasMed != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(
          _status(PetFieldIcons.medication, '예방약', PetStatusType.critical));
    }

    // 중성화
    final isNeutered = _petField<bool>('is_neutered');
    final neuteredDate = _petField<String>('neutered_date');
    if (isNeutered == true &&
        neuteredDate != null &&
        neuteredDate.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.isNeutered,
        label: '중성화',
        value: neuteredDate.replaceAll('-', '.'),
      ));
    } else if (isNeutered != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(_status(
        PetFieldIcons.isNeutered,
        '중성화',
        isNeutered == true ? PetStatusType.warning : PetStatusType.neutral,
      ));
    }

    // 질병
    final hasDisease = _petField<bool>('has_disease');
    if (hasDisease != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(_status(
        PetFieldIcons.hasDisease,
        '질병',
        hasDisease == true ? PetStatusType.critical : PetStatusType.neutral,
      ));
    }

    // 임신/출산 (수컷이면 hidden)
    if (sex == 0) {
      final pregnancyStatus = _petField<int>('pregnancy_birth_status');
      final lastPregEnd = _petField<String>('last_pregnancy_end_date');
      rows.add(const SizedBox(height: 12));
      if (pregnancyStatus == 2 &&
          lastPregEnd != null &&
          lastPregEnd.isNotEmpty) {
        rows.add(InfoRow(
          icon: PetFieldIcons.pregnancyBirth,
          label: '임신/출산',
          value: '출산 ${lastPregEnd.replaceAll('-', '.')}',
        ));
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
    final priorCount = _petField<int>('prior_donation_count');
    if (priorCount != null && priorCount > 0) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: PetFieldIcons.prevDonationDate,
        label: '외부 헌혈',
        value: '$priorCount회',
      ));
    }

    // 헌혈량 (헌혈완료 status 시)
    if (post['blood_volume'] != null) {
      rows.add(const SizedBox(height: 12));
      rows.add(InfoRow(
        icon: Icons.water_drop_outlined,
        label: '헌혈량',
        value: '${post['blood_volume']} mL',
      ));
    }

    return rows;
  }

  Widget _buildBirthDateRow(String birthDateRaw) {
    final birthDate = DateTime.tryParse(birthDateRaw);
    String birthText = birthDateRaw.split('T')[0].replaceAll('-', '.');
    if (birthDate != null) {
      final months = (DateTime.now().year - birthDate.year) * 12 +
          (DateTime.now().month - birthDate.month);
      final ageText = months < 12 ? '$months개월' : '${months ~/ 12}살';
      birthText = '$birthText ($ageText)';
    }
    return InfoRow(
        icon: PetFieldIcons.birthDate, label: '생년월일', value: birthText);
  }

  Widget _status(IconData icon, String label, PetStatusType status) {
    return PetStatusRow(icon: icon, label: label, status: status);
  }

  /// 펫 프로필 사진 다운로드 — SnackBar UX 포함 헬퍼 위임.
  Future<void> _onDownloadPet(
    BuildContext context,
    String profileImage,
    String petName,
  ) async {
    if (profileImage.isEmpty) return;
    final imageUrl = DonationPostImageService.getFullImageUrl(profileImage);
    final filename =
        '${petName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.jpg';
    await downloadPetImageWithFeedback(
      context: context,
      imageUrl: imageUrl,
      filename: filename,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
