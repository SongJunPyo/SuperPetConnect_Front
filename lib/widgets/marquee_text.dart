import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration animationDuration;
  final Duration pauseDuration;
  final Widget? leading; // 텍스트 앞에 표시할 위젯 (프로필 사진 등)

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.animationDuration = const Duration(milliseconds: 4000),
    this.pauseDuration = const Duration(milliseconds: 1000),
    this.leading,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  Animation<double>? _animation;

  /// 현재 애니메이션이 진행 중인지. 부모의 ListView.builder가 위젯 위치를
  /// 재사용하거나 텍스트가 바뀔 때 리셋.
  bool _animationStarted = false;

  /// 마지막으로 평가한 (containerWidth, text) 키. 동일 조건이면 재시작 안 함.
  String? _lastEvaluationKey;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ListView.builder는 같은 위치에 다른 텍스트를 그릴 때 State를 재사용하므로,
    // text/style/leading 변경 시 애니메이션을 처음부터 다시 평가해야 함.
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.leading != widget.leading) {
      _stopAnimationAndReset();
      _lastEvaluationKey = null;
    }
  }

  void _stopAnimationAndReset() {
    _animationController.stop();
    _animationController.reset();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _animationStarted = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// build 도중 측정한 결과로 애니메이션 시작/중단을 다음 프레임에 동기화.
  /// 현재 프레임의 build 트리는 [shouldScroll] 값에 따라 이미 결정됨.
  void _syncAnimation({
    required bool shouldScroll,
    required double containerWidth,
    required double leadingWidth,
  }) {
    final key = '$containerWidth|${widget.text}';
    if (key == _lastEvaluationKey) return;
    _lastEvaluationKey = key;

    if (shouldScroll && !_animationStarted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // 자연 폭 측정 (스크롤 거리 계산용) — build와 동일한 effectiveStyle/textScaler.
        final TextScaler textScaler = MediaQuery.textScalerOf(context);
        final TextStyle effectiveStyle =
            DefaultTextStyle.of(context).style.merge(widget.style);
        final naturalPainter = TextPainter(
          text: TextSpan(text: widget.text, style: effectiveStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();

        final contentWidth = naturalPainter.width + leadingWidth;
        final scrollDistance =
            contentWidth - containerWidth + 32.0; // 끝까지 보여주는 여유 32px

        _animation = Tween<double>(
          begin: 0.0,
          end: scrollDistance > 0 ? scrollDistance : 0.0,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.linear,
          ),
        )..addListener(() {
            if (_scrollController.hasClients && _animation != null) {
              _scrollController.jumpTo(_animation!.value);
            }
          });

        _animationStarted = true;
        _runScrollLoop();
      });
    } else if (!shouldScroll && _animationStarted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _stopAnimationAndReset();
      });
    }
  }

  Future<void> _runScrollLoop() async {
    while (mounted && _animationStarted) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_animationStarted) break;

      await _animationController.forward();
      if (!mounted || !_animationStarted) break;

      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_animationStarted) break;

      _animationController.reset();
    }
  }

  Widget _buildScrollingContent() {
    if (widget.leading != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.leading!,
          const SizedBox(width: 4),
          Text(widget.text, style: widget.style, maxLines: 1),
        ],
      );
    }
    return Text(widget.text, style: widget.style, maxLines: 1);
  }

  Widget _buildEllipsisContent() {
    if (widget.leading != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.leading!,
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Text 위젯과 동일한 textScaler를 측정에도 적용해야 시스템 텍스트 크기 설정
    // (접근성 큰 글자 등) 변경 시 폭 측정이 어긋나지 않음.
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    // DefaultTextStyle 상속분도 머지 — Text 위젯은 자동으로 inherit하지만
    // TextPainter는 명시적으로 줘야 함.
    final TextStyle effectiveStyle =
        DefaultTextStyle.of(context).style.merge(widget.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;

        // 무한 폭(스크롤 컨테이너 안에 있는 경우 등)이면 측정 불가 — 자연 폭 그대로
        // 출력. 부모 컨텍스트가 부적절한 경우라 ellipsis 처리도 의미 없음.
        if (!containerWidth.isFinite) {
          return _buildScrollingContent();
        }

        // leading 폭은 실제 CircleAvatar 직경(fontSize * 1.1) + Row gap(4px)에 맞춰 추정.
        final double leadingWidth = widget.leading != null
            ? (effectiveStyle.fontSize ?? 14) * 1.1 + 4
            : 0.0;
        final double availableWidth =
            (containerWidth - leadingWidth).clamp(0.0, double.infinity);

        // 자연 폭 직접 측정 후 가용 폭과 비교. didExceedMaxLines는 일부 케이스
        // (Korean+Latin 혼합 텍스트 등)에서 false negative를 내는 사례가 있어,
        // 단순 비교가 더 안정적. 1픽셀 여유로 borderline 라운딩 차이도 흡수.
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: effectiveStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        final bool shouldScroll = painter.width + 1.0 > availableWidth;

        // build 트리는 이 값에 따라 즉시 결정. 애니메이션 lifecycle은 다음 프레임에 동기화.
        _syncAnimation(
          shouldScroll: shouldScroll,
          containerWidth: containerWidth,
          leadingWidth: leadingWidth,
        );

        if (shouldScroll) {
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: _buildScrollingContent(),
          );
        }
        return _buildEllipsisContent();
      },
    );
  }
}
