# 🚀 앱 배포 체크리스트

## 📋 사전 준비사항

### 1. Firebase 설정 완료

- [ ] Firebase 프로젝트 생성 완료
- [ ] Android 앱 등록 (`google-services.json` 파일 다운로드)
- [ ] iOS 앱 등록 (`GoogleService-Info.plist` 파일 다운로드)
- [ ] Authentication 활성화 (이메일/비밀번호)
- [ ] Firestore Database 생성 및 보안 규칙 설정
- [ ] Firestore 인덱스 생성 (11개 복합 인덱스)

### 2. 앱 설정 파일 확인

- [ ] `lib/firebase_options.dart` 파일 존재
- [ ] `android/app/google-services.json` 파일 존재
- [ ] `ios/Runner/GoogleService-Info.plist` 파일 존재
- [ ] `pubspec.yaml` 의존성 최신화

### 3. 코드 품질 검사

- [ ] 모든 import 문 정리
- [ ] 사용하지 않는 코드 제거
- [ ] 에러 처리 개선
- [ ] 로깅 최적화
- [ ] 성능 최적화

## 🔧 빌드 설정

### Android 빌드

```bash
# 릴리즈 빌드
flutter build apk --release

# App Bundle (Google Play Store용)
flutter build appbundle --release
```

### iOS 빌드

```bash
# 릴리즈 빌드
flutter build ios --release

# Archive (App Store용)
flutter build ipa --release
```

## 📱 플랫폼별 배포

### Google Play Store 배포

1. **앱 서명 설정**

   - [ ] 키스토어 파일 생성
   - [ ] `android/key.properties` 파일 설정
   - [ ] 서명된 APK/AAB 생성

2. **Google Play Console 설정**

   - [ ] 개발자 계정 생성
   - [ ] 앱 등록
   - [ ] 앱 정보 입력 (제목, 설명, 스크린샷)
   - [ ] 개인정보처리방침 URL
   - [ ] 콘텐츠 등급 설정

3. **업로드 및 검토**
   - [ ] AAB 파일 업로드
   - [ ] 릴리즈 노트 작성
   - [ ] 내부 테스트 그룹 설정
   - [ ] 검토 제출

### App Store 배포

1. **Apple Developer 설정**

   - [ ] Apple Developer 계정
   - [ ] App ID 등록
   - [ ] 프로비저닝 프로파일 생성
   - [ ] 인증서 생성

2. **App Store Connect 설정**

   - [ ] 앱 등록
   - [ ] 앱 정보 입력
   - [ ] 스크린샷 및 미리보기 비디오
   - [ ] 개인정보처리방침 URL

3. **업로드 및 검토**
   - [ ] IPA 파일 업로드
   - [ ] 빌드 버전 설정
   - [ ] 검토 제출

## 🔒 보안 설정

### Firebase 보안

- [ ] App Check 활성화 (프로덕션)
- [ ] Firestore 보안 규칙 강화
- [ ] Authentication 설정 검토
- [ ] API 키 보안 설정

### 앱 보안

- [ ] ProGuard/R8 설정 (Android)
- [ ] 코드 난독화
- [ ] 민감한 정보 암호화
- [ ] 네트워크 보안 설정

## 📊 모니터링 설정

### Firebase 모니터링

- [ ] Crashlytics 활성화
- [ ] Performance Monitoring 설정
- [ ] Analytics 설정
- [ ] 오류 알림 설정

### 앱 모니터링

- [ ] 로그 수집 설정
- [ ] 성능 모니터링
- [ ] 사용자 행동 분석
- [ ] 오류 추적

## 🧪 테스트

### 기능 테스트

- [ ] 로컬 게임 플레이
- [ ] 온라인 로그인/회원가입
- [ ] 멀티플레이어 게임
- [ ] 친구 시스템
- [ ] 랭킹 시스템
- [ ] 사운드 기능

### 성능 테스트

- [ ] 메모리 사용량 확인
- [ ] 배터리 소모량 확인
- [ ] 네트워크 사용량 확인
- [ ] 앱 시작 시간 측정

### 호환성 테스트

- [ ] 다양한 Android 버전 테스트
- [ ] 다양한 iOS 버전 테스트
- [ ] 다양한 화면 크기 테스트
- [ ] 다양한 기기 테스트

## 📝 배포 후 관리

### 버전 관리

- [ ] 버전 번호 업데이트
- [ ] 변경사항 문서화
- [ ] 릴리즈 노트 작성
- [ ] Git 태그 생성

### 사용자 지원

- [ ] FAQ 작성
- [ ] 사용자 가이드 작성
- [ ] 문의 채널 설정
- [ ] 피드백 수집 시스템

### 업데이트 계획

- [ ] 정기 업데이트 일정
- [ ] 기능 개선 계획
- [ ] 버그 수정 계획
- [ ] 사용자 피드백 반영

## 🚨 문제 해결

### 일반적인 문제

- [ ] 빌드 오류 해결
- [ ] 서명 오류 해결
- [ ] 업로드 오류 해결
- [ ] 검토 거부 대응

### 성능 문제

- [ ] 메모리 누수 해결
- [ ] 배터리 소모 최적화
- [ ] 네트워크 사용량 최적화
- [ ] 앱 크기 최적화

## 📞 지원 정보

### 개발자 정보

- 개발자: GoldMagnetSoft
- 이메일: [개발자 이메일]
- 웹사이트: [개발자 웹사이트]

### 기술 지원

- Firebase Console: https://console.firebase.google.com/
- Google Play Console: https://play.google.com/console/
- App Store Connect: https://appstoreconnect.apple.com/

### 문서

- Firebase 설정: `FIREBASE_SETUP.md`
- 앱 사용법: `README.md`
- 문제 해결: 이 문서의 문제 해결 섹션
