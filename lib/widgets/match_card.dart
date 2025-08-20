import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/match_details_screen.dart';
import '../constants/app_constants.dart';

class MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const MatchCard({super.key, required this.match});

  // Helper method to get Arabic club name
  String _getArabicClubName(String englishName) {
    // First try to find exact match
    if (AppConstants.clubsArabic.containsKey(englishName)) {
      return AppConstants.clubsArabic[englishName]!;
    }

    // Try to find matches without country codes (remove country codes from keys)
    for (String key in AppConstants.clubsArabic.keys) {
      String cleanKey = key.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      if (cleanKey.toLowerCase() == englishName.toLowerCase()) {
        return AppConstants.clubsArabic[key]!;
      }
    }

    // Try partial matching (contains)
    for (String key in AppConstants.clubsArabic.keys) {
      String cleanKey = key.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      if (cleanKey.toLowerCase().contains(englishName.toLowerCase()) ||
          englishName.toLowerCase().contains(cleanKey.toLowerCase())) {
        return AppConstants.clubsArabic[key]!;
      }
    }

    // If still not found, return the original English name
    return englishName;
  }

  // Helper method to get Arabic league name
  String _getArabicLeagueName(String englishName) {
    return AppConstants.championshipsArabic[englishName] ?? englishName;
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam = match['teams']['home'];
    final awayTeam = match['teams']['away'];
    final goals = match['goals'];
    final fixture = match['fixture'];
    final league = match['league'];
    final status = fixture['status']['short'];
    final statusArabic = AppConstants.matchStatusArabic[status] ?? status;

    final fixtureDateTime = DateTime.parse(fixture['date']).toLocal();

    final time = DateFormat('HH:mm').format(fixtureDateTime);
    final date = DateFormat('d/M/yyyy').format(fixtureDateTime);

    // Get Arabic names
    final homeTeamName = _getArabicClubName(homeTeam['name']);
    final awayTeamName = _getArabicClubName(awayTeam['name']);
    final leagueName = _getArabicLeagueName(league['name']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailsScreen(match: match),
            ),
          );
        },
        child: Column(
          children: [
            // League Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      league['logo'],
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      leagueName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            // Match Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Home team
                  Expanded(
                    child: Column(
                      children: [
                        Image.network(
                          homeTeam['logo'],
                          width: 48,
                          height: 48,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.sports_soccer, size: 48);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          homeTeamName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Match status, time, and score + date
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          statusArabic,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: status == 'NS'
                                ? Colors.blue
                                : (status == 'FT' ||
                                        status == 'AET' ||
                                        status == 'PEN')
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${goals['home'] ?? 0} - ${goals['away'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Away team
                  Expanded(
                    child: Column(
                      children: [
                        Image.network(
                          awayTeam['logo'],
                          width: 48,
                          height: 48,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.sports_soccer, size: 48);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          awayTeamName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
}
