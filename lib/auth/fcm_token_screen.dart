import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmTokenScreen extends StatefulWidget {
  const FcmTokenScreen({super.key});

  @override
  State<FcmTokenScreen> createState() => _FcmTokenScreenState();
}

class _FcmTokenScreenState extends State<FcmTokenScreen> {
  String _fcmToken = '토큰을 가져오는 중...';

  @override
  void initState() {
    super.initState();
    // 위젯의 첫 번째 프레임이 그려진 후 _getAndDisplayFcmToken 호출
    // 이렇게 하면 context가 완전히 유효해진 후에 ScaffoldMessenger.of(context)를 호출하게 됩니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getAndDisplayFcmToken();
    });
  }

  // ... (나머지 코드는 동일) ...

  // FCM 토큰을 가져와 화면에 표시
  Future<void> _getAndDisplayFcmToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();

      // setState 호출 전에 위젯이 마운트되어 있는지 다시 확인 (비동기 작업이므로)
      if (!mounted) return;

      setState(() {
        _fcmToken = token ?? 'FCM 토큰을 가져오지 못했습니다. Firebase 설정을 확인하세요.';
      });


      if (token == null) {
        _showSnackBar('FCM 토큰을 가져오지 못했습니다. Firebase 설정을 확인하세요.');
      } else {
        _showSnackBar('FCM 토큰이 성공적으로 발급되었습니다.');
      }
    } catch (e) {
      if (!mounted) return; // 에러 발생 시에도 마운트 상태 확인
      setState(() {
        _fcmToken = 'FCM 토큰 오류: $e';
      });
      _showSnackBar('FCM 토큰 오류: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      // 위젯이 마운트되어 있을 때만 스낵바 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기
          },
        ),
        title: Text(
          'FCM 토큰 발급',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 기기의 FCM 토큰입니다.',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // 토큰 표시 영역
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              width: double.infinity,
              child: SelectableText(
                // 텍스트 선택 가능하도록
                _fcmToken,
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace', // 토큰은 고정폭 글꼴이 보기 좋음
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 토큰 복사 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 토큰 복사 기능 (navigator.clipboard.writeText는 iframe에서 제한될 수 있으므로, document.execCommand('copy') 사용)
                  // Flutter에서는 Clipboard.setData를 사용합니다.
                  if (_fcmToken != '토큰을 가져오는 중...' &&
                      _fcmToken.isNotEmpty &&
                      _fcmToken.contains('AAAA')) {
                    // 유효한 토큰일 경우에만 복사
                    Clipboard.setData(ClipboardData(text: _fcmToken)).then((_) {
                      _showSnackBar('FCM 토큰이 클립보드에 복사되었습니다.');
                    });
                  } else {
                    _showSnackBar('복사할 유효한 FCM 토큰이 없습니다.');
                  }
                },
                icon: const Icon(Icons.copy_outlined, color: Colors.white),
                label: Text(
                  'FCM 토큰 복사',
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, // 주 색상 사용
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '이 토큰을 백엔드 서버의 `admin_tokens` 리스트에 붙여넣어 관리자 알림을 테스트할 수 있습니다.',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
