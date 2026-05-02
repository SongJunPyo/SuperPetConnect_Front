import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_theme.dart';

/// `RichTextEditor`의 이미지 추가 버튼이 띄우는 카메라/갤러리 선택 바텀시트.
///
/// 웹에서는 카메라 옵션을 숨기고 "파일 선택"만 노출. 사용자가 이미지를 고르면
/// 20MB 검사 후 [onImageSelected]를 호출(부모가 업로드 처리). 사용자가 취소했거나
/// 에러 발생 시 시트를 자동으로 닫음.
class RichTextImagePickerSheet extends StatefulWidget {
  final void Function(XFile) onImageSelected;

  const RichTextImagePickerSheet({super.key, required this.onImageSelected});

  @override
  State<RichTextImagePickerSheet> createState() =>
      _RichTextImagePickerSheetState();
}

class _RichTextImagePickerSheetState extends State<RichTextImagePickerSheet> {
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
