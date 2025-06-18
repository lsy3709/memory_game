import 'package:flutter/material.dart';
import '../models/game_record.dart';
import '../services/firebase_service.dart';

/// 온라인 랭킹 화면
class OnlineRankingScreen extends StatefulWidget {
  const OnlineRankingScreen({super.key});

  @override
  _OnlineRankingScreenState createState() => _OnlineRankingScreenState();
}

class _OnlineRankingScreenState extends State<OnlineRankingScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  
  List<GameRecord> _scoreRankings = [];
  List<GameRecord> _timeRankings = [];
  List<GameRecord> _comboRankings = [];
  List<GameRecord> _recentRankings = [];
  
  bool _isLoading = true;
  String _selectedOrderBy = 'score';
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 랭킹 데이터 로드
  Future<void> _loadRankings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 점수 순 랭킹
      final scoreRankings = await _firebaseService.getOnlineRankings(
        limit: 50,
        orderBy: 'score',
        descending: true,
      );

      // 시간 순 랭킹
      final timeRankings = await _firebaseService.getOnlineRankings(
        limit: 50,
        orderBy: 'timeLeft',
        descending: true,
      );

      // 콤보 순 랭킹
      final comboRankings = await _firebaseService.getOnlineRankings(
        limit: 50,
        orderBy: 'maxCombo',
        descending: true,
      );

      // 최근 기록
      final recentRankings = await _firebaseService.getOnlineRankings(
        limit: 50,
        orderBy: 'createdAt',
        descending: true,
      );

      setState(() {
        _scoreRankings = scoreRankings;
        _timeRankings = timeRankings;
        _comboRankings = comboRankings;
        _recentRankings = recentRankings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('랭킹 로드 오류: $e'),
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

  /// 랭킹 아이템 위젯
  Widget _buildRankingItem(GameRecord record, int index, String type) {
    final isCurrentUser = record.email == _firebaseService.currentUser?.email;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isCurrentUser ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getRankColor(index + 1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.playerName,
                style: TextStyle(
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentUser ? Colors.blue : null,
                ),
              ),
            ),
            if (isCurrentUser)
              const Icon(
                Icons.person,
                color: Colors.blue,
                size: 16,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('점수: ${record.score}점'),
            Text('매칭: ${record.matchCount}회 / 실패: ${record.failCount}회'),
            Text('최고 콤보: ${record.maxCombo}회'),
            Text('완료 시간: ${_formatTime(record.timeLeft)}'),
            Text('날짜: ${_formatDate(record.createdAt)}'),
          ],
        ),
        trailing: _buildRankingValue(record, type),
      ),
    );
  }

  /// 랭킹 타입별 값 표시
  Widget _buildRankingValue(GameRecord record, String type) {
    switch (type) {
      case 'score':
        return Text(
          '${record.score}점',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        );
      case 'time':
        return Text(
          _formatTime(record.timeLeft),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        );
      case 'combo':
        return Text(
          '${record.maxCombo}콤보',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        );
      case 'recent':
        return Text(
          _formatDate(record.createdAt),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 순위별 색상
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 랭킹'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRankings,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '점수 순'),
            Tab(text: '시간 순'),
            Tab(text: '콤보 순'),
            Tab(text: '최근 기록'),
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
                // 점수 순 랭킹
                _buildRankingList(_scoreRankings, 'score'),
                // 시간 순 랭킹
                _buildRankingList(_timeRankings, 'time'),
                // 콤보 순 랭킹
                _buildRankingList(_comboRankings, 'combo'),
                // 최근 기록
                _buildRankingList(_recentRankings, 'recent'),
              ],
            ),
    );
  }

  /// 랭킹 리스트 위젯
  Widget _buildRankingList(List<GameRecord> rankings, String type) {
    if (rankings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '아직 기록이 없습니다.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRankings,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          return _buildRankingItem(rankings[index], index, type);
        },
      ),
    );
  }
} 