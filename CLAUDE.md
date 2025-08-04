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
- `lib/auth/` - 인증 플로우
  - 헌혈 게시판 미리보기가 있는 환영 화면
  - 역할 선택이 있는 로그인/회원가입
  - 알림을 위한 FCM 토큰 관리
- `lib/hospital/` - 병원 기능
  - 헌혈 게시물 생성/관리
  - 지원자 검토 및 승인
  - 시간대 스케줄링 인터페이스
- `lib/user/` - 반려동물 소유자 기능
  - 반려동물 등록 및 프로필 관리
  - 헌혈 기회 탐색/지원
  - 교육 콘텐츠 (칼럼)
- `lib/models/` - 핵심 데이터 모델
- `lib/services/` - API 통신 레이어
- `lib/utils/` - 설정 및 유틸리티
  - `config.dart`: 백엔드 서버 URL 설정
  - `app_theme.dart`: 중앙집중식 테마 (토스 스타일 디자인)
- `lib/widgets/` - 재사용 가능한 UI 컴포넌트

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