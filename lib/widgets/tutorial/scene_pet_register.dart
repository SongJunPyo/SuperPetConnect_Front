// lib/widgets/tutorial/scene_pet_register.dart
// 슬라이드 5 — 반려동물 등록 (자세히).
//
// 스텝 0: 대시보드 AppBar의 "반려동물 관리" 버튼 강조 → 탭 → 펫 관리 화면 전환
// 스텝 1: 펫 관리 [+] 버튼 강조 → 탭 → 등록 폼 화면 전환
// 스텝 2: 등록 폼 [등록] 버튼 강조 → 탭 → 등록 완료 토스트 + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';
import 'tutorial_phone_frame.dart';

class PetRegisterScene extends StatefulWidget {
  final VoidCallback onComplete;

  const PetRegisterScene({super.key, required this.onComplete});

  @override
  State<PetRegisterScene> createState() => _PetRegisterSceneState();
}

class _PetRegisterSceneState extends State<PetRegisterScene> {
  int _step = 0;
  bool _completed = false;
  bool _showToast = false;

  void _onPetMgmtTap() {
    if (_step != 0) return;
    setState(() => _step = 1);
  }

  void _onAddTap() {
    if (_step != 1) return;
    setState(() => _step = 2);
  }

  void _onRegisterTap() {
    if (_step != 2) return;
    setState(() {
      _showToast = true;
      _completed = true;
      _step = 3;
    });
    widget.onComplete();
  }

  String get _helperText {
    switch (_step) {
      case 0:
        return '[탭] 상단 "반려동물 관리" 버튼으로 진입합니다';
      case 1:
        return '[탭] [+] 버튼을 누르면 등록 폼이 열려요';
      case 2:
        return '[탭] 정보를 입력하고 등록합니다';
      default:
        return '🎉 반려동물이 등록됐어요. 관리자 승인 후 헌혈 신청 가능';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialPhoneFrame(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildCurrentView(),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }

  Widget _buildCurrentView() {
    if (_step == 0) {
      return _DashboardWithPetButton(
        key: const ValueKey('dashboard'),
        onTap: _onPetMgmtTap,
      );
    }
    if (_step == 1) {
      return _PetListMock(
        key: const ValueKey('petList'),
        onAddTap: _onAddTap,
      );
    }
    return _RegisterFormMock(
      key: const ValueKey('form'),
      isRegisterActive: !_completed,
      onRegisterTap: _onRegisterTap,
      showToastInsteadOfButton: _showToast,
    );
  }
}

// ====================================================================
// 대시보드 (스텝 0) — 반려동물 관리 버튼 강조
// ====================================================================
class _DashboardWithPetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DashboardWithPetButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialMockAppBar(
          petButton: HighlightTarget(
            isActive: true,
            onTap: onTap,
            borderRadius: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pets_outlined, size: 14, color: AppTheme.textPrimary),
                  const SizedBox(width: 3),
                  Text(
                    '반려동물 관리',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕하세요,',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
              Text(
                '사용자 님!',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '2026년 5월 6일 (수) 14:30',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              _miniCard(
                icon: Icons.bloodtype_outlined,
                iconBg: const Color(0xFFE53935),
                title: '헌혈 모집',
                subtitle: '진행 중인 헌혈 요청 모아보기',
              ),
              const SizedBox(height: 8),
              _miniCard(
                icon: Icons.bloodtype,
                iconBg: const Color(0xFF1976D2),
                title: '헌혈 이력',
                subtitle: '헌혈 신청 및 완료 내역',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 펫 관리 화면 (스텝 1) — [+] 버튼 강조
// ====================================================================
class _PetListMock extends StatelessWidget {
  final VoidCallback onAddTap;

  const _PetListMock({super.key, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialMockSubAppBar(
          title: '반려동물 관리',
          trailing: HighlightTarget(
            isActive: true,
            onTap: onAddTap,
            shape: HighlightShape.circle,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: const [
              _MockPetCardSimple(name: '초코', breed: '골든리트리버', weight: '28kg'),
              SizedBox(height: 8),
              _MockPetCardSimple(name: '멍멍이', breed: '푸들', weight: '8kg'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockPetCardSimple extends StatelessWidget {
  final String name;
  final String breed;
  final String weight;

  const _MockPetCardSimple({
    required this.name,
    required this.breed,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Text('🐾', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$breed · $weight',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 18),
        ],
      ),
    );
  }
}

// ====================================================================
// 등록 폼 화면 (스텝 2) — 입력 필드 visual + [등록] 버튼 강조
// ====================================================================
class _RegisterFormMock extends StatelessWidget {
  final bool isRegisterActive;
  final VoidCallback onRegisterTap;
  final bool showToastInsteadOfButton;

  const _RegisterFormMock({
    super.key,
    required this.isRegisterActive,
    required this.onRegisterTap,
    this.showToastInsteadOfButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TutorialMockSubAppBar(title: '반려동물 등록'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 사진 영역
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.veryLightGray,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    color: AppTheme.textSecondary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _formField(label: '이름', value: '새친구', icon: Icons.badge_outlined),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _formField(
                      label: '동물 종류',
                      value: '강아지',
                      icon: Icons.pets,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _formField(
                      label: '성별',
                      value: '수컷',
                      icon: Icons.male,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _formField(
                      label: '생년월일',
                      value: '2024.03.15',
                      icon: Icons.cake_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _formField(
                      label: '체중',
                      value: '12kg',
                      icon: Icons.fitness_center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _formField(
                label: '혈액형',
                value: 'DEA 1.1+',
                icon: Icons.bloodtype_outlined,
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '⋯ 외 백신 / 항체 / 예방약 일자 등',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 등록 버튼 — 완료 시 토스트로 자리 교체
              if (showToastInsteadOfButton)
                const _RegisteredToast()
              else
                HighlightTarget(
                  isActive: isRegisterActive,
                  onTap: onRegisterTap,
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '등록',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisteredToast extends StatelessWidget {
  const _RegisteredToast();

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
              '반려동물이 등록됐어요',
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
