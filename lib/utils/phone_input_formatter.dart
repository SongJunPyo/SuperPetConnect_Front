import 'package:flutter/services.dart';

/// 전화번호 입력 시 자동으로 하이픈을 삽입하는 TextInputFormatter.
///
/// 입력 도중: `01012345678` → `010-1234-5678` (실시간 포맷)
/// 11자리 휴대폰 기준. 02 시작 일반전화 등 다른 패턴은 디스플레이용
/// [formatPhoneNumber] (lib/utils/phone_formatter.dart)를 사용할 것.
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    text = text.replaceAll(RegExp(r'\D'), '');

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 2 || i == 6) {
        if (i < text.length - 1) buffer.write('-');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
