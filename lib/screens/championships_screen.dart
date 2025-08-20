import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'league_details_screen.dart';

class ChampionshipsScreen extends StatelessWidget {
  const ChampionshipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get all leagues that have both an ID and an Arabic translation
    final leagues = AppConstants.leagueIds.keys
        .where((league) => AppConstants.championshipsArabic.containsKey(league))
        .toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'البطولات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: leagues.length,
        itemBuilder: (context, index) {
          final leagueName = leagues[index];
          final leagueId = AppConstants.leagueIds[leagueName]!;
          final arabicName = AppConstants.championshipsArabic[leagueName]!;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://media.api-sports.io/football/leagues/$leagueId.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.emoji_events, color: Colors.amber),
                    );
                  },
                ),
              ),
              title: Text(
                arabicName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                leagueName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LeagueDetailsScreen(
                      leagueName: leagueName,
                      leagueId: leagueId,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
