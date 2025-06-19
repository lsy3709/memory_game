import 'package:flutter/material.dart';

import '../models/multiplayer_game_record.dart';
import '../models/score_model.dart';

/// 멀티플레이어 게임 결과 상세 비교 화면
/// 두 플레이어의 카드 매칭 기록을 상세히 비교
class MultiplayerComparisonScreen extends StatefulWidget {
  final PlayerGameData player1;
  final PlayerGameData player2;
  final int gameTime;

  const MultiplayerComparisonScreen({
    super.key,
    required this.player1,
    required this.player2,
    required this.gameTime,
  });

  @override
  _MultiplayerComparisonScreenState createState() => _MultiplayerComparisonScreenState();
}

class _MultiplayerComparisonScreenState extends State<MultiplayerComparisonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 게임 시간을 mm:ss 형식으로 반환
  String _formatGameTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 승자 찾기
  PlayerGameData? _getWinner() {
    final player1 = widget.player1;
    final player2 = widget.player2;
    
    if (player1.scoreModel.score > player2.scoreModel.score) {
      return player1;
    } else if (player2.scoreModel.score > player1.scoreModel.score) {
      return player2;
    } else {
      // 점수가 같으면 매칭 성공률로 비교
      final rate1 = player1.scoreModel.matchCount / (player1.scoreModel.matchCount + player1.scoreModel.failCount);
      final rate2 = player2.scoreModel.matchCount / (player2.scoreModel.matchCount + player2.scoreModel.failCount);
      
      if (rate1 > rate2) return player1;
      if (rate2 > rate1) return player2;
      
      // 매칭 성공률도 같으면 무승부
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final winner = _getWinner();
    final isDraw = winner == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게임 결과 비교'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '요약'),
            Tab(text: '매칭 기록'),
            Tab(text: '통계'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 요약 탭
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSummaryTab(winner, isDraw),
          ),
          
          // 매칭 기록 탭
          _buildMatchHistoryTab(),
          
          // 통계 탭
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildStatisticsTab(),
          ),
        ],
      ),
    );
  }

  /// 요약 탭 위젯
  Widget _buildSummaryTab(PlayerGameData? winner, bool isDraw) {
    return Column(
      children: [
        // 승자 표시
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDraw ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDraw ? Colors.orange : Colors.green,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                isDraw ? Icons.handshake : Icons.emoji_events,
                size: 48,
                color: isDraw ? Colors.orange : Colors.amber,
              ),
              const SizedBox(height: 8),
              Text(
                isDraw ? '무승부!' : '${winner!.name} 승리!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '게임 시간: ${_formatGameTime(widget.gameTime)}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 플레이어 비교 카드
        Row(
          children: [
            Expanded(child: _buildPlayerSummaryCard(widget.player1, 0)),
            const SizedBox(width: 16),
            Expanded(child: _buildPlayerSummaryCard(widget.player2, 1)),
          ],
        ),
        const SizedBox(height: 24),

        // 주요 지표 비교
        _buildComparisonTable(),
      ],
    );
  }

  /// 플레이어 요약 카드 위젯
  Widget _buildPlayerSummaryCard(PlayerGameData player, int playerIndex) {
    final isWinner = _getWinner()?.name == player.name;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isWinner ? Colors.green : Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            player.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.green : Colors.black,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          Text(
            '${player.scoreModel.score}점',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text('매칭: ${player.scoreModel.matchCount}회'),
          Text('실패: ${player.scoreModel.failCount}회'),
          Text('최고 콤보: ${player.maxCombo}회'),
          if (isWinner) ...[
            const SizedBox(height: 8),
            const Icon(Icons.emoji_events, color: Colors.amber),
          ],
        ],
      ),
    );
  }

  /// 비교 테이블 위젯
  Widget _buildComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주요 지표 비교',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildComparisonRow('점수', 
            '${widget.player1.scoreModel.score}', 
            '${widget.player2.scoreModel.score}'),
          _buildComparisonRow('매칭 성공', 
            '${widget.player1.scoreModel.matchCount}회', 
            '${widget.player2.scoreModel.matchCount}회'),
          _buildComparisonRow('매칭 실패', 
            '${widget.player1.scoreModel.failCount}회', 
            '${widget.player2.scoreModel.failCount}회'),
          _buildComparisonRow('성공률', 
            '${(widget.player1.scoreModel.matchCount / (widget.player1.scoreModel.matchCount + widget.player1.scoreModel.failCount) * 100).toStringAsFixed(1)}%', 
            '${(widget.player2.scoreModel.matchCount / (widget.player2.scoreModel.matchCount + widget.player2.scoreModel.failCount) * 100).toStringAsFixed(1)}%'),
          _buildComparisonRow('최고 콤보', 
            '${widget.player1.maxCombo}회', 
            '${widget.player2.maxCombo}회'),
        ],
      ),
    );
  }

  /// 비교 행 위젯
  Widget _buildComparisonRow(String label, String value1, String value2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              value1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 매칭 기록 탭 위젯
  Widget _buildMatchHistoryTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.withOpacity(0.1),
            child: const TabBar(
              tabs: [
                Tab(text: '플레이어 1'),
                Tab(text: '플레이어 2'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPlayerMatchHistory(widget.player1),
                _buildPlayerMatchHistory(widget.player2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 플레이어 매칭 기록 위젯
  Widget _buildPlayerMatchHistory(PlayerGameData player) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: player.cardMatches.length,
      itemBuilder: (context, index) {
        final match = player.cardMatches[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    match.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
            title: Text('${match.matchNumber}번째 매칭'),
            subtitle: Text('매칭 시간: ${match.formattedMatchedAt}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '카드 ${match.pairId + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 통계 탭 위젯
  Widget _buildStatisticsTab() {
    return Column(
      children: [
        // 매칭 성공률 차트
        _buildMatchRateChart(),
        const SizedBox(height: 24),
        
        // 콤보 기록 차트
        _buildComboChart(),
        const SizedBox(height: 24),
        
        // 시간별 매칭 분포
        _buildTimeDistributionChart(),
      ],
    );
  }

  /// 매칭 성공률 차트 위젯
  Widget _buildMatchRateChart() {
    final rate1 = widget.player1.scoreModel.matchCount / (widget.player1.scoreModel.matchCount + widget.player1.scoreModel.failCount) * 100;
    final rate2 = widget.player2.scoreModel.matchCount / (widget.player2.scoreModel.matchCount + widget.player2.scoreModel.failCount) * 100;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매칭 성공률',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.player1.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: rate1 / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 4),
                    Text('${rate1.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.player2.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: rate2 / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 4),
                    Text('${rate2.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 콤보 차트 위젯
  Widget _buildComboChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최고 콤보 기록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.player1.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.player1.maxCombo}회',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.player2.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.player2.maxCombo}회',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 시간별 매칭 분포 차트 위젯
  Widget _buildTimeDistributionChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매칭 시간 분포',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('${widget.player1.name}: ${widget.player1.cardMatches.length}개 매칭'),
          Text('${widget.player2.name}: ${widget.player2.cardMatches.length}개 매칭'),
          const SizedBox(height: 16),
          const Text(
            '각 플레이어의 매칭 기록을 시간순으로 확인할 수 있습니다.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 