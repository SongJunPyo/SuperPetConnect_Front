// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop' as js;

/// 웹에서 카카오 주소 검색 팝업을 엽니다.
/// [onComplete] 콜백으로 선택된 주소가 전달됩니다.
void openKakaoPostcode(Function(String address) onComplete) {
  _openKakaoPostcodeJS(((String address) {
    onComplete(address);
  }).toJS);
}

/// JavaScript 함수 호출을 위한 external 선언
@js.JS('openKakaoPostcode')
external void _openKakaoPostcodeJS(js.JSFunction callback);
