import 'package:flutter/material.dart';
import '../models/game_record.dart';
import '../models/player_stats.dart';
import '../services/firebase_service.dart';

/// 온라인 내 기록 보기 화면
class OnlineMyRecordsScreen extends StatefulWidget {
  const OnlineMyRecordsScreen({super.key});

  @override
  _OnlineMyRecordsScreenState createState() => _OnlineMyRecordsScreenState();
}

class _OnlineMyRecordsScreenState extends State<OnlineMyRecordsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  
  List<GameRecord> _myRecords = [];
  PlayerStats? _myStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 내 데이터 로드
  Future<void> _loadMyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 내 게임 기록과 통계를 동시에 로드
      final futures = await Future.wait([
        _firebaseService.getUserOnlineGameRecords(),
        _firebaseService.getOnlinePlayerStats(),
      ]);

      setState(() {
        _myRecords = futures[0] as List<GameRecord>;
        _myStats = futures[1] as PlayerStats?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 시간 포맷팅
  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 통계 카드 위젯
  Widget _buildStatsCard() {
    if (_myStats == null) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              '아직 게임 기록이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '내 통계',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '총 게임',
                    '${_myStats!.totalGames}',
                    Icons.games,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '승리',
                    '${_myStats!.totalWins}',
                    Icons.emoji_events,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '승률',
                    '${_myStats!.totalGames > 0 ? ((_myStats!.totalWins / _myStats!.totalGames) * 100).toStringAsFixed(1) : 0}%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '최고 점수',
                    '${_myStats!.bestScore}',
                    Icons.star,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '최고 콤보',
                    '${_myStats!.maxCombo}',
                    Icons.flash_on,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '최고 시간',
                    _formatTime(_myStats!.bestTime),
                    Icons.timer,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '총 매칭',
                    '${_myStats!.totalMatchCount}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '총 실패',
                    '${_myStats!.totalFailCount}',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 통계 아이템 위젯
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// 게임 기록 아이템 위젯
  Widget _buildRecordItem(GameRecord record, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: record.isCompleted ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
          child: Icon(
            record.isCompleted ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          '${record.score}점',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('매칭: ${record.matchCount}회 / 실패: ${record.failCount}회'),
            Text('최고 콤보: ${record.maxCombo}회'),
            Text('완료 시간: ${_formatTime(record.timeLeft)}'),
            Text('날짜: ${_formatDate(record.createdAt)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.isCompleted ? '완료' : '미완료',
              style: TextStyle(
                color: record.isCompleted ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${index + 1}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 기록'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyData,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '통계'),
            Tab(text: '게임 기록'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // 통계 탭
                RefreshIndicator(
                  onRefresh: _loadMyData,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildStatsCard(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // 게임 기록 탭
                RefreshIndicator(
                  onRefresh: _loadMyData,
                  child: _myRecords.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '아직 게임 기록이 없습니다.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _myRecords.length,
                          itemBuilder: (context, index) {
                            return _buildRecordItem(_myRecords[index], index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 