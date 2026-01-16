import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import '../models/donation_post_image_model.dart';
import '../services/donation_post_image_service.dart';
import '../utils/app_theme.dart';

/// 리치 텍스트 에디터 위젯 (flutter_quill 기반)
/// 이미지를 텍스트 내 인라인으로 삽입 가능
class RichTextEditor extends StatefulWidget {
  final String? initialText;
  final List<DonationPostImage>? initialImages;
  final Function(String text, List<DonationPostImage> images)? onChanged;
  final int? postIdx;
  final int maxImages;
  final bool enabled;

  const RichTextEditor({
    super.key,
    this.initialText,
    this.initialImages,
    this.onChanged,
    this.postIdx,
    this.maxImages = 5,
    this.enabled = true,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// 업로드된 이미지 목록
  List<DonationPostImage> _images = [];

  /// 업로드 중인 임시 이미지 (진행률 표시용)
  DonationPostImage? _uploadingImage;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 에디터 초기화
  void _initializeEditor() {
    // 초기 텍스트가 있으면 파싱
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      final plainText = _extractPlainText(widget.initialText!);
      _controller = QuillController(
        document: Document()..insert(0, plainText),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _controller = QuillController.basic();
    }

    // 초기 이미지 설정
    if (widget.initialImages != null) {
      _images = List.from(widget.initialImages!);
    }

    // 변경 감지 리스너
    _controller.document.changes.listen((_) {
      _notifyChange();
    });
  }

  /// [IMAGE:id] 마커 제거하고 순수 텍스트 추출
  String _extractPlainText(String text) {
    return text.replaceAll(RegExp(r'\[IMAGE:\d+\]'), '').trim();
  }

  /// 변경 알림
  void _notifyChange() {
    if (!mounted) return;

    // Delta에서 텍스트와 이미지 정보 추출
    final delta = _controller.document.toDelta();
    final buffer = StringBuffer();
    final List<int> embeddedImageIds = [];

    for (final op in delta.toList()) {
      if (op.isInsert) {
        if (op.data is String) {
          buffer.write(op.data);
        } else if (op.data is Map) {
          final data = op.data as Map;
          if (data.containsKey('image')) {
            // 이미지 URL에서 ID 추출
            final imageUrl = data['image'] as String;
            final imageId = _extractImageIdFromUrl(imageUrl);
            if (imageId != null) {
              embeddedImageIds.add(imageId);
              buffer.write('[IMAGE:$imageId]');
            }
          }
        }
      }
    }

    widget.onChanged?.call(buffer.toString(), _images);
  }

  /// URL에서 이미지 ID 추출
  int? _extractImageIdFromUrl(String url) {
    // _images에서 URL과 매칭되는 이미지 찾기
    for (final image in _images) {
      final fullUrl = DonationPostImageService.getFullImageUrl(image.imagePath);
      if (url == fullUrl || url == image.imagePath) {
        return image.imageId;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: AppTheme.lightGray.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius16 - 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 툴바
                if (widget.enabled) _buildToolbar(),

                // 에디터 영역 (반응형)
                Flexible(
                  fit: FlexFit.loose,
                  child: _buildEditor(),
                ),

                // 업로드 진행 표시
                if (_uploadingImage != null) _buildUploadProgress(),

                // 하단 정보
                _buildFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 툴바
  Widget _buildToolbar() {
    // 툴바 버튼 Row
    final toolbarButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 텍스트 스타일 버튼들
        _buildQuillButton(
          attribute: Attribute.bold,
          icon: Icons.format_bold,
          tooltip: '굵게',
        ),
        const SizedBox(width: 4),
        _buildQuillButton(
          attribute: Attribute.italic,
          icon: Icons.format_italic,
          tooltip: '기울임',
        ),
        const SizedBox(width: 4),
        _buildQuillButton(
          attribute: Attribute.underline,
          icon: Icons.format_underline,
          tooltip: '밑줄',
        ),

        // 구분선
        _buildDivider(),

        // 정렬 버튼들
        _buildAlignButton(Attribute.leftAlignment, Icons.format_align_left, '왼쪽 정렬'),
        const SizedBox(width: 4),
        _buildAlignButton(Attribute.centerAlignment, Icons.format_align_center, '가운데 정렬'),
        const SizedBox(width: 4),
        _buildAlignButton(Attribute.rightAlignment, Icons.format_align_right, '오른쪽 정렬'),

        // 구분선
        _buildDivider(),

        // 불릿 버튼
        _buildQuillButton(
          attribute: Attribute.ul,
          icon: Icons.format_list_bulleted,
          tooltip: '목록',
        ),

        // 구분선
        _buildDivider(),

        // 이미지 버튼
        _buildImageButton(),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.veryLightGray,
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: toolbarButtons,
        ),
      ),
    );
  }

  /// Quill 스타일 버튼
  Widget _buildQuillButton({
    required Attribute attribute,
    required IconData icon,
    required String tooltip,
  }) {
    final isActive = _controller.getSelectionStyle().containsKey(attribute.key);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppTheme.info : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: InkWell(
          onTap: () {
            if (_controller.getSelectionStyle().containsKey(attribute.key)) {
              _controller.formatSelection(Attribute.clone(attribute, null));
            } else {
              _controller.formatSelection(attribute);
            }
            setState(() {});
          },
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : AppTheme.darkGray,
            ),
          ),
        ),
      ),
    );
  }

  /// 정렬 버튼
  Widget _buildAlignButton(Attribute attribute, IconData icon, String tooltip) {
    final style = _controller.getSelectionStyle();
    final isActive = style.containsKey(Attribute.align.key) &&
        style.attributes[Attribute.align.key]?.value == attribute.value;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppTheme.info : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: InkWell(
          onTap: () {
            _controller.formatSelection(attribute);
            setState(() {});
          },
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : AppTheme.darkGray,
            ),
          ),
        ),
      ),
    );
  }

  /// 구분선
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.lightGray,
    );
  }

  /// 이미지 버튼
  Widget _buildImageButton() {
    final canAddMore = _images.length < widget.maxImages;

    return Tooltip(
      message: '이미지 (${_images.length}/${widget.maxImages})',
      child: Material(
        color: canAddMore ? Colors.white : AppTheme.lightGray,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: InkWell(
          onTap: canAddMore ? _showImagePicker : null,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              Icons.image,
              size: 20,
              color: canAddMore ? AppTheme.darkGray : AppTheme.mediumGray,
            ),
          ),
        ),
      ),
    );
  }

  /// 에디터 영역
  Widget _buildEditor() {
    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
        ),

      child: QuillEditor(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          placeholder: '헌혈에 대한 추가 설명을 작성해주세요...',
          padding: EdgeInsets.zero,
          autoFocus: false,
          expands: false,
          scrollable: true,
          textCapitalization: TextCapitalization.none,
          embedBuilders: [
            _CustomImageEmbedBuilder(
              onDelete: _removeImageFromEditor,
              enabled: widget.enabled,
            ),
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
            placeHolder: DefaultTextBlockStyle(
              TextStyle(
                color: AppTheme.mediumGray,
                fontSize: AppTheme.bodyMedium,
                height: 1.6,
              ),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(0, 0),
              const VerticalSpacing(0, 0),
              null,
            ),
          ),
        ),
      ),
    );
  }

  /// 업로드 진행 표시
  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _uploadingImage?.uploadProgress,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            '이미지 업로드 중...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 하단 정보
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.veryLightGray,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.image, size: 16, color: AppTheme.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            '이미지 ${_images.length}/${widget.maxImages}',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: AppTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 이미지 선택 다이얼로그
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImagePickerBottomSheet(
        onImageSelected: (XFile file) async {
          Navigator.pop(context);
          await _uploadImage(file);
        },
      ),
    );
  }

  /// 이미지 업로드 및 에디터에 삽입
  Future<void> _uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      if (fileSize > 20 * 1024 * 1024) {
        _showSnackBar('이미지 크기가 20MB를 초과합니다.', isError: true);
        return;
      }

      // 업로드 진행 표시
      setState(() {
        _uploadingImage = DonationPostImage.temporary(
          localPath: kIsWeb ? null : file.path,
          localBytes: bytes,
          originalName: file.name,
          fileSize: fileSize,
        );
      });

      // 서버 업로드
      final uploadedImage = await DonationPostImageService.uploadImageBytes(
        imageBytes: bytes,
        fileName: file.name,
        postIdx: widget.postIdx,
        imageOrder: _images.length,
        onProgress: (progress) {
          setState(() {
            _uploadingImage = _uploadingImage?.copyWithProgress(progress);
          });
        },
      );

      // 이미지 목록에 추가
      _images.add(uploadedImage);

      // 에디터에 이미지 삽입 (현재 커서 위치에)
      final imageUrl = DonationPostImageService.getFullImageUrl(uploadedImage.imagePath);
      final index = _controller.selection.baseOffset;

      // 새 줄 추가 후 이미지 삽입
      _controller.document.insert(index, '\n');
      _controller.document.insert(index + 1, BlockEmbed.image(imageUrl));
      _controller.document.insert(index + 2, '\n');

      // 커서를 이미지 뒤로 이동
      _controller.updateSelection(
        TextSelection.collapsed(offset: index + 3),
        ChangeSource.local,
      );

      setState(() {
        _uploadingImage = null;
      });

      _notifyChange();
    } catch (e) {
      _showSnackBar('이미지 업로드 실패: $e', isError: true);
      setState(() {
        _uploadingImage = null;
      });
    }
  }

  /// 에디터에서 이미지 삭제
  void _removeImageFromEditor(String imageUrl) {
    // 이미지 목록에서 해당 이미지 찾기
    final imageToRemove = _images.where((img) {
      final fullUrl = DonationPostImageService.getFullImageUrl(img.imagePath);
      return fullUrl == imageUrl || img.imagePath == imageUrl;
    }).firstOrNull;

    if (imageToRemove != null) {
      _confirmDeleteImage(imageToRemove, imageUrl);
    }
  }

  /// 이미지 삭제 확인
  void _confirmDeleteImage(DonationPostImage image, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 삭제'),
        content: const Text('이 이미지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeImage(image, imageUrl);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 이미지 삭제
  Future<void> _removeImage(DonationPostImage image, String imageUrl) async {
    if (!image.isTemporary) {
      try {
        await DonationPostImageService.deleteImage(image.imageId);
      } catch (e) {
        _showSnackBar('이미지 삭제 실패: $e', isError: true);
        return;
      }
    }

    // 이미지 목록에서 제거
    setState(() {
      _images.removeWhere((img) => img.imageId == image.imageId);
    });

    // 에디터에서 이미지 블록 제거
    _removeImageBlockFromDocument(imageUrl);

    _notifyChange();
  }

  /// 문서에서 이미지 블록 제거
  void _removeImageBlockFromDocument(String imageUrl) {
    final delta = _controller.document.toDelta();
    int index = 0;

    for (final op in delta.toList()) {
      if (op.isInsert) {
        if (op.data is Map) {
          final data = op.data as Map;
          if (data.containsKey('image') && data['image'] == imageUrl) {
            // 이미지 블록 삭제
            _controller.document.delete(index, 1);
            break;
          }
        }
        index += op.length ?? 1;
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
    }
  }

  // Public getters
  String get text {
    final delta = _controller.document.toDelta();
    final buffer = StringBuffer();

    for (final op in delta.toList()) {
      if (op.isInsert) {
        if (op.data is String) {
          buffer.write(op.data);
        } else if (op.data is Map) {
          final data = op.data as Map;
          if (data.containsKey('image')) {
            final imageUrl = data['image'] as String;
            final imageId = _extractImageIdFromUrl(imageUrl);
            if (imageId != null) {
              buffer.write('[IMAGE:$imageId]');
            }
          }
        }
      }
    }

    return buffer.toString();
  }

  List<DonationPostImage> get images => _images;
  List<int> get imageIds =>
      _images.where((img) => !img.isTemporary).map((img) => img.imageId).toList();
}

/// 커스텀 이미지 임베드 빌더
class _CustomImageEmbedBuilder extends EmbedBuilder {
  final Function(String imageUrl) onDelete;
  final bool enabled;

  _CustomImageEmbedBuilder({
    required this.onDelete,
    required this.enabled,
  });

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
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 이미지 선택 바텀시트
class _ImagePickerBottomSheet extends StatefulWidget {
  final Function(XFile) onImageSelected;

  const _ImagePickerBottomSheet({
    required this.onImageSelected,
  });

  @override
  State<_ImagePickerBottomSheet> createState() => _ImagePickerBottomSheetState();
}

class _ImagePickerBottomSheetState extends State<_ImagePickerBottomSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '이미지 추가',
                style: TextStyle(
                  fontSize: AppTheme.h4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else ...[
              if (!kIsWeb)
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.veryLightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt, color: AppTheme.darkGray),
                  ),
                  title: const Text('카메라로 촬영'),
                  subtitle: Text(
                    '직접 사진을 촬영합니다',
                    style: TextStyle(color: AppTheme.textTertiary),
                  ),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.veryLightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library, color: AppTheme.darkGray),
                ),
                title: Text(kIsWeb ? '파일 선택' : '갤러리에서 선택'),
                subtitle: Text(
                  kIsWeb ? '컴퓨터에서 이미지를 선택합니다' : '기기에 저장된 사진을 선택합니다',
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.veryLightGray,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('취소'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isLoading = true);

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.length > 20 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('이미지 크기가 20MB를 초과합니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        widget.onImageSelected(pickedFile);
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
