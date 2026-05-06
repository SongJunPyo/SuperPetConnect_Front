// lib/widgets/tutorial/scene_pet_management.dart
// 슬라이드 3 — 반려동물 관리 미니 모형. 2스텝 시퀀스.
//
// 스텝 1: + 버튼 → 가짜 펫 한 마리 추가 (슬라이드 인 애니메이션)
// 스텝 2: 첫 펫의 ⋮ 메뉴 → 해당 펫 제거 (페이드 아웃) + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'spotlight_stage.dart';

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
  final GlobalKey _addButtonKey = GlobalKey();

  late List<_MockPet> _pets;
  int _stepIndex = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _pets = [
      _MockPet(name: '초코', breed: '골든리트리버', weight: '28kg'),
      _MockPet(name: '멍멍이', breed: '푸들', weight: '8kg'),
    ];
  }

  void _addPet() {
    if (_stepIndex != 0 || _completed) return;
    setState(() {
      _pets.add(
        _MockPet(name: '새친구', breed: '비글', weight: '12kg'),
      );
      _stepIndex = 1;
    });
  }

  void _removeFirstPet() {
    if (_stepIndex != 1 || _completed) return;
    setState(() {
      if (_pets.isNotEmpty) {
        _pets.removeAt(0);
      }
      _stepIndex = 2;
      _completed = true;
    });
    widget.onComplete();
  }

  List<SpotlightStep> _buildSteps() {
    if (_completed) return const [];
    if (_stepIndex == 0) {
      return [
        SpotlightStep(
          targetKey: _addButtonKey,
          tooltip: '여기를 눌러 새 반려동물을 등록해보세요',
          shape: SpotlightShape.circle,
          onTap: _addPet,
        ),
      ];
    } else if (_stepIndex == 1 && _pets.isNotEmpty) {
      return [
        SpotlightStep(
          targetKey: _pets.first.menuKey,
          tooltip: '메뉴를 눌러 반려동물을 삭제할 수 있어요',
          shape: SpotlightShape.circle,
          onTap: _removeFirstPet,
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return SpotlightStage(
      steps: _buildSteps(),
      onComplete: () {},
      child: _buildPetList(),
    );
  }

  Widget _buildPetList() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Text(
                  '반려동물',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  key: _addButtonKey,
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
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // 펫 카드 목록
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Column(
              children: [
                for (var i = 0; i < _pets.length; i++) ...[
                  _MockPetCard(pet: _pets[i]),
                  if (i < _pets.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockPetCard extends StatelessWidget {
  final _MockPet pet;

  const _MockPetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Text('🐾', style: TextStyle(fontSize: 24)),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.breed} · ${pet.weight}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            key: pet.menuKey,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
