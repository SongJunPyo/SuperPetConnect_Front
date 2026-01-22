import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../services/donation_post_image_service.dart';
import '../utils/app_theme.dart';

/// 리치 텍스트 뷰어 위젯 (flutter_quill 기반)
/// Delta JSON을 읽기 전용으로 렌더링
class RichTextViewer extends StatefulWidget {
  /// Delta JSON 문자열 (리치 텍스트)
  final String? contentDelta;

  /// Plain text 버전 (contentDelta가 없을 때 fallback)
  final String? plainText;

  /// 배경색
  final Color? backgroundColor;

  /// 패딩
  final EdgeInsets padding;

  const RichTextViewer({
    super.key,
    this.contentDelta,
    this.plainText,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(AppTheme.spacing16),
  });

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(RichTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // contentDelta나 plainText가 변경되면 컨트롤러 재초기화
    if (oldWidget.contentDelta != widget.contentDelta ||
        oldWidget.plainText != widget.plainText) {
      _controller.dispose();
      _initializeController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 컨트롤러 초기화
  void _initializeController() {
    debugPrint('[RichTextViewer] 초기화 시작');
    debugPrint('[RichTextViewer] contentDelta: ${widget.contentDelta}');
    debugPrint('[RichTextViewer] plainText: ${widget.plainText}');

    // contentDelta가 있으면 Delta JSON 파싱
    if (widget.contentDelta != null && widget.contentDelta!.isNotEmpty) {
      debugPrint('[RichTextViewer] Delta JSON 파싱 시도...');
      try {
        final deltaJson = jsonDecode(widget.contentDelta!) as List;
        final List<Map<String, dynamic>> processedDelta = [];

        for (final op in deltaJson) {
          if (op is Map) {
            final insert = op['insert'];
            final attributes = op['attributes'];

            final Map<String, dynamic> processedOp = {};

            // insert 처리
            if (insert is String) {
              processedOp['insert'] = insert;
            } else if (insert is Map) {
              // 이미지인 경우 상대 경로를 절대 경로로 변환
              if (insert.containsKey('image')) {
                final imagePath = insert['image'] as String;
                final fullUrl = _toAbsoluteUrl(imagePath);
                processedOp['insert'] = {'image': fullUrl};
              } else {
                processedOp['insert'] = Map<String, dynamic>.from(insert);
              }
            }

            // attributes 처리
            if (attributes != null && attributes is Map) {
              processedOp['attributes'] = Map<String, dynamic>.from(attributes);
            }

            if (processedOp.isNotEmpty) {
              processedDelta.add(processedOp);
            }
          }
        }

        // Delta로 변환하여 Document 생성
        final delta = Delta.fromJson(processedDelta);
        _controller = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (e) {
        // 파싱 실패 시 plain text로 fallback
        debugPrint('Delta JSON 파싱 실패: $e');
        _initPlainTextController();
      }
    } else {
      // contentDelta가 없으면 plain text 사용
      _initPlainTextController();
    }
  }

  /// Plain text 컨트롤러 초기화
  void _initPlainTextController() {
    final text = widget.plainText ?? '';
    // [IMAGE:id] 마커 제거
    final cleanText = text.replaceAll(RegExp(r'\[IMAGE:\d+\]'), '').trim();

    if (cleanText.isNotEmpty) {
      _controller = QuillController(
        document: Document()..insert(0, cleanText),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } else {
      _controller = QuillController.basic();
      _controller.readOnly = true;
    }
  }

  /// 상대 경로를 절대 URL로 변환
  String _toAbsoluteUrl(String path) {
    // 이미 절대 URL인 경우 그대로 반환
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // 상대 경로를 절대 URL로 변환
    final baseUrl = DonationPostImageService.baseUrl;
    if (path.startsWith('/')) {
      return '$baseUrl$path';
    }
    return '$baseUrl/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      padding: widget.padding,
      child: QuillEditor(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          padding: EdgeInsets.zero,
          autoFocus: false,
          expands: false,
          scrollable: false, // 외부 스크롤 사용
          showCursor: false,
          enableInteractiveSelection: true,
          embedBuilders: [
            _ReadOnlyImageEmbedBuilder(),
          ],
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              TextStyle(
                color: AppTheme.textPrimary,
                fontSize: AppTheme.bodyMedium,
                height: 1.6,
              ),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(0, 8),
              const VerticalSpacing(0, 0),
              null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 읽기 전용 이미지 임베드 빌더
class _ReadOnlyImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final imageUrl = embedContext.node.value.data;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.veryLightGray,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
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
    );
  }
}
