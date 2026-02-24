import 'package:flutter/material.dart';

/// 게시글 상세 바텀시트 상단의 핸들바 (드래그 인디케이터)
class PostDetailHandleBar extends StatelessWidget {
  const PostDetailHandleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
