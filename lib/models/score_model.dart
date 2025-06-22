import 'dart:math';

/// 게임 점수 모델
class ScoreModel {
  int _score = 0;
  int _matchCount = 0;
  int _failCount = 0;
  int _maxCombo = 0;
  int _currentCombo = 0;
  int _timeLeft = 0;
  int _totalTime = 0;
  bool _isCompleted = false;

  ScoreModel();

  /// 현재 점수
  int get score => _score;

  /// 매치 횟수
  int get matchCount => _matchCount;

  /// 실패 횟수
  int get failCount => _failCount;

  /// 최대 콤보
  int get maxCombo => _maxCombo;

  /// 현재 콤보
  int get currentCombo => _currentCombo;

  /// 남은 시간
  int get timeLeft => _timeLeft;

  /// 총 시간
  int get totalTime => _totalTime;

  /// 게임 완료 여부
  bool get isCompleted => _isCompleted;

  /// 점수 추가
  void addScore(int points) {
    _score += points;
    _currentCombo++;
    if (_currentCombo > _maxCombo) {
      _maxCombo = _currentCombo;
    }
  }

  /// 매치 성공
  void addMatch() {
    _matchCount++;
    addScore(10);
  }

  /// 매치 성공 (기존 메서드명 호환성)
  void addMatchScore() {
    _matchCount++;
    _currentCombo++;
    _score += 100 + (_currentCombo * 10);
  }

  /// 매치 실패
  void addFail() {
    _failCount++;
    _currentCombo = 0;
  }

  /// 매치 실패 (기존 메서드명 호환성)
  void addFailPenalty() {
    _failCount++;
    _currentCombo = 0;
    _score = max(0, _score - 10); // 음수 점수 방지
  }

  /// 시간 설정
  void setTime(int timeLeft, int totalTime) {
    _timeLeft = timeLeft;
    _totalTime = totalTime;
  }

  /// 게임 완료 설정
  void setCompleted(bool completed) {
    _isCompleted = completed;
  }

  /// 점수 초기화
  void reset() {
    _score = 0;
    _matchCount = 0;
    _failCount = 0;
    _maxCombo = 0;
    _currentCombo = 0;
    _timeLeft = 0;
    _totalTime = 0;
    _isCompleted = false;
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'score': _score,
      'matchCount': _matchCount,
      'failCount': _failCount,
      'maxCombo': _maxCombo,
      'currentCombo': _currentCombo,
      'timeLeft': _timeLeft,
      'totalTime': _totalTime,
      'isCompleted': _isCompleted,
    };
  }

  /// JSON에서 생성
  factory ScoreModel.fromJson(Map<String, dynamic> json) {
    final model = ScoreModel();
    model._score = json['score'] ?? 0;
    model._matchCount = json['matchCount'] ?? 0;
    model._failCount = json['failCount'] ?? 0;
    model._maxCombo = json['maxCombo'] ?? 0;
    model._currentCombo = json['currentCombo'] ?? 0;
    model._timeLeft = json['timeLeft'] ?? 0;
    model._totalTime = json['totalTime'] ?? 0;
    model._isCompleted = json['isCompleted'] ?? false;
    return model;
  }

  /// 현재 점수 (기존 getter명 호환성)
  int get currentScore => _score;

  /// 콤보 카운트 (기존 getter명 호환성)
  int get comboCount => _currentCombo;

  /// 최고 점수 (기존 getter명 호환성)
  int get bestScore => _score; // 단순화를 위해 현재 점수 반환
} 