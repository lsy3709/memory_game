import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../models/game_record.dart';

/// 랭킹 보드 화면
/// 최고 점수, 최단 시간, 최고 연속 매칭 기록을 표시
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService.instance;
  
  late TabController _tabController;
  List<GameRecord> _topRankings = [];
  GameRecord? _bestScoreRecord;
  GameRecord? _bestTimeRecord;
  GameRecord? _bestComboRecord;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRankingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 랭킹 데이터 로드
  Future<void> _loadRankingData() async {
    setState(() => _isLoading = true);

    try {
      // 병렬로 모든 데이터 로드
      final futures = await Future.wait([
        _storageService.getTopRankings(limit: 20),
        _storageService.getBestScoreRecord(),
        _storageService.getBestTimeRecord(),
        _storageService.getBestComboRecord(),
      ]);

      setState(() {
        _topRankings = futures[0] as List<GameRecord>;
        _bestScoreRecord = futures[1] as GameRecord?;
        _bestTimeRecord = futures[2] as GameRecord?;
        _bestComboRecord = futures[3] as GameRecord?;
        _isLoading = false;
      });
    } catch (e) {
      print('랭킹 데이터 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 기록 카드 위젯 생성
  Widget _buildRecordCard(GameRecord record, String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.playerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      record.formattedCreatedAt,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${record.score}점',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '${record.matchCount}매칭 / ${record.failCount}실패',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (record.isCompleted) ...[
              const SizedBox(height: 8),
              Text(
                '완료 시간: ${record.formattedGameTime}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 랭킹 리스트 아이템 위젯 생성
  Widget _buildRankingItem(GameRecord record, int rank) {
    final isTop3 = rank <= 3;
    final rankColors = [Colors.amber, Colors.grey, Colors.brown];
    
    return Card(
      elevation: isTop3 ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTop3 ? rankColors[rank - 1] : Colors.blue,
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          record.playerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${record.formattedCreatedAt} • ${record.matchCount}매칭',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${record.score}점',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            if (record.isCompleted)
              Text(
                record.formattedGameTime,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
          ],
        ),
        onTap: () => _showRecordDetail(record),
      ),
    );
  }

  /// 기록 상세 정보 다이얼로그 표시
  void _showRecordDetail(GameRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record.playerName}의 기록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('점수', '${record.score}점'),
            _buildDetailRow('매칭 성공', '${record.matchCount}회'),
            _buildDetailRow('매칭 실패', '${record.failCount}회'),
            _buildDetailRow('최고 연속 매칭', '${record.maxCombo}회'),
            if (record.isCompleted) ...[
              _buildDetailRow('완료 시간', record.formattedGameTime),
              _buildDetailRow('남은 시간', '${record.timeLeft}초'),
            ],
            _buildDetailRow('생성 시간', record.formattedCreatedAt),
            _buildDetailRow('게임 완료', record.isCompleted ? '완료' : '미완료'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 상세 정보 행 위젯 생성
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('랭킹 보드'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '전체 랭킹'),
            Tab(text: '최고 점수'),
            Tab(text: '최단 시간'),
            Tab(text: '최고 콤보'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRankingData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 전체 랭킹 탭
                _topRankings.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 기록이 없습니다.\n게임을 플레이해보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _topRankings.length,
                        itemBuilder: (context, index) {
                          return _buildRankingItem(_topRankings[index], index + 1);
                        },
                      ),

                // 최고 점수 탭
                _bestScoreRecord == null
                    ? const Center(
                        child: Text(
                          '최고 점수 기록이 없습니다.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        child: _buildRecordCard(
                          _bestScoreRecord!,
                          '최고 점수 기록',
                          Icons.emoji_events,
                          Colors.amber,
                        ),
                      ),

                // 최단 시간 탭
                _bestTimeRecord == null
                    ? const Center(
                        child: Text(
                          '최단 시간 기록이 없습니다.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        child: _buildRecordCard(
                          _bestTimeRecord!,
                          '최단 시간 기록',
                          Icons.timer,
                          Colors.green,
                        ),
                      ),

                // 최고 콤보 탭
                _bestComboRecord == null
                    ? const Center(
                        child: Text(
                          '최고 연속 매칭 기록이 없습니다.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        child: _buildRecordCard(
                          _bestComboRecord!,
                          '최고 연속 매칭 기록',
                          Icons.local_fire_department,
                          Colors.orange,
                        ),
                      ),
              ],
            ),
    );
  }
} 