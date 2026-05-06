// lib/widgets/tutorial/spotlight_stage.dart
// 튜토리얼 인터랙티브 슬라이드의 공통 컨테이너.
//
// child(가데이터 모형 화면)을 감싸고 그 위에 어두운 오버레이 + 강조 영역(구멍) + 말풍선을 그림.
// 강조 영역을 탭하면 step의 onTap 콜백 실행 → 다음 step으로 진행.
// 마지막 step 탭 시 onComplete 호출 (부모가 [다음] 버튼 활성화 트리거).

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 강조 영역 모양.
enum SpotlightShape { circle, roundedRect }

/// 단일 스포트라이트 스텝 정의.
class SpotlightStep {
  /// 강조할 위젯의 GlobalKey (모형 화면 안에서 부여).
  final GlobalKey targetKey;

  /// 말풍선 텍스트.
  final String tooltip;

  /// 강조 영역 모양.
  final SpotlightShape shape;

  /// 강조 영역 패딩 (위젯 경계로부터 바깥쪽 여유).
  final double padding;

  /// 사용자가 강조 영역을 탭했을 때 실행 (모형 상태 변경 등).
  /// 호출 후 자동으로 다음 step으로 진행됨.
  final VoidCallback onTap;

  const SpotlightStep({
    required this.targetKey,
    required this.tooltip,
    required this.onTap,
    this.shape = SpotlightShape.roundedRect,
    this.padding = 8,
  });
}

/// 모형 화면 + 스포트라이트 시퀀스 컨테이너.
class SpotlightStage extends StatefulWidget {
  /// 가데이터 모형 화면 (child가 자체 state 가질 수 있음).
  final Widget child;

  /// 스텝 시퀀스. 부모가 mock state를 가질 경우 매 빌드마다 새로 만들어 전달.
  final List<SpotlightStep> steps;

  /// 모든 step 완료 후 1회 호출.
  final VoidCallback onComplete;

  /// 현재 step 인덱스 (외부 컨트롤). null이면 internal state 사용.
  final int? currentStep;

  const SpotlightStage({
    super.key,
    required this.child,
    required this.steps,
    required this.onComplete,
    this.currentStep,
  });

  @override
  State<SpotlightStage> createState() => _SpotlightStageState();
}

class _SpotlightStageState extends State<SpotlightStage> {
  Rect? _targetRect;
  Size? _stageSize;
  final GlobalKey _stageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void didUpdateWidget(SpotlightStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // step이 바뀌었거나 mock state가 바뀐 후 좌표 재측정.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  void _measureTarget() {
    if (!mounted) return;
    final stepIdx = widget.currentStep ?? 0;
    if (stepIdx >= widget.steps.length) return;

    final step = widget.steps[stepIdx];
    final targetCtx = step.targetKey.currentContext;
    final stageCtx = _stageKey.currentContext;
    if (targetCtx == null || stageCtx == null) return;

    final targetBox = targetCtx.findRenderObject() as RenderBox?;
    final stageBox = stageCtx.findRenderObject() as RenderBox?;
    if (targetBox == null || stageBox == null) return;
    if (!targetBox.hasSize || !stageBox.hasSize) return;

    final targetTopLeft = targetBox.localToGlobal(
      Offset.zero,
      ancestor: stageBox,
    );
    final rect = targetTopLeft & targetBox.size;

    if (mounted) {
      setState(() {
        _targetRect = rect.inflate(step.padding);
        _stageSize = stageBox.size;
      });
    }
  }

  void _handleTap(Offset position) {
    final rect = _targetRect;
    if (rect == null) return;
    final stepIdx = widget.currentStep ?? 0;
    if (stepIdx >= widget.steps.length) return;

    if (rect.contains(position)) {
      final step = widget.steps[stepIdx];
      step.onTap();
      // 마지막 step이면 완료 콜백
      if (stepIdx == widget.steps.length - 1) {
        widget.onComplete();
      }
    }
    // 강조 영역 밖 탭은 무시 (오버레이가 흡수).
  }

  @override
  Widget build(BuildContext context) {
    final stepIdx = widget.currentStep ?? 0;
    final isActive = stepIdx < widget.steps.length;
    final currentStep = isActive ? widget.steps[stepIdx] : null;

    return Stack(
      key: _stageKey,
      children: [
        // 모형 화면
        widget.child,

        // 어두운 오버레이 + 구멍
        if (_targetRect != null && currentStep != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTap(details.localPosition),
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: _targetRect!,
                  shape: currentStep.shape,
                ),
              ),
            ),
          ),

        // 말풍선
        if (_targetRect != null &&
            _stageSize != null &&
            currentStep != null)
          _buildTooltip(currentStep, _targetRect!, _stageSize!),
      ],
    );
  }

  Widget _buildTooltip(SpotlightStep step, Rect rect, Size stageSize) {
    // 강조 영역의 위/아래 중 더 공간이 넓은 쪽에 배치
    final spaceAbove = rect.top;
    final spaceBelow = stageSize.height - rect.bottom;
    final placeBelow = spaceBelow >= spaceAbove;

    return Positioned(
      left: 16,
      right: 16,
      top: placeBelow ? rect.bottom + 12 : null,
      bottom: placeBelow ? null : stageSize.height - rect.top + 12,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Flexible(
                  child: Text(
                    step.tooltip,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final SpotlightShape shape;

  _SpotlightPainter({required this.targetRect, required this.shape});

  @override
  void paint(Canvas canvas, Size size) {
    // 어두운 배경 + 구멍을 evenOdd로 합성
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = shape == SpotlightShape.circle
        ? (Path()
          ..addOval(Rect.fromCircle(
            center: targetRect.center,
            radius: targetRect.longestSide / 2,
          )))
        : (Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              targetRect,
              const Radius.circular(AppTheme.radius12),
            ),
          ));

    final combined = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(
      combined,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    // 구멍 외곽 흰색 테두리 (강조)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.8);
    if (shape == SpotlightShape.circle) {
      canvas.drawCircle(
        targetRect.center,
        targetRect.longestSide / 2,
        borderPaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect,
          const Radius.circular(AppTheme.radius12),
        ),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.targetRect != targetRect || old.shape != shape;
}
