import 'package:flutter/material.dart';
import '../services/football_api_service.dart';
import '../constants/app_constants.dart';
import '../widgets/match_card.dart';

class LeagueDetailsScreen extends StatefulWidget {
  final String leagueName;
  final int leagueId;

  const LeagueDetailsScreen({
    super.key,
    required this.leagueName,
    required this.leagueId,
  });

  @override
  State<LeagueDetailsScreen> createState() => _LeagueDetailsScreenState();
}

class _LeagueDetailsScreenState extends State<LeagueDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FootballApiService _apiService = FootballApiService();
  int _selectedSeason = DateTime.now().year;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _standings = [];
  List<dynamic> _topScorers = [];
  List<dynamic> _matches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeagueData();
  }

  Future<void> _loadLeagueData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _standings = [];
      _topScorers = [];
      _matches = [];
    });

    try {
      final standings = await _apiService.getLeagueStandings(
          widget.leagueId, _selectedSeason);
      final scorers =
          await _apiService.getTopScorers(widget.leagueId, _selectedSeason);

      List<dynamic> matches = [];
      final today = DateTime.now();
      final isCurrentSeason = _selectedSeason == today.year;

      if (isCurrentSeason) {
        for (int i = -7; i < 30; i++) {
          final date = today.add(Duration(days: i));
          final dateStr = date.toString().split(' ')[0];
          final matchesResponse = await _apiService.getMatchesByDate(dateStr);
          final leagueMatches = matchesResponse
              .where((match) =>
                  match['league']['id'] == widget.leagueId &&
                  match['league']['season'] == _selectedSeason)
              .toList();
          matches.addAll(leagueMatches);
        }
      } else {
        final seasonMatches = await _apiService.getMatchesBySeason(
            widget.leagueId, _selectedSeason);
        matches = seasonMatches
            .where((match) =>
                match['league']['id'] == widget.leagueId &&
                match['league']['season'] == _selectedSeason)
            .toList();
      }

      setState(() {
        _standings = standings;
        _topScorers = scorers;
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء تحميل البيانات: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://media.api-sports.io/football/leagues/${widget.leagueId}.png',
                width: 32,
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.emoji_events,
                        color: Colors.amber, size: 20),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppConstants.championshipsArabic[widget.leagueName] ??
                    widget.leagueName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          DropdownButton<int>(
            value: _selectedSeason,
            dropdownColor: Colors.grey[900],
            underline: const SizedBox(),
            items: List.generate(
              DateTime.now().year - 2010 + 1,
              (index) => DropdownMenuItem(
                value: DateTime.now().year - index,
                child: Text(
                  '${DateTime.now().year - index}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedSeason = value;
                });
                _loadLeagueData();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
        // <-- FIXED: Added controller here!
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Selected tab text color

          labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color:
                  Color.fromARGB(255, 41, 92, 210)), // Selected tab text style
          unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold), // Unselected tab text style
          indicatorColor: const Color.fromARGB(
              255, 41, 92, 210), // Underline indicator color
          tabs: const [
            Tab(text: 'ترتيب'),
            Tab(text: 'الهدافين'),
            Tab(text: 'المباريات'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLeagueData,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStandingsTab(),
                    _buildTopScorersTab(),
                    _buildMatchesTab(),
                  ],
                ),
    );
  }

  Widget _buildStandingsTab() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor:
              WidgetStateColor.resolveWith((states) => Colors.grey[900]!),
          columns: const [
            DataColumn(
                label: Text('المركز', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('الفريق', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('ل', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('ف', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('ت', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('خ', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('له', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('عليه', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('فارق', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('النقاط', style: TextStyle(color: Colors.white))),
          ],
          rows: _standings.map((team) {
            return DataRow(
              cells: [
                DataCell(Text(team['rank'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        team['team']['logo'],
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.sports_soccer, size: 24);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(team['team']['name'],
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                DataCell(Text(team['all']['played'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['all']['win'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['all']['draw'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['all']['lose'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['all']['goals']['for'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['all']['goals']['against'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['goalsDiff'].toString(),
                    style: const TextStyle(color: Colors.white))),
                DataCell(Text(team['points'].toString(),
                    style: const TextStyle(color: Colors.white))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopScorersTab() {
    return ListView.builder(
      itemCount: _topScorers.length,
      itemBuilder: (context, index) {
        final scorer = _topScorers[index];
        final player = scorer['player'];
        final stats = scorer['statistics'][0];
        final team = stats['team'];

        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                player['photo'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[700],
                    child:
                        const Icon(Icons.person, size: 30, color: Colors.white),
                  );
                },
              ),
            ),
            title: Text(
              player['name'],
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            subtitle: Row(
              children: [
                Image.network(
                  team['logo'],
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.shield, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Text(team['name'], style: TextStyle(color: Colors.grey[400])),
              ],
            ),
            trailing: Text(
              '${stats['goals']['total']} ⚽',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return const Center(
        child: Text('لا توجد مباريات متاحة',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      );
    }

    final finishedMatches = _matches.where((match) {
      final status = match['fixture']['status']['short'];
      return status == 'FT' || status == 'AET' || status == 'PEN';
    }).toList();

    final upcomingMatches = _matches.where((match) {
      final status = match['fixture']['status']['short'];
      return status == 'NS' || status == 'PST';
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (finishedMatches.isNotEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'المباريات المنتهية',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            ...finishedMatches.map((match) => MatchCard(match: match)),
          ],
          if (upcomingMatches.isNotEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'المباريات القادمة',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            ...upcomingMatches.map((match) => MatchCard(match: match)),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
