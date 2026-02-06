import 'package:flutter/material.dart';
import '../services/hospital_column_service.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/rich_text_editor.dart';

class HospitalColumnEdit extends StatefulWidget {
  final HospitalColumn column;

  const HospitalColumnEdit({super.key, required this.column});

  @override
  State createState() => _HospitalColumnEditState();
}

class _HospitalColumnEditState extends State<HospitalColumnEdit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  final GlobalKey<RichTextEditorState> _editorKey = GlobalKey<RichTextEditorState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.column.title);
    _urlController = TextEditingController(text: widget.column.columnUrl ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _updateColumn() async {
    if (!_formKey.currentState!.validate()) return;

    // RichTextEditor에서 내용 가져오기
    final editorState = _editorKey.currentState;
    final plainText = editorState?.text.trim() ?? '';
    final contentDelta = editorState?.contentDelta;

    // 내용 검증
    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }
    if (plainText.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용은 10글자 이상 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = HospitalColumnUpdateRequest(
        title: _titleController.text.trim(),
        content: plainText,
        contentDelta: contentDelta,
        columnUrl:
            _urlController.text.trim().isEmpty
                ? null
                : _urlController.text.trim(),
      );

      await HospitalColumnService.updateColumn(
        widget.column.columnIdx,
        request,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        debugPrint('칼럼 수정 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(title: '칼럼 수정', showBackButton: true),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppTheme.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '제목',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: '칼럼 제목을 입력하세요 (최대 100자)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    borderSide: const BorderSide(color: AppTheme.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                ),
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  if (value.trim().length < 3) {
                    return '제목은 3글자 이상 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),
              Text(
                '내용',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.lightGray),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  child: RichTextEditor(
                    key: _editorKey,
                    editorType: EditorType.column,
                    columnIdx: widget.column.columnIdx,
                    initialContentDelta: widget.column.contentDelta,
                    initialText: widget.column.contentDelta == null ? widget.column.content : null,
                    placeholder: '칼럼 내용을 입력하세요.',
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing32),
              Text(
                'URL (선택)',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    borderSide: const BorderSide(color: AppTheme.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final urlPattern = RegExp(
                      r'^https?://[\w\-]+(\.[\w\-]+)+[/#?]?.*$',
                      caseSensitive: false,
                    );
                    if (!urlPattern.hasMatch(value.trim())) {
                      return '올바른 URL 형식이 아닙니다. (http:// 또는 https://)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing32),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateColumn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          '칼럼 수정',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
              const SizedBox(height: AppTheme.spacing20),
            ],
          ),
        ),
      ),
    );
  }
}
