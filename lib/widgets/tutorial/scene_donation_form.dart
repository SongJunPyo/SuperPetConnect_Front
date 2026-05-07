// lib/widgets/tutorial/scene_donation_form.dart
// 슬라이드 2 — 헌혈 신청 ② 폼 작성.
//
// 시간대 탭 후 진입하는 신청 폼 화면.
// 상단에 자세한 게시글 정보 헤더 (이전 바텀시트 내용 재표시).
// 스텝 0: 반려동물 카드 ("초코") 탭 → 선택됨 표시
// 스텝 1: 사전 안내사항 동의 체크박스 탭 → 체크됨
// 스텝 2: [확인] 버튼 탭 → 신청 완료 토스트 + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';
import 'tutorial_phone_frame.dart';

class DonationFormScene extends StatefulWidget {
  final VoidCallback onComplete;

  const DonationFormScene({super.key, required this.onComplete});

  @override
  State<DonationFormScene> createState() => _DonationFormSceneState();
}

class _DonationFormSceneState extends State<DonationFormScene> {
  int _step = 0;
  bool _completed = false;
  bool _petSelected = false;
  bool _consented = false;
  bool _showCompleteToast = false;

  void _onPetTap() {
    if (_step != 0) return;
    setState(() {
      _petSelected = true;
      _step = 1;
    });
  }

  void _onConsentTap() {
    if (_step != 1) return;
    setState(() {
      _consented = true;
      _step = 2;
    });
  }

  void _onConfirmTap() {
    if (_step != 2) return;
    setState(() {
      _showCompleteToast = true;
      _completed = true;
      _step = 3;
    });
    widget.onComplete();
  }

