import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/time_format_util.dart';
import '../donation_history_sheet.dart';
import '../info_row.dart';
import '../pet_profile_image.dart';
import '../post_detail/post_detail_description.dart';

/// 헌혈마감 / 헌혈완료 / 헌혈취소 탭에서 확정 신청자 1명의 정보를 표시할 때
/// 호출되는 액션 묶음. 모든 콜백 nullable — 해당 status에서 보일 버튼 콜백만 채움.
class CompletionApplicantSheetActions {
  /// status 5 (PENDING_COMPLETION) — "헌혈 마감" 버튼.
  final void Function(int applicationId)? onFinalApproveCompletion;

  /// status 7 (FINAL_COMPLETED) — "헌혈 자료 요청" 버튼.
  final void Function(int applicationId)? onRequestDocuments;

  /// status 6 (PENDING_CANCELLATION) — "헌혈 중단" 버튼.
  final void Function(int applicationId)? onRejectCompletion;

  const CompletionApplicantSheetActions({
    this.onFinalApproveCompletion,
    this.onRequestDocuments,
    this.onRejectCompletion,
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
                    if ((post['status'] == 4 || post['status'] == 6) &&
                        post['cancelled_reason'] != null &&
                        post['cancelled_reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('중단 사유', style: AppTheme.h4Style),
                      const SizedBox(height: 12),
                      _CancelledReasonCard(post: post),
                    ],
                    if (post['status'] != 5 && post['status'] != 6) ...[
                      const SizedBox(height: 24),
                      DonationHistorySection(petIdx: petIdx),
                    ],
                    if (post['status'] == 5 &&
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
                    if (post['status'] == 7 &&
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
                    if (post['status'] == 6 &&
                        actions.onRejectCompletion != null) ...[
                      const SizedBox(height: 24),
                      _ActionButton(
                        label: '헌혈 중단',
                        color: Colors.red,
                        onPressed: () {
                          Navigator.of(context).pop();
                          actions.onRejectCompletion!(
                            post['application_id'] ?? post['id'] ?? 0,
                          );
                        },
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
                  Icons.business,
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
              Icons.location_on,
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
                Icons.calendar_today,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['user_name'] != null &&
              post['user_name'].toString().isNotEmpty)
            InfoRow(
              icon: Icons.person,
              label: '이름',
              value: post['user_name'].toString(),
            ),
          if (post['user_nickname'] != null &&
              post['user_nickname'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.badge,
              label: '닉네임',
              value: post['user_nickname'].toString(),
            ),
          ],
          if (post['pet_name'] != null &&
              post['pet_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.pets,
              label: '반려동물',
              value: post['pet_breed'] != null &&
                      post['pet_breed'].toString().isNotEmpty
                  ? '${post['pet_name']} (${post['pet_breed']})'
                  : post['pet_name'],
            ),
          ],
          if (post['pet_birth_date'] != null &&
              post['pet_birth_date'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBirthDateRow(post['pet_birth_date'].toString()),
          ],
          if (post['pet_blood_type'] != null) ...[
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.bloodtype,
              label: '혈액형',
              value: post['pet_blood_type'].toString(),
            ),
          ],
          if (post['blood_volume'] != null) ...[
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.water_drop,
              label: '헌혈량',
              value: '${post['blood_volume']} mL',
            ),
          ],
        ],
      ),
    );
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
    return InfoRow(icon: Icons.cake, label: '생년월일', value: birthText);
  }
}

class _CancelledReasonCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _CancelledReasonCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post['cancelled_reason'],
            style: AppTheme.bodyMediumStyle.copyWith(height: 1.4),
          ),
          if (post['cancelled_at'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '중단 시간: ${TimeFormatUtils.formatKoreanDateTime(post['cancelled_at'])}',
              style: AppTheme.bodySmallStyle.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
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
