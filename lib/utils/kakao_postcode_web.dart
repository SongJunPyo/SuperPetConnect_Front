// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// 웹에서 카카오 주소 검색 팝업을 엽니다.
/// [onComplete] 콜백으로 선택된 주소가 전달됩니다.
void openKakaoPostcode(Function(String address) onComplete) {
  js.context.callMethod('openKakaoPostcode', [
    js.allowInterop((String address) {
      onComplete(address);
    }),
  ]);
}
