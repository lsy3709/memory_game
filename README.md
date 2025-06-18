# 메모리 카드 게임

Flutter로 개발된 메모리 카드 게임 앱입니다. 로컬 및 온라인 모드를 지원하며, 다양한 게임 기능을 제공합니다.

## 주요 기능

### 🎮 게임 모드

- **로컬 싱글플레이어**: 개인 연습 모드
- **로컬 멀티플레이어**: 2인 대결 모드
- **온라인 싱글플레이어**: 전 세계 플레이어와 경쟁
- **온라인 멀티플레이어**: 온라인 2인 대결

### 📊 기록 시스템

- **로컬 기록**: 기기 내 저장
- **온라인 랭킹**: Firebase 기반 전 세계 랭킹
- **개인 통계**: 상세한 게임 통계 제공
- **멀티플레이어 기록**: 2인 대결 결과 비교

### 🏆 랭킹 시스템

- **점수 순**: 최고 점수 기준
- **시간 순**: 빠른 완료 시간 기준
- **콤보 순**: 최고 연속 매칭 기준
- **최근 기록**: 최신 게임 기록

### 🔐 온라인 기능

- **Firebase 인증**: 이메일/비밀번호 로그인
- **실시간 랭킹**: 전 세계 플레이어와 실시간 비교
- **클라우드 저장**: 게임 기록 자동 동기화
- **개인 통계**: 온라인 게임 통계 관리

## 게임 규칙

1. **목표**: 15분 제한 시간 내에 모든 카드 쌍을 맞추기
2. **점수**:
   - 매칭 성공: +10점
   - 매칭 실패: -2점
   - 콤보 보너스: 연속 매칭 시 추가 점수
3. **카드**: 8x6 그리드, 총 48장 (24쌍)
4. **시간**: 15분 제한 시간

## 설치 및 실행

### 필수 요구사항

- Flutter SDK 3.1.3 이상
- Dart SDK 3.0.0 이상
- Android Studio / VS Code

### 설치 단계

1. **저장소 클론**

   ```bash
   git clone <repository-url>
   cd memory_game
   ```

2. **의존성 설치**

   ```bash
   flutter pub get
   ```

3. **Firebase 설정** (온라인 기능 사용 시)

   - [FIREBASE_SETUP.md](FIREBASE_SETUP.md) 파일 참조
   - Firebase 프로젝트 생성 및 설정
   - `google-services.json` 파일 배치

4. **앱 실행**
   ```bash
   flutter run
   ```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/                   # 데이터 모델
│   ├── card_model.dart
│   ├── game_record.dart
│   ├── player_stats.dart
│   ├── score_model.dart
│   └── multiplayer_game_record.dart
├── screens/                  # 화면
│   ├── main_screen.dart
│   ├── game_screen.dart
│   ├── online_game_screen.dart
│   ├── online_login_screen.dart
│   ├── online_main_screen.dart
│   ├── online_ranking_screen.dart
│   ├── online_my_records_screen.dart
│   ├── multiplayer_setup_screen.dart
│   ├── multiplayer_game_screen.dart
│   ├── multiplayer_comparison_screen.dart
│   ├── player_registration_screen.dart
│   ├── login_screen.dart
│   └── ranking_screen.dart
├── services/                 # 서비스
│   ├── storage_service.dart
│   ├── sound_service.dart
│   └── firebase_service.dart
└── widgets/                  # 위젯
    └── memory_card.dart
```

## 기술 스택

- **프레임워크**: Flutter
- **언어**: Dart
- **백엔드**: Firebase
  - Authentication (인증)
  - Firestore (데이터베이스)
  - Storage (파일 저장)
- **로컬 저장소**: SharedPreferences
- **사운드**: audioplayers
- **유틸리티**: uuid, email_validator, crypto

## 주요 기능 상세

### 온라인 게임 시스템

- **실시간 인증**: Firebase Auth를 통한 안전한 로그인
- **클라우드 동기화**: 게임 기록 자동 저장 및 동기화
- **전 세계 랭킹**: 실시간 랭킹 시스템
- **개인 통계**: 상세한 게임 분석 및 통계

### 멀티플레이어 시스템

- **턴 기반 게임**: 공정한 턴 시스템
- **실시간 점수**: 각 플레이어별 실시간 점수 표시
- **상세 비교**: 게임 종료 후 상세한 결과 비교
- **매칭 히스토리**: 각 플레이어의 매칭 기록 추적

### 사운드 시스템

- **배경음악**: 다양한 배경음악 지원
- **효과음**: 카드 뒤집기, 매칭, 버튼 클릭 등
- **볼륨 제어**: 개별 사운드 볼륨 조절

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 문의사항

프로젝트에 대한 문의사항이나 버그 리포트는 Issues 탭을 이용해 주세요.
