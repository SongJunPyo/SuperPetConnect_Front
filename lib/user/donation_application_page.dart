import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../models/pet_model.dart' as pet_model;
import '../models/unified_post_model.dart';
import '../services/auth_http_client.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/donation_eligibility.dart';
import '../utils/phone_formatter.dart';
import '../utils/pet_field_icons.dart';
import '../utils/preferences_manager.dart';
import '../widgets/pet_profile_image.dart';
import '../widgets/pet_status_row.dart';
import '../widgets/terms_agreement_bottom_sheet.dart';

/// 시간 슬롯을 선택한 뒤 사용자 정보 + 펫 + 자격 검증 + 약관 동의를 거쳐 헌혈
/// 신청을 보내는 풀스크린 모달.
///
/// 호출부는 `showModalBottomSheet`로 띄우고 결과를 다음 형태의 `Map`으로 받음:
/// - `{ 'success': true }` — 신청 성공. 호출부가 목록 새로고침/완료 다이얼로그 표시.
/// - `{ 'error': '...' }` — 서버 에러. 호출부가 메시지 다이얼로그 표시.
/// - `null` — 사용자가 단순 닫기.
class DonationApplicationPage extends StatefulWidget {
  final UnifiedPostModel post;
  final String selectedDate;
  final Map<String, dynamic> selectedTimeSlot;
  final String displayText;

  const DonationApplicationPage({
    super.key,
    required this.post,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.displayText,
  });

  @override
  State<DonationApplicationPage> createState() =>
      _DonationApplicationPageState();
}

