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
  AudioPlayer? _effectPlayer;
  bool _isSoundEnabled = true;
  bool _isMusicEnabled = true;
  double _soundVolume = 1.0;
  double _musicVolume = 0.5;
  final Random _random = Random();

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
    return 'assets/sounds/bgm/bgm$bgmNumber.wav';
  }

  /// 배경 음악 재생
  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      _backgroundPlayer ??= AudioPlayer();
      final bgmPath = _getRandomBGM();
      await _backgroundPlayer!.play(AssetSource(bgmPath));
      await _backgroundPlayer!.setVolume(_musicVolume);
      await _backgroundPlayer!.setReleaseMode(ReleaseMode.loop);
      print('배경음악 재생: $bgmPath');
    } catch (e) {
      print('배경 음악 재생 오류: $e');
      // 사운드 파일이 없을 때는 오류를 무시하고 계속 진행
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
    await _playSound('assets/sounds/effect/game_start.wav');
  }

  /// 카드 뒤집기 사운드
  Future<void> playCardFlipSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('assets/sounds/effect/card_flip.wav');
  }

  /// 카드 뒤집기 사운드 (기존 메서드명 호환성)
  Future<void> playCardFlip() async {
    await playCardFlipSound();
  }

  /// 카드 매치 사운드
  Future<void> playMatchSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('assets/sounds/effect/card_match.wav');
  }

  /// 카드 매치 사운드 (기존 메서드명 호환성)
  Future<void> playCardMatch() async {
    await playMatchSound();
  }

  /// 카드 매치 실패 사운드
  Future<void> playMismatchSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('assets/sounds/effect/card_mismatch.wav');
  }

  /// 카드 매치 실패 사운드 (기존 메서드명 호환성)
  Future<void> playCardMismatch() async {
    await playMismatchSound();
  }

  /// 게임 승리 사운드
  Future<void> playGameWinSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('assets/sounds/effect/game_win.wav');
  }

  /// 박수 효과음
  Future<void> playApplaudSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('assets/sounds/effect/applause.wav');
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

  /// 게임 종료 사운드 (기존 메서드명 호환성)
  Future<void> playGameOverSound() async {
    await playGameWinSound();
  }

  /// 버튼 클릭 사운드
  Future<void> playButtonClickSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('assets/sounds/ui/button_click.wav');
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

  /// 효과음 재생 (내부 메서드)
  Future<void> _playSound(String assetPath) async {
    try {
      _effectPlayer ??= AudioPlayer();
      await _effectPlayer!.play(AssetSource(assetPath));
      await _effectPlayer!.setVolume(_soundVolume);
      print('효과음 재생: $assetPath');
    } catch (e) {
      print('효과음 재생 오류 ($assetPath): $e');
      // 사운드 파일이 없을 때는 오류를 무시하고 계속 진행
      // 실제 프로덕션에서는 기본 사운드 파일을 제공하거나 다른 방식으로 처리
    }
  }

  /// 모든 사운드 정지
  Future<void> stopAllSounds() async {
    try {
      await _backgroundPlayer?.stop();
      await _effectPlayer?.stop();
    } catch (e) {
      print('사운드 정지 오류: $e');
    }
  }

  /// 리소스 해제
  Future<void> dispose() async {
    try {
      await _backgroundPlayer?.dispose();
      await _effectPlayer?.dispose();
      _backgroundPlayer = null;
      _effectPlayer = null;
    } catch (e) {
      print('사운드 서비스 해제 오류: $e');
    }
  }
}