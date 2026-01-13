/// 텍스트 개인화 유틸리티 클래스
/// 공지사항이나 칼럼 내용에서 개인화된 정보를 치환하는 기능을 제공합니다.
class TextPersonalizationUtil {
  
  /// 텍스트 내의 플레이스홀더를 사용자 정보로 치환합니다.
  /// 
  /// [text]: 치환할 원본 텍스트
  /// [userName]: 사용자의 실제 이름 (fallback용)
  /// [userNickname]: 사용자의 닉네임 (우선 사용)
  /// 
  /// 치환 규칙:
  /// - [이름] → 닉네임 (닉네임이 없으면 이름)
  /// - [닉네임] → 닉네임 (닉네임이 없으면 이름)
  /// - [사용자명] → 닉네임 (닉네임이 없으면 이름)
  static String personalizeText({
    required String text,
    required String userName,
    String? userNickname,
  }) {
    if (text.isEmpty) return text;
    
    // 사용할 이름 결정 (닉네임 우선, 없으면 실제 이름)
    final displayName = userNickname?.isNotEmpty == true ? userNickname! : userName;
    
    String personalizedText = text;
    
    // 다양한 플레이스홀더 치환
    personalizedText = personalizedText.replaceAll('[이름]', displayName);
    personalizedText = personalizedText.replaceAll('[닉네임]', displayName);
    personalizedText = personalizedText.replaceAll('[사용자명]', displayName);
    personalizedText = personalizedText.replaceAll('[사용자이름]', displayName);
    personalizedText = personalizedText.replaceAll('[USER_NAME]', displayName);
    personalizedText = personalizedText.replaceAll('[USERNAME]', displayName);
    personalizedText = personalizedText.replaceAll('[NICKNAME]', displayName);
    
    return personalizedText;
  }
  
  /// 제목에서 플레이스홀더를 치환합니다.
  static String personalizeTitle({
    required String title,
    required String userName,
    String? userNickname,
  }) {
    return personalizeText(
      text: title,
      userName: userName,
      userNickname: userNickname,
    );
  }
  
  /// 내용에서 플레이스홀더를 치환합니다.
  static String personalizeContent({
    required String content,
    required String userName,
    String? userNickname,
  }) {
    return personalizeText(
      text: content,
      userName: userName,
      userNickname: userNickname,
    );
  }
}