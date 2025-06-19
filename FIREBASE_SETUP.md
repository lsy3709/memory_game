# Firebase 설정 가이드

## 1. Firebase 프로젝트 설정

### 1.1 Firebase Console에서 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름 입력 (예: memory-game-58c95)
4. Google Analytics 설정 (선택사항)
5. 프로젝트 생성 완료

### 1.2 Android 앱 등록

1. 프로젝트 대시보드에서 Android 아이콘 클릭
2. Android 패키지 이름 입력: `com.goldmagnetsoft.memory_game`
3. 앱 닉네임 입력 (선택사항)
4. SHA-1 인증서 지문 추가 (선택사항)
5. `google-services.json` 파일 다운로드
6. `android/app/` 폴더에 `google-services.json` 파일 복사

### 1.3 iOS 앱 등록 (선택사항)

1. 프로젝트 대시보드에서 iOS 아이콘 클릭
2. iOS 번들 ID 입력
3. `GoogleService-Info.plist` 파일 다운로드
4. iOS 프로젝트에 파일 추가

## 2. Firestore 데이터베이스 설정

### 2.1 Firestore 데이터베이스 생성

1. Firebase Console에서 "Firestore Database" 선택
2. "데이터베이스 만들기" 클릭
3. 보안 규칙 선택: "테스트 모드에서 시작" (개발용)
4. 위치 선택 (가까운 지역 선택)

### 2.2 보안 규칙 설정

Firestore Database > 규칙 탭에서 다음 규칙 설정:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 데이터 - 본인만 읽기/쓰기 가능, 이메일 검색은 인증된 사용자만 가능
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // 친구 요청을 위한 이메일 검색 허용
      allow read: if request.auth != null;
    }

    // 온라인 게임 기록 - 인증된 사용자만 읽기/쓰기 가능
    match /online_game_records/{recordId} {
      allow read, write: if request.auth != null;
    }

    // 온라인 멀티플레이어 기록 - 인증된 사용자만 읽기/쓰기 가능
    match /online_multiplayer_records/{recordId} {
      allow read, write: if request.auth != null;
    }

    // 플레이어 통계 - 본인만 읽기/쓰기 가능
    match /online_player_stats/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // 온라인 게임 방 - 인증된 사용자만 읽기/쓰기 가능
    match /online_rooms/{roomId} {
      allow read, write: if request.auth != null;
    }

    // 친구 관계 - 인증된 사용자만 읽기/쓰기 가능 (본인과 관련된 데이터만)
    match /friends/{friendId} {
      allow read, write: if request.auth != null;
    }

    // 게임 초대 - 인증된 사용자만 읽기/쓰기 가능 (본인과 관련된 데이터만)
    match /game_invites/{inviteId} {
      allow read, write: if request.auth != null;
    }

    // 온라인 게임 상태 - 인증된 사용자만 읽기/쓰기 가능
    match /online_rooms/{roomId}/game_state/{docId} {
      allow read, write: if request.auth != null;
    }

    // 카드 액션 - 인증된 사용자만 읽기/쓰기 가능
    match /online_rooms/{roomId}/card_actions/{docId} {
      allow read, write: if request.auth != null;
    }

    // 턴 변경 - 인증된 사용자만 읽기/쓰기 가능
    match /online_rooms/{roomId}/turn_changes/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 3. Firestore 인덱스 설정 (중요!)

온라인 랭킹 기능을 위해 다음 복합 인덱스들을 생성해야 합니다.

### 3.1 Firebase Console에서 인덱스 생성

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

**7. 온라인 게임 방 - 상태별 생성일 순**

- 컬렉션: `online_rooms`
- 필드:
  - `status` (오름차순)
  - `createdAt` (내림차순)

**8. 친구 관계 - 사용자별 상태**

- 컬렉션: `friends`
- 필드:
  - `userId` (오름차순)
  - `status` (오름차순)

**9. 친구 관계 - 친구별 상태**

- 컬렉션: `friends`
- 필드:
  - `friendId` (오름차순)
  - `status` (오름차순)

**10. 게임 초대 - 수신자별 상태**

- 컬렉션: `game_invites`
- 필드:
  - `toUserId` (오름차순)
  - `status` (오름차순)

