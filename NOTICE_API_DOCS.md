# 공지글 API 문서

## 개요
관리자가 공지글을 작성, 수정, 삭제하고 사용자가 공지글을 조회할 수 있는 API입니다.

## 기본 정보
- **Base URL**: `/api/notices`
- **인증**: 공지글 작성/수정/삭제는 관리자 권한 필요 (JWT 토큰)
- **Content-Type**: `application/json`

---

## API 엔드포인트

### 1. 공지글 작성 (관리자만)
**POST** `/api/notices/`

**Headers:**
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "title": "공지사항 제목",
  "content": "공지사항 내용입니다. 마크다운 형식도 지원합니다.",
  "is_important": false  // 중요 공지 여부 (선택사항, 기본값: false)
}
```

**Response (201 Created):**
```json
{
  "notice_idx": 1,
  "title": "공지사항 제목",
  "content": "공지사항 내용입니다. 마크다운 형식도 지원합니다.",
  "is_important": false,
  "is_active": true,
  "created_at": "2024-01-01T12:00:00.000Z",
  "updated_at": "2024-01-01T12:00:00.000Z",
  "author_name": "관리자",
  "author_email": "admin@example.com"
}
```

---

### 2. 공지글 목록 조회 (모든 사용자)
**GET** `/api/notices/`

**Query Parameters:**
- `page` (선택): 페이지 번호 (기본값: 1)
- `page_size` (선택): 페이지당 항목 수 (기본값: 10, 최대: 50)
- `active_only` (선택): 활성화된 공지만 조회 (기본값: true)
- `important_only` (선택): 중요 공지만 조회 (기본값: false)

**예시 요청:**
```
GET /api/notices/?page=1&page_size=10&active_only=true&important_only=false
```

**Response (200 OK):**
```json
{
  "notices": [
    {
      "notice_idx": 2,
      "title": "[중요] 시스템 점검 안내",
      "content": "시스템 점검으로 인해 서비스가 일시 중단됩니다.",
      "is_important": true,
      "is_active": true,
      "created_at": "2024-01-02T12:00:00.000Z",
      "updated_at": "2024-01-02T12:00:00.000Z",
      "author_name": "관리자",
      "author_email": "admin@example.com"
    },
    {
      "notice_idx": 1,
      "title": "일반 공지사항",
      "content": "일반적인 공지사항 내용입니다.",
      "is_important": false,
      "is_active": true,
      "created_at": "2024-01-01T12:00:00.000Z",
      "updated_at": "2024-01-01T12:00:00.000Z",
      "author_name": "관리자",
      "author_email": "admin@example.com"
    }
  ],
  "total_count": 15,
  "page": 1,
  "page_size": 10
}
```

---

### 3. 특정 공지글 상세 조회 (모든 사용자)
**GET** `/api/notices/{notice_idx}`

**Path Parameters:**
- `notice_idx`: 공지글 ID (정수)

**Response (200 OK):**
```json
{
  "notice_idx": 1,
  "title": "공지사항 제목",
  "content": "공지사항 내용입니다. 마크다운 형식도 지원합니다.",
  "is_important": false,
  "is_active": true,
  "created_at": "2024-01-01T12:00:00.000Z",
  "updated_at": "2024-01-01T12:00:00.000Z",
  "author_name": "관리자",
  "author_email": "admin@example.com"
}
```

**Error Response (404 Not Found):**
```json
{
  "detail": "공지글을 찾을 수 없습니다."
}
```

---

### 4. 공지글 수정 (관리자만)
**PUT** `/api/notices/{notice_idx}`

**Headers:**
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

**Path Parameters:**
- `notice_idx`: 공지글 ID (정수)

**Request Body (모든 필드 선택사항):**
```json
{
  "title": "수정된 제목",
  "content": "수정된 내용",
  "is_important": true,
  "is_active": false  // 비활성화하여 숨기기
}
```

**Response (200 OK):**
```json
{
  "notice_idx": 1,
  "title": "수정된 제목",
  "content": "수정된 내용",
  "is_important": true,
  "is_active": false,
  "created_at": "2024-01-01T12:00:00.000Z",
  "updated_at": "2024-01-01T12:30:00.000Z",
  "author_name": "관리자",
  "author_email": "admin@example.com"
}
```

---

### 5. 공지글 삭제 (관리자만)
**DELETE** `/api/notices/{notice_idx}`

**Headers:**
```
Authorization: Bearer {jwt_token}
```

**Path Parameters:**
- `notice_idx`: 공지글 ID (정수)

**Response (204 No Content):**
```json
{
  "message": "공지글이 삭제되었습니다."
}
```

---

## 에러 응답

### 인증 오류 (401 Unauthorized)
```json
{
  "detail": "토큰이 유효하지 않습니다."
}
```

### 권한 오류 (403 Forbidden)
```json
{
  "detail": "관리자 권한이 필요합니다."
}
```

### 공지글 없음 (404 Not Found)
```json
{
  "detail": "공지글을 찾을 수 없습니다."
}
```

### 유효성 검사 오류 (422 Unprocessable Entity)
```json
{
  "detail": [
    {
      "loc": ["body", "title"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

---

## 프론트엔드 구현 가이드

### 1. 공지글 목록 페이지
- **중요 공지**는 `is_important: true`인 항목을 상단에 표시
- **페이징** 구현 시 `total_count`, `page`, `page_size` 활용
- **정렬**: 중요 공지 먼저, 그 다음 최신순 (API에서 자동 정렬됨)

### 2. 관리자 공지글 작성/수정 페이지
- **제목**: 최대 100자
- **내용**: 텍스트 에어리어 (마크다운 지원 고려)
- **중요 공지**: 체크박스
- **활성화**: 체크박스 (수정 시에만 표시)

### 3. 상태 관리
```javascript
// 공지글 목록 상태 예시
const [notices, setNotices] = useState([]);
const [currentPage, setCurrentPage] = useState(1);
const [totalCount, setTotalCount] = useState(0);
const [loading, setLoading] = useState(false);

// API 호출 예시
const fetchNotices = async (page = 1, pageSize = 10) => {
  setLoading(true);
  try {
    const response = await fetch(
      `/api/notices/?page=${page}&page_size=${pageSize}&active_only=true`
    );
    const data = await response.json();
    setNotices(data.notices);
    setTotalCount(data.total_count);
  } catch (error) {
    console.error('공지글 조회 실패:', error);
  } finally {
    setLoading(false);
  }
};
```

### 4. 권한 확인
- 관리자 권한 확인: JWT 토큰 디코딩하여 `account_type === 1` 확인
- 관리자가 아닌 경우 작성/수정/삭제 버튼 숨김

### 5. UI/UX 권장사항
- **중요 공지**: 빨간색 배지 또는 핀 아이콘 표시
- **날짜 표시**: 상대적 시간 (예: "2일 전") 또는 절대 시간
- **내용 미리보기**: 목록에서는 내용을 100자 정도로 자르기
- **로딩 상태**: 스켈레톤 UI 또는 스피너 표시
- **빈 상태**: 공지글이 없을 때 안내 메시지

---

## 데이터베이스 스키마

```sql
CREATE TABLE notices (
    notice_idx INT PRIMARY KEY AUTO_INCREMENT,
    author_idx INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    is_important BOOLEAN DEFAULT FALSE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (author_idx) REFERENCES accounts(account_idx),
    INDEX ix_notices_notice_idx (notice_idx)
);
```