import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../rich_text_viewer.dart';

/// 게시글 상세 설명글 섹션
/// RichTextViewer를 사용하여 Delta JSON 또는 일반 텍스트 표시
class PostDetailDescription extends StatelessWidget {
  final String? contentDelta; // Delta JSON (리치 텍스트)
  final String? plainText; // 일반 텍스트 (fallback)

  const PostDetailDescription({
    super.key,
    this.contentDelta,
    this.plainText,
  });

  bool get _hasContent {
    if (contentDelta != null && contentDelta!.isNotEmpty) return true;
    if (plainText != null && plainText!.isNotEmpty) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.veryLightGray,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.lightGray.withValues(alpha: 0.5),
            ),
          ),
          child: RichTextViewer(
            contentDelta: contentDelta,
            plainText: plainText,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
