# Mac 작업자에게 전달 사항

## ✅ 통합 작업 완료

Windows 환경에서 Mac의 iOS 설정과 Windows 작업을 모두 main 브랜치에 통합했습니다.
충돌 없이 깔끔하게 머지되었으니, Mac에서 최신 코드를 받아주세요!

---

## 🔄 Mac에서 해야 할 작업

### 1단계: 최신 main 브랜치 가져오기
```bash
git checkout main
git pull origin main
```

### 2단계: 패키지 의존성 업데이트
```bash
flutter pub get
```

### 3단계: 정상 작동 확인
```bash
# iOS 시뮬레이터에서 실행
flutter run -d <iOS_시뮬레이터>

# 또는 기기 목록 확인 후 선택
flutter devices
flutter run -d <device_id>
```

---

## 📊 통합된 변경사항

### Mac에서 작업한 내용 (ios-setup 브랜치)
| 파일 | 변경 내용 |
|------|----------|
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID 통일, 배포 타겟 13.0 |
| `ios/Runner/Info.plist` | NSAppTransportSecurity 추가 (HTTP 연결 허용) |
| `ios/Podfile` | 신규 생성 (CocoaPods 의존성) |
| `ios/Podfile.lock` | 신규 생성 |
| `ios/Flutter/*.xcconfig` | CocoaPods 설정 추가 |
| `pubspec.yaml` | flutter_naver_login 1.8.0 -> 2.1.1 업데이트 |
| `lib/auth/login.dart` | 네이버 로그인 v2.x API 변경 반영 |

### Windows에서 추가 작업한 내용 (windows-changes 브랜치)
| 파일 | 변경 내용 |
|------|----------|
| `lib/auth/welcome.dart` | 환영 화면 UI/로직 개선 |
| `lib/services/hospital_column_service.dart` | 병원 칼럼 서비스 로직 개선 |

---

## 📝 최종 커밋 히스토리

```
*   949c9a3 (HEAD -> main, origin/main) Merge windows-changes
├─┐
│ * 834c59f Windows 환경 작업: welcome.dart 및 hospital_column_service 수정
* | 2d18ec0 iOS 빌드 환경 세팅 및 네이버 로그인 패키지 업데이트
|/
* cf9de9a 보안: Refresh Token 도입 및 인증 체계 강화
```

---

## ⚠️ 주의사항

### 1. .env 파일 확인
- `.env` 파일은 `.gitignore`에 포함되어 git에 올라가지 않음
- Mac 환경에 `.env` 파일이 있는지 확인하고, 없으면 생성:
```
SERVER_URL=http://58.126.141.86:7000
```

### 2. CocoaPods 의존성
- `ios/Podfile.lock`이 업데이트되었으니, iOS 빌드 전 확인:
```bash
cd ios
pod install
cd ..
```

### 3. 네이버 로그인 API v2
- `lib/auth/login.dart`에서 네이버 로그인 API가 v2로 업데이트됨
- `NaverAccessToken` → `NaverToken`
- `FlutterNaverLogin.currentAccessToken` → `FlutterNaverLogin.getCurrentAccessToken()`
- iOS에서도 정상 작동하는지 테스트 필요

---

## 🎯 앞으로의 작업 방식

이제부터는 **main 브랜치를 기준으로 동일하게 작업**하면 됩니다!

### 새로운 작업 시작할 때
```bash
# 1. 최신 main 가져오기
git checkout main
git pull origin main

# 2. 새 브랜치 생성
git checkout -b feature/새기능

# 3. 작업 후 커밋
git add .
git commit -m "작업 내용"
git push origin feature/새기능

# 4. GitHub에서 PR 생성 후 리뷰
```

### 충돌 방지 팁
- 같은 파일을 동시에 수정하지 않기
- 작업 시작 전 항상 `git pull origin main`으로 최신 상태 유지
- 작업 완료 후 빠르게 PR 만들어서 머지하기

---

## 🚀 테스트 체크리스트

Mac에서 다음 항목들이 정상 작동하는지 확인해주세요:

- [ ] iOS 시뮬레이터에서 앱 빌드 및 실행
- [ ] 네이버 로그인 정상 작동 (API v2)
- [ ] 환영 화면 정상 표시
- [ ] 병원 칼럼 목록 조회 정상 작동
- [ ] HTTP 연결 정상 작동 (Info.plist 설정 적용)

---

## 📞 문제 발생 시

문제가 생기면 다음 순서로 확인:

1. `flutter clean && flutter pub get`
2. `cd ios && pod install && cd ..`
3. Xcode에서 빌드 캐시 삭제 (Product → Clean Build Folder)
4. iOS 시뮬레이터 재시작

그래도 안 되면 Windows 작업자에게 연락주세요!

---

**작성일**: 2026-02-11
**작성자**: Windows 환경 작업자
**통합 완료 커밋**: `949c9a3`
