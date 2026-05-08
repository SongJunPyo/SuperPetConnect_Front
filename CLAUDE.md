# CLAUDE.md

이 파일은 Claude Code (claude.ai/code)가 이 저장소에서 작업할 때 필요한 가이드라인을 제공합니다.

## 주요 명령어

### 개발
- `flutter pub get` - 종속성 설치
- `flutter run` - 디버그 모드로 애플리케이션 실행 (연결된 기기/에뮬레이터에서 실행)
- `flutter run -d chrome` - Chrome 브라우저에서 웹 앱으로 실행
- `flutter build apk` - 릴리스용 Android APK 빌드
- `flutter build ios` - iOS 앱 빌드 (Xcode가 설치된 macOS 필요)
- `flutter clean` - 빌드 산출물 및 캐시 파일 정리

### 코드 품질 & 테스트
- `flutter analyze` - 정적 분석을 실행하여 코드 문제점 확인
- `flutter format .` - Flutter 스타일 가이드에 따라 모든 Dart 파일 포맷팅
- `flutter test` - 단위 테스트 실행 (테스트가 구현된 경우)
- `flutter test test/specific_test.dart` - 특정 테스트 파일 실행

### 디버깅
- `flutter doctor` - Flutter 설치 및 개발 환경 확인
- `flutter logs` - 앱 실행 중 기기 로그 확인
- `flutter inspector` - UI 디버깅을 위한 위젯 인스펙터 실행

## 프로젝트 아키텍처

### 애플리케이션 개요
**Super Pet Connect** - 병원, 반려동물 소유자, 관리자를 연결하여 반려동물 헌혈을 촉진하는 Flutter 모바일 애플리케이션입니다. 응급 및 정기적인 헌혈 요청을 조정하는 플랫폼 역할을 합니다.

### 핵심 아키텍처 패턴

**역할 기반 아키텍처**
- 세 가지 구별되는 사용자 인터페이스: 관리자, 병원, 사용자(반려동물 소유자)
- 인증 기반 라우팅과 역할 검증
- 역할별 별도의 대시보드 및 기능 세트

**Model-View-Service 패턴**
- **Models** (`lib/models/`): API 통신을 위한 데이터 구조
  - Post: 시간대 및 긴급도 플래그가 있는 헌혈 요청
  - Hospital: 연락처 및 검증 정보가 있는 병원 엔티티
  - Pet: 혈액형 및 의료 정보가 있는 반려동물 프로필
  - TimeRange: 예약 스케줄링 슬롯
- **Views**: 사용자 유형별로 정리된 역할별 화면
- **Services** (`lib/services/`): 비즈니스 로직 및 백엔드 API 통합

**상태 관리**
- StatefulWidget 기반 로컬 상태 관리
- 지속적인 데이터를 위한 SharedPreferences (사용자 토큰, 설정)
- 전역 상태 관리 솔루션 없음 (복잡한 상태를 위해 Provider/Riverpod 추가 고려)

### 주요 디렉토리

- `lib/admin/` - 관리자 인터페이스
  - 사용자 승인 워크플로우
  - 병원 검증 관리
  - 시스템 전체 콘텐츠 조정
  - 헌혈 사전 설문 검토 (`admin_donation_survey_list.dart`, `_detail.dart`)
- `lib/auth/` - 인증 플로우
  - 헌혈 게시판 미리보기가 있는 환영 화면
  - 역할 선택이 있는 로그인/회원가입
  - 알림을 위한 FCM 토큰 관리
- `lib/hospital/` - 병원 기능
  - 헌혈 게시물 생성/관리
  - 지원자 검토 및 승인
  - 시간대 스케줄링 인터페이스
  - 신청자 사전 설문 조회 (`hospital_donation_survey_list.dart`, `_detail.dart`)
- `lib/user/` - 반려동물 소유자 기능
  - 반려동물 등록 및 프로필 관리
  - 헌혈 기회 탐색/지원
  - 교육 콘텐츠 (칼럼)
  - 헌혈 사전 설문 작성/수정 (`donation_survey_form_page.dart` — 신규/수정/잠금 자동 분기)
- `lib/models/` - 핵심 데이터 모델
  - 헌혈 설문: `donation_consent_model.dart`, `donation_survey_model.dart`
- `lib/services/` - API 통신 레이어
  - 헌혈 설문 CRUD: `donation_survey_service.dart` (사용자/admin/hospital 3 클래스)
  - PDF/Excel 다운로드: `donation_survey_download_service.dart` + `file_download_helper_{stub,io,web}.dart` (conditional import)
- `lib/utils/` - 설정 및 유틸리티
  - `config.dart`: 백엔드 서버 URL 설정
  - `app_theme.dart`: 중앙집중식 테마 (토스 스타일 디자인)
  - `app_constants.dart`: enum/상수 (BloodCollectionSite, PrevDonationSource 등)
  - `donation_eligibility.dart`: 헌혈 자격 검증 (백엔드 1:1 동기화)
- `lib/widgets/` - 재사용 가능한 UI 컴포넌트
  - `terms_agreement_bottom_sheet.dart`: 헌혈 신청 시 동의 마크다운 렌더

### 주요 설정

**백엔드 통합**
- `lib/utils/config.dart`에 설정된 서버 URL
- HTTP 기반 REST API 통신
- JWT 토큰 인증
- 오류 처리 및 응답 파싱

**Firebase 설정**
- `main.dart`에서 Firebase Core 초기화
- 백그라운드 메시지 처리와 함께 푸시 알림을 위한 FCM
- Android 알림 채널이 있는 로컬 알림
- `google-services.json` (Android) 및 `GoogleService-Info.plist` (iOS) 필요

**지역화**
- Asia/Seoul 시간대의 한국 시장 중심
- 한국 주소 검색을 위한 KPostal 통합
- 한국 로케일에 맞는 날짜/시간 포맷팅

### 인증 및 내비게이션 플로우

1. **앱 시작** → 헌혈 게시물을 보여주는 환영 화면
2. **인증** → 역할 선택이 있는 로그인/회원가입
3. **관리자 승인** → 새 사용자는 관리자 검증 필요
4. **역할 기반 라우팅**:
   - 관리자 → `AdminDashboard`
   - 병원 → `HospitalDashboard`
   - 사용자 → `UserDashboard`
5. **토큰 관리** → SharedPreferences에 저장된 JWT

### 핵심 기능

**헌혈 게시물 시스템**
- `interval_time_picker`를 사용한 시간대 스케줄링
- 응급 요청을 위한 긴급도 플래그
- 위치 기반 매칭을 위한 지역 필터링
- 실시간 상태 업데이트

**알림 시스템**
- 긴급 요청을 위한 FCM 푸시 알림
- 앱 참여를 위한 로컬 알림
- 백그라운드 메시지 처리
- Android용 알림 채널 설정

**반려동물 관리**
- 의료 세부사항이 있는 반려동물 프로필 생성
- 혈액형 추적
- 헌혈 이력
- 건강 상태 모니터링

### 종속성

**핵심 패키지**
- `http: ^1.4.0` - REST API 통신
- `shared_preferences: ^2.2.2` - 로컬 데이터 지속성
- `intl: ^0.19.0` - 국제화 및 날짜 포맷팅

**Firebase 통합**
- `firebase_core: ^2.27.0` - Firebase 초기화
- `firebase_messaging: ^14.7.10` - 푸시 알림
- `flutter_local_notifications: ^17.0.0` - 시스템 알림
- `timezone: ^0.9.2` - 시간대 설정

**UI/UX 개선사항**
- `interval_time_picker: ^3.0.3+9` - 시간대 선택
- `kpostal: 1.1.0` - 한국 우편번호 검색
- `cupertino_icons: ^1.0.8` - iOS 스타일 아이콘
- `font_awesome_flutter: ^10.7.0` - Font Awesome 아이콘
- `flutter_markdown: ^0.7.4` - 마크다운 렌더 (헌혈 동의 안내문, 2026-05 PR-2)

**파일/다운로드** (2026-05 PR-4 헌혈 설문 PDF/Excel 다운로드)
- `path_provider: ^2.1.5` - 모바일 임시 디렉토리 (앱 내 파일 저장)
- `open_filex: ^4.5.0` - 시스템 viewer로 PDF/Excel 열기 (모바일 한정)
- 웹은 의존성 없이 `dart:html` Blob + anchor download 사용 (`file_download_helper_web.dart`)

**개발 도구**
- `flutter_lints: ^5.0.0` - 코드 품질 강화

### 디자인 시스템

**테마 설정** (`lib/utils/app_theme.dart`)
- 토스 스타일의 미니멀리스트 디자인
- 의미론적 네이밍이 있는 일관된 색상 팔레트
- 계층 구조를 위한 타이포그래피 스케일
- 일관된 레이아웃을 위한 간격 시스템
- 사용자 정의 위젯 스타일링 (버튼, 카드, 입력)

**UI 컴포넌트** (`lib/widgets/`)
- 역할 기반 스타일링이 있는 CustomAppBar
- 유효성 검사가 있는 재사용 가능한 폼 입력
- 콘텐츠 표시를 위한 카드 컴포넌트
- 로딩 상태 및 오류 처리

### API 통합 패턴

**요청 구조**
```dart
// 일반적인 API 호출 패턴
final response = await http.post(
  Uri.parse('${Config.serverUrl}/endpoint'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
  body: jsonEncode(data),
);
```

**오류 처리**
- 네트워크 오류 감지
- HTTP 상태 코드 검증
- 사용자 친화적인 오류 메시지
- 실패한 요청에 대한 재시도 메커니즘

### 개발 고려사항

**플랫폼별 설정**
- Android: 최소 SDK 21, 대상 SDK 33+
- iOS: 최소 배포 대상 iOS 11.0
- 두 플랫폼 모두에 Firebase 구성 파일 필요

**성능 최적화**
- 리스트 뷰의 지연 로딩
- 이미지 캐싱 전략
- 효율적인 상태 업데이트
- 리소스의 적절한 해제

**보안 고려사항**
- JWT 토큰 만료 처리
- 민감한 데이터의 안전한 저장
- API 엔드포인트 보호
- 입력 유효성 검사 및 살균

## 개발 가이드라인

### 새 기능 추가 시 체크리스트

작업 완료 전 아래를 한 번 확인하세요. 중앙 집중 구조를 깨뜨리지 않는 것이 이 프로젝트의 장기 유지보수성의 핵심입니다.

- [ ] **API 경로**: 새 엔드포인트는 [lib/utils/api_endpoints.dart](lib/utils/api_endpoints.dart)에 추가했는가? 서비스 파일에 `/api/...` 문자열을 하드코딩하지 않았는가?
- [ ] **상수/enum 값**: 상태 코드, 계정 타입, 긴급도 등의 `int` 리터럴을 직접 쓰지 않고 [lib/utils/app_constants.dart](lib/utils/app_constants.dart)의 상수를 참조했는가?
- [ ] **모델 위치**: 새 모델 클래스는 [lib/models/](lib/models/)에 분리했는가? 서비스 파일 안에 모델 정의를 섞지 않았는가? (기존 `admin_hospital_service.dart` 같은 통합 케이스는 점진 분리 대상)
- [ ] **HTTP 호출**: 인증 필요한 요청에 `http.get/post` 대신 [AuthHttpClient](lib/services/auth_http_client.dart)를 사용했는가?
- [ ] **저장소 접근**: `SharedPreferences.getInstance()` 직접 호출 대신 [PreferencesManager](lib/utils/preferences_manager.dart)를 경유했는가?
- [ ] **에러 메시지**: 서버 에러는 `response.extractErrorMessage()` 또는 `response.toException()`을 사용했는가? (백엔드의 `detail` Map 구조까지 자동 파싱됨)
- [ ] **로그**: `print()` 대신 `debugPrint()`를 사용했는가? (`analysis_options.yaml`의 `avoid_print` 룰이 차단)
- [ ] **dead code**: 임시 추가한 상수/함수가 결국 안 쓰이게 되었다면 제거했는가?
- [ ] **`flutter analyze`**: 이슈 0건 확인했는가?
- [ ] **계약 변경**: 백엔드 응답 스키마/enum 값이 바뀌는 작업이라면 CLAUDE.md의 해당 섹션도 함께 업데이트했는가?

### pre-commit hook (선택, 권장)

`.git/hooks/pre-commit` 파일을 만들고 실행 권한을 주면 커밋 전에 자동으로 lint가 돌아갑니다:

```bash
#!/bin/sh
flutter analyze --no-fatal-infos || {
  echo "flutter analyze 실패 — 이슈를 먼저 해결하세요."
  exit 1
}
```

Windows에서는 `.git/hooks/pre-commit.cmd` 사용.

### 핵심 작업 원칙

**API 우선 접근법**
- 모든 작업 시작 전 반드시 API 엔드포인트와 응답 구조 확인
- API 문제 발생 시 하드코딩 우회 금지
- 서버 측 문제 발견 시 구체적인 문제 상황과 해결 방안을 포함한 메시지 작성
- 임시 해결책 사용 시 반드시 TODO 주석으로 향후 개선 사항 명시

**코드 품질 유지**
- 하드코딩 대신 문제의 본질적 해결 추구
- 임시 처리 코드에는 반드시 다음 형식의 주석 포함:
  ```dart
  // TODO: [문제 설명] - [영구적 해결 방안]
  // 예: TODO: API 응답 구조 변경 필요 - 서버에서 user_type 필드 일관성 유지
  ```

**문제 해결 접근법**
1. API 문서/응답 구조 확인
2. 로그 및 오류 메시지 분석
3. 서버 측 수정이 필요한 경우 상세한 문제 보고서 작성
4. 클라이언트 측에서 해결 가능한 경우에만 코드 수정 진행

### 응답 및 커뮤니케이션

**언어 사용**
- 모든 답변과 코멘트는 한국어로 작성
- 기술적 용어는 영어 유지하되 설명은 한국어로 제공
- 코드 내 주석도 한국어로 작성

**서버 문제 보고 형식**
```
[문제 유형]: API 응답 구조 불일치
[엔드포인트]: POST /api/auth/login
[예상 응답]: { "user_type": 1, "token": "..." }
[실제 응답]: { "userType": 1, "token": "..." }
[영향]: 클라이언트에서 user_type 파싱 실패
[제안 해결책]: 응답 필드명 일관성 유지 또는 API 명세서 업데이트
```

## 데이터 타입 및 상수 정의

### 사용자 유형 (Account Type / accounts.account_type)
백엔드 `constants/enums.py`의 `AccountType` 기준. **라우팅의 핵심 필드이므로 절대 문자열화하거나 재매핑하지 말 것** (`int` 값 그대로 유지).
- `1`: **ADMIN** (관리자 / 시스템 관리자)
  - 사용자 승인 및 관리
  - 병원 검증 및 승인
  - 시스템 전체 콘텐츠 조정
- `2`: **HOSPITAL** (병원 / 동물병원)
  - 헌혈 요청 게시물 작성
  - 지원자 관리 및 승인
  - 스케줄링 관리
- `3`: **USER** (일반 사용자 / 반려동물 소유자)
  - 반려동물 등록 및 관리
  - 헌혈 요청 조회 및 지원
  - 교육 콘텐츠 접근

### 계정 상태 (Account Status)
- `0`: **대기 중** - 관리자 승인 대기
- `1`: **활성화** - 정상 사용 가능
- `2`: **비활성화** - 계정 일시 정지
- `3`: **차단됨** - 계정 영구 정지

### 헌혈 요청 상태 (Post Status / donation_posts.status)
백엔드 `constants/enums.py`의 `PostStatus` 기준. 프론트 `lib/utils/app_constants.dart`도 동일한 값을 사용.
- `0`: **WAIT** (모집 대기) - 등록 직후 관리자 검토 대기
- `1`: **APPROVED** (승인) - 관리자 승인, 지원자 모집 중
- `2`: **REJECTED** (거절) - 관리자가 요청 거절
- `3`: **CLOSED** (마감) - 모집 기한 종료
- `4`: **COMPLETED** (완료) - 병원이 완료/중단 처리
- `5`: **SUSPENDED** (대기 상태) - 관리자가 모집중 → 대기로 변경

### 긴급도 (Post Type / donation_posts.types)
백엔드 `constants/enums.py`의 `PostType` 기준. **0과 1의 의미가 직관과 반대이므로 주의**.
- `0`: **URGENT** (긴급) - 응급 상황으로 즉시 헌혈 필요
- `1`: **REGULAR** (정기) - 정기적인 헌혈 요청

### 신청 상태 (Applied Donation Status / applied_donation.status)
백엔드 `constants/enums.py`의 `AppliedDonationStatus` 기준. 라이프사이클 단순화(2026-04-29) — 백엔드는 0~4만 사용. 의료진 "중단" 액션 폐기 (changelog 참조).
- `0`: **PENDING** (대기 중) - 신청 직후, 병원 승인 대기
- `1`: **APPROVED** (승인됨) - 병원이 신청자 승인
- `2`: **PENDING_COMPLETION** (완료 대기) - 병원 1차 완료 처리, 관리자 최종 승인 대기
- `3`: **COMPLETED** (완료) - 관리자 최종 승인으로 정식 완료
- `4`: **CLOSED** (종결) - 미선정 / 관리자 수동 종결 (4 의미 변경 2026-04-29)

**의료진의 "중단" 액션은 폐기됨** — 의료진은 단일 "헌혈 완료" 버튼만 사용. 채혈 못한 케이스는 `blood_volume=0` + `incompletion_reason` 조합으로 표현되며 admin이 'complete'로 최종 승인. ~~`5 PENDING_COMPLETION`~~/~~`6 PENDING_CANCELLATION`~~/~~`7 FINAL_COMPLETED`~~는 deprecated (백엔드 enum에서 제거됨).

**4번 의미 변경 (2026-04-29 admin 마감 가드 완화 라운드)**: 기존 `CANCELED`(사용자 자발 취소) → `CLOSED`(종결)로 의미 확장. 사용자 자발 취소는 더 이상 4를 거치지 않고 **행 자체 hard delete**로 처리됨 (DELETE /api/applied_donation/{idx} 라우트로 통일).

