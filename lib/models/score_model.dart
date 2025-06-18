class ScoreModel {
  int currentScore;      // 현재 점수
  int comboCount;        // 연속 매칭 횟수
  int bestScore;         // 최고 점수
  int matchCount;        // 매칭 성공 횟수
  int failCount;         // 매칭 실패 횟수

  ScoreModel({
    this.currentScore = 0,
    this.comboCount = 0,
    this.bestScore = 0,
    this.matchCount = 0,
    this.failCount = 0,
  });

  // 점수 계산 메서드
  void addMatchScore() {
    // 기본 점수: 100점
    int baseScore = 100;
    
    // 콤보 보너스: 연속 매칭 시 점수 증가
    int comboBonus = comboCount > 1 ? comboCount * 50 : 0;
    
    // 최종 점수 계산
    int finalScore = baseScore + comboBonus;
    
    currentScore += finalScore;
    comboCount++;
    matchCount++;
    
    // 최고 점수 업데이트
    if (currentScore > bestScore) {
      bestScore = currentScore;
    }
  }

  // 매칭 실패 시 처리
  void addFailPenalty() {
    currentScore = (currentScore - 10).clamp(0, currentScore); // 최소 0점
    comboCount = 0;
    failCount++;
  }

  // 게임 리셋
  void reset() {
    currentScore = 0;
    comboCount = 0;
    matchCount = 0;
    failCount = 0;
  }
} 