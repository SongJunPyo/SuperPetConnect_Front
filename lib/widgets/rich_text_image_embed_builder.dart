import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/app_theme.dart';

/// flutter_quill 본문 안에 인라인으로 박힌 이미지 임베드를 렌더링하는 빌더.
///
/// `RichTextEditor`가 편집 모드일 때(`enabled=true`) 이미지 우상단에 ✕ 버튼을
/// 띄워 [onDelete]로 삭제 트리거. 뷰어 모드(`enabled=false`)는 이미지만 표시.
/// 네트워크 이미지 로드 실패 시 회색 placeholder를 보여줌.
class RichTextImageEmbedBuilder extends EmbedBuilder {
  final void Function(String imageUrl) onDelete;
  final bool enabled;

  RichTextImageEmbedBuilder({required this.onDelete, required this.enabled});

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Stack(
        children: [
          // 이미지
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.veryLightGray,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 48,
                        color: AppTheme.mediumGray,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '이미지를 불러올 수 없습니다',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: AppTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 삭제 버튼
          if (enabled)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => onDelete(imageUrl),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
