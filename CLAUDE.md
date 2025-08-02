# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development
- `flutter pub get` - Install dependencies
- `flutter run` - Run the application in debug mode
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter test` - Run unit tests
- `flutter analyze` - Run static analysis
- `flutter clean` - Clean build artifacts

### Code Quality
- `flutter analyze` - Check code for issues and warnings
- `flutter format .` - Format all Dart files

## Project Architecture

### Application Structure
This is a Flutter mobile application for "Super Pet Connect" - a blood donation system for pets connecting hospitals, users, and administrators.

### Core Architecture Patterns
- **Role-based UI**: Three distinct user interfaces (Admin, Hospital, User) with separate dashboard flows
- **Model-based data handling**: Centralized data models in `lib/models/` for API communication
- **Service layer**: Backend communication through HTTP services
- **Firebase integration**: FCM for push notifications with local notification handling

### Key Directories

- `lib/admin/` - Administrative interface screens and functionality
- `lib/auth/` - Authentication screens (login, register, welcome, FCM token)
- `lib/hospital/` - Hospital-specific screens for posting blood donation requests
- `lib/user/` - User screens for pet management and donation responses
- `lib/models/` - Data models (Post, Hospital, Pet models)
- `lib/services/` - Business logic and API communication services
- `lib/utils/` - Configuration and utility functions

### Key Configuration
- **Server Configuration**: Backend API URL is configured in `lib/utils/config.dart`
- **Firebase**: Integrated for push notifications with proper initialization in main.dart
- **Navigation**: Role-based navigation after login directs to appropriate dashboard

### Authentication Flow
1. Welcome screen → Login/Register
2. Login validates credentials against backend API
3. Based on user role, redirects to appropriate dashboard:
   - Admin → AdminDashboard
   - Hospital → HospitalDashboard  
   - User → UserDashboard

### Data Models
- **Post**: Blood donation requests with time ranges, hospital info, urgency flags
- **Hospital**: Hospital entity with contact information and address
- **Pet**: Pet information for users managing their pets
- **TimeRange**: Time slots for blood donation appointments

### Firebase Integration
- FCM token management for push notifications
- Background and foreground message handling
- Local notification display with proper Android notification channels
- Timezone handling for Korean locale (Asia/Seoul)

### Dependencies
Key packages include:
- `http` for API communication
- `shared_preferences` for local storage
- `firebase_messaging` and `firebase_core` for push notifications
- `flutter_local_notifications` for local notification display
- `interval_time_picker` for time selection in hospital posts
- `kpostal` for Korean postal code lookup


# CLAUDE.md
- 이 파일은 Claude Code(claude.ai/code)가 이 저장소의 코드로 작업할 때 참고하는 가이드입니다.

## 자주 사용하는 명령어

### 개발
- flutter pub get - 의존성 설치

- flutter run - 디버그 모드로 애플리케이션 실행

- flutter build apk - 안드로이드 APK 빌드

- flutter build ios - iOS 앱 빌드

- flutter test - 유닛 테스트 실행

- flutter analyze - 정적 분석 실행

- flutter clean - 빌드 결과물 삭제

### 코드 품질
- flutter analyze - 코드 이슈 및 경고 확인

- flutter format . - 모든 Dart 파일 포맷팅

# 프로젝트 아키텍처
## 애플리케이션 구조
- 이 애플리케이션은 "Super Pet Connect"를 위한 Flutter 모바일 앱입니다. 병원, 사용자, 관리자를 연결하는 반려동물 헌혈 시스템입니다.

### 핵심 아키텍처 패턴
- 역할 기반 UI: 관리자, 병원, 사용자 세 가지의 독립적인 사용자 인터페이스와 각기 다른 대시보드 흐름을 가집니다.

- 모델 기반 데이터 처리: API 통신을 위해 lib/models/ 디렉터리에 데이터 모델을 중앙화하여 관리합니다.

- 서비스 레이어: HTTP 서비스를 통해 백엔드와 통신합니다.

- Firebase 연동: 푸시 알림을 위해 FCM을 사용하며, 로컬 알림 처리 기능이 포함됩니다.

### 주요 디렉터리
- lib/admin/ - 관리자 인터페이스 화면 및 기능

- lib/auth/ - 인증 화면 (로그인, 회원가입, 환영, FCM 토큰)

- lib/hospital/ - 병원 전용 화면 (헌혈 요청 게시)

- lib/user/ - 사용자 화면 (반려동물 관리 및 헌혈 신청)

- lib/models/ - 데이터 모델 (게시글, 병원, 반려동물 모델)

- lib/services/ - 비즈니스 로직 및 API 통신 서비스

- lib/utils/ - 설정 및 유틸리티 함수

### 주요 설정
- 서버 설정: 백엔드 API URL은 lib/utils/config.dart 파일에서 설정합니다.

- Firebase: 푸시 알림을 위해 연동되어 있으며, main.dart에서 초기화됩니다.

- 내비게이션: 로그인 후 역할에 따라 적절한 대시보드로 이동하는 역할 기반 내비게이션을 사용합니다.

### 인증 흐름
- 환영 화면 → 로그인/회원가입

- 로그인 시 백엔드 API를 통해 자격 증명 검증

- 사용자 역할에 따라 적절한 대시보드로 리디렉션:

- 관리자 → AdminDashboard

- 병원 → HospitalDashboard

- 사용자 → UserDashboard

### 데이터 모델
- Post: 시간대, 병원 정보, 긴급 여부 플래그를 포함하는 헌혈 요청

- Hospital: 연락처 정보와 주소를 포함하는 병원 엔티티

- Pet: 사용자가 관리하는 반려동물 정보

- TimeRange: 헌혈 예약을 위한 시간대 슬롯

### Firebase 연동
- 푸시 알림을 위한 FCM 토큰 관리

- 포그라운드 및 백그라운드 메시지 처리

- 안드로이드 알림 채널을 이용한 로컬 알림 표시

- 한국 시간대(Asia/Seoul) 처리

### 의존성
- 주요 패키지는 다음과 같습니다:

- http: API 통신

- shared_preferences: 로컬 저장소

- firebase_messaging, firebase_core: 푸시 알림

- flutter_local_notifications: 로컬 알림 표시

- interval_time_picker: 병원 게시글의 시간 선택

- kpostal: 한국 우편번호 검색