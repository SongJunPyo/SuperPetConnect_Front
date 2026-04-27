// 한국 전화번호 표시 포맷팅 공용 유틸.
//
// 원래 admin/user 화면 5~6곳에 동일한 _formatPhoneNumber 함수가 중복 정의되어 있었으나,
// 11자리 휴대폰만 처리하고 02 시작 서울 일반전화는 dash가 붙지 않아
// `0212345678` 같은 raw 문자열이 그대로 노출되는 문제가 있었음.
//
// 입력에서 숫자만 추출 후 한국 전화번호 6가지 패턴으로 분기.
// - null / 빈 문자열: [fallback] 반환 (기본 '')
// - 매칭 안 되면 원본 반환
String formatPhoneNumber(String? phoneNumber, {String fallback = ''}) {
  if (phoneNumber == null || phoneNumber.isEmpty) return fallback;
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return phoneNumber;

  // 02 (서울 일반전화)
  if (digits.startsWith('02')) {
    if (digits.length == 9) {
      return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6)}';
    }
  }

  // 휴대폰(010-XXXX-XXXX) / 3자리 지역번호 일반전화(031, 053 등)
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  return phoneNumber;
}
