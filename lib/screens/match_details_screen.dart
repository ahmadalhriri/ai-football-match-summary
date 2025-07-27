import 'package:fball/constants/app_constants.dart' as constants;
import 'package:flutter/material.dart';
import 'package:fball/services/football_api_service.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> match;

  const MatchDetailsScreen({
    super.key,
    required this.match,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen>
    with SingleTickerProviderStateMixin {
  final FootballApiService _apiService = FootballApiService();
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _matchDetails;
  List<dynamic>? _lineups;
  List<dynamic>? _events;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMatchData();
  }

  Future<void> _loadMatchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fixtureId = widget.match['fixture']['id'];

      // Get match details and lineups in parallel
      final results = await Future.wait([
        _apiService.getMatchDetails(fixtureId),
        _apiService.getMatchLineups(fixtureId),
        _apiService.getMatchEvents(fixtureId),
      ]);

      if (mounted) {
        setState(() {
          _matchDetails = results[0] as Map<String, dynamic>;
          _lineups = results[1] as List<dynamic>;
          _events = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('تفاصيل المباراة'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'نظرة عامة'),
            Tab(text: 'التشكيلات'),
            Tab(text: 'الأحداث'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildLineupsTab(),
                    _buildEventsTab(),
                  ],
                ),
    );
  }

  Widget _buildEventList(String title, List<dynamic> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...events.map((event) => _buildEventItem(event)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(dynamic event) {
    final time = event['time']?['elapsed']?.toString() ?? '';
    final player = event['player'] ?? {};
    final playerName = player['name'] ?? 'غير معروف';
    final type = event['type'] ?? '';
    final detail = event['detail'] ?? '';
    final translatedDetail = _translateEventDetail(detail);
    final icon = _getEventIcon(type, detail);
    final iconColor = _getEventColor(type, detail);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: "$time' - $playerName - $translatedDetail",
              child: Text(
                "$time' - $playerName - $translatedDetail",
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_events == null || _events!.isEmpty) {
      return const Center(child: Text('لا توجد أحداث متاحة'));
    }

    final homeTeamName =
        widget.match['teams']['home']['name'] ?? 'الفريق المضيف';
    final awayTeamName =
        widget.match['teams']['away']['name'] ?? 'الفريق الضيف';

    final homeEvents = _events!
        .where((e) => e['team']?['id'] == widget.match['teams']['home']['id'])
        .toList();
    final awayEvents = _events!
        .where((e) => e['team']?['id'] == widget.match['teams']['away']['id'])
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildEventList(homeTeamName, homeEvents)),
          const SizedBox(width: 16),
          Expanded(child: _buildEventList(awayTeamName, awayEvents)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTeamsSection(),
          const SizedBox(height: 24),
          _buildMatchInfoSection(),
        ],
      ),
    );
  }

  Widget _buildTeamsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            children: [
              Image.network(
                widget.match['teams']['home']['logo'] ?? '',
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.sports_soccer, size: 80);
                },
              ),
              const SizedBox(height: 8),
              Text(
                widget.match['teams']['home']['name'] ?? 'الفريق المضيف',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Text(
          'VS',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Column(
            children: [
              Image.network(
                widget.match['teams']['away']['logo'] ?? '',
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.sports_soccer, size: 80);
                },
              ),
              const SizedBox(height: 8),
              Text(
                widget.match['teams']['away']['name'] ?? 'الفريق الضيف',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchInfoSection() {
    final fixture = widget.match['fixture'];
    final status = fixture['status']['short'];
    final statusArabic =
        constants.AppConstants.matchStatusArabic[status] ?? status;
    final goals = widget.match['goals'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fixture['venue']['name'] ?? 'ملعب غير معروف',
                  style: const TextStyle(fontSize: 16),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusArabic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatTime(fixture['date']),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            if (['FT', 'AET', 'PEN', '1H', '2H', 'HT'].contains(status))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${goals['home'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${goals['away'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineupsTab() {
    if (_lineups == null || _lineups!.length < 2) {
      return const Center(child: Text('لا توجد معلومات عن التشكيلات متاحة'));
    }

    final homeLineup = _lineups![0];
    final awayLineup = _lineups![1];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _buildTeamLineup(
                  widget.match['teams']['home']['name'] ?? 'الفريق المضيف',
                  homeLineup)),
          const SizedBox(width: 16),
          Expanded(
              child: _buildTeamLineup(
                  widget.match['teams']['away']['name'] ?? 'الفريق الضيف',
                  awayLineup)),
        ],
      ),
    );
  }

  Widget _buildTeamLineup(String title, Map<String, dynamic> team) {
    final startXI = (team['startXI'] as List<dynamic>?) ?? [];
    final substitutes = (team['substitutes'] as List<dynamic>?) ?? [];

    // Debug logging
    print('Team lineup data: $team');
    if (startXI.isNotEmpty) {
      print('First player data: ${startXI.first}');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (team['coach'] != null)
              Text('المدرب: ${team['coach']['name'] ?? 'غير معروف'}'),
            const SizedBox(height: 8),
            const Text('اللاعبين الأساسيين:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...startXI.map((player) {
              final p = player['player'] ?? player;
              print('Player data: $p'); // Debug log
              return _buildPlayerRow(p);
            }),
            const SizedBox(height: 16),
            const Text('الاحتياط:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...substitutes.map((player) {
              final p = player['player'] ?? player;
              print('Substitute data: $p'); // Debug log
              return _buildPlayerRow(p);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player) {
    // Extract player data from the nested structure
    final playerData = player['player'] ?? player;
    final name = playerData['name'] ?? 'غير معروف';
    final number = playerData['number']?.toString() ?? '-';
    final position = playerData['pos'] ?? '';
    final playerId = playerData['id'];
    final photoUrl = playerId != null
        ? 'https://media.api-sports.io/football/players/$playerId.png'
        : '';

    // Debug log for player data
    print('Building player row for: $name');
    print('Player ID: $playerId');
    print('Photo URL: $photoUrl');
    print('Full player data: $playerData');

    final positionColor = _getPositionColor(position);
    final positionIcon = _getPositionIcon(position);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    cacheWidth: 80, // 2x for retina displays
                    cacheHeight: 80,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading player photo for $name:');
                      print('Error: $error');
                      print('Stack trace: $stackTrace');
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.person,
                            size: 24, color: Colors.grey[600]),
                      );
                    },
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.person, size: 24, color: Colors.grey[600]),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: positionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        number,
                        style: TextStyle(
                          color: positionColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(positionIcon, size: 16, color: positionColor),
                    const SizedBox(width: 4),
                    Text(
                      position,
                      style: TextStyle(
                        fontSize: 12,
                        color: positionColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _translateEventDetail(String detail) {
    switch (detail) {
      case 'Goal':
      case 'Normal Goal':
        return 'هدف';
      case 'Own Goal':
        return 'هدف في مرماه';
      case 'Penalty':
        return 'ركلة جزاء';
      case 'Yellow Card':
        return 'بطاقة صفراء';
      case 'Red Card':
        return 'بطاقة حمراء';
      case 'Substitution':
        return 'تبديل';
      default:
        return detail;
    }
  }

  IconData _getEventIcon(String type, String detail) {
    final lowerDetail = detail.toLowerCase();

    if (type.toLowerCase() == 'goal' || lowerDetail.contains('goal')) {
      return Icons.sports_soccer;
    }
    if (type.toLowerCase() == 'card') {
      if (lowerDetail.contains('yellow')) return Icons.square_foot_outlined;
      if (lowerDetail.contains('red')) return Icons.stop_circle_outlined;
      return Icons.report;
    }
    if (type.toLowerCase() == 'substitution' ||
        lowerDetail.contains('substitution')) {
      return Icons.swap_horiz;
    }
    return Icons.info_outline;
  }

  Color _getEventColor(String type, String detail) {
    final lowerDetail = detail.toLowerCase();

    if (type.toLowerCase() == 'goal' || lowerDetail.contains('goal')) {
      return Colors.green;
    }
    if (type.toLowerCase() == 'card') {
      if (lowerDetail.contains('yellow')) return Colors.amber;
      if (lowerDetail.contains('red')) return Colors.red;
      return Colors.orange;
    }
    if (type.toLowerCase() == 'substitution' ||
        lowerDetail.contains('substitution')) {
      return Colors.blueAccent;
    }
    return Colors.grey;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'FT':
      case 'AET':
      case 'PEN':
        return Colors.green;
      case 'NS':
        return Colors.blue;
      case '1H':
      case '2H':
      case 'HT':
        return Colors.orange;
      case 'PST':
      case 'CANC':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'G':
        return Colors.red;
      case 'D':
        return Colors.blue;
      case 'M':
        return Colors.green;
      case 'F':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getPositionIcon(String position) {
    switch (position) {
      case 'G':
        return Icons.sports_handball;
      case 'D':
        return Icons.shield;
      case 'M':
        return Icons.sports_soccer;
      case 'F':
        return Icons.sports;
      default:
        return Icons.person;
    }
  }

  String _formatTime(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