**11. 게임 초대 - 발신자별 상태**

- 컬렉션: `game_invites`
- 필드:
  - `fromUserId` (오름차순)
  - `status` (오름차순)

### 3.2 인덱스 생성 방법

각 인덱스에 대해:

1. "복합 인덱스 만들기" 클릭
2. 컬렉션 ID 입력
3. 필드 추가 (위의 필드들을 순서대로 추가)
4. 정렬 순서 설정 (오름차순/내림차순)
5. "인덱스 만들기" 클릭

### 3.3 인덱스 생성 확인

인덱스 생성 후 "상태"가 "사용 가능"으로 변경될 때까지 기다립니다 (보통 몇 분 소요).

## 4. Authentication 설정

### 4.1 이메일/비밀번호 인증 활성화

1. Firebase Console에서 "Authentication" 선택
2. "로그인 방법" 탭 클릭
3. "이메일/비밀번호" 선택
4. "사용 설정" 체크
5. "저장" 클릭

### 4.2 사용자 등록 테스트

1. "사용자" 탭에서 "사용자 추가" 클릭
2. 이메일과 비밀번호 입력하여 테스트 사용자 생성

## 5. 앱 설정

### 5.1 FlutterFire CLI 설치 (선택사항)

```bash
dart pub global activate flutterfire_cli
```

### 5.2 Firebase 설정 파일 생성

```bash
flutterfire configure
```

### 5.3 의존성 추가

`pubspec.yaml`에 다음 의존성이 있는지 확인:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  crypto: ^3.0.3
  email_validator: ^2.1.17
```

## 6. 테스트 및 확인

### 6.1 Firebase 연결 테스트

1. 앱 실행
2. 온라인 로그인 시도
3. Firebase Console에서 사용자 생성 확인

### 6.2 Firestore 데이터 확인

1. 게임 플레이 후 기록 저장
2. Firebase Console > Firestore Database에서 데이터 확인

### 6.3 인덱스 오류 확인

1. 온라인 랭킹 화면 접속
2. 콘솔에서 인덱스 오류 메시지 확인

## 7. 문제 해결

### 7.1 권한 오류 해결

만약 "Missing or insufficient permissions" 오류가 발생한다면:

1. Firebase Console > Firestore Database > 규칙 탭에서 위의 보안 규칙이 정확히 설정되었는지 확인
2. 규칙 변경 후 "게시" 버튼 클릭
3. 앱을 다시 실행하여 테스트

### 7.2 친구 요청 오류 해결

친구 요청 시 권한 오류가 발생하는 경우:

1. 사용자가 로그인되어 있는지 확인
2. Firestore 규칙에서 `users` 컬렉션에 대한 읽기 권한이 올바르게 설정되었는지 확인
3. 친구로 요청하려는 사용자가 실제로 존재하는지 확인

### 7.3 인덱스 오류 해결

복합 인덱스 오류가 발생하는 경우:

1. Firebase Console > Firestore Database > 인덱스 탭에서 필요한 인덱스들이 모두 생성되었는지 확인
2. 인덱스 상태가 "사용 가능"인지 확인
3. 인덱스 생성 후 몇 분 기다린 후 다시 시도

## 8. 프로덕션 배포

### 8.1 보안 규칙 강화

```javascript
// 프로덕션용 보안 규칙 예시
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 더 엄격한 규칙 적용
    match /users/{userId} {
      allow read, write: if request.auth != null &&
        request.auth.uid == userId &&
        request.auth.token.email_verified == true;
    }
  }
}
```

### 8.2 App Check 설정

1. Firebase Console에서 App Check 활성화
2. 앱에서 App Check 구현

### 8.3 모니터링 설정

1. Firebase Console에서 모니터링 활성화
2. 오류 알림 설정

## 9. 추가 기능

### 9.1 푸시 알림 (선택사항)

1. Firebase Cloud Messaging 설정
2. 앱에서 푸시 알림 구현

### 9.2 분석 (선택사항)

1. Firebase Analytics 설정
2. 사용자 행동 분석 구현

이 설정을 완료하면 온라인 멀티플레이어 게임, 친구 시스템, 실시간 게임 초대 등의 모든 기능을 사용할 수 있습니다.
