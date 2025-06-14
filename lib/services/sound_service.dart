// services/sound_service.dart

import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  // 효과음과 BGM을 재생할 플레이어 인스턴스
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer    = AudioPlayer();
  final Random _random            = Random();

  bool _isBgmPlaying = false;

  SoundService() {
    // 효과음은 low-latency 모드로 설정
    _effectPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  Future<void> playButtonSound() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/ui/button_click.wav'),
      );
    } catch (e) {
      print('Error playing button sound: $e');
    }
  }

  Future<void> playCardFlip() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/card_flip.wav'),
      );
    } catch (e) {
      print('Error playing card flip: $e');
    }
  }

  Future<void> playCardMatch() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/card_match.wav'),
      );
    } catch (e) {
      print('Error playing card match: $e');
    }
  }

  Future<void> playCardMismatch() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/card_mismatch.wav'),
      );
    } catch (e) {
      print('Error playing card mismatch: $e');
    }
  }

  Future<void> playGameStart() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/game_start.wav'),
      );
    } catch (e) {
      print('Error playing game start: $e');
    }
  }

  Future<void> playGameWin() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/game_win.wav'),
      );
      // 1.5초 후에 박수 효과음 추가 재생
      Future.delayed(const Duration(milliseconds: 1500), () {
        _effectPlayer.play(
          AssetSource('sounds/effect/applause.wav'),
        );
      });
    } catch (e) {
      print('Error playing game win: $e');
    }
  }

  Future<void> startBackgroundMusic() async {
    if (_isBgmPlaying) {
      await _bgmPlayer.stop();
    }
    try {
      final int track = _random.nextInt(10) + 1;
      await _bgmPlayer.play(
        AssetSource('sounds/bgm/bgm$track.wav'),
      );
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      _isBgmPlaying = true;
    } catch (e) {
      print('Error playing BGM: $e');
    }
  }

  Future<void> pauseBackgroundMusic() async {
    if (_isBgmPlaying) {
      await _bgmPlayer.pause();
    }
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_isBgmPlaying) {
      await _bgmPlayer.resume();
      _isBgmPlaying = true;
    }
  }

  Future<void> stopBackgroundMusic() async {
    await _bgmPlayer.stop();
    _isBgmPlaying = false;
  }

  void dispose() {
    _effectPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
