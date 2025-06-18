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
