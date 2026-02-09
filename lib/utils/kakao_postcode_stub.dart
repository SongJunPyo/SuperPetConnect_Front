/// 모바일에서는 kpostal 패키지를 사용하므로 이 함수는 호출되지 않습니다.
void openKakaoPostcode(Function(String address) onComplete) {
  throw UnsupportedError('카카오 주소 검색 웹 API는 웹 플랫폼에서만 사용 가능합니다.');
}
