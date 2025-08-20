import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/match_card.dart';
import '../services/football_api_service.dart';
import '../constants/app_constants.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FootballApiService _apiService = FootballApiService();
  Map<String, List<dynamic>> _groupedMatches = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadMatches();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _loadMatches();
    }
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      late DateTime fromDate;
      late DateTime toDate;

      final isYesterday = _tabController.index == 0;
      final isToday = _tabController.index == 1;
      final isTomorrow = _tabController.index == 2;

      if (isYesterday) {
        fromDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        toDate = fromDate.add(const Duration(days: 1));
      } else if (isToday) {
        fromDate = DateTime(now.year, now.month, now.day);
        toDate = fromDate.add(const Duration(days: 1));
      } else {
        fromDate =
            DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        toDate = fromDate.add(const Duration(days: 1));
      }

      final matches = await _apiService.getMatchesByDate(
        DateFormat('yyyy-MM-dd').format(fromDate),
      );

      // Get the list of allowed league IDs from constants
      final allowedLeagueIds = AppConstants.leagueIds.values.toSet();

      final filtered = matches.where((match) {
        final localDate = DateTime.parse(match['fixture']['date']).toLocal();
        final matchDay =
            DateTime(localDate.year, localDate.month, localDate.day);
        final status = match['fixture']['status']['short'];
        final leagueId = match['league']['id'];

        // Filter: only include matches from allowed leagues by ID
        if (!allowedLeagueIds.contains(leagueId)) {
          return false;
        }

        if (isYesterday) {
          return matchDay == fromDate && status == 'FT';
        }

        if (isToday) {
          return matchDay == fromDate &&
              ['NS', '1H', '2H', 'HT', 'ET', 'P', 'FT'].contains(status);
        }

        if (isTomorrow) {
          return matchDay == fromDate && status == 'NS';
        }

        return false;
      }).toList();

      _groupMatchesByLeague(filtered);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _groupMatchesByLeague(List<dynamic> matches) {
    final grouped = <String, List<dynamic>>{};

    for (var match in matches) {
      final league = match['league'];
      final leagueName = league['name'];
      final leagueId = league['id'].toString();
      final key = '$leagueName ($leagueId)';

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(match);
    }

    // Remove leagues that only contain not-started matches in "Yesterday"
    if (_tabController.index == 0) {
      grouped.removeWhere((_, matches) =>
          matches.every((m) => m['fixture']['status']['short'] == 'NS'));
    }

    // Sort matches within each league by status priority
    for (var leagueKey in grouped.keys) {
      final leagueMatches = grouped[leagueKey]!;
      leagueMatches.sort((a, b) {
        final statusA = a['fixture']['status']['short'];
        final statusB = b['fixture']['status']['short'];

        // Define status priority: currently playing > will start soon > finished
        final statusPriority = {
          '1H': 1, // First half
          '2H': 1, // Second half
          'HT': 1, // Half time
          'ET': 1, // Extra time
          'P': 1, // Penalties
          'NS': 2, // Not started
          'FT': 3, // Full time
          'AET': 3, // After extra time
          'PEN': 3, // Penalties finished
        };

        final priorityA = statusPriority[statusA] ?? 4;
        final priorityB = statusPriority[statusB] ?? 4;

        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }

        // If same priority, sort by time
        final timeA = DateTime.parse(a['fixture']['date']).toLocal();
        final timeB = DateTime.parse(b['fixture']['date']).toLocal();
        return timeA.compareTo(timeB);
      });
    }

    // Sort leagues - live ones first if in Today tab
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final liveStatuses = ['1H', '2H', 'ET', 'P', 'HT'];

        final aLive = a.value
            .any((m) => liveStatuses.contains(m['fixture']['status']['short']));
        final bLive = b.value
            .any((m) => liveStatuses.contains(m['fixture']['status']['short']));

        if (_tabController.index == 1) {
          if (aLive && !bLive) return -1;
          if (!aLive && bLive) return 1;
        }

        final aTime =
            DateTime.parse(a.value.first['fixture']['date']).toLocal();
        final bTime =
            DateTime.parse(b.value.first['fixture']['date']).toLocal();
        return aTime.compareTo(bTime);
      });

    setState(() {
      _groupedMatches = Map.fromEntries(sortedEntries);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'أهم المباريات',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color.fromARGB(255, 41, 92, 210),
          labelStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          indicatorColor: const Color.fromARGB(210, 41, 92, 210),
          tabs: const [
            Tab(text: 'أمس'),
            Tab(text: 'اليوم'),
            Tab(text: 'غدا'),
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMatches,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _groupedMatches.isEmpty
                  ? const Center(
                      child: Text(
                        'No matches available',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _groupedMatches.length,
                      itemBuilder: (context, index) {
                        final leagueName =
                            _groupedMatches.keys.elementAt(index);
                        final matches = _groupedMatches[leagueName]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.blue,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events,
                                      color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      leagueName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...matches
                                .map((match) => MatchCard(match: match))
                                .toList(),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
}
