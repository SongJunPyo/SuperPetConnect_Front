import 'package:flutter/material.dart';

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
  late Animation<double> _animation;
  bool _needsScrolling = false;
  double _contentWidth = 0;
  double _containerWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSizes();
    });
  }

  void _calculateSizes() {
    if (!mounted) return;

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();

    // leading 위젯 크기 추정 (있으면 fontSize + 간격)
    final double leadingWidth = widget.leading != null
        ? (widget.style?.fontSize ?? 14) + 6
        : 0;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox != null && renderBox.hasSize) {
      setState(() {
        _contentWidth = textPainter.width + leadingWidth;
        _containerWidth = renderBox.size.width;
        _needsScrolling = _contentWidth > _containerWidth;
      });

      if (_needsScrolling) {
        _setupAnimation();
        _startScrolling();
      }
    }
  }

  void _setupAnimation() {
    final double extraSpace = 32.0;
    final double scrollDistance = _contentWidth - _containerWidth + extraSpace;

    _animation = Tween<double>(
      begin: 0.0,
      end: scrollDistance > 0 ? scrollDistance : 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );

    _animation.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animation.value);
      }
    });
  }

  void _startScrolling() async {
    if (!mounted || !_needsScrolling) return;

    while (mounted && _needsScrolling) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      await _animationController.forward();
      if (!mounted) break;

      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildContent() {
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

  @override
  Widget build(BuildContext context) {
    return _needsScrolling
        ? SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: _buildContent(),
        )
        : widget.leading != null
            ? Row(
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
              )
            : Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
  }
}
