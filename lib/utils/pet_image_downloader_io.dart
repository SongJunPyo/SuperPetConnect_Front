// 모바일(iOS/Android) 펫 이미지 저장 — gal 패키지 사용.
// pet_image_downloader.dart의 conditional import로 자동 선택됨 (dart:io가 있는 환경).

import 'dart:typed_data';
import 'package:gal/gal.dart';

import 'pet_image_downloader.dart';

/// 사진 갤러리에 저장. 권한 거부 시 PetImagePermissionException throw.
Future<void> savePetImage(Uint8List bytes, String filename) async {
  // 권한 확인 — toAlbum=false (Photos add-only), iOS 14+/Android 10+에서 동작.
  final hasAccess = await Gal.hasAccess();
  if (!hasAccess) {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw PetImagePermissionException('갤러리 접근 권한이 거부되었습니다.');
    }
  }

  // gal은 확장자(.jpg/.png)를 name 파라미터에서 자동 처리하지 않음 → name에 확장자 제외 베이스만 전달.
  // 실제 파일 형식은 bytes 헤더로 결정됨 (jpg/png 자동 감지).
  final baseName = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
  await Gal.putImageBytes(bytes, name: baseName);
}
