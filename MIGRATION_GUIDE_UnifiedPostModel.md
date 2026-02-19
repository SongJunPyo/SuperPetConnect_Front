# UnifiedPostModel 마이그레이션 가이드

## 📋 개요

서버 API 통일 작업 2단계부터 모든 헌혈 게시글 API가 동일한 응답 형식(`UnifiedPostResponse`)으로 통합됩니다.
이에 대응하여 프론트엔드에서는 `UnifiedPostModel`을 사용하여 일관된 데이터 처리가 가능합니다.

---

## 🎯 주요 변경사항

### 서버 API 통합 범위
다음 4개 API가 동일한 응답 형식으로 통합됩니다:
- `/public/posts` (공개 게시글 조회)
- `/hospital/posts` (병원 게시글 조회)
- `/posts` (게시글 상세 조회)
- `/api/admin/posts` (관리자 게시글 관리)

### 기존 모델과의 차이점

| 항목 | 기존 (DonationPost/HospitalPost/Post) | 통합 후 (UnifiedPostModel) |
|------|--------------------------------------|----------------------------|
| **ID 타입** | `int` 또는 `String` (API마다 다름) | `int` 통일 |
| **status** | `int` 또는 한글 `String` | `int` + `statusLabel`(한글) |
| **animalType** | `int` (0: 강아지, 1: 고양이) | `String` ("dog", "cat") |
| **수혈환자 정보** | `patient_name` (snake_case) | `patientName` (camelCase) |
| **리치텍스트** | `content_delta` (snake_case) | `contentDelta` (camelCase) |
| **병원 정보** | flat(snake) / nested object | flat + camelCase |
| **병원명 필드** | `hospitalName` / `hospital_name` / `nickname` | `hospitalName` 통일 |

---

## 📂 UnifiedPostModel 주요 필드

### 식별 정보
```dart
final int id;                // 게시글 ID (int 통일)
final String title;          // 제목
final int types;             // 0: 긴급, 1: 정기
final int status;            // 0: 대기, 1: 모집중, 2: 거절, 3: 마감, 4: 완료
```

### 새로 추가된 한글 라벨 (2단계부터 서버 제공)
```dart
final String? statusLabel;   // "모집중", "마감" 등
final String? typesLabel;    // "긴급", "정기"
```

### 동물/혈액 정보
```dart
final String animalType;     // "dog" 또는 "cat" (String 통일!)
final String? bloodType;     // 긴급 헌혈 혈액형
```

### 수혈환자 정보 (camelCase 통일)
```dart
final String? patientName;   // 기존: patient_name
final String? breed;         // 견종/묘종
final int? age;              // 나이
final String? diagnosis;     // 병명/증상
```

### 본문 및 이미지
```dart
final String description;        // 본문 텍스트
final String? contentDelta;      // 리치텍스트 (기존: content_delta)
final List<PostImage>? images;   // 이미지 목록
```

### 병원 정보 (flat + camelCase)
```dart
final String hospitalName;       // 병원 표시이름
final String? hospitalNickname;  // 병원 닉네임
final String? hospitalCode;      // 병원 코드
final String location;           // 병원 주소
```

---

## 🔧 헬퍼 메서드 및 Getter

### 기존 모델과 동일하게 제공되는 헬퍼
```dart
// 긴급도 확인
bool get isUrgent;              // types == 0
bool get isRegular;             // types == 1

// 텍스트 변환 (서버 라벨 우선, 없으면 로컬 변환)
String get typeText;            // typesLabel ?? AppConstants.getPostTypeText(types)
String get statusText;          // statusLabel ?? AppConstants.getPostStatusText(status)

// 동물 타입
String get animalTypeKorean;    // "강아지" 또는 "고양이"
int get animalTypeInt;          // 0 또는 1 (기존 API 호환용)

// 혈액형 표시
String get displayBloodType;    // 긴급일 때만 표시, 아니면 "혈액형 무관"

// 병원 표시명
String get hospitalDisplayName; // hospitalNickname ?? hospitalName

// 가장 빠른 헌혈 날짜
DateTime? get earliestDonationDate;
```

---

## 🚀 단계별 마이그레이션 계획

### Phase 1: 준비 단계 (현재) ✅
- [x] `UnifiedPostModel` 클래스 생성 완료
- [x] 기존 API 응답 호환성 확보 (snake_case, nested 지원)
- [x] 헬퍼 메서드 구현 완료
- **변경 사항**: 없음 (기존 코드 그대로 사용)

### Phase 2: 서버 API 통일 완료 후 (1-2개월 예상)
서버 측에서 `/public/posts`, `/hospital/posts`, `/api/admin/posts`가 `UnifiedPostResponse` 형식으로 응답하기 시작합니다.

#### 2-1. 모델 교체 작업 (예상 소요 시간: 6-8시간)
```dart
// Before (기존 모델)
import '../models/donation_post_model.dart';

List<DonationPost> posts = await DashboardService.getPublicPosts();

// After (통합 모델)
import '../models/unified_post_model.dart';

List<UnifiedPostModel> posts = await DashboardService.getPublicPosts();
```