class _DonationApplicationPageState extends State<DonationApplicationPage> {
  pet_model.Pet? selectedPet;
  List<pet_model.Pet> userPets = [];
  Map<String, dynamic>? userInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPets();
  }

  Future<void> _loadUserDataAndPets() async {
    try {
      // 사용자 정보 API 호출
      final userResponse = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/user/profile'),
      );

      // 반려동물 목록 API 호출
      final petsResponse = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/pets'),
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));
        final userNickname =
            (await PreferencesManager.getUserNickname()) ?? '닉네임 없음';

        setState(() {
          // 사용자 정보 매핑 (DB 스키마 기준)
          userInfo = {
            'name': userData['data']['name'] ?? '',
            'nickname': userNickname,
            'phone': userData['data']['phone_number'] ?? '',
            'address': userData['data']['address'] ?? '',
            'email': userData['data']['email'] ?? '',
          };

          // 반려동물 정보는 API 성공 시에만 처리
          if (petsResponse.statusCode == 200) {
            final petsList = petsResponse.parseJsonList();

            // Pet 모델로 변환 (자격 검증에 필요한 모든 필드 포함)
            userPets =
                petsList
                    .map((pet) => pet_model.Pet.fromJson(pet as Map<String, dynamic>))
                    .toList();
          } else {
            // 반려동물 API 실패 시 빈 리스트
            userPets = [];
          }

          isLoading = false;
        });
      } else {
        String errorMessage =
            'API 호출 실패: User ${userResponse.statusCode}, Pets ${petsResponse.statusCode}';
        if (userResponse.statusCode != 200) {
          try {
            final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));
            errorMessage = userData['detail'] ?? errorMessage;
          } catch (e) {
            // JSON 파싱 실패 시 기본 오류 메시지 사용
            debugPrint('Failed to parse user response: $e');
          }
        }
        if (petsResponse.statusCode != 200) {
          try {
            final petsData = jsonDecode(utf8.decode(petsResponse.bodyBytes));
            errorMessage = petsData['detail'] ?? errorMessage;
          } catch (e) {
            // JSON 파싱 실패 시 기본 오류 메시지 사용
            debugPrint('Failed to parse user response: $e');
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        // 오류 시 기본값 설정
        userInfo = {'name': '사용자', 'phone': '', 'address': '', 'email': ''};
        userPets = [];
        isLoading = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                const Text('오류'),
              ],
            ),
            content: Text('사용자 정보를 불러올 수 없습니다: ${e.toString().replaceFirst('Exception: ', '')}'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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

          // 앱바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '헌혈 신청',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 메인 콘텐츠
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 선택한 일정 정보
                          _buildSelectedScheduleInfo(),
                          const SizedBox(height: 24),

                          // 반려동물 선택
                          _buildPetSelection(),
                          const SizedBox(height: 24),

                          // 선택된 반려동물 정보 표시 (위로 이동)
                          if (selectedPet != null) _buildSelectedPetInfo(),
                          if (selectedPet != null) const SizedBox(height: 24),

                          // 신청자 정보 표시 (아래로 이동)
                          _buildUserInfo(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
          ),

          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    _canSubmitApplication() ? _showTermsBottomSheet : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: BorderSide(
                    color: _canSubmitApplication()
                        ? AppTheme.success
                        : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '신청',
                  style: AppTheme.h4Style.copyWith(
                    color: _canSubmitApplication()
                        ? AppTheme.success
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 헌혈 신청 가능 여부 확인
  bool _canSubmitApplication() {
    if (selectedPet == null) return false;

    // 선택된 반려동물의 자격 검증
    final eligibility = DonationEligibility.checkEligibility(selectedPet!);
    return eligibility.isEligible || eligibility.needsConsultation;
  }

  Widget _buildSelectedScheduleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택한 헌혈 일정',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.displayText,
                  style: AppTheme.h4Style.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 헌혈 불가 사유 메시지 표시
  void _showIneligibleReasons(pet_model.Pet pet, EligibilityResult eligibility) {
    final reasons = eligibility.failedConditions.map((c) => '• ${c.message}').join('\n');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${pet.name} - 헌혈 불가',
                style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다음 조건이 충족되지 않았습니다:',
              style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              reasons,
              style: AppTheme.bodyMediumStyle.copyWith(color: Colors.red[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelection() {
    // 동물 종류가 일치하는 반려동물 필터링
    final matchingPets = userPets.where((pet) {
      return DonationEligibility.matchesAnimalType(pet, widget.post.animalType);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '반려동물 선택',
          style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 반려동물이 없을 때 안내 메시지
        if (matchingPets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(
                  widget.post.animalType == 0
                      ? FontAwesomeIcons.dog
                      : FontAwesomeIcons.cat,
                  size: 30,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    '해당 헌혈 게시글에 참여할 수 있는 \n${widget.post.animalType == 0 ? "강아지" : "고양이"}가 없습니다',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...matchingPets.map((pet) {
            final eligibility = DonationEligibility.checkEligibility(pet);
            final isSelectable = eligibility.isEligible || eligibility.needsConsultation;
            final isSelected = selectedPet?.petIdx == pet.petIdx;

            // 선택 강조 색은 초록(success)으로 통일.
            final accentColor = !isSelectable
                ? Colors.red.shade400
                : isSelected
                    ? AppTheme.success
                    : AppTheme.textSecondary;
            final borderColor = !isSelectable
                ? Colors.red.shade300
                : isSelected
                    ? AppTheme.success
                    : Colors.grey.shade400;
            final bgColor = !isSelectable
                ? Colors.red.shade50
                : isSelected
                    ? AppTheme.success.withValues(alpha: 0.06)
                    : Colors.grey.shade100;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSelectable
                      ? () {
                          setState(() {
                            selectedPet = pet;
                          });
                        }
                      : () => _showIneligibleReasons(pet, eligibility),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                      color: bgColor,
                    ),
                    child: Row(
                      children: [
                        // 프로필 사진 아바타 (없으면 PetProfileImage가 종별 아이콘으로 fallback).
                        PetProfileImage(
                          profileImage: pet.profileImage,
                          species: pet.species,
                          radius: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      pet.name,
                                      style: AppTheme.bodyLargeStyle.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: !isSelectable
                                            ? Colors.red.shade700
                                            : isSelected
                                                ? AppTheme.success
                                                : AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isSelectable) ...[
                                    const SizedBox(width: 6),
                                    _buildStatusBadge(
                                      '헌혈 불가',
                                      Colors.red.shade100,
                                      Colors.red.shade700,
                                    ),
                                  ],
                                  if (isSelectable && eligibility.needsConsultation) ...[
                                    const SizedBox(width: 6),
                                    _buildStatusBadge(
                                      '협의 필요',
                                      Colors.orange.shade100,
                                      Colors.orange.shade700,
                                    ),
                                  ],
                                  if (eligibility.isEligible) ...[
                                    const SizedBox(width: 6),
                                    _buildStatusBadge(
                                      '헌혈 가능',
                                      AppTheme.success.withValues(alpha: 0.1),
                                      AppTheme.success,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 혈액형 + 체중 (아이콘 동반).
                              Row(
                                children: [
                                  Icon(
                                    Icons.bloodtype_outlined,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    pet.bloodType ?? '미상',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: !isSelectable
                                          ? Colors.red.shade400
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(
                                    Icons.monitor_weight_outlined,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${pet.weightKg}kg',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: !isSelectable
                                          ? Colors.red.shade400
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isSelectable)
                          Icon(Icons.info_outline,
                              color: Colors.red.shade400, size: 22)
                        else if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppTheme.success, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildUserInfo() {
    if (userInfo == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '신청자 정보',
              style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
              onPressed: () {},
              tooltip: '프로필 관리',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: PetFieldIcons.userName,
                label: '이름',
                value: userInfo!['name'] ?? '-',
              ),
              _buildInfoRow(
                icon: PetFieldIcons.nickname,
                label: '닉네임',
                value: userInfo!['nickname'] ?? '-',
              ),
              _buildInfoRow(
                icon: PetFieldIcons.phone,
                label: '연락처',
                value: formatPhoneNumber(userInfo!['phone'] as String?,
                    fallback: '-'),
              ),
              _buildInfoRow(
                icon: PetFieldIcons.address,
                label: '주소',
                value: userInfo!['address'] ?? '-',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPetInfo() {
    final pet = selectedPet!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '선택된 반려동물 정보',
              style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // 펫 정보 표시 순서 (회원가입 관리 / 관리자 펫 관리 / 모집마감 시트와 정합):
              // (이름은 카드 헤더에 이미 노출) 종류 → 품종 → 성별 → 혈액형 → 체중 →
              // 생년월일 → 최근 헌혈일 → 접종 → 예방약 → 중성화 → 질병 → 임신/출산
              _buildInfoRow(
                icon: PetFieldIcons.species,
                label: '종류',
                value: pet.species,
              ),
              if (pet.breed?.isNotEmpty == true)
                _buildInfoRow(
                  icon: PetFieldIcons.breed,
                  label: '품종',
                  value: pet.breed,
                )
              else
                const PetStatusRow(
                  icon: PetFieldIcons.breed,
                  label: '품종',
                  labelWidth: 78,
                  status: PetStatusType.neutral,
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
              _buildInfoRow(
                icon: PetFieldIcons.sex(pet.sex),
                label: '성별',
                value: pet.sex == 0 ? '암컷' : '수컷',
              ),
              if (pet.bloodType != null)
                _buildInfoRow(
                  icon: PetFieldIcons.bloodType,
                  label: '혈액형',
                  value: pet.bloodType,
                )
              else
                const PetStatusRow(
                  icon: PetFieldIcons.bloodType,
                  label: '혈액형',
                  labelWidth: 78,
                  status: PetStatusType.neutral,
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
              _buildInfoRow(
                icon: PetFieldIcons.weight,
                label: '체중',
                value: '${pet.weightKg}kg',
              ),
              // 생년월일: 미입력 시 주황 ⚠
              if (pet.birthDate != null)
                _buildInfoRow(
                  icon: PetFieldIcons.birthDate,
                  label: '생년월일',
                  value: pet.birthDateWithAge,
                )
              else
                const PetStatusRow(
                  icon: PetFieldIcons.birthDate,
                  label: '생년월일',
                  labelWidth: 78,
                  status: PetStatusType.warning,
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
              // 최근 헌혈일: 미입력 시 회색 — (첫 헌혈)
              // effective date (max of system / prior) — 2026-05 PR-1 컬럼 분리.
              if (pet.effectiveLastDonationDate != null)
                _buildInfoRow(
                  icon: PetFieldIcons.prevDonationDate,
                  label: '최근 헌혈일',
                  value: DateFormat('yyyy-MM-dd')
                      .format(pet.effectiveLastDonationDate!),
                )
              else
                const PetStatusRow(
                  icon: PetFieldIcons.prevDonationDate,
                  label: '최근 헌혈일',
                  labelWidth: 78,
                  status: PetStatusType.neutral,
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
              // 접종 / 예방약 — 4단계 시스템 (true → 초록 ✓, false → 빨강 !)
              PetStatusRow(
                icon: PetFieldIcons.vaccinated,
                label: '접종',
                labelWidth: 78,
                status: pet.vaccinated == true
                    ? PetStatusType.positive
                    : PetStatusType.critical,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              // 종합백신 접종일 + 항체검사 일자 (카페 정책 — 2026-05 PR-1)
              if (pet.vaccinated == true && pet.lastVaccinationDate != null)
                _buildInfoRow(
                  icon: PetFieldIcons.vaccinationDate,
                  label: '종합백신',
                  value:
                      DateFormat('yyyy-MM-dd').format(pet.lastVaccinationDate!),
                ),
              if (pet.vaccinated == true && pet.lastAntibodyTestDate != null)
                _buildInfoRow(
                  icon: PetFieldIcons.antibodyTestDate,
                  label: '항체검사',
                  value: DateFormat('yyyy-MM-dd')
                      .format(pet.lastAntibodyTestDate!),
                ),
              PetStatusRow(
                icon: PetFieldIcons.medication,
                label: '예방약',
                labelWidth: 78,
                status: pet.hasPreventiveMedication == true
                    ? PetStatusType.positive
                    : PetStatusType.critical,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              // 예방약 복용일 (카페 정책 — 2026-05 PR-1)
              if (pet.hasPreventiveMedication == true &&
                  pet.lastPreventiveMedicationDate != null)
                _buildInfoRow(
                  icon: PetFieldIcons.preventiveMedicationDate,
                  label: '예방약 복용',
                  value: DateFormat('yyyy-MM-dd')
                      .format(pet.lastPreventiveMedicationDate!),
                ),
              // 중성화: 완료 시 날짜 텍스트, 미완료 시 회색 — (자연스러운 부재)
              if (pet.isNeutered == true && pet.neuteredDate != null)
                _buildInfoRow(
                  icon: PetFieldIcons.isNeutered,
                  label: '중성화',
                  value: DateFormat('yyyy-MM-dd').format(pet.neuteredDate!),
                  statusIcon: Icons.check_circle_outline,
                  statusColor: AppTheme.success,
                )
              else
                PetStatusRow(
                  icon: PetFieldIcons.isNeutered,
                  label: '중성화',
                  labelWidth: 78,
                  status: pet.isNeutered == true
                      ? PetStatusType.positive
                      : PetStatusType.neutral,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              // 질병: 있음 → 빨강 !, 없음 → 회색 —
              PetStatusRow(
                icon: PetFieldIcons.hasDisease,
                label: '질병',
                labelWidth: 78,
                status: pet.hasDisease == true
                    ? PetStatusType.critical
                    : PetStatusType.neutral,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              // 임신/출산 (암컷만 노출):
              //   status=2 + 종료일 → 텍스트 "출산 YYYY-MM-DD"
              //   status=1 → 주황 ⚠ / status=0 → 회색 —
              if (pet.sex == 0) ...[
                if (pet.pregnancyBirthStatus == 2 &&
                    pet.lastPregnancyEndDate != null)
                  _buildInfoRow(
                    icon: PetFieldIcons.pregnancyBirth,
                    label: '임신/출산',
                    value:
                        '출산 ${DateFormat('yyyy-MM-dd').format(pet.lastPregnancyEndDate!)}',
                  )
                else
                  PetStatusRow(
                    icon: PetFieldIcons.pregnancyBirth,
                    label: '임신/출산',
                    labelWidth: 78,
                    status: pet.pregnancyBirthStatus == 1
                        ? PetStatusType.warning
                        : PetStatusType.neutral,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 라벨 좌측 아이콘 + 라벨 + (선택적) 상태 아이콘 + (선택적) 값 텍스트.
  /// [value]가 null이면 텍스트는 그리지 않고 [statusIcon]만 노출 — "완료/복용/
  /// 없음/안 함" 등 자명한 단어를 텍스트 대신 아이콘으로 대체하기 위함.
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    String? value,
    IconData? statusIcon,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (statusIcon != null) ...[
                  Icon(
                    statusIcon,
                    size: 18,
                    color: statusColor ?? AppTheme.textTertiary,
                  ),
                  if (value != null) const SizedBox(width: 6),
                ],
                if (value != null)
                  Expanded(
                    child: Text(
                      value,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 헌혈 가능/협의 필요/헌혈 불가 뱃지 — 펫 카드 우측 상단 라벨용.
  Widget _buildStatusBadge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTheme.bodySmallStyle.copyWith(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showTermsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TermsAgreementBottomSheet(onConfirm: _submitApplication),
    );
  }

  void _submitApplication() async {
    try {
      if (selectedPet == null) {
        throw Exception('반려동물을 선택해주세요.');
      }

      // 디버그: 전송할 데이터 확인
      debugPrint(
        '[DonationApplication] post_times_idx: ${widget.selectedTimeSlot['post_times_idx']}',
      );
      debugPrint('[DonationApplication] pet_idx: ${selectedPet!.petIdx}');
      debugPrint(
        '[DonationApplication] selectedTimeSlot 전체: ${widget.selectedTimeSlot}',
      );

      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}/api/donation/apply'),
        body: jsonEncode({
          'post_times_idx': widget.selectedTimeSlot['post_times_idx'],
          'pet_idx': selectedPet!.petIdx,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        jsonDecode(utf8.decode(response.bodyBytes));

        if (mounted) {
          // 신청 페이지 닫기 + 성공 결과 전달
          Navigator.pop(context, {'success': true});
        }
      } else {
        throw response.extractErrorMessage('신청 처리 중 오류가 발생했습니다.');
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        // 바텀시트를 닫고 에러 메시지를 부모에게 전달
        Navigator.pop(context, {'error': errorMessage});
      }
    }
  }
}
