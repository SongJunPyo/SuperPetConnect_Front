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
  int _isImportant = 1; // 0=뱃지 표시, 1=뱃지 숨김, 기본값은 숨김
  bool _isActive = true;
  bool _isLoading = false;
  int _targetAudience = 0; // 0: 전체, 1: 관리자, 2: 병원, 3: 사용자

  bool get isEditMode => widget.editNotice != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _titleController.text = widget.editNotice!.title;
      _contentController.text = widget.editNotice!.content;
      _urlController.text = widget.editNotice!.noticeUrl ?? '';
      _isImportant = widget.editNotice!.noticeImportant;
      _isActive = widget.editNotice!.noticeActive;
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
          noticeActive: _isActive,
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
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: const Text('전체'),
                      subtitle: const Text('모든 사용자에게 표시'),
                      value: 0,
                      groupValue: _targetAudience,
                      onChanged: (value) {
                        setState(() {
                          _targetAudience = value!;
                        });
                      },
                      activeColor: AppTheme.primaryBlue,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<int>(
                      title: const Text('관리자'),
                      subtitle: const Text('관리자에게만 표시'),
                      value: 1,
                      groupValue: _targetAudience,
                      onChanged: (value) {
                        setState(() {
                          _targetAudience = value!;
                        });
                      },
                      activeColor: AppTheme.primaryBlue,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<int>(
                      title: const Text('병원'),
                      subtitle: const Text('병원 사용자에게만 표시'),
                      value: 2,
                      groupValue: _targetAudience,
                      onChanged: (value) {
                        setState(() {
                          _targetAudience = value!;
                        });
                      },
                      activeColor: AppTheme.primaryBlue,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<int>(
                      title: const Text('사용자'),
                      subtitle: const Text('일반 사용자에게만 표시'),
                      value: 3,
                      groupValue: _targetAudience,
                      onChanged: (value) {
                        setState(() {
                          _targetAudience = value!;
                        });
                      },
                      activeColor: AppTheme.primaryBlue,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // 중요 공지 체크박스
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isImportant == 0, // 0=뱃지 표시이면 체크
                      onChanged: (value) {
                        setState(() {
                          _isImportant =
                              (value ?? false)
                                  ? 0
                                  : 1; // 체크되면 뱃지 표시(0), 아니면 숨김(1)
                        });
                      },
                      activeColor: AppTheme.primaryBlue,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '공지 뱃지 표시',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Text(
                            '체크하면 공지 뱃지가 표시되어 상단에 고정됩니다.',
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

              // 수정 모드일 때만 활성화 체크박스 표시
              if (isEditMode) ...[
                const SizedBox(height: AppTheme.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: AppTheme.veryLightGray,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value ?? true;
                          });
                        },
                        activeColor: AppTheme.primaryBlue,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '공지글 활성화',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing4),
                            Text(
                              '체크 해제하면 공지글이 숨겨집니다.',
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
              ],

              const SizedBox(height: AppTheme.spacing32),

              // 작성/수정 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _submitNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
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
