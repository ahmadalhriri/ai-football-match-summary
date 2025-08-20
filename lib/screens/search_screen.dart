import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'league_details_screen.dart';
import 'club_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];

      // Search in championships
      for (var entry in AppConstants.championshipsArabic.entries) {
        if (entry.key.toLowerCase().contains(query.toLowerCase()) ||
            entry.value.contains(query)) {
          final leagueId = AppConstants.leagueIds[entry.key];
          if (leagueId != null) {
            _searchResults.add({
              'name': entry.value,
              'englishName': entry.key,
              'type': 'championship',
              'id': leagueId,
            });
          }
        }
      }

      // Search in clubs
      for (var entry in AppConstants.clubsArabic.entries) {
        if (entry.key.toLowerCase().contains(query.toLowerCase()) ||
            entry.value.contains(query)) {
          final clubId = AppConstants.clubIds[entry.key];
          if (clubId != null) {
            _searchResults.add({
              'name': entry.value,
              'englishName': entry.key,
              'type': 'club',
              'id': clubId,
            });
          }
        }
      }
    });
  }

  void _navigateToDetails(Map<String, dynamic> result) {
    if (result['type'] == 'championship') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LeagueDetailsScreen(
            leagueName: result['englishName'],
            leagueId: result['id'],
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubDetailsScreen(
            clubName: result['englishName'],
            clubId: result['id'],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for clubs or championships...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _performSearch,
            ),
          ),
          Expanded(
            child: _isSearching
                ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: Icon(
                          result['type'] == 'championship'
                              ? Icons.emoji_events
                              : Icons.sports_soccer,
                        ),
                        title: Text(
                          result['name'],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subtitle: Text(
                          result['englishName'],
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        onTap: () => _navigateToDetails(result),
                      );
                    },
                  )
                : const Center(
                    child: Text('Start typing to search...'),
                  ),
          ),
        ],
      ),
    );
  }
}
