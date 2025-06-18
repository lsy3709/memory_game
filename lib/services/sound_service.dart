// services/sound_service.dart

import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  // 효과음과 배경음악(BGM) 재생을 위한 AudioPlayer 인스턴스
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer    = AudioPlayer();
  final Random _random            = Random(); // 랜덤 BGM 선택용

  bool _isBgmPlaying = false; // BGM 재생 상태 플래그

  SoundService() {
    // 효과음 플레이어를 저지연 모드로 설정
    _effectPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  // 버튼 클릭 효과음 재생
  Future<void> playButtonSound() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/ui/button_click.wav'),
      );
    } catch (e) {
      print('Error playing button sound: $e');
    }
  }

  // 카드 뒤집기 효과음 재생
  Future<void> playCardFlip() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/card_flip.wav'),
      );
    } catch (e) {
      print('Error playing card flip: $e');
    }
  }

  // 카드 매치 성공 효과음 재생
  Future<void> playCardMatch() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/card_match.wav'),
      );
    } catch (e) {
      print('Error playing card match: $e');
    }
  }

  // 카드 매치 실패 효과음 재생
  Future<void> playCardMismatch() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/card_mismatch.wav'),
      );
    } catch (e) {
      print('Error playing card mismatch: $e');
    }
  }

  // 게임 시작 효과음 재생
  Future<void> playGameStart() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/game_start.wav'),
      );
    } catch (e) {
      print('Error playing game start: $e');
    }
  }

  // 게임 승리 효과음 및 박수 소리 재생
  Future<void> playGameWin() async {
    try {
      await _effectPlayer.play(
        AssetSource('sounds/effect/game_win.wav'),
      );
      // 1.5초 후 박수 효과음 추가 재생
      Future.delayed(const Duration(milliseconds: 1500), () {
        _effectPlayer.play(
          AssetSource('sounds/effect/applause.wav'),
        );
      });
    } catch (e) {
      print('Error playing game win: $e');
    }
  }

  // 랜덤 BGM 트랙을 선택해 배경음악 재생 (반복)
  Future<void> startBackgroundMusic() async {
    if (_isBgmPlaying) {
      await _bgmPlayer.stop();
    }
    try {
      final int track = _random.nextInt(10) + 1; // 1~10번 트랙 중 랜덤 선택
      await _bgmPlayer.play(
        AssetSource('sounds/bgm/bgm$track.wav'),
      );
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop); // 반복 재생
      _isBgmPlaying = true;
    } catch (e) {
      print('Error playing BGM: $e');
    }
  }

  // 배경음악 일시정지
  Future<void> pauseBackgroundMusic() async {
    if (_isBgmPlaying) {
      await _bgmPlayer.pause();
    }
  }

  // 배경음악 재개
  Future<void> resumeBackgroundMusic() async {
    if (!_isBgmPlaying) {
      await _bgmPlayer.resume();
      _isBgmPlaying = true;
    }
  }

  // 배경음악 정지
  Future<void> stopBackgroundMusic() async {
    await _bgmPlayer.stop();
    _isBgmPlaying = false;
  }

  // 플레이어 리소스 해제
  void dispose() {
    _effectPlayer.dispose();
    _bgmPlayer.dispose();
  }
}