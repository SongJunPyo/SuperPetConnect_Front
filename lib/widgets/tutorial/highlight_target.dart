// lib/widgets/tutorial/highlight_target.dart
// 튜토리얼에서 강조할 위젯을 감싸는 래퍼.
//
// active일 때만 동작:
//   - 자식 위에 펄싱 보더 + 글로우 (foreground decoration, 레이아웃 흔들림 없음)
//   - 탭 감지해서 onTap 호출
// inactive일 때는 자식 그대로 통과 (오버레이/탭 가로채기 X).
//
// 검은색 배경 오버레이 없음. 강조 색은 빨강(`AppTheme.error`).

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

enum HighlightShape { roundedRect, circle }

class HighlightTarget extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final VoidCallback? onTap;
  final HighlightShape shape;

  /// 보더 라운드 반경. circle일 때 무시.
  final double borderRadius;

  const HighlightTarget({
    super.key,
    required this.child,
    required this.isActive,
    this.onTap,
    this.shape = HighlightShape.roundedRect,
    this.borderRadius = 12,
  });

  @override
  State<HighlightTarget> createState() => _HighlightTargetState();
}

class _HighlightTargetState extends State<HighlightTarget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(HighlightTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    final accent = AppTheme.error;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value;
          return Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: widget.shape == HighlightShape.circle
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: widget.shape == HighlightShape.circle
                          ? null
                          : BorderRadius.circular(widget.borderRadius),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.55 + 0.45 * t),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25 * t),
                          blurRadius: 6 + 10 * t,
                          spreadRadius: 1 + 2 * t,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 강조 영역 아래/위에 표시되는 안내 텍스트 박스.
/// 슬라이드 본문 하단에 단독 위젯으로 배치하는 용도 (강조 영역과 분리).
class TutorialHelperText extends StatelessWidget {
  final String text;

  const TutorialHelperText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 18, color: AppTheme.error),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