라이프사이클:
- 정상 흐름: `PENDING(0) → APPROVED(1) → PENDING_COMPLETION(2) → COMPLETED(3)` 단방향.
- 종결 흐름: `PENDING/APPROVED → CLOSED(4)` (경로별 트리거 상이)
  - 시간대 정원 충족 시 자동 (`_auto_close_remaining_pending`, **PENDING만**)
  - 게시글 마감 시 일괄 (`_send_recruitment_closed_notifications`, **PENDING만**. APPROVED는 1차 완료 입력 대기로 유지)
  - 관리자 수동 종결 (`PUT /api/applied_donation/{idx}/status` body `{status: 4}`, **PENDING/APPROVED 둘 다**)
- 사용자 자발 취소: `PENDING → hard delete` (DELETE 라우트, 행 자체 삭제. CLOSED 상태로 남기지 않음)

**관리자 게시글 마감 가드 (2026-04-29 완화)**: `PATCH /api/admin/posts/{post_idx}/close`는 신청자 0명 / 선정 0명이어도 마감 허용. 가드는 PostStatus 전이 가능 여부만 검사 (APPROVED(1) → CLOSED(3)). 마감 시점에 해당 게시글의 PENDING 신청은 동일 트랜잭션에서 CLOSED(4)로 일괄 변경됨. APPROVED 신청은 그대로 유지되어 헌혈마감 탭에서 1차 완료 입력 흐름 진행. 응답 스키마 / 알림 동작 변경 없음. 메시지 `POST_NO_APPROVED_APPLICANTS` 제거.

### 반려동물 혈액형 (Pet Blood Type)
**개 혈액형**
- `DEA1.1+`: DEA 1.1 양성
- `DEA1.1-`: DEA 1.1 음성

**고양이 혈액형**
- `A`: A형
- `B`: B형
- `AB`: AB형

### 반려동물 성별 (Pet Sex / pets.sex)
백엔드 `constants/enums.py::PetSex` 기준. **NOT NULL** 컬럼이므로 가입/수정 폼에서 필수 입력. 알파 데이터는 1(수컷)로 일괄 마이그레이션됨 (암컷이 있으면 관리자가 별도 보정).
- `0`: **FEMALE** (암컷)
- `1`: **MALE** (수컷)

### 임신/출산 상태 (Pregnancy Birth Status / pets.pregnancy_birth_status)
백엔드 `constants/enums.py::PregnancyBirthStatus` 기준. **NOT NULL, default 0**. 단일 셀렉터로 통합 관리 (이전 `pregnant` bool + `has_birth_experience` bool 두 필드를 대체).
- `0`: **NONE** (해당 없음)
- `1`: **PREGNANT** (현재 임신중) - `last_pregnancy_end_date` 입력 안 받음
- `2`: **POST_BIRTH** (출산 이력 있음) - `last_pregnancy_end_date` 필수

**status=1 → status=2 전이는 사용자 수동** (백엔드에 batch/cron/전용 endpoint 없음). 출산 종료 시 펫 정보 수정 화면에서 직접 status 변경 + 종료일 입력. 폼에 안내 문구 권장: "출산 종료 시 직접 '출산 이력 있음'으로 변경하고 종료일을 입력해주세요."

### 헌혈 자격 거부 사유 (Eligibility Reason / failed_conditions[*].reason)
백엔드 `constants/donation_eligibility.py::EligibilityReason` 기준. **`condition == "pregnancyBirth"`인 항목에만 부여**. 다른 condition 항목에는 reason 없음.
- `"pregnant"`: 현재 임신중 (status=1)
- `"cooldown"`: 출산 12개월 미경과 (status=2 + 종료일 < 12개월)
- `"date_missing"`: status=2인데 종료일 NULL

백엔드 `message` 텍스트가 바뀌어도 `reason`은 유지되므로 UI 분기는 reason 기반 권장. 표시 텍스트는 `message` 그대로 fallback 가능.

### 채혈 부위 (Blood Collection Site / donation_survey.prev_blood_collection_site)
백엔드 `constants/enums.py::BloodCollectionSite` 미러. 카페 설문지 18-6번 (직전 외부 헌혈 채혈 부위) 전용. 값 변경 금지 (DB 저장값 보존).
- `0`: **JUGULAR** (경정맥)
- `1`: **LIMB** (사지)
- `2`: **BOTH** (둘 다)
- `3`: **OTHER** (기타) — `prev_blood_collection_site_etc` 컬럼에 자유 텍스트 별도 입력 필수

프론트 박제: [lib/utils/app_constants.dart](lib/utils/app_constants.dart) `bloodCollectionSite*` 상수 + `getBloodCollectionSiteText()` 헬퍼.

### 직전 헌혈 출처 (Prev Donation Source)
`GET /api/applied-donations/{id}/survey/template` 응답의 `prev_donation_source` 필드. 백엔드는 string 그대로 emit. 프론트는 분기 안전성을 위해 상수 박제.
- `"system"`: 시스템 헌혈 이력 있음 → 직전 헌혈 정보 자동 채움 (수정 불가)
- `"external"`: `prior_last_donation_date`만 있음 → 사용자가 prev_* 필드 직접 입력
- `"none"`: 첫 헌혈 → 직전 헌혈 섹션 숨김 또는 비활성

