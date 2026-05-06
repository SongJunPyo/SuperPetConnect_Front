// lib/widgets/tutorial/scene_pet_delete.dart
// 슬라이드 6 — 반려동물 삭제 (자세히).
//
// 스텝 0: 펫 관리 화면 → 첫 펫의 ⋮ 메뉴 강조 → 탭 → 메뉴 popup 등장
// 스텝 1: popup의 "삭제" 항목 강조 → 탭 → 확인 다이얼로그 등장
// 스텝 2: 다이얼로그의 [삭제] 버튼 강조 → 탭 → 펫 사라짐 + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';
import 'tutorial_phone_frame.dart';

class _PetData {
  final String name;
  final String breed;
  final String weight;

  const _PetData({
    required this.name,
    required this.breed,
    required this.weight,
  });
}

enum _OverlayState { none, menu, dialog }

class PetDeleteScene extends StatefulWidget {
  final VoidCallback onComplete;

  const PetDeleteScene({super.key, required this.onComplete});

  @override
  State<PetDeleteScene> createState() => _PetDeleteSceneState();
}

class _PetDeleteSceneState extends State<PetDeleteScene> {
  int _step = 0;
  bool _completed = false;
  _OverlayState _overlay = _OverlayState.none;

  late List<_PetData> _pets;

  @override
  void initState() {
    super.initState();
    _pets = const [
      _PetData(name: '초코', breed: '골든리트리버', weight: '28kg'),
      _PetData(name: '멍멍이', breed: '푸들', weight: '8kg'),
    ];
  }

  void _onMenuTap() {
    if (_step != 0) return;
    setState(() {
      _overlay = _OverlayState.menu;
      _step = 1;
    });
  }

  void _onDeleteMenuTap() {
    if (_step != 1) return;
    setState(() {
      _overlay = _OverlayState.dialog;
      _step = 2;
    });
  }

  void _onConfirmDeleteTap() {
    if (_step != 2 || _pets.isEmpty) return;
    setState(() {
      _pets = _pets.sublist(1);
      _overlay = _OverlayState.none;
      _step = 3;
      _completed = true;
    });
    widget.onComplete();
  }

  String get _helperText {
    if (_completed) return '🎉 반려동물이 삭제됐어요';
    switch (_step) {
      case 0:
        return '[탭] 카드 우측 ⋮ 메뉴를 누르면 옵션이 나와요';
      case 1:
        return '[탭] "삭제"를 누르면 확인 다이얼로그가 떠요';
      case 2:
        return '[탭] [삭제] 버튼을 눌러야 실제로 삭제됩니다';
      default:
        return '';
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
              _buildPetList(),
              if (_overlay == _OverlayState.menu) _buildMenuPopup(),
              if (_overlay == _OverlayState.dialog) _buildConfirmDialog(),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }

  Widget _buildPetList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TutorialMockSubAppBar(title: '반려동물 관리'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Column(
              children: [
                for (var i = 0; i < _pets.length; i++) ...[
                  _MockPetCard(
                    pet: _pets[i],
                    isMenuActive: i == 0 && _step == 0,
                    onMenuTap: _onMenuTap,
                  ),
                  if (i < _pets.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 카드 우측에 뜨는 컨텍스트 메뉴 (수정/삭제). 첫 펫의 ⋮ 위치 근처에.
  Widget _buildMenuPopup() {
    return Stack(
      children: [
        // 메뉴 외부 클릭 dim
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        // 첫 펫 카드의 ⋮ 위치 옆에 메뉴 (대략 좌표)
        Positioned(
          top: 80, // SubAppBar 약 50 + padding 12 + 카드 위쪽
          right: 28,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _menuItem(
                    icon: Icons.edit_outlined,
                    label: '수정',
                    isActive: false,
                  ),
                  Container(height: 1, color: AppTheme.lightGray),
                  HighlightTarget(
                    isActive: !_completed && _step == 1,
                    onTap: _onDeleteMenuTap,
                    borderRadius: 6,
                    child: _menuItem(
                      icon: Icons.delete_outline,
                      label: '삭제',
                      isActive: true,
                      destructive: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required bool isActive,
    bool destructive = false,
  }) {
    final color =
        destructive ? AppTheme.error : AppTheme.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.bodySmallStyle.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: destructive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 확인 다이얼로그 — "삭제하시겠습니까?" + 취소/삭제.
  Widget _buildConfirmDialog() {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '반려동물을 삭제할까요?',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"초코"의 등록 정보가 모두 삭제됩니다.\n이 작업은 되돌릴 수 없어요.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            child: Text(
                              '취소',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 24, color: AppTheme.lightGray),
                        Expanded(
                          child: HighlightTarget(
                            isActive: !_completed && _step == 2,
                            onTap: _onConfirmDeleteTap,
                            borderRadius: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              child: Text(
                                '삭제',
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: AppTheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MockPetCard extends StatelessWidget {
  final _PetData pet;
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
          HighlightTarget(
            isActive: isMenuActive,
            onTap: onMenuTap,
            shape: HighlightShape.circle,
            child: Container(
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
