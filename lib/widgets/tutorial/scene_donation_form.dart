// lib/widgets/tutorial/scene_donation_form.dart
// 슬라이드 2 — 헌혈 신청 ② 폼 작성.
//
// 시간대 탭 후 진입하는 신청 폼 화면.
// 스텝 0: 반려동물 카드 ("초코") 탭 → 선택됨 표시
// 스텝 1: 사전 안내사항 동의 체크박스 탭 → 체크됨
// 스텝 2: [확인] 버튼 탭 → 신청 완료 + onComplete

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
        return '[탭] 헌혈할 반려동물을 선택합니다';
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
          child: Stack(
            children: [
              _buildForm(),
              if (_showCompleteToast)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _CompletedToast(),
                ),
            ],
          ),
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
              // 헤더 (게시글 정보)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bloodtype_outlined,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '행복동물병원 · 5/15 (월) 14:00',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                  breed: '골든리트리버',
                  weight: '28kg',
                  bloodType: 'DEA 1.1+',
                  selected: _petSelected,
                ),
              ),
              const SizedBox(height: 6),
              _PetCard(
                name: '멍멍이',
                breed: '푸들',
                weight: '8kg',
                bloodType: 'DEA 1.1−',
                selected: false,
              ),
              const SizedBox(height: 14),

              // 사전 안내사항 섹션
              Text(
                '헌혈 사전 안내사항',
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
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet('헌혈 12시간 전부터 금식'),
                    _bullet('당일 충분한 휴식 후 방문'),
                    _bullet('보호자 동행 필수'),
                    _bullet('과거 병력·복용약 사전 안내'),
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

              // 확인 버튼
              HighlightTarget(
                isActive: !_completed && _step == 2,
                onTap: _onConfirmTap,
                child: _ConfirmButton(),
              ),
            ],
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

class _PetCard extends StatelessWidget {
  final String name;
  final String breed;
  final String weight;
  final String bloodType;
  final bool selected;

  const _PetCard({
    required this.name,
    required this.breed,
    required this.weight,
    required this.bloodType,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primaryBlue.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AppTheme.primaryBlue
              : AppTheme.lightGray.withValues(alpha: 0.6),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const Text('🐾', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$breed · $weight · $bloodType',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, size: 18, color: AppTheme.primaryBlue),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
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

class _CompletedToast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '신청이 완료됐어요',
              style: AppTheme.bodySmallStyle.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