**2026-05-06 메모** — 사용자 입력 폼에서 `prior_last_donation_date` / `prior_donation_count` 두 필드가 제거됨 (Issue #5). `"external"` 케이스는 admin이 수동으로 보정한 펫에서만 발생. 일반 사용자 가입/펫 추가 흐름에서는 system 또는 none만 가능. external 분기는 dead path가 아니라 admin 보정 데이터를 반영하기 위해 유지.

프론트 박제: [lib/utils/app_constants.dart](lib/utils/app_constants.dart) `prevDonationSource*` 상수.

### 동의 텍스트 버전 (Donation Consent Version)
백엔드 `constants/donation_consent.py::DONATION_CONSENT_VERSION`. 현재 `"1.1.0"` (2026-05 카페 안내문 30개 + 동의 5개 정식 박제).

설문 저장 시 `donation_consent.terms_version_at_consent`에 박제됨 (사용자가 동의한 시점의 버전 영구 보존). 프론트는 `GET /api/donation-consent/items` 응답의 `version` 필드를 그대로 표시 (박제 불필요).

### 지역 코드 (Region Code)
- 한국 시도별 코드 (KPostal 표준 따름)
- 예: `서울`, `경기`, `인천`, `대구`, `부산`, `광주`, `대전`, `울산`, `세종`, `강원`, `충북`, `충남`, `전북`, `전남`, `경북`, `경남`, `제주`

### API 응답 코드 (Response Code)
- `200`: 성공
- `201`: 생성 성공
- `400`: 잘못된 요청
- `401`: 인증 실패
- `403`: 권한 없음
- `404`: 리소스 없음
- `500`: 서버 오류

### 알림 타입 (Notification Type)
- `1`: **헌혈 요청** - 새로운 헌혈 요청 알림
- `2`: **지원 승인** - 헌혈 지원 승인 알림
- `3`: **지원 거절** - 헌혈 지원 거절 알림
- `4`: **시스템** - 시스템 공지사항

## 백엔드 의존 계약 (Backend Contract)

아래 항목들은 백엔드와 프론트가 공동으로 지키는 고정 계약입니다. 백엔드가 변경할 때는 반드시 changelog로 사전 공지하며, 프론트가 임의로 재정의하지 않습니다.

### 로그인 응답 필드 (절대 필드명 변경 금지)
`POST /api/login` 및 네이버 로그인 응답은 아래 필드를 포함합니다. 프론트의 `lib/auth/login.dart`와 `PreferencesManager`가 이 키에 직접 의존합니다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `access_token` | string | JWT 액세스 토큰 (15분) |
| `refresh_token` | string \| null | 리프레시 토큰 (7일). null이면 저장 스킵 |
| `account_type` | int (1/2/3) | **라우팅 핵심** — 문자열화 금지 |
| `account_idx` | int | 계정 PK |
| `email` | string | 사용자 이메일 |
| `name` | string | 사용자 이름 |
| `hospital_code` | string | `account_type == 2`일 때만 (병원 식별자) |
| `onboarding_completed` | bool | false면 온보딩 화면으로 리다이렉트 |
| `approved` | bool | false면 "승인 대기 중" 다이얼로그 표시 |

### 에러 응답 `detail` 구조
`AuthHttpClient`의 `extractErrorMessage()`가 아래 두 형태를 파싱합니다.

- **문자열 형태**: `{"detail": "자격이 맞지 않습니다."}`
- **Map 형태** (자격 검증 실패 등):
  ```json
  {
    "detail": {
      "message": "헌혈 자격 조건을 충족하지 않습니다.",
      "failed_conditions": [
        {"condition": "weight", "message": "체중 부족"},
        {"condition": "pregnancyBirth", "reason": "pregnant", "message": "현재 임신 중"}
      ]
    }
  }
  ```

각 항목은 `condition` (조건 키) + `message` (한국어 표시) 필수 + `reason` (선택, `pregnancyBirth`에만). reason 가능 값은 "데이터 타입 → 헌혈 자격 거부 사유" 섹션 참조.

서버의 `constants/messages.py`에 있는 한국어 메시지는 **클라이언트에 그대로 노출됨** — 메시지 변경은 곧 UI 변경.

### HTTP 상태 코드 의미 (프론트가 분기하는 코드)
| 코드 | 의미 | 프론트 처리 |
|------|------|-------------|
| 401 | 인증 실패 | `AuthHttpClient`가 Refresh Token으로 자동 재시도, 실패 시 강제 로그아웃 |
| 403 | 승인 대기 / 권한 없음 | 로그인 시 "승인 대기 중" 다이얼로그, 일반 요청은 권한 메시지 |
| 409 | 중복 가입 | 네이버 로그인 시 "이미 가입된 이메일입니다" |
| 413 | **이미지 개수(5개) 초과 전용** | "게시글당 최대 5개의 이미지만 업로드" |
| 429 | Rate Limit | `Retry-After` 헤더의 초 단위 값으로 "N초 후 다시 시도" 안내 |

**413 계약 주의사항**: HTTP 표준상 413은 "Payload Too Large"지만, 백엔드와 합의하여 **이미지 개수 초과 전용**으로 사용 중. **파일 크기 초과(20MB)는 400**으로 반환되며 `detail`에 사유가 포함됨(`IMAGE_FILE_TOO_LARGE_DETAIL`). 지원하지 않는 포맷도 400. 현재 프론트의 "413 = 5개 초과" 해석은 정확.

**429 계약 적용 범위** (현재 백엔드에서 `@limiter.limit(...)` 걸린 엔드포인트만):
| 엔드포인트 | 제한 |
|------------|------|
| `POST /api/login` | 5 req/min/IP |
| `POST /api/register` | 3 req/min/IP |

- 이미지 업로드 / 헌혈 신청 / 게시글 생성 등에는 **429 안 뜸** (처리 로직 불필요).
- `Retry-After` 헤더는 slowapi가 항상 자동 첨부 (보증됨). 프론트의 60초 fallback은 안전장치로 유지.
- 신규 엔드포인트에 429 추가 예정 시 백엔드 changelog **필수**.

### 인증 토큰
- **로그인 엔드포인트**: **`POST /api/login`** (form-urlencoded, `username` / `password` 필드). `/api/auth/login`은 **존재하지 않음** (호출하면 404). 백엔드 `OAuth2PasswordBearer.tokenUrl`이 `/api/login`을 가리키고 있어 경로 변경 시 OAuth2 설정과 함께 움직여야 함 (백엔드 changelog로 사전 공지 필수).
- **Access Token**: `SharedPreferences`의 `auth_token` 키에 저장. 요청 시 `Authorization: Bearer {token}` 헤더로 전송.
- **Refresh Token 전달 방식** (백엔드는 쿠키/body 둘 다 지원):
  - 웹: 백엔드가 HttpOnly 쿠키로도 발급하며 브라우저가 `/api/auth/refresh` 호출 시 자동 첨부. 프론트는 **body 방식으로 통일해서 사용 중**.
  - 모바일: body로 전달/재전송 (`{"refresh_token": "..."}`).
- **현재 방식**: body 방식으로 통일. CORS `credentials: 'include'` / SameSite 설정 실수 시 전체 인증이 막히는 리스크가 커서 쿠키 전용 전환은 별도 보안 라운드로 분리. 전환 시 백엔드가 changelog로 사전 공지.
- **토큰 수명**: Access 15분 / Refresh 7일 (백엔드 `.env`의 `ACCESS_TOKEN_EXPIRE_MINUTES=15`, `REFRESH_TOKEN_EXPIRE_DAYS=7`). 변경 시 백엔드가 `Auth: access token lifetime changed 15min → X min` 형식 changelog 필수 (리프레시 빈도 = 네트워크 부하 / UX 영향).

### 실시간 알림 전송 채널 (FCM 단일화 2026-05-02)
- **모바일/웹 모두 FCM**: 로그인 직후 `POST /api/user/fcm-token` body `{"fcm_token": "...", "platform": "android"|"ios"|"web"}`로 디바이스 토큰 등록. `onTokenRefresh` 리스너가 갱신 시 자동 재전송. 로그아웃 시 `DELETE /api/user/fcm-token` body `{"fcm_token": "..."}`로 현재 디바이스 토큰만 제거.
- **웹은 Service Worker 기반 Web Push**: `web/firebase-messaging-sw.js`가 백그라운드 푸시 수신 + OS 알림 표시. 사용자가 알림 클릭 시 `client.postMessage`로 dart 측에 data 전달 → `NotificationService.dispatchByType` 라우팅. 같은 origin 탭 없으면 `clients.openWindow`로 새 창. VAPID 공개키는 `--dart-define=FCM_VAPID_KEY=...`로 빌드 시 주입 (SW 파일에 하드코딩 금지).
- **WebSocket /ws 폐기 진행 중**: FE 측 `WebSocketHandler` 제거 완료, BE 측 `@app.websocket("/ws")` + `connection_manager` + `send_websocket_notification` 코드는 FE 웹 배포 + 2주 모니터링 후 별도 PR로 일괄 제거 예정.

### FCM 토큰 멀티 디바이스 contract (2026-05-02 신설)
백엔드 `fcm_tokens` 테이블이 1:N 구조로 토큰 저장. 같은 account가 모바일+웹 동시 사용 시 양쪽 디바이스 모두에 push 도달.

| 컬럼 | 비고 |
|------|------|
| `account_idx` | accounts FK, ON DELETE CASCADE |
| `fcm_token` | varchar |
| `platform` | enum('android', 'ios', 'web'). FE는 명시 송신, BE는 누락 시 'android' default |
| UNIQUE KEY | (account_idx, fcm_token) — 같은 계정 내 중복만 차단 |

**같은 토큰이 다른 account에서 등록 시**: BE가 application-level에서 이전 행 삭제 후 신규 INSERT (디바이스 소유 이전).

**옛 컬럼**: `accounts.fcm_token`은 alembic 85b5f42edcda에서 drop됨. 더 이상 존재하지 않음.

**알림 발송**: BE `send_notification_to_account`이 fcm_tokens 전체 토큰으로 multicast (`messaging.send_each_for_multicast`). UnregisteredError / SenderIdMismatchError 토큰은 자동 DELETE.

**로그아웃 시점 호출**: 프론트 `_logout()`은 `auth_token` 삭제 전에 `UnifiedNotificationManager.deleteCurrentDeviceToken()` 호출 필수. 토큰 삭제 실패해도 로그아웃은 계속 (BE의 multicast 시 자동 정리에 의존).

### 프론트 FCM 수신 아키텍처 (2026-05-02 web FCM 통일)

**책임 분리 (단일 원천 원칙)**

| 클래스 | 책임 |
|--------|------|
| [FCMHandler](lib/services/fcm_handler.dart) | **모바일 FCM 수신** 전담. 포그라운드 `onMessage` 리스너, `onMessageOpenedApp` (스트림 추가용), 토큰 관리 (`updateFCMToken` / `onTokenRefresh`), 상단 로컬 푸시 표시, unknown type fallback. 토큰 등록 시 `platform: 'android'\|'ios'` 명시 |
| [WebFcmInit](lib/services/web_fcm_init.dart) | **웹 FCM 수신** 전담. `firebase_messaging` web으로 `getToken(vapidKey)` + 백엔드 등록 (`platform: 'web'`), `onMessage` 포그라운드 리스너, SW의 `notificationclick` postMessage 수신 → `dispatchByType`. dart:html 사용으로 conditional import (`web_fcm_init_stub.dart` if not html). VAPID 키는 `--dart-define=FCM_VAPID_KEY=...` 주입 |
| [NotificationService](lib/services/notification_service.dart) | FCM **탭 네비게이션** 전담. `onMessageOpenedApp` (navigation용), `getInitialMessage`, `handleLocalNotificationTap`, `dispatchByType` 단일 진입점 (모든 클릭 경로가 여기 위임), `navigatorKey` 보유 |
| [UnifiedNotificationManager](lib/services/unified_notification_manager.dart) | 플랫폼 분기. 모바일은 `FCMHandler.notificationStream`, 웹은 `WebFcmInit.notificationStream`을 구독해 단일 스트림으로 제공. 로그인/로그아웃 시 `updateTokenAfterLogin` / `deleteCurrentDeviceToken` 양쪽 모두 위임 |

**라우팅 책임 분담 (계약 확정 2026-04-28)**

| 영역 | 책임 |
|------|------|
| 백엔드 | `type` + 도메인 식별자(top-level flat 키)만 제공. 어느 화면으로 갈지는 모름. `navigation` 객체는 deprecated, 신규 emit에 추가 금지 |
| 프론트 | `type` → 화면 매핑 ([notification_service.dart](lib/services/notification_service.dart)의 9개 `_navigateToXxx`). 동일 `type`이 다중 수신자(admin/hospital/user)에 발송되는 경우 `account_type`으로 분기 (예: `donation_completed`) |

라우팅 분기는 **100% `data['type']` 기반**. `data.navigation.page` 힌트는 분기 결정에 사용하지 않음. 다중 수신 분기 규약은 "백엔드 의존 계약 → 알림 다중 수신 라우팅" 섹션 참조.

**앱 상태별 알림 탭 → 네비게이션 경로** (세 경로 모두 `NotificationService`가 처리)

| 앱 상태 | Firebase 콜백 | 핸들러 |
|---------|--------------|--------|
| 포그라운드 | `flutter_local_notifications` 탭 → `onDidReceiveNotificationResponse` | `NotificationService.handleLocalNotificationTap(payload)` |
| 백그라운드 | `FirebaseMessaging.onMessageOpenedApp` | `NotificationService.initialize()` 내부 listener |
| 킬 상태 | `FirebaseMessaging.instance.getInitialMessage()` | `NotificationService.initialize()` 내부 |

**주의 — 리스너 중복 금지**: `FirebaseMessaging.onMessage.listen`과 `onTokenRefresh.listen`은 **각각 FCMHandler 1곳에서만** 등록해야 함. 2026-04 이전에 NotificationService와 FCMHandler가 각각 등록해서 동일 메시지가 목록에 2번 뜨거나 토큰 갱신 시 서버 전송이 2번 발생하던 버그 있었음. 향후 새 리스너 필요 시 FCMHandler에 추가.

**주의 — 상단 푸시 호출 위치**: 포그라운드 상단 로컬 푸시(`main.dart::showGlobalLocalNotification`)는 `FCMHandler._handleForegroundMessage`에서만 호출. 백그라운드/킬 상태는 시스템이 이미 푸시를 표시하므로 `_handleMessageOpenedApp`에서는 호출하지 않음 (중복 표시 방지).

### WebSocket 메시지 스키마 (계약 확정)
백엔드 `services/notification_service.py` 기준. **필드명 변경 금지**, `timestamp`는 **Unix 초(밀리초 아님)**.

```json
{
  "type": "string",              // NotificationType 중 하나 (아래 목록)
  "notification_id": 1234,       // int | null — DB PK, 읽음 처리 API에서 사용
  "title": "string",
  "body": "string",
  "data": { /* object */ },      // 중첩 object 허용 (WebSocket 전용 특성)
  "timestamp": 1716550800        // int, Unix seconds
}
```

- **data 키 추가는 허용** (프론트는 모르는 키 무시). 키 이름 변경/삭제는 changelog 필수.
- **`data` 필드 타입 보증** (백엔드 확정): **항상 JSON object (Map)**. `null`은 올 수 없음 (백엔드가 송신 시 `{}`로 승격: `services/notification_service.py:112`). array도 올 수 없음 (전 호출 경로에서 dict 리터럴만 사용). 빈 `{}`는 정상 값. 프론트의 "Map일 때만 `relatedData`로 복사" 방어 로직은 유지하되, 실제로 그 분기가 탈 일은 없음.
- 시스템 메시지 `pong` / `ping` / `connection_established`는 수신 시 NotificationModel로 변환하지 않고 조용히 무시.
- **Unknown `type` fallback**: 프론트 매핑에 없는 타입을 받으면 silent drop하지 않고 로그 + 유저타입별 `systemNotice`로 승격해서 목록에 표시 (최소한 title/body는 전달). 백엔드가 신규 type을 추가했는데 프론트가 아직 못 따라간 경우의 safety-net. 모바일은 [FCMHandler._convertAndPublish](lib/services/fcm_handler.dart), 웹은 [WebFcmInit](lib/services/web_fcm_init.dart)의 `onMessage` 핸들러가 처리.

### FCM data 직렬화 규칙 (WebSocket과의 차이)
- **WebSocket**: `data`가 원본 object 그대로 전달 (중첩 dict/list 사용 가능).
- **FCM**: Firebase 스펙상 `data`의 모든 값이 **string이어야 함**. 백엔드가 dict는 `json.dumps()`로 직렬화, 나머지는 `str()` 캐스팅. 프론트는 `post_info`, `navigation` 같은 필드를 `jsonDecode`로 재파싱해야 함 — [notification_converter.dart:parseRelatedData](lib/services/notification_converter.dart)에서 이미 처리 중.

### 알림 제목 두 출처 — 의도된 분리 (계약 확정 2026-05-08)

알림 제목 표시는 **두 출처가 의도적으로 분리되어 있음**. 통합 작업 금지.

| 출처 | 위치 | 의미 | 사용처 |
|------|------|------|--------|
| BE `notification.title` | 백엔드 동적 emit (`messages.py`) | 사용자 대면 본문 제목 (개인화 가능, 예: `"홍길동님이 신청하셨습니다"`) | OS 푸시 알림 + 인앱 알림 카드 메인 제목 ([unified_notification_page.dart:773](lib/widgets/unified_notification_page.dart)) |
| FE `NotificationTypeNames` | [notification_types.dart](lib/models/notification_types.dart) 박제 | 카테고리 메타 라벨 (필터/그룹핑용 고정 텍스트, 예: `"칼럼 게시글 승인 요청"`) | 알림 카드 우측 상단 카테고리 칩 ([unified_notification_page.dart:802](lib/widgets/unified_notification_page.dart)) |

**한 화면 동시 노출**: 메인 제목(상세) + 카테고리 칩(분류)으로 역할 분담. 통합하면 카테고리 필터/그룹핑 UI가 BE 응답에 의존하게 되어 BE 메시지 변경 시 FE 그룹핑 깨짐 위험.

**금지 사항**:
- BE `title` 텍스트를 FE 카테고리 라벨로 재사용 금지
- FE `NotificationTypeNames` 라벨을 OS 푸시 표시에 끌어다 쓰는 시도 금지 (FCM은 BE `notification.title` 그대로 OS 전달)
- 두 출처를 병합하는 "단일 원천" 리팩터 금지 — 의미가 다름

### FCM/WebSocket data 키 컨벤션 (계약 확정 2026-04-28, 2026-05-01 정리)

도메인 식별자는 항상 **top-level flat 키**로 emit. 신규 emit 사이트에서 객체로 묶지 말 것.

**표준 키**

| 키 | 타입 | 용도 |
|----|------|------|
| `post_idx` | int | `donation_posts.post_idx` |
| `application_id` | int | `applied_donation.applied_donation_idx`. **FCM data만** 이 키 이름. REST 응답 body는 `applied_donation_idx` 그대로 (의도된 보존, 아래 참조) |
| `column_idx` | int | `hospital_columns.column_idx` (2026-05-01 백엔드 4c1de27 commit으로 `column_id` → `column_idx` 정정) |
| `pet_idx` | int | `pets.pet_idx` |
| `is_selected` | string `"true"`/`"false"` | `recruitment_closed`에서 선정 여부 분기 |
| `new_status` | int (0~3) | account 상태 알림 전용 — 별도 섹션 참조 |
| `status_label` | string | account 상태 알림 전용 — 별도 섹션 참조 |
| `document_request_id` | int | `document_request_responded` 알림 전용 (자료 요청 PK) |

**`navigation` 객체 emit 제거 완료** (2026-05-01 백엔드 4c1de27 commit). 백엔드 emit 15곳에서 일괄 제거. 라우팅 결정은 **100% `data['type']` 기반**. 프론트는 양방향 fallback (`data['post_idx'] ?? data['post_id']`)으로 안전 마이그레이션 (구버전 캐시 알림 호환).

**구버전 키 → 신버전 키 (2026-05-01 정리, 프론트 fallback 적용 위치)**

| 구버전 키 | 신버전 키 | 프론트 fallback 위치 |
|-----------|-----------|---------------------|
| `post_id` | `post_idx` | [notification_mapping.dart:280](lib/models/notification_mapping.dart#L280), [notification_model.dart:relatedId](lib/models/notification_model.dart), [notification_service.dart:_navigateToHospitalPosts](lib/services/notification_service.dart), [unified_notification_page.dart:_extractPostId](lib/widgets/unified_notification_page.dart) |
| `column_id` | `column_idx` | [notification_mapping.dart:relatedId](lib/models/notification_mapping.dart), [notification_model.dart:relatedId](lib/models/notification_model.dart), [notification_converter.dart:keysToExtract](lib/services/notification_converter.dart), [notification_service.dart:_navigateToHospitalColumns](lib/services/notification_service.dart) |
| `data['navigation']` 객체 | top-level 식별자만 | [notification_service.dart:_navigateToPostManagement](lib/services/notification_service.dart) — `tab` 정보는 type별 default tab 매핑으로 대체 |

**FCM data vs REST 응답 body 키 이름 차이 (의도된 보존)**

`applied_donation_idx`는 백엔드가 광범위하게 사용 중인 정식 컬럼명이지만, FCM data는 프론트 핸들러 일관성을 위해 `application_id`로 정정함 (2026-04-28). REST 응답 body는 그대로 `applied_donation_idx` 유지:

| 위치 | 키 | 비고 |
|------|---|------|
| FCM data (2곳) | `application_id` | `donation_completion_rejected`, `donation_completed` (admin report) |
| REST 응답 body (다수) | `applied_donation_idx` | 모델 4개 + 화면 다수 의존. 추후 단일 키로 통일 가능하나 별도 마이그레이션 라운드로 분리 |

[donation_history_screen.dart:802](lib/user/donation_history_screen.dart#L802), [applied_donation_model.dart:583](lib/models/applied_donation_model.dart#L583)은 이미 양방향 fallback (`json['applied_donation_idx'] ?? json['application_id']`).

### FCM `type` 공식 목록 (계약 확정)
백엔드 `constants/enums.py::NotificationType`가 **단일 원천**. 총 **30개 고유** (2026-05-01 `hospital_notice` 제거 + `document_request_responded` 추가, 양쪽 +1/-1 상쇄로 30 유지). **신규 추가 시 changelog 필수** — 안 그러면 프론트가 fallback `systemNotice`로 떨어짐. 프론트 쪽 매핑 파일([lib/models/notification_mapping.dart](lib/models/notification_mapping.dart))과 **이중 동기화** 필요.

```
# 관리자용 (9개)
admin_alert, new_user_registration, new_post_approval, column_approval,
new_donation_application, donation_completed, pet_review_request,
new_pet_registration,                       # 2026-04 append: services/pets_service.py:90
document_request_responded                  # 2026-05-01 append: 자료 요청 응답 (USER + ADMIN)

# 병원용 (11개, hospital_notice 제거 1846768)
hospital_alert, donation_post_approved, donation_post_rejected, new_donation_application,
column_approved, column_rejected, timeslot_filled, all_timeslots_filled,
post_suspended, post_resumed, document_request

# 사용자용 (13개)
broadcast, general, donation_completed, donation_completion_rejected, recruitment_closed,
account_suspended, account_status_changed, pet_approved, pet_rejected,
new_donation_post,                          # 2026-04 append: services/admin_post_service.py:154
donation_application_approved,              # 2026-04 append: services/applied_donation_service.py:648
donation_application_rejected,              # 2026-04 append: services/applied_donation_service.py:656
document_request_responded                  # 2026-05-01 append: 자료 요청 응답 (USER + ADMIN)
```

**2026-04 동기화 배경**: 위 4개 타입은 백엔드가 emit은 하고 있었으나 `constants/enums.py`에 등록되지 않아 알림 **목록 조회 API** (`/api/*/notifications`) 에서 필터링되어 숨겨져 있던 버그 상태였음. enums.py에 append하면서 과거 DB 레코드도 목록에 노출되기 시작 — 별도 데이터 마이그레이션 불필요.

**2026-05-01 변경**:
- `hospital_notice` 제거 (백엔드 1846768 commit) — `POST /api/notifications/hospital/patients` endpoint와 함께 deprecate. 사용자 의도("병원은 헌혈 게시글 + 칼럼만 작성, 환자 직접 알림 권한 없음") 반영. 프론트 호출 0건이라 영향 없음.
- `document_request_responded` 추가 (admin + user 양쪽 수신). `POST /api/donation/respond-documents` 엔드포인트가 트리거. data: `{type, document_request_id, application_id, post_idx, hospital_name, post_title}`. 프론트 매핑: [notification_mapping.dart](lib/models/notification_mapping.dart) + [notification_service.dart:_navigateForDocumentRequestResponded](lib/services/notification_service.dart) (admin → AdminPostCheck 헌혈완료 탭, user → DonationHistoryScreen).

**2026-05 PR-5 추가** (헌혈 사전 정보 설문 시스템 — "헌혈 사전 정보 설문 시스템" 섹션 참조):

| type | audience | trigger | data 키 |
|------|----------|---------|---------|
| `donation_day_before_reminder` | USER + HOSPITAL + ADMIN | D-1 09:00 cron | role별 상이 — USER: `application_id`, `survey_filled` / HOSPITAL: `applicant_count`, `post_title` / ADMIN: `post_title`. 공통: `post_idx`, `donation_date`, `donation_time` |
| `donation_application_auto_closed` | USER | D-2 23:55 미작성자 | `post_idx`, `application_id`, `reason="survey_not_submitted"`, `donation_date`, `donation_time`, `post_title` |
| `donation_survey_submitted` | ADMIN | 설문 제출 (옵션 A+C) | `application_id`, `post_idx`, `pet_idx`, `pet_name`, `hospital_name`, `is_resubmission` ("true"/"false" string) |
| `pet_info_update_request` | USER | 운영진 수동 트리거 | `missing_fields` (json string list of "last_vaccination_date" / "last_preventive_medication_date") |
| `donation_survey_pre_lock_reminder` | USER (미작성자만) | D-2 09:00 cron | `post_idx`, `application_id`, `donation_date`, `donation_time` |

deep link 라우팅 — [lib/services/notification_service.dart](lib/services/notification_service.dart):
- `donation_day_before_reminder` → 3분기: admin/hospital/user 각각 다른 화면
- `donation_application_auto_closed` → MyApplicationsScreen
- `donation_survey_submitted` → AdminDonationSurveyDetail (`survey_idx` 우선, 없으면 list)
- `pet_info_update_request` → UserPetManagement (기존 헬퍼 재사용)
- `donation_survey_pre_lock_reminder` → DonationSurveyFormPage (작성 모드 자동 진입)

**D-2 09:00 알림 충돌 방지** (백엔드 `_send_reminders` filled_survey_only 옵션):
- 작성자 → `donation_reminder` (일반 D-2 안내)
- 미작성자 → `donation_survey_pre_lock_reminder` (마감 경고)
- 한 사용자가 두 알림 받지 않음 — 백엔드에서 분리 처리

옵션 A+C는 코드 코멘트에 박제됨 (notification_mapping.dart). 백엔드 `services/donation_survey_service.py`의 `submit_donation_survey` (is_resubmission=False) + `update_donation_survey` (was_reviewed_before_edit 분기로 is_resubmission=True) 조건과 1:1 동기화.

### 알림 타입 추가 시 dual-sync contract (필수 4단계)

백엔드 `constants/enums.py::NotificationType`과 프론트 [lib/models/notification_mapping.dart](lib/models/notification_mapping.dart)는 **독립된 두 개의 단일 원천**이며 **둘 다 유지**해야 합니다. 한쪽만 갱신하면 아래처럼 silent degrade:

| 빠뜨린 단계 | silent degrade 방식 |
|------------|---------------------|
| (1) 서비스에서 emit 안 함 | 알림 자체 발송 안 됨 (가장 명확한 실패) |
| (2) `enums.py`에 append 안 함 | push는 뜨지만 목록 API에서 필터링되어 **누적 기록만 사라짐** (2026-04에 발견된 케이스) |
| (3) `notification_mapping.dart`에 매핑 추가 안 함 | 프론트가 `systemNotice` fallback으로 표시 (아이콘/제목/priority 불명확, navigation 기본값) |
| (4) `notification_service.dart`에 `_navigateToXxx` 핸들러 추가 안 함 | 알림 탭 시 기본 대시보드로 이동 (특정 상세 화면으로 점프 불가) |

프론트 FCM/WebSocket → client enum 변환은 [lib/services/notification_converter.dart::fromFCM](lib/services/notification_converter.dart) / `fromServerData`가 **`ServerNotificationMapping`을 단일 원천으로 참조**. 신규 `type` 추가 시 `notification_mapping.dart`의 `serverToClientMapping`에 한 줄 추가하면 변환 완료.

**changelog 포맷 예시** (백엔드 → 프론트):
```
New notification type:
  - name: "pet_deleted"
  - audience: ["user"]
  - emit: services/pets_service.py:<line>
  - data keys: { "pet_idx": int, "deleted_by": "admin"|"user" }
  - title/body example: "반려동물이 삭제되었습니다" / "{pet_name} 기록이 제거되었습니다"
```

(`navigation payload` 항목은 deprecated. 신규 type 추가 시 포함 금지.)

### 알림 다중 수신 라우팅 (계약 확정 2026-04-28)

같은 `type`이라도 수신자(audience)가 여러 역할이면 **프론트가 `account_type`으로 분기**. 백엔드는 `type`을 분리하지 않음 (양측 dual-sync 부담 회피). 분기 위치는 [notification_service.dart](lib/services/notification_service.dart)의 `_navigateToXxx` 함수 내부, [PreferencesManager.getAccountType()](lib/utils/preferences_manager.dart)으로 조회.

**`donation_completed` (admin / hospital / user 3분기)**

| 수신자 | 발송 시점 | 본문 키 (`constants/messages.py`) | 도착 화면 |
|--------|----------|----------------------------------|----------|
| user (account_type=3) | 관리자 최종 승인 시 | `DONATION_COMPLETE_USER_BODY` | 본인 헌혈 이력 화면 |
| hospital (account_type=2) | 관리자 최종 승인 시 | `DONATION_COMPLETE_CONFIRM_BODY` | 게시글 신청자/완료 헌혈자 관리 화면 ([hospital_post_check.dart](lib/hospital/hospital_post_check.dart)) |
| admin (account_type=1) | 병원 1차 완료 처리 시 | `DONATION_COMPLETE_REPORT_BODY` | 헌혈 최종 승인 대기 목록 ([admin_donation_approval_page.dart](lib/admin/admin_donation_approval_page.dart)) |

**`new_donation_application` (admin only)**

백엔드 emit 사이트 3곳 모두 `send_notification_to_admins(...)` 사용 — `donation_apply_service.py`, `donation_apply_user_service.py`, `applied_donation/commands.py`. **hospital은 수신하지 않음**.

프론트 매핑 정리 (2026-04-28):
- `new_donation_application`의 `UserType.hospital` 라인 → 제거 (dead code)
- `new_donation_application_hospital` 매핑 → 전체 제거 (emit 사이트 0건)
- `donation_application` 매핑 → 전체 제거 (백엔드 enums.py에서도 함께 제거됨)

도착 화면: 관리자의 헌혈 신청 검토/관리 화면. data에 `post_idx`, `application_id` 포함되어 있어 추가 작업 불요.

### account 상태 알림 키 (계약 확정 2026-04-28)

`account_suspended`, `account_status_changed` 두 type의 data에 다음 키 포함 (백엔드 emit: `services/admin_users_service.py`의 `_send_suspension_notification`, `_send_status_change_notification`):

| 키 | 타입 | 값 |
|----|------|---|
| `new_status` | int | 0=PENDING, 1=ACTIVE, 2=SUSPENDED, 3=BLOCKED — `UserStatus` 미러 (CLAUDE.md "계정 상태" 섹션 동일) |
| `status_label` | string | `"pending"` / `"active"` / `"suspended"` / `"blocked"` (분기 가독성용, 영문 enum 라벨 lowercase) |

**프론트 분기 (옵션 d)** — 임팩트별 차등 처리:
- `new_status == 1` (ACTIVE) / `new_status == 0` (PENDING) → 대시보드 진입 + 상단 토스트로 상태 안내 (부드러운 처리)
- `new_status == 2` (SUSPENDED) / `new_status == 3` (BLOCKED) → 강제 모달 + 강제 로그아웃 (강한 처리)

이유: ACTIVE 복귀 알림과 정지/차단 알림은 임팩트가 달라 동일 처리 부적절. SUSPENDED/BLOCKED 상태에서는 어차피 다른 API가 403 반환하므로 모달+로그아웃이 자연스러움.

### 이미지 URL
- 백엔드는 **상대 경로**로 반환 (예: `/uploads/posts/abc.jpg`).
- 프론트는 `DonationPostImageService.getFullImageUrl()`이 `http`로 시작하지 않으면 `Config.serverUrl`을 prefix로 붙임. CDN 전환해서 절대 URL을 반환해도 안전.

### Nickname contract (계약 확정 2026-04-28)

`accounts.nickname`은 **DB NOT NULL** 컬럼이며 회원가입 시 백엔드가 자동 조합으로 채움. 형식: `{대표 펫}|{지역}|{입력별명}({성명})`. 예: `"초코|서울 강남|비타민(홍길동)"`. account_type 1/2/3 모두 동일.

**응답 보장 — 다음 4개 필드는 백엔드가 non-null 보장 (Pydantic schema-level enforcement)**

| Schema | 필드 |
|--------|------|
| `NoticeResponse` | `author_nickname` |
| `PublicNoticeResponse` | `author_nickname` |
| `HospitalColumnResponse` | `hospital_nickname` |
| `DonationPostWithHospitalResponse` | `hospital_nickname` |

→ 백엔드 e25f865에서 `Optional[str] = None` → `str` 좁힘 완료. 향후 누군가 None 응답을 만들면 Pydantic ValidationError로 즉시 차단됨.

**금지 사항**
- 백엔드는 `"닉네임 없음"`, `""` 같은 placeholder 문자열을 **절대 emit 안 함**. 코드베이스 전체 검색 0건 확인.
- 프론트는 `?? hospitalName` / `?? authorName` / `.toLowerCase() != '닉네임 없음'` 같은 fallback 로직 **불필요**. dead defensive code로 분류.

**프론트 사용 패턴**
위 4개 응답 필드 사용처에서는 nickname을 직접 노출:
```dart
authorName: column.authorNickname  // ✅ ?? fallback 없음
authorName: notice.authorNickname  // ✅ ?? fallback 없음
```

**예외 — 여전히 nullable 처리 필요한 2건**
다음은 위 contract에 포함되지 않으며 nullable 유지 필요:
1. **헌혈 history 응답** (`pet_donation_history_schema::hospital_nickname`) — 시스템 기록(completed_donation snapshot) 기반. 과거 삭제된 병원의 historical 기록은 NULL 가능
2. **`hospital_post_schema`의 nickname류 필드** (`hospital_nickname`, `user_nickname`, `nickname`) — 같은 schema의 다른 필드(`hospital_name`, `userName` 등)도 모두 Optional인 mixed-purpose schema. 단독 정정 위험

→ 위 2건에서 받는 nickname은 `?? fallback` 유지. NotificationModel/applied_donation 등 다른 응답에서 받는 nickname도 위 4개 응답 필드 contract와 별개이므로 응답 schema 재확인 후 결정.

**모델 nullability 정책 (프론트 측 결정)**
프론트 모델 클래스(`HospitalColumn`, `Notice`, `ColumnPost`, `NoticePost`)의 `authorNickname` 필드는 **현재도 `String?` 유지**. 백엔드가 NOT NULL 보장하더라도 fromJson 단에서 응답 누락 시 즉시 크래시되는 것보다는 nullable로 받고 호출부에서 직접 사용하는 패턴이 안전. 백엔드 응답이 1년간 안정적이면 추후 `String`으로 좁히는 라운드 별도 진행 가능.

### 회원가입 응답 펫 인덱스 contract (계약 확정)
이메일 가입(`POST /api/register`)과 네이버 온보딩(`POST /api/auth/onboarding`) **모두 동일 규약**. 가입 시 함께 받은 펫 사진을 가입 직후 `POST /api/pets/{pet_idx}/profile-image`로 multipart 자동 업로드하는 흐름의 기반.

**응답 스키마** (두 엔드포인트 공통)

| 필드 | 타입 | 설명 |
|------|------|------|
| `message` | string | 안내 메시지 |
| `account_idx` | int | 가입 직후 식별자 (토큰 발급 전 단계용) |
| `pet_idx` | int \| null | 대표 펫 idx. 펫 0마리면 null |
| `pet_idxs` | int[] \| null | 등록된 모든 펫의 idx 배열. 펫 0마리면 null |

**순서 보장 (절대 깨면 안 됨)**
요청 `pets[i]`와 응답 `pet_idxs[i]`는 **인덱스 1:1 일치**. 백엔드는 sequential `for` + `db.flush()` 패턴으로 채번하고 있으며, **`asyncio.gather` / `TaskGroup` 등 동시 실행 도입 금지** — silent reorder가 발생하면 사진이 다른 펫에 붙는 데이터 오염이 생김. 백엔드 리팩터 시 이 가드를 반드시 유지해야 함 (백엔드 측 CLAUDE.md에도 동일 contract 박제됨).

**프론트 사용 패턴**
프론트는 가입 폼에서 사용자가 선택한 펫 사진(`XFile?`)을 `RegistrationPetData`에 메모리로 보관 → 가입 응답 수신 후 인덱스 매칭으로 `pets[i]`의 사진을 `pet_idxs[i]`에 `POST /api/pets/{pet_idx}/profile-image`로 업로드. 사진 미선택 펫은 호출 스킵. 부분 실패(가입 OK / 사진 일부 실패) 시 "프로필 > 반려동물에서 다시 등록해주세요" 안내.

**펫 0마리 가입**
`pet_idx = null`, `pet_idxs = null`. 프론트는 `null`과 빈 배열 둘 다 방어 (향후 백엔드가 빈 배열로 바꿀 가능성 대비).

**호환성 메모**
`POST /api/register` 응답은 2026-04 이전까지 **빈 body**였음. 새 필드 추가는 순수 추가라 기존 코드 영향 없음 (프론트는 응답 body 미사용). status code 201 유지.

**가입 직후 access_token 정책 (계약 확정 2026-04-28)**

이메일/네이버 가입 흐름을 통일하기 위해 `POST /api/register` 응답에도 access_token이 포함됨. 사진 업로드 endpoint를 인증 후 호출할 수 있게 함이 목적.

| 필드 | 값 | 비고 |
|------|---|------|
| `access_token` | string (15분 유효) | 정식 로그인 토큰과 동일 만료시간. `lib/auth/login.dart`의 토큰과 같은 저장소(`PreferencesManager.setAuthToken`)에 저장 |
| `token_type` | `"bearer"` | |
| `refresh_token` | **미발급** | 미승인 상태에서 7일 세션은 부적절. 사진 업로드 후 만료시키고 승인 + 정식 로그인으로 재발급 |

**미승인 토큰의 권한 범위** (백엔드 `_get_own_pet()` ownership 검증):
- ✅ `POST /api/pets/{pet_idx}/profile-image` — 본인 소유 펫만
- ✅ `DELETE /api/pets/{pet_idx}/profile-image` — 본인 소유 펫만
- ❌ 그 외 모든 endpoint → 400 `UNAPPROVED_USER`로 차단 (`get_current_active_account` 가드 그대로)

**프론트 처리 (계약 확정)**:
- 가입 응답 수신 즉시 `setAuthToken(access_token)`만 저장 (`setRefreshToken` 호출 금지 — refresh_token 응답에 없음)
- `pet_idxs[i]` ↔ 폼의 `pets[i].profileImage` 매칭 루프로 `POST /api/pets/{pet_idx}/profile-image` 호출
- 업로드 종료 후 `PreferencesManager.clearAll()` — 토큰을 즉시 클리어해 다음 로그인 시점까지 정리. (백엔드는 "그대로 두고 만료" / "즉시 클리어" 둘 다 허용했지만 명시적 정리가 깔끔)
- 사진 업로드는 **PENDING 상태 펫이라 200 즉시 반영** — 검토 워크플로우 진입 안 함 (CLAUDE.md "펫 프로필 사진 검토 워크플로우" 섹션 참고)
- 부분 실패(가입 OK / 사진 일부 실패) 시 사용자에게 "프로필 > 반려동물에서 다시 등록해주세요" 안내 후 WelcomeScreen 진행. 펫 자체는 등록되어 있어 승인 후 재업로드 가능.

**호환성**: 기존 필드(`account_idx`, `pet_idx`, `pet_idxs`, `message`)는 그대로. 신규 필드 추가일 뿐이라 기존 코드 영향 없음.

### 펫 프로필 사진 검토 워크플로우 (계약 확정 2026-04-28)

APPROVED 펫의 프로필 사진 변경에 한해 관리자 검토를 거치는 2단계 플로우. PENDING/REJECTED 펫의 사진 변경은 즉시 반영(200)되고 검토 대상이 아님. [pet_model.dart](lib/models/pet_model.dart)의 `pendingProfileImage` / `pendingImageStatus` / `pendingImageRejectionReason` 3개 필드가 이 contract의 프론트 측 단일 원천.

**사용자 측 — 사진 업로드 응답 분기** (`POST /api/pets/{pet_idx}/profile-image`)

| 펫 상태 | status | 응답 body | 의미 |
|---------|--------|----------|------|
| APPROVED (`approval_status=1`) | **202** | `{message, pending_profile_image, profile_image?}` | 검토 대기 등록. 기존 `profile_image`는 그대로, `pending_profile_image`만 신규 |
| PENDING/REJECTED (`approval_status=0|2`) | **200** | `{message, profile_image}` | 즉시 반영, 검토 대기 없음 |

펫당 검토 슬롯은 **1개**. 사용자가 검토 중에 사진을 다시 올리면 이전 `pending_profile_image` 파일이 자동 삭제되고 새 사진으로 덮어쓰기. "낡은 pending" 개념 없음 → 동시성 409 없음.

**관리자 측 — 검토 API 3종**

| 메서드 | 경로 | 비고 |
|--------|------|------|
| GET | `/api/admin/pets/profile-images/pending` | query: `page`(≥1, default 1), `page_size`(1~50, default 20). search 미지원. 정렬은 `pet_idx desc` |
| POST | `/api/admin/pets/{pet_idx}/profile-image/approve` | body 없음. 200 응답: `{message, pet_idx, pet_name, profile_image}` |
| POST | `/api/admin/pets/{pet_idx}/profile-image/reject` | body: `{rejection_reason?: string}` (optional, snake_case 정확). 200 응답: `{message, pet_idx, pet_name, rejection_reason}` |

**목록 응답 스키마** (`GET .../pending`)

```json
{
  "pets": [
    {
      "pet_idx": 1,
      "name": "초코",
      "species": "강아지",
      "breed": "골든리트리버",
      "animal_type": 0,
      "profile_image": "/uploads/pet_profiles/.../current.jpg",
      "pending_profile_image": "/uploads/pet_profiles/.../new.jpg",
      "pending_image_status": 0,
      "owner": { "account_idx": 5, "name": "홍길동", "nickname": "...", "email": "..." }
    }
  ],
  "total_count": 1, "current_page": 1, "page_size": 20,
  "total_pages": 1, "has_next": false, "has_previous": false
}
```

- `profile_image`: **nullable** (가입 후 사진 없이 승인된 펫이 첫 사진 올린 경우 NULL).
- `pending_image_status`: 이 목록에서는 항상 **0**. 거절(2)은 즉시 정리되어 응답에 등장 안 함.
- `requested_at` 필드 **없음** — 정렬은 `pet_idx desc`.
- 빈 결과: `pets: []`, `total_count: 0` 보장 (null 불가).

**거절 시 DB 정리 정책**

거절 즉시:
- `pending_profile_image` 파일을 디스크에서 삭제
- `pending_profile_image` / `pending_image_status` / `pending_image_rejection_reason` **3개 컬럼 모두 NULL**로 정리
- 기존 `profile_image`는 변경 없이 유지

→ DB에 거절 사유는 보관되지 않음. 사유는 푸시 알림 body에만 들어감. 펫 상세 화면에서 사유를 보여주려면 알림 body 자체를 활용해야 함 (`pendingImageRejectionReason` 필드는 사실상 항상 NULL).

**푸시 알림 type/data**

| 시점 | type | data | 수신자 | body |
|------|------|------|--------|------|
| ~~사용자가 APPROVED 펫 사진 변경 (202 응답 후)~~ | ~~`pet_profile_image_review_request`~~ | — | — | **2026-05-06 폐기** — 아래 참조 |
| 관리자 승인 | `pet_profile_image_approved` | `{pet_idx}` | user | 정형 메시지 |
| 관리자 거절 | `pet_profile_image_rejected` | `{pet_idx}` | user | "반려동물 'X'의 새 프로필 사진이 거절되었습니다." (사유 있으면 ` 사유: {reason}` append). **`rejection_reason`은 data에 없음** — body 텍스트로만 전달 |

**2026-05-06 변경 (Issue #6 사진 업로드 알림 통합)** — 사진 업로드 시점에 발송하던 `pet_profile_image_review_request` 알림을 폐기. 사진은 여전히 `pending_profile_image`에 저장되지만 관리자 알림은 후속 `PUT /api/pets/{pet_idx}` 호출 시 `pet_review_request` 통합 알림으로 1회 발송. 사용자가 사진만 변경하고 PUT을 호출하지 않으면 검토 워크플로우 진입 안 됨 (pending 사진 그대로 대기).

**프론트 측 인지 강화** ([lib/user/pet_register.dart](lib/user/pet_register.dart)):
- 202 응답 SnackBar 메시지: 백엔드 `message` 필드를 단일 원천으로 사용 (프론트 fallback만 보유). 백엔드 카탈로그 `messages.py::PetProfileImageMsg.UPLOAD_SUCCESS_PENDING_REVIEW` 권장 텍스트: "사진이 변경되었습니다. '정보 수정' 버튼을 눌러야 관리자 검토가 요청됩니다."
- `_photoPendingReviewRequest` 플래그: 202 응답 수신 시 set, `_savePet` PUT 성공 시 클리어
- `PopScope.canPop=false` + `onPopInvokedWithResult` 콜백: 플래그 true 상태로 페이지 떠나려 하면 confirm 다이얼로그 ("사진 변경이 저장되지 않았습니다 / 계속 작성 / 나가기")

프론트 [notification_mapping.dart](lib/models/notification_mapping.dart)의 `serverToClientMapping`에서 `pet_profile_image_review_request` 매핑은 dead code 상태로 남아있을 수 있음. 백엔드 emit 0건이라 실제 silent degrade 없음. 다음 정리 라운드에서 함께 제거 가능.

**정보 수정 ↔ 사진 검토는 별개 결정 단위**

두 워크플로우는 서로 다른 컬럼을 사용하고 서로 다른 API로 처리됨.

| 워크플로우 | 식별 컬럼 | 결정 API |
|-----------|----------|---------|
| 정보 수정 (재심사 포함) | `approval_status`(0/1/2) + `previous_values` JSON | `POST /api/admin/pets/{idx}/approve` / `/reject` |
| 사진 검토 | `pending_profile_image` + `pending_image_status`(NULL/0) | `POST /api/admin/pets/{idx}/profile-image/approve` / `/reject` |

→ 정보는 승인하면서 사진은 거절하는 **분리 결정 가능**. 묶음 처리 단일 endpoint는 백엔드가 제공하지 않음. 프론트가 통합 카드 UI를 원하면 두 목록(`GET /api/admin/pets?status=0` + `GET .../profile-images/pending`)을 각각 호출해서 `pet_idx` 기준으로 merge한 뒤 카드 1개에 두 결정 버튼 세트를 같이 노출하는 방식으로 처리.

### Pet 모델 / 헌혈 자격 검증 contract (계약 확정 2026-04-28 Phase 1)

`pregnant` (bool) + `has_birth_experience` (bool) 두 필드를 폐기하고 `sex` + `pregnancy_birth_status` + `last_pregnancy_end_date` 3필드로 재구성. 헌혈 자격 검증 로직도 함께 변경.

**Pet 스키마 wire format** (백엔드 `schemas/pet_schema.py:82-86`)

| 필드 | 타입 | nullable | 비고 |
|------|------|----------|------|
| `sex` | int | **NO** (필수) | 0=FEMALE, 1=MALE. 모든 GET 응답에서 non-null 보장 |
| `pregnancy_birth_status` | int | **NO** (default 0) | 0=NONE, 1=PREGNANT, 2=POST_BIRTH |
| `last_pregnancy_end_date` | date \| null | YES | status=2일 때만 값 존재. `"YYYY-MM-DD"` 문자열 (birth_date / neutered_date와 동일 포맷) |

**제거된 필드** — 응답에서 더 이상 오지 않음. 프론트 모델에서도 제거:
- `pregnant` (bool)
- `has_birth_experience` (bool)

**적용 엔드포인트 (요청·응답 양방향)**
- `POST /api/pets`, `PUT /api/pets/{pet_idx}`, `GET /api/pets/me`, `PATCH /api/pets/donation-complete`
- `POST /api/register`, `POST /api/auth/onboarding`
- `GET /api/signup_management/pending-users` (응답 내 `pets[*]`)
- `GET /api/admin/pets*` (관리자 펫 관리 응답)

**자격 검증 변경** (백엔드 `services/donation_eligibility_service.py`)

| 항목 | 변경 |
|------|------|
| 강아지 체중 | 25kg → **20kg 단일 기준** (협의 zone 폐기) |
| 임신/출산 통합 | condition 키 `pregnant` + `birthExperience` → **`pregnancyBirth`** |
| 임신/출산 쿨다운 | 출산 후 **12개월** 미경과는 fail (강아지·고양이 공통) |
| 헌혈 간격 | 56일(8주) → **180일(6개월)** (강아지·고양이 공통, 백엔드 동기화 2026-04-29). 기준일은 admin 최종 승인 시점 (`prev_donation_date`) |
| 중성화 | `is_neutered=true`이면 **`neutered_date` 필수** (NULL이면 fail) |
| None 처리 | 모든 None 값은 **보수적으로 fail** (이전엔 일부 None 통과) |

`failed_conditions[*].reason` 필드 ("데이터 타입 → 헌혈 자격 거부 사유" 섹션 참조)는 `pregnancyBirth`에만 붙음. 백엔드 메시지 카탈로그는 `constants/messages.py::ELIGIBILITY_*`.

**프론트 자체 검증** ([lib/utils/donation_eligibility.dart](lib/utils/donation_eligibility.dart))

프론트는 사용자 안내용으로 자체 검증을 가짐 (백엔드와 이중 체크). **백엔드 로직과 1:1 동기화 필요** — 백엔드가 변경되면 프론트도 같은 결과를 내야 함. 협의 zone 필드(`consultWeightMinKg`/`consultWeightMaxKg`) 폐기, `_checkPregnant`/`_checkBirthExperience` 통합 → `_checkPregnancyBirth`, `_checkNeutered`의 `neuteredDate==null` 처리를 `needsConsultation` → `ineligible`로 변경.

**status=1 → status=2 전이는 사용자 수동** (CLAUDE.md "임신/출산 상태" 섹션 참조). 백엔드에 자동 전이 로직 없음.

**정보 수정 → 재심사 워크플로우 진입**

세 신규 필드(`sex`, `pregnancy_birth_status`, `last_pregnancy_end_date`) 모두 수정 시 재심사 진입(approval_status PENDING + previous_values 기록 + admin에게 `pet_review_request` 알림). 기존 정보 수정 워크플로우와 동일.

`previous_values` JSON에 `last_pregnancy_end_date`는 `"YYYY-MM-DD"` 문자열로 저장됨 (백엔드 `_normalize`가 date → str 변환). `sex` / `pregnancy_birth_status`는 int 그대로.

폼 안내 문구 권장: "정보 수정 시 관리자 재심사가 진행되어 일시적으로 헌혈 신청이 제한될 수 있습니다."

### Pet 컬럼 분리 정책 (계약 확정 2026-05 PR-1, Phase 2)

자격 검증 우회 차단 + 카페 정책 의료 정보 도입을 위해 Pet 테이블에 6개 컬럼 추가/변경. 백엔드 `pets` 테이블 + 프론트 [Pet 모델](lib/models/pet_model.dart) 양쪽 1:1 박제.

**헌혈 일자 컬럼 분리 (system vs user input)**

| 컬럼 | 타입 | 설명 | 요청 (POST/PUT) | 응답 |
|------|------|------|----------------|------|
| `prev_donation_date_system` | DATE \| null | admin 최종 승인 시점에 시스템이 자동 갱신 | **차단** (사용자 수정 불가) | 포함 |
| `prior_last_donation_date` | DATE \| null | 외부 헌혈 마지막 일자 (사용자 자기신고) | **차단** (2026-05-06부터 사용자 입력 불가) | 포함 (admin 보정용) |
| `prior_donation_count` | int (default 0, NOT NULL) | 외부 헌혈 누적 횟수 (사용자 자기신고) | **차단** (2026-05-06부터 사용자 입력 불가) | 포함 (admin 보정용) |

**2026-05-06 변경 (Issue #5 헌혈 이력 입력 차단)** — 백엔드가 `PetCreate` / `PetUpdate` 요청 스키마에서 `prior_donation_count`, `prior_last_donation_date` 두 필드를 제거. 영향 받는 엔드포인트: `POST /api/register`, `POST /api/auth/onboarding`, `POST /api/pets`, `PUT /api/pets/{pet_idx}`. 응답 (`PetResponse`) 에는 두 필드 유지 (관리자 수동 조회용). 자격 검증은 시스템 자동 갱신 컬럼만 기준으로 작동.

**프론트 작업 박제 (2026-05-06)**:
- `RegistrationPetData` (가입 폼) `priorLastDonationDate` / `priorDonationCount` 필드 + `toJson` 키 제거 ([lib/widgets/registration_pet_manager.dart](lib/widgets/registration_pet_manager.dart))
- `lib/user/pet_register.dart` (펫 추가/수정) 입력 필드 + petData 키 제거
- `lib/user/pet_management.dart` 헌혈 이력 "+ 추가" / 수정 / 삭제 시트 제거. 시스템 자동 기록 read-only 표시는 유지
- `lib/services/donation_history_service.dart` `addHistory` / `addHistoryBulk` / `updateHistory` / `deleteHistory` 4개 메서드 + `dart:convert` import 제거. `getHistory` (GET) 만 유지
- `lib/utils/api_endpoints.dart` `petDonationHistoryBulk` / `petDonationHistoryItem` 제거. `petDonationHistoryByPet` (GET) 만 유지
- `lib/models/donation_history_model.dart` `DonationHistoryCreateRequest` / `DonationHistoryUpdateRequest` 클래스 + `canEdit`/`canDelete` getter 제거
- `Pet` 모델 자체는 변경 없음 — 응답 fromJson + `effectiveLastDonationDate` getter 유지 (백엔드 응답에 두 필드 여전히 포함)

**자격 검증은 effective date로 비교** — `max(prev_donation_date_system, prior_last_donation_date)`. admin이 수동으로 `prior_last_donation_date`를 보정하면 system 값과 비교해 더 큰 값 사용 (180일 헌혈 간격 카운트). 백엔드 헬퍼 `utils/pet_helpers.py::get_effective_last_donation_date()` ↔ 프론트 [Pet.effectiveLastDonationDate](lib/models/pet_model.dart) getter 1:1 동기화.

**구버전 응답 호환** — `GET /api/hospital/post-times`의 `pet_prev_donation_date` 응답 필드명은 유지. 값은 effective date로 자동 변환되어 의료진 화면 호환 보장.

**헌혈 이력 응답 contract — 옵션 A (계약 확정 2026-05-07)**

`GET /api/pet-donation-history/{pet_idx}` 응답 의미:

| 필드 | 정의 |
|------|------|
| `histories` | system record만 (manual 입력은 2026-05-06 폐기) |
| `total_count` | `system_record_count + pet.prior_donation_count` (시스템 + 외부 합산) |
| `system_record_count` | 시스템 자동 기록 수 |
| `manual_record_count` | **항상 0** (deprecated, 모델 필드는 1년 안정 운영 후 제거 라운드) |
| `total_blood_volume_ml` | system만 합산 (외부 채혈량 정보 없음) |
| `last_donation_date` | `max(system 가장 최근, pet.prior_last_donation_date)` — effective date |
| `first_donation_date` | system만 (외부 첫 헌혈일 정보 없음) |
| `total_pages` | system 기록 list 기준 페이지 수 |

**백엔드 헬퍼**: `utils/donation_utils.py::record_donation_completion(application, db)` — 두 admin 최종 승인 흐름(`POST /api/admin/donation-final-approval` 시간대 일괄 / `POST /api/admin/completed-donations/approve-completion/{id}` 단건)이 모두 이 헬퍼로 통일. `pet.prev_donation_date_system` 갱신 + `pet_donation_history` INSERT를 한 번에 박제. 분기 비대칭 버그 (2026-05-07 #1) 영구 차단.

**프론트 측 박제**:
- 모델 [DonationHistoryResponse](lib/models/donation_history_model.dart) 변경 없음 — `totalCount`가 자동 합산값
- [pet_management.dart::_buildDonationHistorySection](lib/user/pet_management.dart) — `histories.isEmpty && totalCount > 0` 케이스(외부만 있는 펫)에 "외부 헌혈 N회 기록 — 이 앱을 통한 헌혈은 아직 없습니다" 안내 박스 추가. 시스템 기록 없는 외부 헌혈은 list row를 만들 수 없음 (병원명/채혈량 정보 부재)
- `manualRecordCount` 모델 필드는 응답에 항상 0이 와도 dead defensive 유지 (1년 후 제거 라운드)

**카페 정책 의료 정보 (3 컬럼 추가)**

| 컬럼 | 타입 | 카페 정책 |
|------|------|----------|
| `last_vaccination_date` | DATE \| null | 종합백신 24개월 이내 접종 필수 |
| `last_antibody_test_date` | DATE \| null | 백신 24개월 초과 시 항체검사 12개월 이내 필수 |
| `last_preventive_medication_date` | DATE \| null | 헌혈 예정일 3개월 전부터 예방약 복용 필수 |

**자격 검증 추가 reason 코드** ([lib/utils/donation_eligibility.dart](lib/utils/donation_eligibility.dart) `EligibilityReason` 상수)
- `vaccination_expired`: 백신 24개월 초과 + 항체검사 NULL
- `antibody_test_expired`: 백신 24개월 초과 + 항체검사 12개월 초과
- `preventive_medication_expired`: 예방약 3개월 초과

**자격 검증 상수 dual-sync** (백엔드 `constants/donation_eligibility.py` ↔ 프론트 `DonationEligibility` 클래스)
```dart
static const int vaccinationMaxMonths = 24;
static const int antibodyTestMaxMonths = 12;
static const int preventiveMedicationMaxMonths = 3;
```

**`monthsBetween` 헬퍼** — 캘린더 월 차이만 사용 (day 비교 없음). 백엔드 `_months_since_date` 미러:
```dart
static int monthsBetween(DateTime earlier, DateTime later) {
  return (later.year - earlier.year) * 12 + (later.month - earlier.month);
}
```

### 헌혈 완료 처리 contract (계약 확정 2026-04-29)

라이프사이클 단순화로 의료진 "중단" 액션 폐기. 의료진은 단일 "헌혈 완료" 처리 → admin이 'complete'로 최종 승인하는 **단방향 흐름**. AppliedDonationStatus는 0~4만 사용 ("신청 상태" 섹션 참조).

**의료진 1차 완료** (`POST /api/completed_donation/hospital_complete`)

- 단일 엔드포인트. 별도 cancel 엔드포인트 **없음**
- `blood_volume == 0` + `incompletion_reason` 조합으로 "채혈 못함" 케이스 표현
- 백엔드 검증: `blood_volume <= 0` 이고 `incompletion_reason` 비어있으면 → 400 + `ErrorMsg.INCOMPLETION_REASON_REQUIRED`
- 프론트 0L confirm 모달은 사유 입력 후 한 번 더 확인하는 형태 ([donation_completion_sheet.dart:_completeBloodDonation](lib/hospital/donation_completion_sheet.dart)). 백엔드 메시지 카탈로그 `ConfirmMsg.BLOOD_VOLUME_ZERO_HOSPITAL`는 참고용 (응답에 포함되지 않음, 프론트 직접 가짐)

**admin 최종 승인** (`POST /api/admin/donation_final_approval`)

- body: `{post_times_idx: int, action?: "complete"}`. `action` 필드 default `"complete"`이며 **미전송이 권장** (프론트 [admin_donation_approval_service.dart:finalApproval](lib/services/admin_donation_approval_service.dart)는 필드 자체를 보내지 않음)
- `action: "cancel"` 또는 그 외 값 전송 시 → 400 + `ErrorMsg.FINAL_APPROVAL_INVALID_ACTION`
- 정식 완료(`COMPLETED`, status=3) 처리 + `prev_donation_date` 갱신 (헌혈 간격 카운트 시작점)

**`prev_donation_date` 갱신 contract (계약 확정 2026-05-02 BE 검증)**

- **갱신 시점**: admin 최종 승인 (PENDING_COMPLETION → COMPLETED) 단계
- **0mL + 미채혈 사유 케이스도 동일하게 갱신** (admin이 'complete' 액션으로 승인하는 한). 채혈 실패 자체는 "헌혈 시도 인정"으로 처리되어 다음 헌혈 간격 180일이 그 시점부터 카운트됨
- **갱신 값**: 서버 KST(Asia/Seoul) 자정 — `combine_date_with_min_time(date.today())` 기준. DB는 MariaDB DATETIME naive (tzinfo 미부착). 예: `2026-05-02 00:00:00`
- **미래 날짜 보존 로직**: 이미 더 미래 날짜가 prev_donation_date에 있으면 덮어쓰지 않음 (`if today_dt > pet.prev_donation_date`)
- **응답 시리얼라이즈**: `format_date_safe()`로 `"YYYY-MM-DD"` 절단. 헌혈 간격 180일 비교는 내부 DateTime으로 처리되므로 응답 절단과 무관 (정확도 손실 없음)
- **수동 보정 경로** (`PATCH /api/pets/donation-complete`): 호출자가 보낸 `donation_date` 값을 **그대로 저장** (truncate 없음). 시드/이력 보정용이며 자동 흐름에는 영향 없음
- 헌혈 간격 정책 = `DONATION_INTERVAL_DAYS = 180` (강아지·고양이 공통)

**관련 응답 스키마 (2026-04-29 확정)**

`GET /api/admin/pending_donations?date=YYYY-MM-DD` — **시간대 grouping 응답** (option A 채택)

```json
{
  "pending_by_time_slot": [
    {
      "post_times_idx": 5,
      "donation_date": "2026-05-02",
      "donation_time": "14:00",
      "post_idx": 12,
      "post_title": "...",
      "hospital_name": "...",
      "pending_completions": 2,
      "applications": [
        {
          "applied_donation_idx": 1,
          "pet_name": "...", "pet_blood_type": "...",
          "owner_name": "...", "owner_phone": "...",
          "status": 2, "status_text": "완료대기",
          "blood_volume": 0.0,
          "incompletion_reason": "..."
        }
      ]
    }
  ]
}
```

- 시간대 단위 필드는 슬롯 레벨 (`donation_date`/`donation_time`/`post_times_idx`/`post_title`/`hospital_name`/`pending_completions`)
- 신청 단위 필드는 `applications[]` 안 (`applied_donation_idx`/`pet_*`/`owner_*`/`status*`/`blood_volume`/`incompletion_reason`)
- 시간 → 신청 ID 순 정렬
- 빈 배열 (`{"pending_by_time_slot": []}`) 보장 (null 불가)

`GET /api/admin/donation_approval_stats` 응답 키 (단수형 — **복수형 아님**):

| 키 | 타입 | 의미 |
|----|------|------|
| `today_pending_completion` | int | 오늘 완료 대기 |
| `total_pending_completion` | int | 전체 완료 대기 |
| `today_processed` | int | 오늘 처리 완료 |
| `total_processed` | int | 전체 처리 완료 |

→ ~~`today_pending_cancellation`~~ / ~~`total_pending_cancellation`~~ / ~~`week_stats`~~는 응답에 없음.

**`failed_conditions[*].message` 포맷 (2026-04-29 통일)**

`donationInterval` condition만 적용. 백엔드 `messages.py::ELIGIBILITY_INTERVAL_TOO_SHORT`:
```
{remaining}일 후 가능 (현재 {current}일 경과, 최소 {required}일 필요)
```

프론트 자체 검증([donation_eligibility.dart:_checkDonationInterval](lib/utils/donation_eligibility.dart))도 동일 포맷. 두 출처가 같은 톤으로 사용자에게 노출.

**프론트 동기화 (50e3543, bf44ca3 commit)**

- [admin_donation_approval_page.dart](lib/admin/admin_donation_approval_page.dart): "취소 승인" 버튼/통계 카드 제거, action 분기 제거
- [admin_donation_approval_service.dart](lib/services/admin_donation_approval_service.dart): `finalApproval`/`batchFinalApproval` action 파라미터 제거, `pendingCancellations`/`totalPendingCancellations`/`todayPendingCancellations` 응답 파싱 제거
- [post_type_badge.dart](lib/widgets/post_type_badge.dart): '중단대기'/'중단' 라벨 제거
- [hospital_post_check.dart:1430](lib/hospital/hospital_post_check.dart#L1430): 상태 칩 가드 `status <= 4`로 좁힘
- [admin_user_check_bottom_sheets.dart](lib/admin/admin_user_check_bottom_sheets.dart): statusColor switch에서 case 5/6/7 제거

**예외 — `app['cancelled']` 객체** ([admin_user_check_bottom_sheets.dart:_buildApplicationCard](lib/admin/admin_user_check_bottom_sheets.dart))

admin이 user 신청 이력을 조회할 때 status=4 (사용자 신청 취소) 케이스에 대한 `cancelled` 객체는 살아있음. 이 객체 내부의 `cancelled_reason`/`cancelled_subject_kr` 필드는 위 `PendingDonationResponse.cancelled_reason → incompletion_reason` 변경과 **다른 응답**이므로 그대로 유지.

### 헌혈 사전 정보 설문 시스템 (계약 확정 2026-05)

카페 운영진이 구글폼으로 받던 29개 항목 설문지를 앱에 통합. 신청은 가볍게 유지하고 **선정(APPROVED) 후 사전 설문 작성 필수화** (옵션 P). PR-1 ~ PR-5 통합 시스템.

**라이프사이클**
```
선정(APPROVED) → 설문 작성 가능
             → admin 검토 (옵션 a 자동 PATCH로 첫 GET 시 마킹)
             → 사용자 수정 → 옵션 A+C로 admin_reviewed_at NULL 복귀 + 재검토 알림
             → D-2 23:55 잠금 (donation_survey_lock_scheduler) → read-only
             → 미작성자는 status=CLOSED + 자동 종결 알림
헌혈일 D-1 09:00 → 일정 모니터링 알림 (USER + HOSPITAL + ADMIN)
```

**신규 테이블 3개**

| 테이블 | 용도 |
|--------|------|
| `donation_survey` | 설문 본문 (텍스트 4 + 펫 시점성 2 + 기타 3 + 직전 외부 헌혈 6 + 검토/잠금 메타) |
| `donation_consent` | 동의 5개 NOT NULL Boolean + `terms_version_at_consent` 박제 |
| `donation_survey_template` | 안내문 동적 편집용 (활성 1개만 보장) |

**API endpoint 9개**

| 메서드 | 경로 | 권한 | 비고 |
|--------|------|------|------|
| GET | `/api/donation-consent/items` | 인증 | guidance_html 마크다운 + items 5개 + version |
| GET | `/api/applied-donations/{id}/survey/template` | 본인 + APPROVED만 | 자동 채움 데이터, `prev_donation_source` 3-way |
| GET/POST/PATCH | `/api/applied-donations/{id}/survey` | 본인 + APPROVED만 | 1신청당 1설문 (409 가드), 잠금 후 PATCH 차단 |
| GET | `/api/admin/donation-surveys` | admin | 목록 + `pending_count` 배지 |
| GET | `/api/admin/donation-surveys/pending-count` | admin | 배지 전용 경량 |
| GET | `/api/admin/donation-surveys/{idx}` | admin | **첫 GET 시 옵션 a 자동 PATCH** |
| GET | `/api/admin/posts/{post_idx}/donation-surveys` | admin | 게시글 단위 일괄 |
| GET | `/api/hospital/posts/{post_idx}/donation-surveys` | hospital | WHERE 자동 필터 |
| GET | `/api/hospital/donation-surveys/{idx}` | hospital | `assert_hospital_owns_application` 가드 |

**다운로드 endpoint 4개 (PR-4)**

| 메서드 | 경로 | Content-Type |
|--------|------|--------------|
| GET | `/api/admin/donation-surveys/{idx}/pdf` | `application/pdf` |
| GET | `/api/admin/posts/{post_idx}/donation-surveys.xlsx` | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` |
| GET | `/api/hospital/donation-surveys/{idx}/pdf` | `application/pdf` |
| GET | `/api/hospital/posts/{post_idx}/donation-surveys.xlsx` | xlsx |

응답 헤더: `Content-Disposition: attachment; filename*=UTF-8''<percent-encoded 한글>` (RFC 5987). 한글 파일명 예: `헌혈견설문_홍길동_초코_2026-05-20.pdf`. 백엔드는 'Noto Sans CJK KR' 폰트 임베드.

**프론트 다운로드 처리** ([lib/services/donation_survey_download_service.dart](lib/services/donation_survey_download_service.dart))
- RFC 5987 파일명 수동 percent-decode (`http` 패키지는 자동 디코드 안 함)
- 모바일: [file_download_helper_io.dart](lib/services/file_download_helper_io.dart) — `path_provider` 임시 디렉토리 + `OpenFilex` 시스템 viewer
- 웹: [file_download_helper_web.dart](lib/services/file_download_helper_web.dart) — `dart:html` Blob + anchor download
- conditional import: `dart:html` → `dart:io` → stub

**권한 격리 4패턴 (계약 확정)**

| 패턴 | 가드 |
|------|------|
| 단건 조회/다운로드 (admin) | account_type==1 검증 |
| 단건 조회/다운로드 (hospital) | `assert_hospital_owns_application()` 헬퍼 → 403 |
| 목록 조회 (hospital) | `WHERE post.hospital_idx = current.hospital_idx` 자동 필터 |
| 게시글 일괄 다운로드 (hospital) | `assert_hospital_owns_post` 헬퍼 → 403 |

**옵션 P 설문 필수 정책**
- APPROVED 신청은 D-2 23:55까지 설문 작성 필수
- 미작성자는 자동 status=CLOSED(4) + `donation_application_auto_closed` 푸시 (USER)
- 작성자는 `survey.locked_at` 설정으로 read-only 전환 (PATCH 400 SURVEY_LOCKED)

**옵션 A+C 알림 정책 (`donation_survey_submitted`)**
- 첫 제출 → ADMIN 알림 (`is_resubmission=false`)
- admin **미열람** 상태에서 사용자 수정 → 알림 X (어차피 admin이 안 봤음)
- admin **열람 후** 사용자 수정 → `admin_reviewed_at` NULL 복귀 + ADMIN 알림 (`is_resubmission=true`, 재검토 요청)

**옵션 a 자동 PATCH (admin 단건 GET)**
- 첫 GET 시: `admin_reviewed_at = NOW + admin_reviewed_by = current.account_idx` 자동 설정
- 두 번째 이후 GET: read-only (트랜잭션 부담 최소화)
- 이후 사용자가 PATCH로 수정하면 위 옵션 A+C로 NULL 복귀 + 재검토 알림

**프론트 dual-sync 박제 위치**
- 모델: [lib/models/donation_consent_model.dart](lib/models/donation_consent_model.dart) / [lib/models/donation_survey_model.dart](lib/models/donation_survey_model.dart)
- 서비스: [lib/services/donation_survey_service.dart](lib/services/donation_survey_service.dart) (사용자/admin/hospital wrapper) + [donation_survey_download_service.dart](lib/services/donation_survey_download_service.dart)
- 사용자 화면: [donation_survey_form_page.dart](lib/user/donation_survey_form_page.dart) (작성/수정/잠금 단일 페이지, IgnorePointer + AppBar "(조회)" 자동 분기)
- admin 화면: [admin_donation_survey_list.dart](lib/admin/admin_donation_survey_list.dart) + [admin_donation_survey_detail.dart](lib/admin/admin_donation_survey_detail.dart)
- hospital 화면: [hospital_donation_survey_list.dart](lib/hospital/hospital_donation_survey_list.dart) + [hospital_donation_survey_detail.dart](lib/hospital/hospital_donation_survey_detail.dart)
- 진입점: [my_applications_screen.dart](lib/user/my_applications_screen.dart) (사용자 APPROVED 카드) + [hospital_post_check.dart](lib/hospital/hospital_post_check.dart) (게시글 시트 헤더)

**Deferred Work**
- 안내문 템플릿 CRUD 화면 (admin) — 백엔드 PR-3에 endpoint 5개 있음. 운영진이 카페 안내문 직접 등록 화면은 별도 라운드
- admin dashboard 알림 영역에 "검토 대기 N건" 카드 (`pending_count` 활용)
- AdminPostCheck에서 게시글 단위 Excel 일괄 다운로드 직접 진입점 (현재는 admin survey list에서 post_idx 필터 후 다운로드)
- `admin_reviewed_at` 다중 admin 동시 진입 시 row lock(SELECT FOR UPDATE) — first wins 의미 강화
- 동의 텍스트 옵션 B (관리자 편집 테이블) — 현재 옵션 A (`messages.py` 박제) 사용

### donation_survey_lock_scheduler (APScheduler 4번째)

백엔드 `services/donation_survey_lock_scheduler.py` (2026-05 PR-5 신규). 매일 23:55 cron.

**잠금 cron 동작 (D-2 23:55)**

로직 (scheduler:74-78, 97-145):
1. `today = datetime.now().date()` → `target_date = today + timedelta(days=2)` → 헌혈일 == target_date인 APPROVED 신청 조회 (단순 캘린더 계산, 시각 비교 X)
2. 작성된 설문 → `survey.locked_at = NOW()` 설정, **잠금 알림 별도 발송 X** (FE에서 `is_locked=true` 응답 보고 UI 잠금)
3. 미작성자 → `applied_donation.status = CLOSED(4)` + `donation_application_auto_closed` 푸시 즉시 발송

**Timezone (계약 확정 2026-05 PR-5 BE 검증)**

- "23:55"는 **서버 로컬 시간 (KST 환경 가정)**. APScheduler `AsyncIOScheduler()`를 timezone 인자 없이 생성 → default `tzlocal()` = 시스템 OS timezone
- `datetime.now()`도 naive (tzinfo 미부착). 운영 머신 OS TZ가 `Asia/Seoul`이 아니면 24시간 - 오프셋만큼 어긋남
- **운영 머신 TZ가 Asia/Seoul인 게 전제**. 헌혈 완료 처리 contract와 동일 가정

**사전 알림 (D-2 09:00 pre-lock reminder)**

`reminder_scheduler::send_survey_pre_lock_reminders`:
- 미작성자에게만 "오늘 자정까지 작성 안 하면 자동 종결" 푸시 (`donation_survey_pre_lock_reminder`)
- D-2 09:00 → 잠금 23:55까지 **약 14시간 55분 전** 사전 알림
- 같은 D-2 09:00에 일반 `donation_reminder`도 돌지만 `filled_survey_only=True`로 작성자만 받음 → 미작성자/작성자 분기 + 중복 방지 (reminder_scheduler:166-177)

**잠금 후 사용자 수정 시도**

`services/donation_survey_service.py:374-376`:
```python
if survey.locked_at is not None:
    raise HTTPException(400, detail=ErrorMsg.SURVEY_LOCKED)
```
- 응답 메시지 (`constants/messages.py:304`): `"헌혈 전날 자정 이후로는 설문을 수정할 수 없습니다."`
- ⚠️ **메시지 카피와 실제 정책 불일치**: 메시지는 "전날 자정" (D-1 00:00 뉘앙스), 실제는 D-2 23:55. 정책 정렬 시 메시지도 같이 수정 필요

**자동 종결 트랜잭션 패턴 (주의)**

```python
async with AsyncSessionLocal() as db:
    for applied in applications:
        applied.status = CLOSED  # in-memory 변경
        await notification_service.send_notification_to_account(...)  # 내부에서 db.commit()
    await db.commit()  # 마지막 일괄 commit
```
`send_notification_to_account`가 내부에서 `db.commit()` 호출 → 첫 알림 발송 시점에 그때까지 변경된 `applied.status = CLOSED`가 함께 commit됨. **all-or-nothing 트랜잭션 아니라 "순차 commit"**. 알림 도중 에러 시 이미 CLOSED된 신청은 롤백 안 됨.

**자동 종결 vs 수동 종결 구분 라벨 — 없음**

DB에 `closed_reason` 같은 구분 컬럼 없음. 둘 다 `status=CLOSED(4)`로만 표시. admin 화면에서 "사전 설문 미작성으로 자동 종결" 라벨 표시 불가. 알림 type (`donation_application_auto_closed`)으로 사용자 채널만 구분.

**Deferred Work (운영 갭, PR-5 후속 검토 대상)**

| 갭 | 현황 | 우회 |
|----|------|------|
| 헌혈일 변경 시 잠금 재계산 | hook 미구현 — 이미 잠긴 신청은 헌혈일 옮겨도 풀리지 않음 | 수동 SQL `UPDATE donation_survey SET locked_at=NULL WHERE ...` |
| admin 수동 unlock endpoint | 미구현 (코드 검색 0건) | 직접 DB UPDATE만 가능 (위험) |
| 자동/수동 종결 구분 라벨 | DB 컬럼/플래그 없음 | 추가 컬럼 (예: `closed_reason` enum) 필요 |
| 메시지 카피 정렬 | "헌혈 전날 자정" 메시지 vs D-2 23:55 정책 | `constants/messages.py:304` 정정 또는 정책 변경 |

**튜토리얼/사용자 안내 카피 작성 시 주의**

- ✅ "D-2 23:55까지 사전 설문 미작성 시 자동 종결" — 코드 동작과 일치
- ❌ "헌혈일이 변경되면 잠금이 자동 재계산됩니다" — 미구현
- ❌ "관리자에게 문의하면 잠금을 풀 수 있어요" — endpoint 없음, 수동 SQL만 가능

**전체 헌혈일 알림 타임라인 (BE 검증 2026-05 PR-5)**

5개 cron이 매일 돌면서 각자 자기 target_date(X)에 해당하는 신청만 처리. 헌혈일 = X 기준:

| 시점 | cron | 대상 | 발송 내용 |
|------|------|------|----------|
| **X-2 09:00** | `donation_reminder_d2` | 보호자 (작성자) | 정기 D-2 리마인드 + 병원/날짜/시간/주소 |
| **X-2 09:00** | `donation_survey_pre_lock_reminder` | 보호자 (미작성자만) | "오늘 자정(23:55)까지 작성 안 하면 자동 종결" 경고 |
| **X-2 23:55** | `donation_survey_lock_d2` | 보호자 (미작성자) | 자동 종결 안내 (`donation_application_auto_closed`) |
| **X-2 23:55** | `donation_survey_lock_d2` | 보호자 (작성자) | 알림 X. `survey.locked_at` 설정 → read-only |
| **X-1 09:00** | `donation_reminder_d1` | 보호자 (작성자) | "내일 헌혈 안내. 사전 설문 작성 감사" |
| **X-1 09:00** | `donation_reminder_d1` | 병원 (게시글당 1회) | "내일 '{title}' — 신청자 {N}명" |
| **X-1 09:00** | `donation_reminder_d1` | admin 전원 (게시글당 1회) | "내일 '{title}' 모니터링" |
| **X 09:00** | `donation_reminder_dday` | 보호자 | "오늘 헌혈 예정일입니다!" |

**보호자 알림 시퀀스 정리**

작성자: X-2 09:00 D-2 리마인드 → X-1 09:00 D-1 안내 → X 09:00 D-Day
미작성자 (정상): X-2 09:00 pre_lock 경고 → X-2 23:55 자동 종결 → 종료 (X-1/X 알림 안 옴)

**병원/관리자 알림**
- X-1 09:00 단 한 번 (D-2/D-Day 시점에는 사용자만 알림)
- 병원: 게시글당 1회 (시간대 여러 개여도 게시글 단위 묶음). `신청자 N명`은 그 게시글 모든 시간대 APPROVED 합계
- 관리자: 게시글당 모든 admin에게 발송. admin 3명 × 게시글 2개 = 6건

**Deferred Work 추가 — X-2 23:55 lock cron 실패 시 회복 경로 없음**

D-1 reminder 코드는 `status=APPROVED` 필터만 걸어 이론상 미작성자도 잡힘. 정상 흐름에선 D-2 23:55 lock으로 미작성자가 CLOSED 전환되어 D-1 09:00에는 0건이지만, lock cron이 실패한 경우(서버 다운 / DB 에러):

- D-1 09:00에 미작성자가 받는 멘트: `"내일 ... 헌혈 예정. 사전 설문 미작성. 오늘 23:55까지 작성 부탁"` — 그러나 lock cron은 D-2 23:55에만 도므로 **D-1 23:55에 잠금이 안 도는 갭**.
- 결과: 사용자가 D-1에 작성해도 잠기지 않고, 자동 종결도 안 되고, 헌혈 당일까지 미작성 상태 → admin/병원이 수동으로 처리해야 함.
- 정책적 회복 경로 미구현. retry cron 또는 lock cron 실패 모니터링 별도 필요.

**메시지 카피 미스매치 종합 (정책 정렬 시 일괄 수정 권고)**

| 위치 | 현재 카피 | 실제 동작 | 권고 |
|------|----------|----------|------|
| `pre_lock_reminder` 본문 | "오늘 자정(23:55)까지" | D-2 09:00 발송 → 같은 날 23:55 lock | ✅ 정확 |
| D-1 unfilled reminder | "오늘 23:55까지" | D-1 23:55에 lock cron 안 돔 (D-2만) | ❌ 의미 어긋남 — 정책 결정 필요 |
| `SURVEY_LOCKED` 응답 (`messages.py:304`) | "헌혈 전날 자정 이후로는" | D-2 23:55 잠금 | "이틀 전" 또는 "헌혈 D-2 23:55"로 정정 |

**튜토리얼 안내 멘트 작성 가이드 (보호자 대상)**

> 헌혈 일정이 확정되면 다음 알림을 받습니다:
> - 헌혈 2일 전 오전 9시 — 사전 설문 미작성 시 "오늘 자정(23:55)까지 작성하세요" 경고
> - 헌혈 2일 전 23:55 — 미작성 시 신청 자동 종결 (이후 작성 불가)
> - 헌혈 전날 오전 9시 — 작성 완료자에게 "내일 헌혈 안내"
> - 헌혈 당일 오전 9시 — "오늘 헌혈 예정일입니다"
> 
> 사전 설문은 헌혈 2일 전 23:55까지 반드시 완료. 그 이후엔 수정/작성 모두 불가.

### 게시글 라이프사이클 정책 변경 (계약 확정 2026-05 PR-1)

**REJECTED hard delete + WAIT 가드**

기존 `PostStatus.REJECTED(2)` 상태 행 보존을 폐기하고 거절 시 hard delete로 변경. enum 자체는 유지(호환성), 단 사용처 0건.

```python
async def reject_post(post_idx, reason):
    post = await get_post_or_404(post_idx)
    if post.status != PostStatus.WAIT:
        raise HTTPException(400, "WAIT 상태가 아닌 게시글은 거절할 수 없습니다")
    await send_rejection_notification(...)  # DB 삭제 전 발송
    await db.delete(post)  # cascade로 dates/times/applied/images 자동 정리
    await db.commit()
```

**FK ondelete=CASCADE 추가** (PR-1)
- `donation_post_dates.post_idx → donation_posts.post_idx`
- `emergency_donation_post.post_idx → donation_posts.post_idx`
- `donation_post_image`은 이미 CASCADE 명시됨
- **`donation_post_times.post_dates_idx → donation_post_dates.post_dates_id`** (2026-05-07 추가, alembic `5d91455c0c88`)

**거절 시 cascade 체인 완성** (2026-05-07): 거절 = `db.delete(post)` 후 `db.commit()` 패턴이 자식 collection을 lazy-load 안 한 상태에서 호출되므로 ORM cascade만으로는 부족. DB-level FK ondelete=CASCADE + ORM `cascade='all, delete-orphan', passive_deletes=True` 둘 다 박제. donation_posts → donation_post_dates → donation_post_times 3단 cascade 완성. 이전(2026-05-06 PR-1)에 손자 단계 누락으로 IntegrityError 발생하던 버그 해소.

**PUT 가드 정책 (admin 전용)** — `PUT /api/admin/posts/{idx}/edit`

| status | admin 수정 | 근거 |
|--------|-----------|------|
| WAIT (0) | ✅ 허용 | 검토 중 보완 |
| APPROVED (1) | ✅ 허용 | 미세 수정 + 시간대 |
| REJECTED (2) | N/A | hard delete로 도달 안 함 |
| CLOSED (3) | ✅ 허용 (2026-05 변경) | 마감 풀고 모집 재개 시 시간대 추가 |
| COMPLETED (4) | ❌ 차단 | 종결 |
| SUSPENDED (5) | ❌ 차단 | 활성화 전환 후 수정 |

```python
BLOCKED_STATUSES_FOR_EDIT = {PostStatus.COMPLETED, PostStatus.SUSPENDED}
```

병원 측은 게시글 수정 화면 자체 없음 (이미 admin 전용).

**donation-dates 엔드포인트 폐기 이력 (PR-0)**

`PUT/DELETE /api/donation-dates/{id}` 엔드포인트 제거됨. 시간대 변경은 admin의 `PUT /api/admin/posts/{idx}/edit`로 통합. 프론트 [hospital_donation_date_management.dart](lib/hospital/hospital_donation_date_management.dart) dead code 삭제 완료.

**hospital 모집대기 탭 필터 + 뱃지 (계약 확정 2026-05-06)**

[hospital_pending_posts_tab.dart:_filteredPosts](lib/hospital/hospital_pending_posts_tab.dart) 는 `status == 0 || status == 5` 두 상태를 모두 모집대기 탭에 노출. 의미:
- `WAIT (0)`: 등록 직후 관리자 검토 대기
- `SUSPENDED (5)`: 관리자가 모집중 → 대기로 전환

병원 사용자 입장에서는 둘 다 "내 게시글이 보류된 상태"로 동일하게 인식되므로 한 탭에 묶음. 백엔드 `GET /api/hospital/posts`는 status 필터 없이 모든 게시글 반환하므로 필터링은 클라이언트에서 처리. 응답에 두 상태가 모두 포함됨이 보장.

**뱃지 표시** — PostListRow의 `badgeType` 결정 로직은 `admin_pending_posts_tab._getPostType`과 동일:
- status==5 → `'대기'` (purple — PostTypeBadge 색상 매핑)
- 그 외 → `post.isUrgent ? '긴급' : '정기'`

[PostTypeBadge](lib/widgets/post_type_badge.dart)는 '긴급'/'정기'/'대기'/'마감'/'완료'/'완료대기'/'거절'/'진행' type을 모두 단일 위젯에서 색상 매핑. status==0(WAIT) 게시글은 일반 긴급/정기 뱃지가 노출되며 탭 이름 자체가 "모집대기"라 별도 라벨 불필요.

**admin 승인/거절 핸들러의 404 처리 (계약 확정 2026-05-06)**

[admin_post_check.dart::approvePost](lib/admin/admin_post_check.dart) / [admin_post_management_page.dart::_approvePost](lib/admin/admin_post_management_page.dart) 는 `PUT /api/admin/posts/{idx}/approval` 응답이 **404**일 때 "이미 삭제된 게시글입니다. 목록을 갱신합니다." SnackBar + 자동 `_fetchDataForCurrentTab()` / `_loadPosts()` 호출로 stale 항목 제거. 사용자 경합(병원이 WAIT 상태에서 게시글 삭제 → 관리자가 그 사이 승인 시도) 케이스 대응. 백엔드는 `services/admin_post_service.py::approve_reject_post_service`에서 정상 404 raise (`POST_NOT_FOUND`).

**옵션 B 향후 검토**: WebSocket / polling 기반 admin 화면 실시간 동기화. 현재 옵션 A(404 시 1회 refetch)로 처리. 운영 안정 후 사용자 트래픽 보고 도입 결정.

**알림 진입 시 status별 자동 탭 전환 (계약 확정 2026-05-06)**

[hospital_post_check.dart::_statusToTabIndex](lib/hospital/hospital_post_check.dart) — 알림 클릭으로 `initialPostIdx`가 전달되면 PostFrameCallback에서 단건 fetch 후 `post.status` 기반으로 적절한 탭을 `_tabController.animateTo()`로 활성화한 다음 시트 자동 오픈. 매핑:

| status | 탭 인덱스 | 탭 이름 |
|--------|----------|---------|
| 0 (WAIT) / 5 (SUSPENDED) | 0 | 모집대기 |
| 1 (APPROVED) | 1 | 헌혈모집 |
| 3 (CLOSED) | 2 | 모집마감 |
| 4 (COMPLETED) | 3 | 헌혈완료 |

이전엔 `initialPostIdx`만 전달하고 default 탭(0=모집대기)에 머물렀음 — `donation_post_approved` 알림(status=1) 클릭 시 헌혈모집 탭으로 자동 이동되지 않던 버그(2026-05-06 #6) 수정. 알림 발송 시점과 사용자 진입 시점 사이에 status가 바뀌어도 진입 시점의 status로 판단하므로 정확.

**알림 라우팅 fallback 로그 (계약 확정 2026-05-06)**

[notification_service.dart::dispatchByType](lib/services/notification_service.dart)의 default case가 매핑 누락 type을 dashboard로 보내기 전 `debugPrint` 로그 출력. systemNotice류(`broadcast`/`general`/`admin_alert`/`hospital_alert`)는 의도된 fallback이지만 매핑 누락 신규 type 진단 시 `[NotificationService] dispatchByType fallback to dashboard (unmapped type="...", data=...)` 로그를 보고 dual-sync 누락 단계(CLAUDE.md "알림 타입 추가 시 dual-sync contract")를 추적.

**알림 진입 시 게시글 fetch 실패 사용자 안내 (계약 확정 2026-05-07)**

알림 클릭 → 단건 fetch → 시트 자동 오픈 흐름의 양 측 진단 강화:

| 영역 | 위치 | 처리 |
|------|------|------|
| USER 새 게시글 알림 (`new_donation_post`) | [user_donation_posts_list.dart::_showPostDetailById](lib/user/user_donation_posts_list.dart) | `getDonationPostDetail` null → "찾을 수 없거나 더 이상 공개되지 않습니다" SnackBar / catch → "게시글 불러오기 실패. 새로고침해주세요" + debugPrint |
| HOSPITAL 게시글 알림 (`donation_post_approved` 등) | [hospital_post_check.dart](lib/hospital/hospital_post_check.dart) initState | `getPostByIdx` null → "이미 처리되었거나 권한이 없습니다" SnackBar / catch → "게시글 불러오기 실패" + debugPrint |
| 알림 핸들러 자체 | [notification_service.dart::_navigateToNewDonationPost](lib/services/notification_service.dart) | post_idx 추출 실패 시 `[NotificationService] new_donation_post post_idx 추출 실패. data=...` debugPrint (FCM 키 컨벤션 미스매치 감지) |

이전엔 fetch 실패 시 silent — 사용자가 화면 진입은 했는데 시트가 안 떠서 "안 열림"으로 인식되던 경합. 이제 모든 실패 경로에서 사용자에게 명시적 SnackBar + 개발자 콘솔에 debugPrint.

**ADMIN 게시글 알림 라우팅 (계약 확정 2026-05-07)**

`new_post_approval` (모집대기 게시글 승인 요청, status=WAIT) 알림 처리:

- **변경 전**: [notification_service.dart::_navigateToPostManagement](lib/services/notification_service.dart)가 named route `/admin/post-management` 사용 → [AdminPostManagementPage](lib/admin/admin_post_management_page.dart)로 이동. 그러나 admin_dashboard는 [AdminPostCheck](lib/admin/admin_post_check.dart)를 entry로 사용 → 두 화면이 분리되어 알림 클릭 시 자동 시트 오픈 미작동
- **변경 후**: named route 폐기. `Navigator.push(MaterialPageRoute(builder: AdminPostCheck(initialPostIdx, initialTabIndex: 0)))`로 직접 push. admin_dashboard 진입과 동일한 화면

**AdminPostCheck initialPostIdx 자동 시트 오픈 — tab 0/1 둘 다 지원**

[admin_post_check.dart::_autoOpenInitialPostSheet](lib/admin/admin_post_check.dart) — 백엔드에 admin 단건 fetch endpoint 없어서 각 탭의 fetched 리스트에서 post_idx 매칭. tab별 매핑:

| initialTabIndex | 탭 | 사용 key | 알림 type |
|-----------------|-----|---------|----------|
| 0 | 모집대기 | `_pendingTabKey.currentState.posts` | `new_post_approval` (WAIT/SUSPENDED) |
| 1 | 헌혈모집 | `_activeTabKey.currentState.allPosts` | `new_donation_application` (APPROVED/CLOSED) |
| 2~3 | 모집마감/헌혈완료 | 미지원 | (필요 시 추후 확장) |

매칭 실패 시 "게시글을 찾을 수 없습니다 (이미 처리되었거나 다른 탭으로 이동)" SnackBar.

**refresh await 누락 패턴 주의 (2026-05-07 #1 수정)**

```dart
// ❌ 단축형 — Future<Future<void>?>를 반환해 외부 Future만 await됨.
//    refresh의 fetch는 await 안 되어 빈 list로 매칭 시도.
refresh = () async => _pendingTabKey.currentState?.refresh();

// ✅ 명시 await 블록.
refresh = () async {
  await _pendingTabKey.currentState?.refresh();
};
```

자식 mount 직후엔 `currentState == null` race condition 가능. PostFrameCallback이 자식 initState보다 먼저 실행되는 경우 50ms 대기 후 재시도하는 방어 로직 추가됨. 알림 진입은 1회성이라 이 비용 무시 가능.

**알림 클릭 읽음 처리 — 낙관적 업데이트 (계약 확정 2026-05-07)**

[notification_provider.dart::markAsRead](lib/providers/notification_provider.dart) — 사용자가 알림 탭 시 navigation으로 화면을 떠나도 read 상태가 보장되도록 낙관적 업데이트 패턴:

```dart
// 1. 로컬 상태 즉시 업데이트 (notifyListeners)
// 2. 서버 반영 (실패해도 로컬은 read 유지)
```

이전엔 `await NotificationApiService.markAsRead` 응답 후에 로컬 업데이트 → API 늦거나 실패 시 알림 페이지에 read 표시 안 됨. 사용자가 알림 일부만 파란 배경 사라지는 일관성 문제 보고 (2026-05-07). 또한 `notification_id <= 0` 케이스(broadcast 류 server PK 없음)는 로컬 read 처리 후 API 호출 스킵.

### 공지사항(Notice) 정책 (계약 확정 2026-04-28)

운영 정책 변경: 활성/비활성 토글 워크플로우를 폐기하고 "잘못 작성된 공지는 수정 또는 삭제로 처리"하는 정책으로 단순화. 사용자 전용 공지(USER_ONLY)도 운영상 의미가 없어 폐기.

**target_audience enum** (백엔드 `constants/enums.py::NoticeTargetAudience` 미러)

| 값 | 이름 | 비고 |
|---|------|------|
| 0 | ALL (전체) | 모든 사용자에게 노출 |
| 1 | ADMIN_ONLY (관리자) | |
| 2 | HOSPITAL_ONLY (병원) | |
| 3 | ~~USER_ONLY (사용자)~~ | **deprecated 2026-04-28**. 신규 입력 차단(400). DB 0건. enum 미러링 자리만 점유 |

값 재번호 금지 — `noticeTargetUser=3`은 [app_constants.dart](lib/utils/app_constants.dart)에 `@Deprecated` 어노테이션과 함께 자리 점유 중.

**신규 입력 차단** (`POST /api/notices/`, `PUT /api/notices/{notice_idx}`)
- `target_audience=3` 입력 시 **400 응답**
- 응답 본문: `{"detail": "사용자 전용 공지는 더 이상 작성할 수 없습니다. 다른 공지 유형을 선택해주세요."}`
- 메시지 키: `ErrorMsg.NOTICE_TARGET_USER_DEPRECATED`
- 프론트 [admin_notice_create.dart](lib/admin/admin_notice_create.dart)에서 라디오 옵션을 노출 안 하므로 정상 사용 시 도달 불가. API 직접 호출 방어용.

**중요 ↔ 대상 상호 배타 (프론트만 검증)**
- `notice_important=1`(중요)과 `target_audience IN (1, 2)`(관리자/병원)는 동시 선택 불가
- [admin_notice_create.dart](lib/admin/admin_notice_create.dart)에서 양방향 비활성화로 UI 차단 (중요 체크 시 관리자/병원 라디오 disabled, 관리자/병원 선택 시 중요 체크박스 disabled)
- **백엔드 검증 없음**. API 직접 호출 시 충돌 데이터 작성 가능 — 서버 검증 추가는 별도 보안 라운드로 분리 (필요 시 백엔드에 요청)

**대상별 권한 가시성**
백엔드의 dead-branch 정리(2026-04-28)로 사용자/비로그인 화면은 ALL(0)만 응답되도록 분기 정리됨. 단, 명시적 서버 측 권한 필터링은 아직 미적용:

| 호출자 | 보이는 공지 |
|--------|-------------|
| 비로그인 / 사용자 (account_type=3) | ALL(0)만 |
| 병원 (account_type=2) | ALL(0) + HOSPITAL_ONLY(2) — 클라이언트 필터링 |
| 관리자 (account_type=1) | 모두 |

→ 사용자가 API 직접 호출 시 권한 외 공지가 응답에 포함될 가능성 (admin/hospital 엔드포인트). 서버 측 `account_type` 기반 자동 필터링은 별도 보안 라운드로 분리 (필요 시 백엔드에 요청).

**비활성화 토글 폐기**
- `PATCH /api/notices/{notice_idx}/toggle` 엔드포인트 **삭제됨** (구버전 빌드 호출 시 404)
- `notice_active` DB 컬럼은 유지하지만 항상 `true` (DB default). 마이그레이션 미진행
- 프론트의 `NoticeService.toggleNoticeActive` 메서드도 제거됨

**리스트 행 제목 색상 매핑** (UI 정책, [notice_styling.dart](lib/widgets/post_list/notice_styling.dart))

audience가 importance보다 우선. 상호 배타 정책으로 audience=관리자/병원 + importance=중요 조합은 발생하지 않음.

| 조건 | 색 | 정렬 우선순위 |
|------|---|:---:|
| audience=ALL + importance=중요(1) | 빨강 (`AppTheme.error`) | 1 |
| audience=ADMIN_ONLY | 파랑 (`AppTheme.primaryBlue`) | 2 |
| audience=HOSPITAL_ONLY | 초록 (`AppTheme.success`) | 3 |
| audience=ALL + importance=일반(0) | 검정 (`AppTheme.textPrimary`) | 4 |

같은 색 그룹 내에서는 `created_at` 역순.

### 칼럼(Column) 정책 (계약 확정 2026-04-28)

운영 정책: 칼럼은 **병원이 작성하고 관리자가 승인하는 검토 워크플로우**를 유지하되, 대상 분리(`target_audience`)와 중요도(`is_important`) 개념은 **칼럼에 적용되지 않음**. 칼럼은 모든 사용자에게 동일하게 노출되며 중요/일반 구분도 없음.

**필드 부재 (백엔드 응답 스키마 — `HospitalColumnResponse` 시리즈)**

칼럼은 처음부터 백엔드 응답에 다음 두 필드가 **존재한 적이 없음**. 프론트 모델에서도 제거됨 (2026-04-28). 추후 동일 필드명으로 다른 의미 도입 금지.

- `target_audience` — **없음** (모든 사용자에게 노출)
- `is_important` — **없음** (중요/일반 구분 없음)

**`columns_active` (= 프론트 `isPublished`) 워크플로우 (강제 검증, 2026-04-28)**

| 엔드포인트 | 동작 |
|-----------|------|
| `POST /api/hospital/columns` | 요청 본문의 `columns_active` 무시, **항상 `false`로 저장** (관리자 승인 대기) |
| `PUT /api/hospital/columns/{idx}` | 병원이 보낸 `columns_active` 무시 (다른 필드는 정상 반영). 관리자가 호출 시 변경 가능 |
| `PATCH /api/admin/columns/{idx}/publish` | **관리자 전용 토글** — 발행/회수 일원화 |
| ~~`PATCH /api/hospital/columns/{idx}/toggle`~~ | **삭제됨**. 정책 위반 경로였음 |

→ 병원이 악의적으로 `columns_active=true`를 보내도 백엔드가 무시하므로 우회 불가.

**거절 액션 정책 — 토글 일원화 (계약 확정 2026-05-08)**

칼럼은 게시글과 달리 별도의 "거절(reject)" 액션을 두지 않고 **발행 ↔ 회수 단일 토글로 일원화**. 운영 결정 근거:

- 칼럼은 수정 가능한 콘텐츠라 종결적 거절 의미가 부적절
- BE도 reject endpoint를 별도 운영하지 않음 (`PATCH /api/admin/columns/{idx}/publish` 단일)
- [admin_column_management.dart](lib/admin/admin_column_management.dart) UI는 ON/OFF 단일 토글 (`공개 승인` ↔ `공개 해제`)

**`column_rejected` 알림 emit 시점**: 운영자가 "공개 해제"를 누르거나 admin이 별도 회수 처리할 때 emit. 사용자(병원) 입장에서는 동일 알림 type으로 수신하나 본문(reason)으로 거절/회수 맥락을 구분 — title은 프론트 박제(`칼럼 게시글 거절`), body는 백엔드 동적.

향후 별도 reject API 신설 시도 금지 — 토글 일원화 정책은 이중 액션 도입을 명시 차단.

**자동 필터링 (백엔드, 추가 작업 불필요)**

`columns_active=true`인 칼럼만 응답하는 엔드포인트:
- `GET /api/hospital/columns`, `GET /api/hospital/columns/{idx}` (단 본인 작성자는 미발행도 조회)
- `GET /api/hospital/popular/columns`
- `GET /api/hospital/public/columns`
- `GET /api/public/columns`, `GET /api/public/columns/{idx}`, `GET /api/columns`
- 메인 대시보드 칼럼 섹션

예외 (의도된 동작):
- `GET /api/hospital/columns/my` — 병원 본인의 칼럼은 미발행 포함 전부 (작성/수정 화면용)
- `GET /api/admin/columns*` — 관리자는 모든 발행 상태 조회

**프론트 UI 정책**

| 화면 | 보이는 칼럼 | 색상 |
|------|------------|------|
| user_column_list / hospital_column_list | 발행된 것만 (백엔드 자동 필터) | 검정 |
| welcome + 3 dashboards | 발행된 것만 (백엔드 자동 필터) | 검정 |
| admin_column_management | 모든 칼럼 (관리자 권한) | 발행=검정, 미발행=**주황**(`AppTheme.warning`) |
| hospital_column_management_list | 자기가 작성한 모든 칼럼 | 발행=검정, 미발행=**주황**(`AppTheme.warning`) |

미발행 주황 표시는 [admin_column_management.dart](lib/admin/admin_column_management.dart) / [hospital_column_management_list.dart](lib/hospital/hospital_column_management_list.dart)에서만 등장. 단일 리스트(탭 폐기)이며 `column.isPublished`로 분기. 색 선택 근거: 공지의 빨강(중요)/파랑(관리자)/초록(병원) 팔레트와 겹치지 않으면서 "검토 대기" 의미를 표현 (`PetStatusRow`의 warning 톤과도 일치).

**행 위젯**

[BoardListRow](lib/widgets/post_list/board_list_row.dart) 공유 위젯 사용. 공지 화면과 동일한 행 모양 (번호/제목/작성자/작성일).

## API 경로 정규화 계획

백엔드에 단수/복수 섞인 경로(예: `/api/hospital/post/{id}` vs `/api/hospital/posts/{id}`)가 일부 남아있으며, 장기적으로 정리할 예정입니다. **합의된 변경 절차**:

1. 백엔드가 새 경로를 alias로 추가하면서 옛 경로도 당분간 유지 (dual-route 기간)
2. 백엔드가 "새 경로로 마이그레이션해 달라" 요청 시 `lib/utils/api_endpoints.dart`만 수정
3. 한 릴리스 지난 후 백엔드가 옛 경로 제거

**현재**: 프론트 코드 변경 불필요. 백엔드 요청이 오기 전까지 `api_endpoints.dart`의 현재 경로(단수/복수 혼재 상태) 그대로 유지.

## 환경 설정 관리 (.env)

- `.env`는 `.gitignore`에 포함되어 git 추적 대상 아님.
- 키 구조 참고용으로 `.env.example`을 유지. 실제 값은 placeholder로만 표기.
- 레포 이관/재구축 시에는 clean 상태로 시작하고 시크릿을 로테이션.
- 현재 관리 중인 키: `SERVER_URL`, `WEB_SERVER_URL` (웹은 CORS 문제로 분리 가능).

## 모바일 배포 채널

**현재 상태**: 개발 빌드만 운영 중. TestFlight / Google Play Internal Testing 트랙 **미연동**.

- iOS: `flutter build ios` 수동 빌드 → Xcode로 디바이스 설치
- Android: `flutter build apk --release` 수동 빌드 → APK 직접 배포
- Fastlane / CI/CD 파이프라인 없음
- 스토어 배포 채널 구성은 별도 라운드 (TestFlight 내부 테스트 → App Store 심사, Play Internal → Closed Testing → 프로덕션)

> 이 상태는 백엔드 CLAUDE.md와 동일하게 박제되어 기준이 맞춰져 있음.

## 병원 마스터 데이터 API 계약 (`/api/admin/hospitals/master/*`)

**최근 도입 영역** — 계약이 아직 소폭 바뀔 수 있음. 변경 발생 시 백엔드가 changelog로 재전달 예정.

### 공통
- **인증**: JWT Bearer, `account_type == 1` (ADMIN)만 접근. 아니면 **403**.
- **에러 형식**: 기존 `{"detail": "..."}` 규약 그대로.
- **구현 위치** (프론트):
  - 서비스: `lib/services/admin_hospital_service.dart` (`AdminHospitalService.getHospitalMasterList / registerHospitalMaster / updateHospitalMaster / deleteHospitalMaster`)
  - 모델: 같은 파일 하단 `HospitalMaster`, `HospitalMasterListResponse` 클래스 (별도 `lib/models/` 파일 없음)
  - 화면: `lib/admin/admin_hospital_check.dart`, `lib/admin/admin_signup_management.dart` (가입 승인 시 병원 검색)
  - 경로 상수: `lib/utils/api_endpoints.dart`의 `adminHospitalsMaster`, `adminHospitalsMasterRegister`, `adminHospitalMaster(hospitalCode)`

### 응답 스키마 `HospitalMasterResponse` (모든 단건 응답 공통)
```json
{
  "hospital_master_idx": 1,
  "hospital_code": "H0001",
  "hospital_name": "행복동물병원",
  "hospital_address": "서울시 ...",
  "hospital_phone": "02-0000-0000",
  "created_at": "2026-01-01T00:00:00",
  "updated_at": "2026-01-01T00:00:00"
}
```
- `hospital_code`는 서버 자동 발급(H0001 순번 포맷). 프론트 입력 **금지**.
- `hospital_code`는 **immutable** — 수정/삭제 시 path param으로만 쓰며, 다른 테이블(`accounts.hospital_code`)이 참조하므로 DB 레벨로도 변경 금지.

### 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/admin/hospitals/master/register` | 등록. body: `{hospital_name(필수), hospital_address?, hospital_phone?}`. `hospital_code`는 서버 자동 발급 |
| GET  | `/api/admin/hospitals/master` | 목록. query: `search?`, `page?` (default 1), `page_size?` (default 20, max 100). 응답: `{hospitals: HospitalMasterResponse[], total_count: int}` |
| PUT  | `/api/admin/hospitals/master/{hospital_code}` | 부분 수정. body 모든 필드 optional (`hospital_name?`, `hospital_address?`, `hospital_phone?`) |
| DELETE | `/api/admin/hospitals/master/{hospital_code}` | 삭제. 반환 형식 **미정** — 프론트는 200/204만 확인하고 목록 재조회. 참조 계정이 있으면 백엔드가 4xx 반환할 수 있으므로 `detail` 문자열 그대로 노출 |

### GET 목록 응답 불변 계약 (백엔드 런타임 검증 완료)
| 조건 | 응답 | 비고 |
|------|------|------|
| 빈 검색 결과 | `{"hospitals": [], "total_count": 0}` | `hospitals` 빈 배열 (null 불가), `total_count` 정수 0 (null 불가). `services/hospital_master_service.py:108`에서 `count or 0`으로 null 방지 |
| `page_size` 범위 초과 (0, 101 이상) | **400** | 허용 범위 `1 ~ 100`. 프론트는 기본 20, 다이얼로그 미리보기 50 사용 중이므로 안전 |
| `page` 오버플로우 (예: 데이터 2건인데 `page=9999`) | `{"hospitals": [], "total_count": <전체건수>}`, **400 아님** | `total_count`는 필터 조건 기반 실제 전체 건수 유지. 프론트는 `_currentPage > totalPages` 또는 `total_count > 0 && hospitals.isEmpty`로 감지 후 1페이지로 자동 폴백 ([admin_hospital_check.dart:_loadMasterHospitals](lib/admin/admin_hospital_check.dart)) |

**계약**: `hospitals` / `total_count` 필드는 **null이 될 수 없음** (빈 배열 / 정수 0으로 보장). 프론트는 `null` 방어 없이 직접 사용 가능.

### 프론트 구현 상태 메모
- **서버 사이드 페이지네이션 사용 중** (2026-04 전환). `getHospitalMasterList({page, pageSize=20, search})`이 `page` / `page_size` 쿼리를 항상 전송하고 응답 `total_count` 기반으로 `PaginationBar`를 렌더.
- **검색 디바운스 400ms** 적용 ([admin_hospital_check.dart](lib/admin/admin_hospital_check.dart) 마스터 탭, [admin_signup_management.dart](lib/admin/admin_signup_management.dart) 가입 승인 다이얼로그). `clear` 버튼과 다이얼로그 닫힘은 디바운스 즉시 취소.
- 마지막 페이지에서 마지막 레코드 삭제 시 `_loadMasterHospitals()`가 자동으로 1페이지로 폴백 후 재조회.
- DELETE 응답을 200/204 모두 수용하는 방어 코드 이미 반영 ([admin_hospital_service.dart:440](lib/services/admin_hospital_service.dart#L440)).

### hospital_code 부여 플로우 (가입 승인)
병원 계정의 `hospital_code`는 **가입 승인 시점**에 관리자가 연결합니다.

1. 병원이 일반 이메일 회원가입 → `approved=False` 상태로 대기
2. 관리자가 `admin_signup_management` 화면에서 마스터 병원 목록(`/api/admin/hospitals/master`)에서 해당 병원 선택 (이미 등록된 마스터여야 함)
3. 관리자 승인 API가 `hospital_id`(= `hospital_code`) 를 body에 담아 전송
4. 백엔드가 Hospital 레코드 생성 + hospital_master의 주소/이름을 Account에 자동 복사
5. 이후 해당 계정은 `account_type=2` (HOSPITAL)로 전환

**마스터에 없는 신규 병원인 경우**:
- 관리자가 먼저 `POST /api/admin/hospitals/master/register`로 마스터 등록
- 그 다음 가입 요청 승인
- **순서가 중요** — 프론트 UI에서 "마스터에 없음" 감지 시 먼저 마스터 등록 모달로 유도하는 것이 안전

**주의 — 백엔드 현재 동작**: 승인 시 `hospital_master` 조회에 매치가 없어도 에러를 내지 않고 조용히 지나감 (`signup_management_service.py:102-107`). 미등록 코드를 보내면 Hospital 레코드는 생성되지만 주소/이름이 비게 됨. **프론트가 마스터 목록에서만 선택하도록 UI를 제한해서 이 상황을 방지할 것** (현재 [lib/admin/admin_signup_management.dart:292-371](lib/admin/admin_signup_management.dart#L292)이 이 패턴을 따름).

## 아이콘 시스템

펫/사용자/게시글 정보 행 라벨 아이콘은 [lib/utils/pet_field_icons.dart](lib/utils/pet_field_icons.dart)의 `PetFieldIcons`가 단일 진실. 모든 화면이 여기서 import해서 사용 — 직접 `Icons.xxx`를 쓰지 말 것.

### 결정 트리

```
            ┌───────────────────────┐
            │ 아이콘이 어떤 역할?   │
            └──────────┬────────────┘
                       │
        ┌──────────────┼───────────────┐
        ▼              ▼               ▼
   정보 표시      입력 트리거       강조/일러스트
   (read-only)    (date picker)     (통계 chip,
                                     empty state)
        │              │               │
        ▼              ▼               ▼
    outlined       outlined          filled
    (PetFieldIcons (calendar_today_   (Icons.bloodtype,
     상수 사용)     outlined로 통일,   Icons.calendar_today
                   2026-05-01 결정)   같은 강조 자리)
```

**예외 — 종 구분이 필요한 게시글 동물 종류**: `FontAwesomeIcons.dog` / `cat` 사용 (Material에 강아지/고양이 구분 아이콘 없음). [post_detail_meta_section.dart](lib/widgets/post_detail/post_detail_meta_section.dart)에만 적용.

### 도메인별 매핑 (PetFieldIcons 상수)

**펫 도메인**

| 필드 | 상수 | IconData |
|------|------|----------|
| 이름 | `name` | `Icons.badge_outlined` |
| 종 | `species` | `Icons.pets` (변형 없음) |
| 품종 | `breed` | `Icons.category_outlined` |
| 성별 | `sex(int)` | 동적: `Icons.female` (0) / `Icons.male` (1) |
| 성별 (필드 자체) | `sexField` | `Icons.transgender` (변경 내역 행용) |
| 혈액형 | `bloodType` | `Icons.bloodtype_outlined` |
| 생년월일 | `birthDate` | `Icons.cake_outlined` |
| 체중 | `weight` | `Icons.fitness_center` (변형 없음) |
| 백신/예방접종 | `vaccinated` | `Icons.vaccines_outlined` |
| 예방약 | `medication` | `Icons.medication_outlined` |
| 질병 유무 | `hasDisease` | `Icons.local_hospital_outlined` |
| 중성화 | `isNeutered` | `Icons.verified_user_outlined` (방패+체크) |
| 중성화 일자 | `neuteredDate` | `Icons.event_outlined` |
| 임신/출산 | `pregnancyBirth` | `Icons.favorite_outline` |
| 출산 종료일 | `lastPregnancyEndDate` | `Icons.event_outlined` |
| 직전 헌혈일 | `prevDonationDate` | `Icons.history_outlined` |

**사용자 도메인**

| 필드 | 상수 | IconData |
|------|------|----------|
| 사용자 이름 | `userName` | `Icons.person_outline` |
| 닉네임 | `nickname` | `Icons.badge_outlined` |
| 이메일 | `email` | `Icons.email_outlined` |
| 전화/연락처 | `phone` | `Icons.phone_outlined` |
| 주소 | `address` | `Icons.location_on_outlined` |
| 가입일 | `userCreatedAt` | `Icons.event_outlined` |
| 상태 | `userStatus` | `Icons.info_outline` |

**게시글 도메인**

| 필드 | 상수 | IconData |
|------|------|----------|
| 병원명 | `hospital` | `Icons.business_outlined` |
| 위치/주소 | `postLocation` | `Icons.location_on_outlined` |
| 게시일 | `postedAt` | `Icons.calendar_today_outlined` |
| 헌혈 일정 | `donationDate` | `Icons.event_outlined` |
| 환자명 (긴급) | `patientName` | `Icons.badge_outlined` |
| 진단/병명 | `diagnosis` | `Icons.local_hospital_outlined` |

### 신규 정보 행 추가 시 체크리스트

- [ ] 정보 표시인가? → `PetFieldIcons.xxx` 상수 사용 (직접 `Icons.xxx` 금지)
- [ ] 매핑에 없는 신규 필드인가? → `pet_field_icons.dart`에 상수부터 추가하고 거기서 import
- [ ] 백엔드 `previous_values` 필드 키가 있는가? → `PetFieldIcons.forField(key)` 분기에도 추가
- [ ] 입력 폼인가? → `Icons.calendar_today_outlined`처럼 outlined 변형 사용
- [ ] 강조/일러스트인가? → filled 그대로 (`Icons.bloodtype` 64px empty state 등)
- [ ] bool/상태 행인가? → 직접 그리지 말고 [PetStatusRow](lib/widgets/pet_status_row.dart) + 4단계 매핑 사용 (아래 "상태 표시" 섹션 참조)

### 상태 표시 — 4단계 의미 매핑 (`PetStatusRow` 단일 진실)

펫 정보 카드의 bool/상태 값은 모두 [PetStatusRow](lib/widgets/pet_status_row.dart)를 통해 의미별 4단계 아이콘으로 표시. 회원가입 관리 / 관리자 펫 관리 / 모집마감 시트 모두 동일 매핑.

| 상태 | 의미 | 아이콘 | 색상 | 사용 케이스 |
|------|------|--------|------|------------|
| `positive` | 능동 행위 완료 | `check_circle_outline` ✓ | `AppTheme.success` (초록) | 접종 완료, 예방약 복용, 중성화 완료 |
| `critical` | 능동 행위 미수행 / 적극적 위험 | `error_outline` ! | `AppTheme.error` (빨강) | 접종 안됨, 예방약 미복용, 질병 있음 |
| `warning` | 신경써야 할 컨텍스트 상태 | `warning_amber_rounded` ⚠ | `AppTheme.warning` (주황) | 임신중, 생년월일 미입력 |
| `neutral` | 자연스러운 부재 | `remove_circle_outline` — | `AppTheme.textTertiary` (회색) | 질병 없음, 중성화 미시행, 첫 헌혈 |

**색상 구분 규칙**:
- 빨강 vs 주황: "의료 행위 미수행"은 빨강(critical), "정보 미입력 / 컨텍스트 주의"는 주황
- 회색 vs 빨강: "없어서 좋은 것"은 회색(중립), "있어서 나쁜 것"은 빨강

**필드별 매핑 (확정)**

| 필드 | true / 입력됨 | false / 미입력 |
|------|---------------|----------------|
| 접종 (vaccinated) | positive ✓ | critical ! |
| 예방약 (medication) | positive ✓ | critical ! |
| 중성화 (isNeutered) | positive ✓ | neutral — |
| 질병 (hasDisease) | critical ! | neutral — |
| 임신/출산 (status=0) | — | neutral — |
| 임신/출산 (status=1, 임신중) | — | warning ⚠ |
| 임신/출산 (status=2 + 종료일) | — | 텍스트 "출산 YYYY.MM.DD" (PetStatusRow 아닌 InfoRow) |
| 생년월일 (null) | text 날짜 | warning ⚠ |
| 최근 헌혈일 (null) | text 날짜 | neutral — (첫 헌혈) |

### 의도된 예외 (변경 금지 항목)

| 위치 | 아이콘 | 이유 |
|------|--------|------|
| `post_detail_meta_section.dart` 동물 종류 | `FontAwesomeIcons.dog`/`cat` | 강아지/고양이 구분 시각적으로 필요 |
| `Icons.pets` | 변형 없음 | Material에 outlined 변형 미존재 |
| `Icons.fitness_center` (체중) | 변형 없음 | Material에 outlined 변형 미존재 |
| `Icons.transgender`, `Icons.female`/`male` | 변형 없음 | 성별 표시 아이콘 — 변형 미존재 |
| 통계 chip / empty state 64px 큰 아이콘 | filled | 강조/일러스트 역할 |