#### 2-2. 필드 접근 방식 변경
```dart
// Before
final animalTypeInt = post.animalType; // int (0 또는 1)
final animalText = AppConstants.getAnimalTypeText(animalTypeInt);

// After
final animalTypeStr = post.animalType; // String ("dog" 또는 "cat")
final animalText = post.animalTypeKorean; // getter 사용
```

#### 2-3. 한글 라벨 활용 (서버에서 제공)
```dart
// Before (로컬 변환)
final statusText = AppConstants.getPostStatusText(post.status);

// After (서버 제공 우선, fallback은 자동)
final statusText = post.statusText; // statusLabel이 있으면 사용, 없으면 로컬 변환
```

#### 2-4. 수혈환자 정보 필드명 변경
```dart
// Before
final patientName = post.patient_name; // snake_case (일부 API)

// After
final patientName = post.patientName; // camelCase 통일
```

---

## 📝 코드 예제

### 예제 1: 공개 게시글 조회 (User Dashboard)
```dart
// lib/user/user_dashboard.dart

// Before
import '../models/donation_post_model.dart';

Future<void> _loadDonationPosts() async {
  final posts = await DashboardService.getPublicPosts(limit: 11);
  setState(() {
    donationPosts = posts; // List<DonationPost>
  });
}

// After (Phase 2부터)
import '../models/unified_post_model.dart';

Future<void> _loadDonationPosts() async {
  final posts = await DashboardService.getPublicPosts(limit: 11);
  setState(() {
    donationPosts = posts; // List<UnifiedPostModel>
  });
}

// 사용 예시 (기존과 거의 동일)
Widget _buildPostCard(UnifiedPostModel post) {
  return Card(
    child: Column(
      children: [
        Text(post.title),
        Text(post.statusText),        // statusLabel 우선 사용
        Text(post.typeText),          // typesLabel 우선 사용
        Text(post.animalTypeKorean),  // "강아지" 또는 "고양이"
        Text(post.displayBloodType),  // "DEA 1.1+" 또는 "혈액형 무관"
        Text(post.hospitalDisplayName), // 병원 닉네임 우선 표시
      ],
    ),
  );
}
```

### 예제 2: 병원 게시글 관리 (Hospital Dashboard)
```dart
// lib/hospital/hospital_post_check.dart

// Before
import '../models/hospital_post_model.dart';

Future<void> _fetchPosts() async {
  final posts = await HospitalPostService.getHospitalPosts();
  setState(() {
    hospitalPosts = posts; // List<HospitalPost>
  });
}

// After (Phase 2부터)
import '../models/unified_post_model.dart';

Future<void> _fetchPosts() async {
  final posts = await HospitalPostService.getHospitalPosts();
  setState(() {
    hospitalPosts = posts; // List<UnifiedPostModel>
  });
}

// 긴급 헌혈인 경우 수혈환자 정보 표시
Widget _buildPatientInfo(UnifiedPostModel post) {
  if (!post.isUrgent) return SizedBox.shrink();

  return Column(
    children: [
      Text('환자명: ${post.patientName ?? "정보 없음"}'),    // camelCase
      Text('견종: ${post.breed ?? "정보 없음"}'),
      Text('나이: ${post.age?.toString() ?? "정보 없음"}세'),
      Text('진단: ${post.diagnosis ?? "정보 없음"}'),
    ],
  );
}
```

### 예제 3: 관리자 게시글 승인 (Admin Dashboard)
```dart
// lib/admin/admin_post_check.dart

// Before
import '../models/donation_post_model.dart';

Future<void> _approvePost(DonationPost post) async {
  await AdminService.approvePost(post.postIdx);
  // ...
}

// After (Phase 2부터)
import '../models/unified_post_model.dart';

Future<void> _approvePost(UnifiedPostModel post) async {
  await AdminService.approvePost(post.id); // postIdx → id
  // ...
}

// 상태 텍스트 표시 (서버 라벨 활용)
Widget _buildStatusBadge(UnifiedPostModel post) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getStatusColor(post.status),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      post.statusText, // statusLabel이 있으면 서버 값 사용
      style: TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
```

---

## ⚠️ 주의사항

### 1. animalType 타입 변경 (int → String)
**Before:**
```dart
if (post.animalType == 0) { // 강아지
  // ...
}
```

**After:**
```dart
if (post.animalType == 'dog') { // 강아지
  // ...
}

// 또는 헬퍼 사용
if (post.animalTypeInt == 0) { // 기존 코드 호환
  // ...
}
```

### 2. ID 필드명 통일 (postIdx → id)
**Before:**
```dart
await ApiService.getPostDetail(post.postIdx);
```

**After:**
```dart
await ApiService.getPostDetail(post.id);
```

### 3. 수혈환자 정보 필드명 (snake_case → camelCase)
**Before:**
```dart
final patientName = post.patient_name;
```

**After:**
```dart
final patientName = post.patientName;
```

### 4. 병원 정보 필드명 통일
**Before:**
```dart
final hospitalName = post.hospital?.name ?? post.hospitalName;
final location = post.hospital?.address ?? post.location;
```

