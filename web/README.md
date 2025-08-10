# Super Pet Connect Web Client

Super Pet Connect 관리자 웹 대시보드입니다. Flutter 앱과 동일한 백엔드 API를 사용하여 브라우저에서 헌혈 게시글 승인 관리를 할 수 있습니다.

## 🚀 주요 기능

### 헌혈 게시글 관리
- 승인 대기 중인 게시글 목록 조회
- 게시글 상세 정보 확인
- 승인/거절 처리
- 실시간 목록 업데이트

### 실시간 알림
- WebSocket을 통한 실시간 알림 수신
- 새 사용자 등록, 게시글 제출 등 즉시 알림
- 브라우저 푸시 알림 지원

## 📋 사용 방법

### 1. 웹 서버 실행

#### Python 내장 서버 사용 (권장)
```bash
# SuperPetConnect_Front/web 디렉토리에서 실행
cd D:\SuperPetConnect_Front\web
python -m http.server 8080
```

#### Node.js serve 패키지 사용
```bash
# serve 패키지 설치 (처음 한 번만)
npm install -g serve

# 서버 실행
cd D:\SuperPetConnect_Front\web
serve -p 8080
```

#### Live Server (VS Code 확장) 사용
1. VS Code에서 `admin_dashboard.html` 파일 열기
2. 우클릭 → "Open with Live Server" 선택

### 2. 웹 브라우저 접속
```
http://localhost:8080/admin_dashboard.html
```

### 3. JWT 토큰 입력
- 페이지 로드 시 JWT 토큰 입력 창이 표시됩니다
- Flutter 앱에서 로그인 후 받은 JWT 토큰을 입력하세요
- 토큰은 브라우저에 저장되어 다음 접속 시 자동으로 사용됩니다

## 🛠️ 기술 스택

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **통신**: REST API, WebSocket
- **인증**: JWT Bearer Token
- **실시간**: WebSocket 연결

## 🔧 설정

### 서버 URL 변경
`admin_dashboard.html` 파일의 JavaScript 부분에서 서버 URL을 수정할 수 있습니다:

```javascript
const SERVER_URL = 'http://10.100.54.176:8002'; // 서버 URL 설정
```

### WebSocket 연결
```javascript
ws = new WebSocket(`ws://10.100.54.176:8002/ws?token=${token}`);
```

## 📱 Flutter 앱과의 연동

### 동일한 백엔드 API 사용
- REST API 엔드포인트 동일
- JWT 토큰 기반 인증 공유
- 실시간 알림 시스템 공유

### 데이터 동기화
- 웹에서 승인/거절 처리 → 앱에서 즉시 반영
- 앱에서 게시글 제출 → 웹에서 즉시 알림
- WebSocket을 통한 실시간 업데이트

## 🎯 주요 API 엔드포인트

### 게시글 조회
```
GET /api/admin/posts?status=0
Authorization: Bearer {JWT_TOKEN}
```

### 게시글 승인/거절
```
PUT /api/admin/posts/{POST_ID}/approval
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "approved": true  // 승인: true, 거절: false
}
```

### WebSocket 연결
```
ws://10.100.54.176:8007/ws?token={JWT_TOKEN}
```

## 🔒 보안 고려사항

1. **JWT 토큰 보안**
   - 토큰을 안전하게 관리하세요
   - 만료 시 재로그인 처리

2. **HTTPS 사용**
   - 프로덕션 환경에서는 HTTPS 사용 권장
   - WebSocket도 WSS로 변경 필요

3. **CORS 설정**
   - 현재 서버는 모든 도메인 허용
   - 프로덕션에서는 특정 도메인만 허용

## 🐛 문제 해결

### 토큰 관련 오류
- 브라우저 개발자 도구에서 localStorage 확인
- `localStorage.removeItem('jwt_token')` 후 새로고침

### WebSocket 연결 오류
- 서버 상태 확인
- 방화벽 설정 확인
- 브라우저 콘솔에서 오류 메시지 확인

### API 호출 오류
- 네트워크 탭에서 요청/응답 확인
- 서버 로그 확인
- JWT 토큰 유효성 확인

## 📞 지원

문제가 발생하면 다음을 확인해보세요:
1. 브라우저 개발자 도구 콘솔
2. 네트워크 탭의 요청/응답
3. 서버 로그 메시지
4. JWT 토큰 유효성

서버 상태 확인: `GET /api/websocket/stats`
연결 테스트: `GET /api/notifications/connection/status`