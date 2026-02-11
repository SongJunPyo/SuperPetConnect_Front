# Windows 작업자에게 전달 사항

## 현재 상황
- Mac에서 iOS 빌드 환경 세팅 완료
- `ios-setup` 브랜치로 GitHub에 push 완료
- iOS 시뮬레이터에서 빌드 및 실행 확인됨

## 머지 순서

### 1단계: ios-setup 브랜치를 main에 머지
GitHub에서 PR 생성 후 머지하거나, 터미널에서:
```bash
git checkout main
git pull origin main
git merge origin/ios-setup
git push origin main
```

### 2단계: Windows에서 최신 main 가져오기
```bash
git checkout main
git pull origin main
```

### 3단계: Windows 고도화 작업을 새 브랜치로 커밋
```bash
git checkout -b feature-upgrade
git add .
git commit -m "기능 고도화 작업"
git push origin feature-upgrade
```

### 4단계: feature-upgrade를 main에 머지
```bash
git checkout main
git merge feature-upgrade
# 충돌 발생 시 아래 "충돌 가능 파일" 참고하여 해결
git push origin main
```

---

## ios-setup 브랜치에서 변경된 파일 목록

| 파일 | 변경 내용 |
|------|----------|
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID를 `com.example.superpet`으로 통일, 배포 타겟 13.0 상향 |
| `ios/Runner/Info.plist` | NSAppTransportSecurity 추가 (HTTP 연결 허용) |
| `ios/Podfile` | 신규 생성 (CocoaPods 의존성) |
| `ios/Podfile.lock` | 신규 생성 |
| `ios/Flutter/AppFrameworkInfo.plist` | Flutter SDK 업데이트 반영 |
| `ios/Flutter/Debug.xcconfig` | CocoaPods 설정 추가 |
| `ios/Flutter/Release.xcconfig` | CocoaPods 설정 추가 |
| `ios/Runner.xcworkspace/contents.xcworkspacedata` | Pods 프로젝트 참조 추가 |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | Xcode 스킴 업데이트 |
| `pubspec.yaml` | flutter_naver_login 1.8.0 -> 2.1.1 업데이트 |
| `pubspec.lock` | 패키지 버전 잠금 파일 업데이트 |
| `lib/auth/login.dart` | 네이버 로그인 v2.x API 변경 반영 |

---

## 충돌 가능 파일 및 해결 방법

### 1. `pubspec.yaml`
- Mac: `flutter_naver_login: ^2.1.1` (기존 ^1.8.0에서 변경)
- Windows에서도 패키지를 추가/변경했다면 충돌 가능
- **해결**: 양쪽 변경사항 모두 반영. flutter_naver_login은 반드시 `^2.1.1` 유지

### 2. `lib/auth/login.dart`
- Mac: 네이버 로그인 API 변경 (v2.x 대응)
  - `NaverAccessToken` -> `NaverToken`
  - `FlutterNaverLogin.currentAccessToken` -> `FlutterNaverLogin.getCurrentAccessToken()`
  - import 3줄 추가
- Windows에서 이 파일을 수정했다면 충돌 가능
- **해결**: Mac의 네이버 로그인 관련 변경은 유지하고, Windows의 다른 변경사항도 함께 반영

### 3. `pubspec.lock`
- **해결**: 충돌 시 머지 후 `flutter pub get` 실행하면 자동 재생성

---

## 머지 후 Windows에서 확인할 것
```bash
flutter pub get
flutter run -d chrome
# 또는
flutter run -d <안드로이드_에뮬레이터>
```

## 참고: .env 파일
- `.env` 파일은 `.gitignore`에 포함되어 있어 git에 올라가지 않음
- 각 환경에서 직접 생성 필요:
```
SERVER_URL=http://58.126.141.86:7000
```
