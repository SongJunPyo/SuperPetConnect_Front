import 'package:flutter/material.dart';

/// 천천히 깜빡이는 아이콘 위젯
/// 사용자의 주목을 끌기 위해 사용
class BlinkingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final Duration duration;

  // ignore: prefer_const_constructors_in_immutables
  BlinkingIcon({
    super.key,
    required this.icon,
    this.color = Colors.black,
    this.size = 24,
    Duration? duration,
  }) : duration = duration ?? const Duration(seconds: 2);

  @override
  State<BlinkingIcon> createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<BlinkingIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacityAnimation;
  Animation<Color?>? _colorAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 생성
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 투명도 애니메이션: 0.5 ~ 1.0 사이를 부드럽게 왕복
    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ),
    );

    // 색상 애니메이션: 검은색 ↔ 빨간색 왕복
    _colorAnimation = ColorTween(
      begin: widget.color,
      end: Colors.red.shade600,
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ),
    );

    // 무한 반복
    _controller!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 애니메이션이 초기화되지 않은 경우 정적 아이콘 표시
    if (_controller == null || _opacityAnimation == null || _colorAnimation == null) {
      return Icon(
        widget.icon,
        color: widget.color,
        size: widget.size,
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation!.value,
          child: Icon(
            widget.icon,
            color: _colorAnimation!.value,
            size: widget.size,
          ),
        );
      },
    );
  }
}
