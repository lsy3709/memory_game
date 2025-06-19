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

  /// 배경 음악 재생
  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      _backgroundPlayer ??= AudioPlayer();
      await _backgroundPlayer!.play(AssetSource('sounds/background_music.mp3'));
      await _backgroundPlayer!.setVolume(_musicVolume);
      await _backgroundPlayer!.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      print('배경 음악 재생 오류: $e');
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
    await _playSound('sounds/game_start.mp3');
  }

  /// 카드 뒤집기 사운드
  Future<void> playCardFlipSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/card_flip.mp3');
  }

  /// 카드 매치 사운드
  Future<void> playMatchSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/match.mp3');
  }

  /// 카드 매치 실패 사운드
  Future<void> playMismatchSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/mismatch.mp3');
  }

  /// 게임 종료 사운드
  Future<void> playGameOverSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/game_over.mp3');
  }

  /// 버튼 클릭 사운드
  Future<void> playButtonClickSound() async {
    if (!_isSoundEnabled) return;
    await _playSound('sounds/button_click.mp3');
  }

  /// 효과음 재생 (내부 메서드)
  Future<void> _playSound(String assetPath) async {
    try {
      _effectPlayer ??= AudioPlayer();
      await _effectPlayer!.play(AssetSource(assetPath));
      await _effectPlayer!.setVolume(_soundVolume);
    } catch (e) {
      print('효과음 재생 오류 ($assetPath): $e');
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