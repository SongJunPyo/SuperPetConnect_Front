// lib/widgets/tutorial/scene_pet_management.dart
// 슬라이드 3 — 대시보드 → 반려동물 관리 화면 흐름.
//
// 스텝 0: 대시보드 모형 + AppBar의 "반려동물 관리" 버튼 강조 → 탭 → 펫 관리 화면 전환
// 스텝 1: 펫 관리 화면 + [+] 버튼 강조 → 탭 → 가짜 펫 추가
// 스텝 2: 첫 펫 카드의 ⋮ 메뉴 강조 → 탭 → 해당 펫 제거 + 완료

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';

class _MockPet {
  final String name;
  final String breed;
  final String weight;
  final GlobalKey menuKey;

  _MockPet({
    required this.name,
    required this.breed,
    required this.weight,
  }) : menuKey = GlobalKey();
}

class PetManagementScene extends StatefulWidget {
  final VoidCallback onComplete;

  const PetManagementScene({super.key, required this.onComplete});

  @override
  State<PetManagementScene> createState() => _PetManagementSceneState();
}

class _PetManagementSceneState extends State<PetManagementScene> {
  int _step = 0;
  bool _completed = false;

  late List<_MockPet> _pets;

  @override
  void initState() {
    super.initState();
    _pets = [
      _MockPet(name: '초코', breed: '골든리트리버', weight: '28kg'),
      _MockPet(name: '멍멍이', breed: '푸들', weight: '8kg'),
    ];
  }

  void _onPetMgmtButtonTap() {
    if (_step != 0) return;
    setState(() => _step = 1);
  }

  void _onAddTap() {
    if (_step != 1) return;
    setState(() {
      _pets.add(_MockPet(name: '새친구', breed: '비글', weight: '12kg'));
      _step = 2;
    });
  }

  void _onMenuTap() {
    if (_step != 2 || _pets.isEmpty) return;
    setState(() {
      _pets.removeAt(0);
      _step = 3;
      _completed = true;
    });
    widget.onComplete();
  }

  String get _helperText {
    if (_completed) return '🎉 등록과 삭제 흐름을 모두 익혔어요';
    switch (_step) {
      case 0:
        return 'AppBar의 "반려동물 관리" 버튼을 탭해보세요';
      case 1:
        return '우측 상단 [+] 버튼으로 새 반려동물을 등록할 수 있어요';
      case 2:
        return '카드 우측 ⋮ 메뉴로 반려동물을 삭제해보세요';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhoneFrame(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _step == 0
                ? _DashboardWithPetButton(
                    key: const ValueKey('dashboard'),
                    isButtonActive: true,
                    onButtonTap: _onPetMgmtButtonTap,
                  )
                : _PetManagementMock(
                    key: const ValueKey('petMgmt'),
                    pets: _pets,
                    isAddActive: !_completed && _step == 1,
                    activeMenuPetIndex: !_completed && _step == 2 ? 0 : null,
                    onAddTap: _onAddTap,
                    onMenuTap: _onMenuTap,
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }
}

// ====================================================================
// 대시보드 미니어처 (스텝 0) — 반려동물 관리 버튼 강조
// ====================================================================
class _DashboardWithPetButton extends StatelessWidget {
  final bool isButtonActive;
  final VoidCallback onButtonTap;

  const _DashboardWithPetButton({
    super.key,
    required this.isButtonActive,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AppBar with highlighted pet button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.lightGray)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_none,
                size: 20,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: 4),
              // 반려동물 관리 버튼 — 강조 대상
              HighlightTarget(
                isActive: isButtonActive,
                onTap: onButtonTap,
                borderRadius: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pets,
                        size: 16,
                        color: AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '반려동물 관리',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
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
                  fontSize: 17,
                ),
              ),
              Text(
                '사용자 님!',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 17,
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
              const SizedBox(height: AppTheme.spacing16),
              // 헌혈 모집 카드 (visual, 비강조)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bloodtype_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '헌혈 모집',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '진행 중인 헌혈 요청 모아보기',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// 펫 관리 화면 미니어처 (스텝 1, 2)
// ====================================================================
class _PetManagementMock extends StatelessWidget {
  final List<_MockPet> pets;
  final bool isAddActive;
  final int? activeMenuPetIndex;
  final VoidCallback onAddTap;
  final VoidCallback onMenuTap;

  const _PetManagementMock({
    super.key,
    required this.pets,
    required this.isAddActive,
    required this.activeMenuPetIndex,
    required this.onAddTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.lightGray)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                '반려동물 관리',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // [+] 버튼 — 강조 대상
              HighlightTarget(
                isActive: isAddActive,
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
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Column(
              children: [
                for (var i = 0; i < pets.length; i++) ...[
                  _MockPetCard(
                    pet: pets[i],
                    isMenuActive: activeMenuPetIndex == i,
                    onMenuTap: onMenuTap,
                  ),
                  if (i < pets.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MockPetCard extends StatelessWidget {
  final _MockPet pet;
  final bool isMenuActive;
  final VoidCallback onMenuTap;

  const _MockPetCard({
    required this.pet,
    required this.isMenuActive,
    required this.onMenuTap,
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
                  pet.name,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.breed} · ${pet.weight}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // ⋮ 메뉴 — 활성 펫에서만 강조
          HighlightTarget(
            isActive: isMenuActive,
            onTap: onMenuTap,
            shape: HighlightShape.circle,
            child: Container(
              key: pet.menuKey,
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: Icon(
                Icons.more_vert,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 폰 프레임 (각 scene에 복사 — 추후 공용 추출 가능)
class _PhoneFrame extends StatelessWidget {
  final Widget child;

  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
