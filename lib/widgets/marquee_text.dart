import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration animationDuration;
  final Duration pauseDuration;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.animationDuration = const Duration(milliseconds: 4000), // 더 빠르게
    this.pauseDuration = const Duration(milliseconds: 1000), // 더 짧은 대기
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
  double _textWidth = 0;
  double _containerWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // 위젯이 렌더링된 후 크기 계산
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSizes();
    });
  }

  void _calculateSizes() {
    if (!mounted) return;

    // TextPainter를 사용하여 텍스트 크기 계산
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    
    // 컨테이너 크기 가져오기
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    
    if (renderBox != null && renderBox.hasSize) {
      setState(() {
        _textWidth = textPainter.width;
        _containerWidth = renderBox.size.width;
        _needsScrolling = _textWidth > _containerWidth;
      });

      if (_needsScrolling) {
        _setupAnimation();
        _startScrolling();
      }
    }
  }

  void _setupAnimation() {
    // 스크롤 거리: 텍스트 폭에서 컨테이너 폭을 뺀 만큼 + 추가 공백
    final double extraSpace = 32.0; // 2개 정도의 공백 (16px * 2)
    final double scrollDistance = _textWidth - _containerWidth + extraSpace;
    
    _animation = Tween<double>(
      begin: 0.0,
      end: scrollDistance > 0 ? scrollDistance : 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear, // 일정한 속도로 변경
    ));

    _animation.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animation.value);
      }
    });
  }

  void _startScrolling() async {
    if (!mounted || !_needsScrolling) return;

    while (mounted && _needsScrolling) {
      // 처음 위치에서 잠시 대기
      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      // 스크롤 시작
      await _animationController.forward();
      if (!mounted) break;

      // 끝에서 잠시 대기 (텍스트 끝 부분이 보이는 상태)
      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      // 처음으로 돌아가기
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _needsScrolling
        ? SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(), // 사용자 스크롤 비활성화
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
            ),
          )
        : Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
  }
}