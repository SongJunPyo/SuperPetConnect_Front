// 웹용 플랫폼 헬퍼 (dart:io 사용 불가)
// 웹에서는 File 타입 대신 스텁 클래스 제공

/// 웹용 File 스텁 클래스
/// 웹에서는 uploadImageBytes 메서드를 사용해야 함
class File {
  final String path;

  File(this.path);

  Future<int> length() async {
    throw UnsupportedError('File.length()는 웹에서 지원되지 않습니다. uploadImageBytes를 사용하세요.');
  }
}
