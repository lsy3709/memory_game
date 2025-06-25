// services/sound_service.dart

import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 사운드 서비스를 관리하는 클래스
class SoundService {
  static SoundService? _instance;
  static SoundService get instance => _instance ??= SoundService._();
  
  SoundService._();

  AudioPlayer? _backgroundPlayer;
  List<AudioPlayer> _effectPlayers = [];
  bool _isSoundEnabled = true;
  bool _isMusicEnabled = true;
  double _soundVolume = 1.0;
  double _musicVolume = 0.5;
  final Random _random = Random();
  bool _isInitialized = false;
  int _currentEffectPlayerIndex = 0;
  static const int maxEffectPlayers = 3; // 최대 3개의 효과음 플레이어 사용

  /// 사운드 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _backgroundPlayer = AudioPlayer();
      for (int i = 0; i < maxEffectPlayers; i++) {
        _effectPlayers.add(AudioPlayer());
      }
      _isInitialized = true;
      print('🔊 사운드 서비스 초기화 완료');
    } catch (e) {
      print('❌ 사운드 서비스 초기화 오류: $e');
    }
  }

  /// 사운드 활성화/비활성화
  bool get isSoundEnabled => _isSoundEnabled;
  set isSoundEnabled(bool value) {
    _isSoundEnabled = value;
    if (!value) {
      _stopBackgroundMusic();
    }
  }

  /// 음악 활성화/비활성화
  bool get isMusicEnabled => _isMusicEnabled;
  set isMusicEnabled(bool value) {
    _isMusicEnabled = value;
    if (!value) {
      _stopBackgroundMusic();
    } else {
      playBackgroundMusic();
    }
  }

  /// 사운드 볼륨
  double get soundVolume => _soundVolume;
  set soundVolume(double value) {
    _soundVolume = value.clamp(0.0, 1.0);
  }

  /// 음악 볼륨
  double get musicVolume => _musicVolume;
  set musicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    if (_backgroundPlayer != null) {
      _backgroundPlayer!.setVolume(_musicVolume);
    }
  }

  /// 랜덤 BGM 선택 (bgm1 ~ bgm10)
  String _getRandomBGM() {
    final bgmNumber = _random.nextInt(10) + 1; // 1~10
    return 'sounds/bgm/bgm$bgmNumber.wav';
  }

  /// 배경 음악 재생
  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    // 초기화되지 않은 경우 초기화
    if (!_isInitialized) {
      await initialize();
    }

    final bgmPath = _getRandomBGM();
    
    try {
      _backgroundPlayer ??= AudioPlayer();
      
      // 이전 배경 음악이 재생 중이면 정지
      await _backgroundPlayer!.stop();
      
      // AudioPlayer 상태 확인 후 재생
      if (_backgroundPlayer!.state == PlayerState.stopped || 
          _backgroundPlayer!.state == PlayerState.completed) {
        await _backgroundPlayer!.play(AssetSource(bgmPath));
        await _backgroundPlayer!.setVolume(_musicVolume);
        await _backgroundPlayer!.setReleaseMode(ReleaseMode.loop);
        print('🎵 배경음악 재생 성공: $bgmPath');
      }
    } catch (e) {
      // 사운드 파일이 없거나 재생 오류가 발생하면 조용히 무시
      print('🔇 배경음악 재생 건너뜀: $bgmPath (파일이 없거나 오류 발생)');
    }
  }

  /// 배경 음악 정지
  Future<void> _stopBackgroundMusic() async {
    try {
      await _backgroundPlayer?.stop();
    } catch (e) {
      print('배경 음악 정지 오류: $e');
    }
  }

  /// 게임 시작 사운드
  Future<void> playGameStartSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/game_start.wav');
  }

  /// 카드 뒤집기 사운드
  Future<void> playCardFlipSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/card_flip.wav');
  }

  /// 카드 뒤집기 사운드 (기존 메서드명 호환성)
  Future<void> playCardFlip() async {
    await playCardFlipSound();
  }

  /// 카드 매치 사운드
  Future<void> playMatchSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/card_match.wav');
  }

  /// 카드 매치 성공 사운드 (새로운 메서드)
  Future<void> playMatchSuccessSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/card_match.wav');
  }

  /// 카드 매치 실패 사운드
  Future<void> playMismatchSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/card_mismatch.wav');
  }

  /// 카드 매치 실패 사운드 (새로운 메서드)
  Future<void> playMatchFailureSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/card_mismatch.wav');
  }

  /// 카드 매치 사운드 (기존 메서드명 호환성)
  Future<void> playCardMatch() async {
    await playMatchSound();
  }

  /// 카드 매치 실패 사운드 (기존 메서드명 호환성)
  Future<void> playCardMismatch() async {
    await playMismatchSound();
  }

  /// 게임 승리 사운드
  Future<void> playGameWinSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/game_win.wav');
  }

  /// 박수 효과음
  Future<void> playApplaudSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/applause.wav');
  }

  /// 게임 승리 사운드 (박수 효과음 포함)
  Future<void> playGameWin() async {
    if (!_isSoundEnabled) return;
    // 게임 승리 사운드와 박수 효과음을 순차적으로 재생
    await playGameWinSound();
    // 잠시 후 박수 효과음 재생
    Future.delayed(const Duration(milliseconds: 500), () {
      playApplaudSound();
    });
  }

  /// 게임 실패 사운드
  Future<void> playGameLose() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/effect/game_lose.wav');
  }

  /// 게임 종료 사운드 (기존 메서드명 호환성)
  Future<void> playGameOverSound() async {
    await playGameWinSound();
  }

  /// 버튼 클릭 사운드
  Future<void> playButtonClickSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/ui/button_click.wav');
  }

  /// 버튼 클릭 사운드 (기존 메서드명 호환성)
  Future<void> playButtonSound() async {
    await playButtonClickSound();
  }

  /// 배경 음악 정지 (기존 메서드명 호환성)
  Future<void> stopBackgroundMusic() async {
    await _stopBackgroundMusic();
  }

  /// 배경 음악 재개 (기존 메서드명 호환성)
  Future<void> resumeBackgroundMusic() async {
    await playBackgroundMusic();
  }

  /// 배경 음악 시작 (기존 메서드명 호환성)
  Future<void> startBackgroundMusic() async {
    await playBackgroundMusic();
  }

  /// 배경 음악 일시정지 (기존 메서드명 호환성)
  Future<void> pauseBackgroundMusic() async {
    await _stopBackgroundMusic();
  }

  /// 게임 시작 사운드 (기존 메서드명 호환성)
  Future<void> playGameStart() async {
    await playGameStartSound();
  }

  /// 사운드 파일 존재 여부 확인
  bool _isSoundFileAvailable(String assetPath) {
    // 실제 사운드 파일이 있는지 확인하는 대신, 
    // 사운드 재생을 시도하고 오류가 발생하면 무시하는 방식으로 처리
    return true;
  }

  /// 효과음 재생 (내부 메서드)
  Future<void> _playSound(String assetPath) async {
    if (!_isSoundEnabled) return;
    
    // 초기화되지 않은 경우 초기화
    if (!_isInitialized) {
      await initialize();
    }
    
    // 사용 가능한 플레이어 찾기
    AudioPlayer? availablePlayer;
    int attempts = 0;
    
    while (attempts < maxEffectPlayers) {
      final player = _effectPlayers[_currentEffectPlayerIndex];
      
      try {
        // 플레이어 상태 확인
        if (player.state == PlayerState.stopped || 
            player.state == PlayerState.completed) {
          availablePlayer = player;
          break;
        }
      } catch (e) {
        // 상태 확인 실패 시 다음 플레이어 시도
        print('플레이어 상태 확인 실패: $e');
      }
      
      // 다음 플레이어로 이동
      _currentEffectPlayerIndex = (_currentEffectPlayerIndex + 1) % maxEffectPlayers;
      attempts++;
    }
    
    // 사용 가능한 플레이어가 없으면 첫 번째 플레이어 강제 사용
    if (availablePlayer == null) {
      availablePlayer = _effectPlayers[0];
      try {
        await availablePlayer.stop();
      } catch (e) {
        print('플레이어 강제 정지 실패: $e');
        return; // 재생 포기
      }
    }
    
    try {
      // 안전하게 재생
      await availablePlayer.play(AssetSource(assetPath));
      await availablePlayer.setVolume(_soundVolume);
      print('🔊 효과음 재생 성공: $assetPath');
      
      // 다음 플레이어로 인덱스 이동
      _currentEffectPlayerIndex = (_currentEffectPlayerIndex + 1) % maxEffectPlayers;
    } catch (e) {
      // 사운드 파일이 없거나 재생 오류가 발생하면 조용히 무시
      print('🔇 사운드 재생 건너뜀: $assetPath (파일이 없거나 오류 발생)');
    }
  }

  /// 모든 사운드 정지
  Future<void> stopAllSounds() async {
    try {
      await _backgroundPlayer?.stop();
      for (AudioPlayer player in _effectPlayers) {
        await player.stop();
      }
    } catch (e) {
      print('사운드 정지 오류: $e');
    }
  }

  /// 리소스 해제
  Future<void> dispose() async {
    try {
      await _backgroundPlayer?.dispose();
      for (AudioPlayer player in _effectPlayers) {
        await player.dispose();
      }
      _backgroundPlayer = null;
      _effectPlayers.clear();
    } catch (e) {
      print('사운드 서비스 해제 오류: $e');
    }
  }
}