**After:**
```dart
final hospitalName = post.hospitalName; // flat 구조로 통일
final location = post.location;
```

---

## 🧪 호환성 테스트

`UnifiedPostModel`은 기존 API 응답도 파싱 가능하도록 설계되었습니다:

### 지원되는 응답 형식
- ✅ camelCase (통합 API, 2단계 이후)
- ✅ snake_case (기존 API)
- ✅ nested hospital object (기존 API)
- ✅ flat hospital fields (통합 API)
- ✅ int ID (통합 API)
- ✅ String ID (기존 일부 API)

### 테스트 방법
```dart
// 기존 API 응답으로 테스트
final jsonOld = {
  'id': '123',                    // String ID
  'animal_type': 0,              // int 타입
  'patient_name': '초코',        // snake_case
  'hospital': {                  // nested 구조
    'name': '행복병원',
    'address': '서울...',
  },
};

final postOld = UnifiedPostModel.fromJson(jsonOld);
print(postOld.id);               // 123 (int로 변환됨)
print(postOld.animalType);       // "dog" (String으로 변환됨)
print(postOld.patientName);      // "초코"
print(postOld.hospitalName);     // "행복병원"

// 통합 API 응답으로 테스트 (2단계 이후)
final jsonNew = {
  'id': 123,                      // int ID
  'animalType': 'dog',           // String 타입
  'patientName': '초코',         // camelCase
  'hospitalName': '행복병원',    // flat 구조
  'statusLabel': '모집중',       // 서버 제공 라벨
};

final postNew = UnifiedPostModel.fromJson(jsonNew);
print(postNew.id);               // 123
print(postNew.animalType);       // "dog"
print(postNew.statusText);       // "모집중" (서버 라벨 사용)
```

---

## 📅 마이그레이션 타임라인

### 현재 (Phase 1) - 준비 완료 ✅
- `UnifiedPostModel` 클래스 생성
- 기존 API 응답 호환성 확보
- 문서화 완료
- **작업 필요**: 없음

### 서버 Phase 2 완료 후 (1-2개월 예상)
서버에서 통합 API 배포 완료 시:

#### Week 1-2: 모델 교체
1. `DonationPost` → `UnifiedPostModel` 교체
   - user_dashboard.dart
   - user_donation_posts_list.dart
   - user_donation_list.dart

2. `HospitalPost` → `UnifiedPostModel` 교체
   - hospital_post_check.dart
   - hospital_dashboard.dart

3. `Post` → `UnifiedPostModel` 교체 (Admin)
   - admin_post_check.dart
   - admin_post_management_page.dart
   - admin_approved_posts.dart

#### Week 3: 테스트 및 검증
- [ ] 모든 화면에서 게시글 정상 표시 확인
- [ ] 바텀시트 정상 작동 확인
- [ ] 신청/승인/거절 기능 정상 작동
- [ ] 필터링 및 검색 정상 작동

#### Week 4: 레거시 모델 제거
- [ ] DonationPost 삭제
- [ ] HospitalPost 삭제
- [ ] Post 삭제
- [ ] 관련 import 정리

---

## 🔍 현재 상태 확인

### 영향받는 파일 목록 (총 8개 화면)

#### User (3개)
- [ ] `lib/user/user_dashboard.dart` - 대시보드 바텀시트
- [ ] `lib/user/user_donation_posts_list.dart` - 게시글 리스트 (2,866줄)
- [ ] `lib/user/user_donation_list.dart` - 필터링 리스트

#### Hospital (2개)
- [ ] `lib/hospital/hospital_dashboard.dart` - 대시보드
- [ ] `lib/hospital/hospital_post_check.dart` - 게시글 현황 (5개 탭)

#### Admin (3개)
- [ ] `lib/admin/admin_dashboard.dart` - 대시보드
- [ ] `lib/admin/admin_post_check.dart` - 게시글 관리 (5개 탭, 4,000+ 줄)
- [ ] `lib/admin/admin_post_management_page.dart` - 관리 페이지 (4개 탭)
- [ ] `lib/admin/admin_approved_posts.dart` - 승인된 게시글 (2개 탭)

---

## 💡 권장 사항

1. **서버 Phase 2 완료 전**
   - 현재는 아무 작업 불필요
   - `UnifiedPostModel`은 준비만 완료된 상태

2. **서버 Phase 2 완료 후**
   - User 화면부터 점진적으로 교체 (가장 사용 빈도 높음)
   - Hospital → Admin 순서로 진행
   - 각 화면 교체 후 즉시 테스트

3. **코드 리뷰 시 확인 사항**
   - animalType int → String 변경 확인
   - postIdx → id 변경 확인
   - snake_case → camelCase 변경 확인
   - statusLabel/typesLabel 활용 확인

---

## 📞 문의 및 지원

마이그레이션 중 문제 발생 시:
1. 이 가이드 재확인
2. `UnifiedPostModel` 클래스의 주석 확인
3. 기존 모델 파싱 로직과 비교

**예상 작업 시간**: 6-8시간 (서버 Phase 2 완료 후)
**예상 코드 절감**: 400-500줄 (모델 통합 + 중복 제거)