  String get _helperText {
    switch (_step) {
      case 0:
        return '[탭] 반려동물 카드를 누르면 상세 정보가 펼쳐져요';
      case 1:
        return '[탭] 안내사항 정독 동의 (필수)';
      case 2:
        return '[탭] 신청을 완료합니다';
      default:
        return '🎉 신청 완료! 이제 관리자 검토를 기다리면 돼요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialPhoneFrame(
          child: _buildForm(),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TutorialMockSubAppBar(title: '헌혈 신청'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 자세한 게시글 정보 헤더 (이전 바텀시트 내용)
              _buildPostInfoHeader(),
              const SizedBox(height: 14),

              // 반려동물 선택 섹션
              Text(
                '반려동물 선택',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              HighlightTarget(
                isActive: !_completed && _step == 0,
                onTap: _onPetTap,
                child: _PetCard(
                  name: '초코',
                  bloodType: 'DEA 1.1+',
                  weight: '28kg',
                  selected: _petSelected,
                ),
              ),
              const SizedBox(height: 6),
              const _PetCard(
                name: '멍멍이',
                bloodType: 'DEA 1.1−',
                weight: '8kg',
                selected: false,
              ),

              // 펫 선택 시에만 펼쳐지는 상세 정보 (실제 앱과 정합)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: _petSelected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: const _SelectedPetInfo(),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),

              // 사전 안내사항 섹션 (실제 앱은 별도 바텀시트로 뜸)
              Text(
                '헌혈 사전 안내사항',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '실제 앱에서는 [신청] 시 별도 바텀시트로 안내문이 노출돼요',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet('헌혈 자격 조건 안내 (체중·간격·접종 등)'),
                    _bullet('헌혈 절차 (검사 → 채혈 → 휴식)'),
                    _bullet('헌혈 후 주의사항 (충분한 휴식)'),
                    _bullet('응급 상황 시 협회 연락처'),
                    _bullet('⋯ 외 다수 안내'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              HighlightTarget(
                isActive: !_completed && _step == 1,
                onTap: _onConsentTap,
                borderRadius: 8,
                child: _ConsentCheckRow(checked: _consented),
              ),
              const SizedBox(height: 14),

              // 확인 버튼 — 완료 시 토스트로 자리 교체 (가려짐 방지)
              if (_showCompleteToast)
                const _CompletedToast()
              else
                HighlightTarget(
                  isActive: !_completed && _step == 2,
                  onTap: _onConfirmTap,
                  child: const _ConfirmButton(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '긴급',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '강아지 긴급 헌혈 필요',
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _infoLine(Icons.local_hospital_outlined, '행복동물병원'),
          const SizedBox(height: 3),
          _infoLine(Icons.event, '5/15 (월) 14:00'),
          const SizedBox(height: 3),
          _infoLine(Icons.pets, '환자: 7세 보더콜리 · 12kg'),
          const SizedBox(height: 3),
          _infoLine(Icons.medical_information_outlined, '필요 혈액형: DEA 1.1+'),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 펫 선택 카드 — 실제 donation_application_page.dart와 정합.
/// 프로필 아이콘 + 이름 + 상태 뱃지 + 혈액형/체중 한 줄.
/// 접종/예방약/중성화 칩은 표시하지 않음 (그건 선택 후 상세 섹션에서 노출).
class _PetCard extends StatelessWidget {
  final String name;
  final String bloodType;
  final String weight;
  final bool selected;

  const _PetCard({
    required this.name,
    required this.bloodType,
    required this.weight,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppTheme.success : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.success.withValues(alpha: 0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppTheme.success : Colors.grey.shade400,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // 프로필 아바타
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🐾', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTheme.bodySmallStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? AppTheme.success
                              : AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '헌혈 가능',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.bloodtype_outlined,
                      size: 12,
                      color: accent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      bloodType,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.monitor_weight_outlined,
                      size: 12,
                      color: accent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      weight,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, size: 18, color: AppTheme.success),
        ],
      ),
    );
  }
}

/// 선택된 반려동물 상세 정보 섹션.
/// 실제 _buildSelectedPetInfo와 정합 — 종류/품종/성별/혈액형/체중/생년월일/
/// 최근 헌혈/접종/예방약/중성화/질병/임신·출산.
class _SelectedPetInfo extends StatelessWidget {
  const _SelectedPetInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '선택된 반려동물 정보',
          style: AppTheme.bodySmallStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _row(Icons.pets, '종류', '강아지'),
              _row(Icons.category_outlined, '품종', '골든리트리버'),
              _row(Icons.male, '성별', '수컷'),
              _row(Icons.bloodtype_outlined, '혈액형', 'DEA 1.1+'),
              _row(Icons.monitor_weight_outlined, '체중', '28kg'),
              _row(Icons.cake_outlined, '생년월일', '2022-03-15'),
              _row(Icons.history_outlined, '최근 헌혈일', '2025-11-08'),
              _statusRow(Icons.vaccines_outlined, '접종', positive: true),
              _statusRow(Icons.medication_outlined, '예방약', positive: true),
              _statusRow(Icons.verified_user_outlined, '중성화', positive: true),
              _statusRow(Icons.local_hospital_outlined, '질병', positive: false),
              _statusRow(Icons.favorite_outline, '임신/출산', positive: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4단계 status (positive=초록 ✓, neutral=회색 —).
  /// 질병·임신/출산은 false=회색(없음), 나머지는 true=초록(완료).
  Widget _statusRow(IconData icon, String label, {required bool positive}) {
    final color = positive ? AppTheme.success : AppTheme.textTertiary;
    final statusIcon = positive
        ? Icons.check_circle_outline
        : Icons.remove_circle_outline;
    final statusText = positive
        ? (label == '질병' || label == '임신/출산' ? '있음' : '완료')
        : (label == '질병' || label == '임신/출산' ? '없음' : '미완');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          Icon(statusIcon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: AppTheme.bodySmallStyle.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentCheckRow extends StatelessWidget {
  final bool checked;

  const _ConsentCheckRow({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: checked
            ? AppTheme.success.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked
              ? AppTheme.success
              : AppTheme.lightGray.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: checked ? AppTheme.success : AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '안내사항을 정독했으며 동의합니다',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text(
        '확인',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 신청 완료 토스트 — 부드러운 성공 톤 (이전 너무 진했음).
class _CompletedToast extends StatelessWidget {
  const _CompletedToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '신청이 완료됐어요',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
