# Firebase 설정 가이드

## 1. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름을 "memory-game"으로 설정
4. Google Analytics 활성화 (선택사항)
5. 프로젝트 생성 완료

## 2. Android 앱 등록

1. Firebase 콘솔에서 Android 아이콘 클릭
2. Android 패키지 이름: `com.goldmagnetsoft.memory_game`
3. 앱 닉네임: "Memory Game" (선택사항)
4. SHA-1 인증서 지문 추가 (디버그용)
5. `google-services.json` 파일 다운로드

## 3. iOS 앱 등록 (선택사항)

1. Firebase 콘솔에서 iOS 아이콘 클릭
2. iOS 번들 ID: `com.goldmagnetsoft.memoryGame`
3. 앱 닉네임: "Memory Game" (선택사항)
4. `GoogleService-Info.plist` 파일 다운로드

## 4. 파일 배치

### Android

- `google-services.json` 파일을 `android/app/` 폴더에 배치

### iOS

- `GoogleService-Info.plist` 파일을 `ios/Runner/` 폴더에 배치

## 5. Firestore 데이터베이스 설정

1. Firebase 콘솔에서 "Firestore Database" 선택
2. "데이터베이스 만들기" 클릭
3. 보안 규칙을 "테스트 모드에서 시작"으로 설정
4. 위치 선택 (가까운 지역)

## 6. Firestore 보안 규칙

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 정보
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // 온라인 게임 기록
    match /online_game_records/{recordId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // 온라인 멀티플레이어 기록
    match /online_multiplayer_records/{recordId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // 온라인 플레이어 통계
    match /online_player_stats/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // 연결 테스트용 컬렉션
    match /connection_test/{docId} {
      allow read: if true;
    }
  }
}
```

## 7. 인증 설정

1. Firebase 콘솔에서 "Authentication" 선택
2. "시작하기" 클릭
3. "이메일/비밀번호" 제공업체 활성화
4. "사용자 등록" 활성화

## 8. 앱 실행

설정이 완료되면 앱을 실행하여 온라인 기능을 테스트할 수 있습니다.

## 주의사항

- `google-services.json`과 `GoogleService-Info.plist` 파일은 민감한 정보를 포함하므로 Git에 커밋하지 마세요
- 프로덕션 환경에서는 보안 규칙을 더 엄격하게 설정하세요
- Firebase 사용량에 따라 요금이 발생할 수 있습니다

## 9. Firestore 인덱스 설정 (중요!)

온라인 랭킹 기능을 위해 다음 복합 인덱스들을 생성해야 합니다.

### 9.1 Firebase Console에서 인덱스 생성

1. Firebase Console에서 "Firestore Database" 선택
2. "인덱스" 탭 클릭
3. "복합 인덱스 만들기" 클릭

#### 필요한 인덱스들:

**1. 온라인 게임 기록 - 점수 순**

- 컬렉션: `online_game_records`
- 필드:
  - `isCompleted` (오름차순)
  - `score` (내림차순)

**2. 온라인 게임 기록 - 시간 순**

- 컬렉션: `online_game_records`
- 필드:
  - `isCompleted` (오름차순)
  - `timeLeft` (내림차순)

**3. 온라인 게임 기록 - 콤보 순**

- 컬렉션: `online_game_records`
- 필드:
  - `isCompleted` (오름차순)
  - `maxCombo` (내림차순)

**4. 온라인 게임 기록 - 생성일 순**

- 컬렉션: `online_game_records`
- 필드:
  - `isCompleted` (오름차순)
  - `createdAt` (내림차순)

**5. 사용자 게임 기록 - 생성일 순**

- 컬렉션: `online_game_records`
- 필드:
  - `userId` (오름차순)
  - `createdAt` (내림차순)

**6. 온라인 멀티플레이어 기록 - 생성일 순**

- 컬렉션: `online_multiplayer_records`
- 필드:
  - `isCompleted` (오름차순)
  - `createdAt` (내림차순)

### 9.2 인덱스 생성 방법

1. Firebase Console에서 "Firestore Database" > "인덱스" 탭
2. "복합 인덱스 만들기" 클릭
3. 컬렉션 ID 입력: `online_game_records`
4. 필드 추가:
   - 첫 번째 필드: `isCompleted`, 정렬: 오름차순
   - 두 번째 필드: `score`, 정렬: 내림차순
5. "인덱스 만들기" 클릭
6. 위의 모든 인덱스를 동일한 방법으로 생성

### 9.3 인덱스 생성 확인

인덱스 생성 후 "빌드 중" 상태에서 "사용 가능" 상태로 변경될 때까지 기다려야 합니다 (보통 몇 분 소요).

### 9.4 인덱스 없이도 작동

앱은 인덱스가 없어도 클라이언트 사이드 정렬로 작동하지만, 성능상 서버 사이드 정렬이 권장됩니다.

## 10. Authentication 설정

### 10.1 이메일/비밀번호 인증 활성화

1. Firebase Console에서 "Authentication" 선택
2. "시작하기" 클릭
3. "로그인 방법" 탭에서 "이메일/비밀번호" 활성화
4. "사용 설정" 체크박스 선택
5. "저장" 클릭

## 11. 앱 테스트

### 11.1 온라인 기능 테스트

1. 앱 실행
2. 온라인 로그인 화면에서 회원가입
3. 온라인 게임 실행
4. 게임 완료 후 온라인 랭킹 확인

### 11.2 문제 해결

**인덱스 오류가 발생하는 경우:**

- Firebase Console에서 필요한 인덱스가 모두 생성되었는지 확인
- 인덱스 상태가 "사용 가능"인지 확인
- 앱을 재시작하여 새로운 인덱스 적용

**로그인 오류가 발생하는 경우:**

- Authentication에서 이메일/비밀번호 인증이 활성화되었는지 확인
- `google-services.json` 파일이 올바른 위치에 있는지 확인

**데이터 저장 오류가 발생하는 경우:**

- Firestore 보안 규칙이 올바르게 설정되었는지 확인
- 사용자가 로그인되어 있는지 확인

## 12. 프로덕션 배포 시 주의사항

### 12.1 보안 규칙 업데이트

프로덕션 환경에서는 더 엄격한 보안 규칙을 사용하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 프로덕션용 보안 규칙
    // 필요에 따라 추가 제한사항 설정
  }
}
```

### 12.2 App Check 설정 (권장)

1. Firebase Console에서 "App Check" 활성화
2. 앱에서 App Check 구현
3. 보안 강화

### 12.3 모니터링 설정

1. Firebase Console에서 "Crashlytics" 활성화
2. 앱 성능 모니터링 설정
3. 사용자 분석 설정

## 13. 추가 리소스

- [Firebase 공식 문서](https://firebase.google.com/docs)
- [Flutter Firebase 플러그인](https://firebase.flutter.dev/)
- [Firestore 보안 규칙 가이드](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore 인덱스 가이드](https://firebase.google.com/docs/firestore/query-data/indexing)
