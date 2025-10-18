import 'package:flutter/material.dart';
import '../services/hospital_column_service.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class HospitalColumnCreate extends StatefulWidget {
  const HospitalColumnCreate({super.key});

  @override
  State createState() => _HospitalColumnCreateState();
}

class _HospitalColumnCreateState extends State<HospitalColumnCreate> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final bool _isPublished = false; // 기본값을 미발행으로 변경
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = []; // 선택된 이미지 목록

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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

  // 이미지 선택 바텀시트 표시
  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }

  // 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        _insertImageToContent(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지를 선택할 수 없습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 카메라로 이미지 촬영
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        _insertImageToContent(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진을 촬영할 수 없습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 이미지를 내용에 삽입
  void _insertImageToContent(XFile image) {
    final currentText = _contentController.text;
    final cursorPosition = _contentController.selection.baseOffset;

    // 이미지 플레이스홀더 텍스트 삽입
    final imagePlaceholder = '\n[이미지: ${image.name}]\n';

    String newText;
    if (cursorPosition == -1) {
      // 커서 위치를 알 수 없으면 끝에 추가
      newText = currentText + imagePlaceholder;
    } else {
      // 커서 위치에 삽입
      newText = currentText.substring(0, cursorPosition) +
          imagePlaceholder +
          currentText.substring(cursorPosition);
    }

    _contentController.text = newText;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPosition + imagePlaceholder.length),
    );
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
      );

      await HospitalColumnService.createColumn(request);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('칼럼이 등록되었습니다. 관리자 승인 후 발행됩니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = e.toString().replaceAll('Exception: ', '');

        // 서버 오류에 대한 더 친화적인 메시지
        if (errorMessage.contains('500') || errorMessage.contains('서버')) {
          errorMessage = '서버에서 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
        } else if (errorMessage.contains('403') ||
            errorMessage.contains('권한')) {
          errorMessage = '칼럼 작성 권한이 없습니다.\n관리자에게 문의하세요.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isCheckingPermission
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('권한을 확인하고 있습니다...'),
                  ],
                ),
              )
              : !_hasPermission
              ? Center(
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
                    const SizedBox(height: 16),
                    const Text(
                      '2초 후 자동으로 이전 페이지로 돌아갑니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
              : _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('칼럼을 등록하고 있습니다...'),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 칼럼 작성 타이틀
                        Text("칼럼 작성", style: AppTheme.h3Style),
                        const SizedBox(height: 16),

                        // 제목 입력
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radius16),
                            border: Border.all(
                              color: AppTheme.lightGray.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('제목', style: AppTheme.h4Style),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    hintText: '칼럼 제목을 입력하세요',
                                    prefixIcon: Icon(
                                      Icons.title,
                                      color: Colors.grey[600],
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '제목을 입력해주세요';
                                    }
                                    if (value.trim().length < 3) {
                                      return '제목은 3글자 이상 입력해주세요';
                                    }
                                    return null;
                                  },
                                  maxLength: 100,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 내용 입력
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radius16),
                            border: Border.all(
                              color: AppTheme.lightGray.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('내용', style: AppTheme.h4Style),
                                    IconButton(
                                      onPressed: _showImageSourceBottomSheet,
                                      icon: const Icon(
                                        Icons.image,
                                        color: Colors.black,
                                      ),
                                      tooltip: '이미지 추가',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _contentController,
                                  maxLines: 15,
                                  decoration: InputDecoration(
                                    hintText: '유용한 정보를 공유해주세요...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '내용을 입력해주세요';
                                    }
                                    if (value.trim().length < 10) {
                                      return '내용은 10글자 이상 입력해주세요';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 등록 버튼
                        Material(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(AppTheme.radius12),
                          child: InkWell(
                            onTap: _isLoading ? null : _createColumn,
                            borderRadius: BorderRadius.circular(AppTheme.radius12),
                            child: Container(
                              height: AppTheme.buttonHeightLarge,
                              alignment: Alignment.center,
                              child: Text(
                                _isLoading ? '등록 중...' : '칼럼 등록',
                                style: AppTheme.h4Style.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
