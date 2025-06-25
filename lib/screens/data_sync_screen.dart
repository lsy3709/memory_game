import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_sync_service.dart';
import '../services/hive_database_service.dart';
import '../models/hive_models.dart';

/// 데이터 동기화 설정 화면
class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  final DataSyncService _syncService = DataSyncService();
  final HiveDatabaseService _hiveService = HiveDatabaseService();
  
  bool _isAutoSyncEnabled = true;
  bool _isSyncing = false;
  Map<String, dynamic> _syncStatus = {};
  Map<String, dynamic> _overallStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 데이터 로드
  Future<void> _loadData() async {
    _isAutoSyncEnabled = _syncService.isAutoSyncEnabled;
    _isSyncing = _syncService.isSyncing;
    _syncStatus = await _syncService.getSyncStatus();
    _overallStats = _hiveService.getOverallStats();
    
    if (mounted) {
      setState(() {});
    }
  }

  /// 자동 동기화 설정 변경
  Future<void> _toggleAutoSync(bool value) async {
    try {
      await _syncService.setAutoSyncEnabled(value);
      _isAutoSyncEnabled = value;
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '자동 동기화가 활성화되었습니다.' : '자동 동기화가 비활성화되었습니다.'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('설정 변경 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 수동 동기화 실행
  Future<void> _performManualSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await _syncService.performManualSync();
      await _loadData(); // 데이터 새로고침
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('동기화가 완료되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('동기화 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  /// 특정 데이터 타입 동기화
  Future<void> _syncSpecificDataType(String dataType, String displayName) async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await _syncService.syncSpecificDataType(dataType);
      await _loadData(); // 데이터 새로고침
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$displayName 동기화가 완료되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$displayName 동기화 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('데이터 동기화'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 동기화 상태 카드
              _buildSyncStatusCard(),
              const SizedBox(height: 16),
              
              // 자동 동기화 설정 카드
              _buildAutoSyncCard(),
              const SizedBox(height: 16),
              
              // 수동 동기화 카드
              _buildManualSyncCard(),
              const SizedBox(height: 16),
              
              // 데이터 통계 카드
              _buildDataStatsCard(),
              const SizedBox(height: 16),
              
              // 데이터 관리 카드
              _buildDataManagementCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// 동기화 상태 카드
  Widget _buildSyncStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isSyncing ? Icons.sync : Icons.check_circle,
                  color: _isSyncing ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  '동기화 상태',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('상태', _isSyncing ? '동기화 중...' : '대기 중'),
            _buildStatusRow('자동 동기화', _isAutoSyncEnabled ? '활성화' : '비활성화'),
            _buildStatusRow('미동기화 게임 기록', '${_syncStatus['unsyncedGameRecords'] ?? 0}개'),
            _buildStatusRow('미동기화 멀티플레이어 기록', '${_syncStatus['unsyncedMultiplayerRecords'] ?? 0}개'),
            _buildStatusRow('총 로컬 기록', '${_syncStatus['totalLocalRecords'] ?? 0}개'),
            _buildStatusRow('데이터베이스 크기', '${_syncStatus['databaseSize'] ?? 0}개'),
          ],
        ),
      ),
    );
  }

  /// 자동 동기화 설정 카드
  Widget _buildAutoSyncCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '자동 동기화 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('자동 동기화'),
              subtitle: const Text('5분마다 자동으로 데이터를 동기화합니다'),
              value: _isAutoSyncEnabled,
              onChanged: _toggleAutoSync,
              secondary: const Icon(Icons.sync),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '• 네트워크 연결 시 자동 동기화\n'
                '• 5분 간격으로 백그라운드 동기화\n'
                '• 로컬 데이터를 Firebase에 업로드\n'
                '• Firebase 데이터를 로컬로 다운로드',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 수동 동기화 카드
  Widget _buildManualSyncCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '수동 동기화',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 전체 동기화 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _performManualSync,
                icon: _isSyncing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? '동기화 중...' : '전체 동기화'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 개별 데이터 타입 동기화
            const Text(
              '개별 동기화',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : () => _syncSpecificDataType('game_records', '게임 기록'),
                    child: const Text('게임 기록'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : () => _syncSpecificDataType('multiplayer_records', '멀티플레이어 기록'),
                    child: const Text('멀티플레이어'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSyncing ? null : () => _syncSpecificDataType('online_rooms', '온라인 방'),
                child: const Text('온라인 방'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 데이터 통계 카드
  Widget _buildDataStatsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  '데이터 통계',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('총 게임 수', '${_overallStats['totalGames'] ?? 0}개'),
            _buildStatusRow('로컬 게임', '${_overallStats['localGames'] ?? 0}개'),
            _buildStatusRow('온라인 게임', '${_overallStats['onlineGames'] ?? 0}개'),
            _buildStatusRow('완료된 게임', '${_overallStats['completedGames'] ?? 0}개'),
            _buildStatusRow('총 플레이어 수', '${_overallStats['totalPlayers'] ?? 0}명'),
            _buildStatusRow('평균 점수', '${(_overallStats['averageScore'] ?? 0).toStringAsFixed(1)}점'),
            _buildStatusRow('최고 점수', '${_overallStats['bestScore'] ?? 0}점'),
          ],
        ),
      ),
    );
  }

  /// 데이터 관리 카드
  Widget _buildDataManagementCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  '데이터 관리',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 데이터 삭제 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDeleteConfirmDialog('local'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('로컬 데이터 삭제'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDeleteConfirmDialog('online'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('온라인 데이터 삭제'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showDeleteConfirmDialog('all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('모든 데이터 삭제'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태 행 위젯
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(String type) {
    String title, content, actionText;
    
    switch (type) {
      case 'local':
        title = '로컬 데이터 삭제';
        content = '로컬에 저장된 모든 게임 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.';
        actionText = '로컬 데이터 삭제';
        break;
      case 'online':
        title = '온라인 데이터 삭제';
        content = '온라인에 저장된 모든 게임 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.';
        actionText = '온라인 데이터 삭제';
        break;
      case 'all':
        title = '모든 데이터 삭제';
        content = '로컬과 온라인에 저장된 모든 게임 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.';
        actionText = '모든 데이터 삭제';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteData(type);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }

  /// 데이터 삭제
  Future<void> _deleteData(String type) async {
    try {
      switch (type) {
        case 'local':
          await _hiveService.clearDataByType(GameType.local);
          break;
        case 'online':
          await _hiveService.clearDataByType(GameType.online);
          break;
        case 'all':
          await _hiveService.clearAllData();
          break;
      }
      
      await _loadData(); // 데이터 새로고침
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${type == 'all' ? '모든' : type == 'local' ? '로컬' : '온라인'} 데이터가 삭제되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터 삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 