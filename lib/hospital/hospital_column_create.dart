import 'package:flutter/material.dart';
import '../services/hospital_column_service.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';

class HospitalColumnCreate extends StatefulWidget {
  const HospitalColumnCreate({super.key});

  @override
  State createState() => _HospitalColumnCreateState();
}

class _HospitalColumnCreateState extends State<HospitalColumnCreate> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final bool _isPublished = false; // 기본값을 미발행으로 변경
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await HospitalColumnService.checkColumnPermission();
      setState(() {
        _hasPermission = hasPermission;
        _isCheckingPermission = false;
      });

      if (!hasPermission) {
        // 권한이 없으면 2초 후 자동으로 뒤로가기
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _isCheckingPermission = false;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> _createColumn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = HospitalColumnCreateRequest(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        isPublished: _isPublished,
        columnUrl:
            _urlController.text.trim().isEmpty
                ? null
                : _urlController.text.trim(),
      );

      await HospitalColumnService.createColumn(request);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        // 서버 오류에 대한 더 친화적인 메시지
        if (errorMessage.contains('500') || errorMessage.contains('서버')) {
          errorMessage = '서버에서 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
        } else if (errorMessage.contains('403') ||
            errorMessage.contains('권한')) {
          errorMessage = '칼럼 작성 권한이 없습니다.\n관리자에게 문의하세요.';
        }

        debugPrint('칼럼 등록 실패: $errorMessage');
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
    Widget bodyContent;

    if (_isCheckingPermission) {
      bodyContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('권한을 확인하고 있습니다...'),
          ],
        ),
      );
    } else if (!_hasPermission) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              '관리자의 권한이 필요합니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '칼럼 작성 권한이 없습니다.\n관리자에게 문의하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    } else {
      bodyContent = Form(
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
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: '칼럼 내용을 입력하세요',
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
                maxLines: 18,
                minLines: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '내용을 입력해주세요.';
                  }
                  if (value.trim().length < 10) {
                    return '내용은 10글자 이상 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing32),
              Text(
                '관련 링크 (선택)',
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
                onPressed: _isLoading ? null : _createColumn,
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
                          '칼럼 등록',
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
      );
    }

    return Scaffold(
      appBar: AppAppBar(
        title: '칼럼 작성',
        showBackButton: true,
      ),
      body: bodyContent,
    );
  }
}
