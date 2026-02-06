// lib/models/applicant_model.dart
// 신청자 공통 모델

/// 신청자 정보 모델
class ApplicantInfo {
  final int id;
  final int? userId;
  final String name;
  final String? nickname;
  final String contact;
  final String dogInfo; // pet_info에서 조합: "품종 / 나이세 / 혈액형"
  final String lastDonationDate;
  final int? petIdx; // 헌혈 이력 조회용
  int status; // 0: 대기, 1: 승인, 2: 거절, 3: 취소

  ApplicantInfo({
    required this.id,
    this.userId,
    required this.name,
    this.nickname,
    required this.contact,
    required this.dogInfo,
    required this.lastDonationDate,
    this.petIdx,
    required this.status,
  });

  factory ApplicantInfo.fromJson(Map<String, dynamic> json) {
    // pet_info 객체에서 정보 추출
    final petInfo = json['pet_info'] as Map<String, dynamic>?;
    String dogInfoStr = '';
    String lastDonation = '';

    if (petInfo != null) {
      // "품종 / 나이세" 형식으로 조합
      final breed = petInfo['breed'] ?? '';
      final age = petInfo['age'];
      final bloodType = petInfo['blood_type'] ?? '';

      List<String> infoParts = [];
      if (breed.isNotEmpty) infoParts.add(breed);
      if (age != null) infoParts.add('${age}세');
      if (bloodType.isNotEmpty) infoParts.add(bloodType);
      dogInfoStr = infoParts.join(' / ');

      // 마지막 헌혈일
      lastDonation = petInfo['last_donation_date']?.toString() ?? '';
    }

    return ApplicantInfo(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      name: json['name'] ?? '',
      nickname: json['nickname'],
      contact: json['contact'] ?? '',
      dogInfo: dogInfoStr,
      lastDonationDate: lastDonation,
      petIdx: json['pet_idx'],
      status: json['status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'nickname': nickname,
      'contact': contact,
      'dog_info': dogInfo,
      'last_donation_date': lastDonationDate,
      'pet_idx': petIdx,
      'status': status,
    };
  }

  /// 상태 텍스트
  String get statusText {
    switch (status) {
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '거절';
      case 3:
        return '취소';
      default:
        return '알 수 없음';
    }
  }

  /// 대기 상태인지 확인
  bool get isPending => status == 0;

  /// 승인 상태인지 확인
  bool get isApproved => status == 1;

  /// 거절 상태인지 확인
  bool get isRejected => status == 2;

  /// 취소 상태인지 확인
  bool get isCancelled => status == 3;

  /// 직전 헌혈일 포맷 (YYYY.MM.DD)
  String get formattedLastDonationDate {
    if (lastDonationDate.isEmpty) return '-';
    try {
      final date = DateTime.parse(lastDonationDate);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return lastDonationDate;
    }
  }
}
