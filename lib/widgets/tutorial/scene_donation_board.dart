// lib/widgets/tutorial/scene_donation_board.dart
// 슬라이드 1 — 헌혈 게시판 미니 모형. 첫 번째 게시글 카드에 스포트라이트.
// 사용자가 카드를 탭하면 펄스 애니메이션 + 시퀀스 완료.

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'spotlight_stage.dart';

class DonationBoardScene extends StatefulWidget {
  /// 시퀀스 완료 시 호출.
  final VoidCallback onComplete;

  const DonationBoardScene({super.key, required this.onComplete});

  @override
  State<DonationBoardScene> createState() => _DonationBoardSceneState();
}

class _DonationBoardSceneState extends State<DonationBoardScene>
    with SingleTickerProviderStateMixin {
  final GlobalKey _firstCardKey = GlobalKey();
  late final AnimationController _pulseController;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onCardTap() {
    if (_completed) return;
    setState(() => _completed = true);
    _pulseController.forward(from: 0);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _completed
        ? <SpotlightStep>[]
        : [
            SpotlightStep(
              targetKey: _firstCardKey,
              tooltip: '관심 있는 게시글을 탭해보세요',
              onTap: _onCardTap,
            ),
          ];

    return SpotlightStage(
      steps: steps,
      onComplete: () {},
      child: _buildBoard(),
    );
  }

  Widget _buildBoard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing8,
            ),
            child: Text(
              '헌혈 게시판',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  1.0 + (0.04 * (1 - (_pulseController.value - 0.5).abs() * 2));
              return Transform.scale(
                scale: _pulseController.isAnimating ? scale : 1.0,
                child: child,
              );
            },
            child: _MockPostCard(
              key: _firstCardKey,
              urgent: true,
              title: '강아지 헌혈 필요',
              hospital: '행복동물병원',
              distance: '5km',
              completed: _completed,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _MockPostCard(
            urgent: false,
            title: '정기 헌혈 모집',
            hospital: '사랑동물병원',
            distance: '12km',
            completed: false,
          ),
        ],
      ),
    );
  }
}

class _MockPostCard extends StatelessWidget {
  final bool urgent;
  final String title;
  final String hospital;
  final String distance;
  final bool completed;

  const _MockPostCard({
    super.key,
    required this.urgent,
    required this.title,
    required this.hospital,
    required this.distance,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: completed
              ? AppTheme.primaryBlue
              : AppTheme.lightGray.withValues(alpha: 0.6),
          width: completed ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bloodtype_outlined,
            color: urgent ? AppTheme.error : AppTheme.primaryBlue,
            size: 28,
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (urgent) ...[
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$hospital · $distance',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (completed)
            Icon(Icons.check_circle, color: AppTheme.primaryBlue, size: 20),
        ],
      ),
    );
  }
}
