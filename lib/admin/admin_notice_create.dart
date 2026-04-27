import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../models/notice_model.dart';
import '../services/notice_service.dart';

class AdminNoticeCreateScreen extends StatefulWidget {
  final Notice? editNotice; // 수정 모드일 경우 전달받는 공지글

  const AdminNoticeCreateScreen({super.key, this.editNotice});

  @override
  State<AdminNoticeCreateScreen> createState() =>
      _AdminNoticeCreateScreenState();
}

class _AdminNoticeCreateScreenState extends State<AdminNoticeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _urlController = TextEditingController();
  int _isImportant = 0; // 0=일반, 1=중요공지(빨강)
  bool _isLoading = false;
  int _targetAudience = 0; // 0: 전체, 1: 관리자, 2: 병원

  bool get isEditMode => widget.editNotice != null;

  // audience가 관리자/병원이면 중요 공지(importance=1)와 충돌하므로 비활성화
  bool get _importantDisabled =>
      _targetAudience == 1 || _targetAudience == 2;

  // importance가 중요(1)이면 관리자/병원 audience와 충돌하므로 비활성화
  bool get _audienceRestrictedDisabled => _isImportant == 1;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _titleController.text = widget.editNotice!.title;
      _contentController.text = widget.editNotice!.content;
      _urlController.text = widget.editNotice!.noticeUrl ?? '';
      _isImportant = widget.editNotice!.noticeImportant;
      _targetAudience = widget.editNotice!.targetAudience;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submitNotice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (isEditMode) {
        // 수정 모드
        final updateRequest = NoticeUpdateRequest(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          noticeImportant: _isImportant,
          targetAudience: _targetAudience,
          noticeUrl:
              _urlController.text.trim().isEmpty
                  ? null
                  : _urlController.text.trim(),
        );

        await NoticeService.updateNotice(
          widget.editNotice!.noticeIdx,
          updateRequest,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('공지글이 성공적으로 수정되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // 수정 성공 표시
        }
      } else {
        // 새 작성 모드
        final createRequest = NoticeCreateRequest(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          noticeImportant: _isImportant,
          targetAudience: _targetAudience,
          noticeUrl:
              _urlController.text.trim().isEmpty
                  ? null
                  : _urlController.text.trim(),
        );

        await NoticeService.createNotice(createRequest);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('공지글이 성공적으로 작성되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // 작성 성공 표시
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: isEditMode ? '공지글 수정' : '공지글 작성',
        showBackButton: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppTheme.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목 입력
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
                  hintText: '공지글 제목을 입력하세요 (최대 100자)',
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
                  if (value.trim().length > 100) {
                    return '제목은 100자 이내로 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),

              // 내용 입력
              Text(
                '내용',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: '공지글 내용을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    borderSide: const BorderSide(color: AppTheme.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                ),
                maxLines: 10,
                minLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '내용을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),

              // URL 입력 (선택사항)
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
                  hintText: 'https://example.com (네이버 카페 등)',
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
                    // URL 형식 검증
                    final urlPattern = RegExp(
                      r'^https?://[\w\-]+(\.[\w\-]+)+[/#?]?.*$',
                      caseSensitive: false,
                    );
                    if (!urlPattern.hasMatch(value.trim())) {
                      return '올바른 URL 형식이 아닙니다 (http:// 또는 https://로 시작해야 합니다)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),

              // 공지 대상 선택
              Text(
                '공지 대상',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(color: AppTheme.lightGray),
                ),
                child: RadioGroup<int>(
                  groupValue: _targetAudience,
                  onChanged: (value) {
                    if (value == null) return;
                    // 중요 공지일 때는 관리자/병원으로 변경 차단
                    if (_audienceRestrictedDisabled &&
                        (value == 1 || value == 2)) {
                      return;
                    }
                    setState(() {
                      _targetAudience = value;
                    });
                  },
                  child: Column(
                    children: [
                      RadioListTile<int>(
                        title: const Text('전체'),
                        subtitle: const Text('모든 사용자에게 표시'),
                        value: 0,
                        activeColor: AppTheme.black,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<int>(
                        title: Text(
                          '관리자',
                          style: TextStyle(
                            color: _audienceRestrictedDisabled
                                ? AppTheme.textTertiary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          _audienceRestrictedDisabled
                              ? '중요 공지 해제 후 선택할 수 있습니다'
                              : '관리자에게만 표시',
                        ),
                        value: 1,
                        activeColor: AppTheme.primaryBlue,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<int>(
                        title: Text(
                          '병원',
                          style: TextStyle(
                            color: _audienceRestrictedDisabled
                                ? AppTheme.textTertiary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          _audienceRestrictedDisabled
                              ? '중요 공지 해제 후 선택할 수 있습니다'
                              : '병원 사용자에게만 표시',
                        ),
                        value: 2,
                        activeColor: AppTheme.success,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // 중요 공지 체크박스 (대상이 관리자/병원이면 비활성화)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isImportant == 1,
                      onChanged: _importantDisabled
                          ? null
                          : (value) {
                              setState(() {
                                _isImportant = (value ?? false) ? 1 : 0;
                              });
                            },
                      activeColor: AppTheme.error,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '중요 공지',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _importantDisabled
                                  ? AppTheme.textTertiary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Text(
                            _importantDisabled
                                ? '대상이 전체일 때만 중요 공지로 지정할 수 있습니다.'
                                : '체크하면 빨강색으로 표시되며 상단에 고정됩니다.',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing32),

              // 작성/수정 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _submitNotice,
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
                          isEditMode ? '공지글 수정' : '공지글 작성',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
