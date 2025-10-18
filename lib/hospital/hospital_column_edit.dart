import 'package:flutter/material.dart';
import '../services/hospital_column_service.dart';
import '../models/hospital_column_model.dart';
import '../utils/app_theme.dart';

class HospitalColumnEdit extends StatefulWidget {
  final HospitalColumn column;

  const HospitalColumnEdit({super.key, required this.column});

  @override
  State createState() => _HospitalColumnEditState();
}

class _HospitalColumnEditState extends State<HospitalColumnEdit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.column.title);
    _contentController = TextEditingController(text: widget.column.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updateColumn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = HospitalColumnUpdateRequest(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );

      await HospitalColumnService.updateColumn(
        widget.column.columnIdx,
        request,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('칼럼이 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '수정 실패: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
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
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('칼럼을 수정하고 있습니다...'),
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
                        // 칼럼 수정 타이틀
                        Text("칼럼 수정", style: AppTheme.h3Style),
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
                                Text('내용', style: AppTheme.h4Style),
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

                        // 수정 버튼
                        Material(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(AppTheme.radius12),
                          child: InkWell(
                            onTap: _isLoading ? null : _updateColumn,
                            borderRadius: BorderRadius.circular(AppTheme.radius12),
                            child: Container(
                              height: AppTheme.buttonHeightLarge,
                              alignment: Alignment.center,
                              child: Text(
                                _isLoading ? '수정 중...' : '칼럼 수정',
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
