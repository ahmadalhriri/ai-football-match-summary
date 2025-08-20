import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class FootballApiService {
  static const String baseUrl = 'https://v3.football.api-sports.io';

  static Map<String, String> get headers => {
        'x-apisports-key': AppConstants.apiKey,
      };

  Future<dynamic> _makeRequest(String endpoint) async {
    try {
      print('Making request to: $baseUrl$endpoint');
      print('Headers: $headers');

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Debug response data
        print('Response data structure: ${data.keys}');

        if (data['errors'] != null && data['errors'].isNotEmpty) {
          final error = data['errors'].values.first;
          print('API Error: $error');
          if (error.toString().contains('rate limit')) {
            throw Exception(AppConstants.errorMessages['rate_limit']);
          }
          throw Exception(error);
        }

        if (data['response'] == null) {
          print('No response data found');
          throw Exception(AppConstants.errorMessages['no_data']);
        }

        return data['response'];
      } else if (response.statusCode == 429) {
        throw Exception(AppConstants.errorMessages['rate_limit']);
      } else if (response.statusCode == 401) {
        throw Exception(AppConstants.errorMessages['invalid_api_key']);
      } else if (response.statusCode == 404) {
        throw Exception(AppConstants.errorMessages['not_found']);
      } else {
        print('Error response: ${response.body}');
        throw Exception(AppConstants.errorMessages['api_error']);
      }
    } catch (e) {
      print('Error in _makeRequest: $e');
      if (e.toString().contains('SocketException')) {
        throw Exception(AppConstants.errorMessages['network_error']);
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getMatchesByDate(String date) async {
    try {
      final data = await _makeRequest('/fixtures?date=$date');
      return data ?? [];
    } catch (e) {
      throw Exception('Error fetching matches: $e');
    }
  }

  Future<Map<String, dynamic>> getLeagueDetails(
      int leagueId, int season) async {
    try {
      final data = await _makeRequest('/leagues?id=$leagueId&season=$season');
      return data?.first ?? {};
    } catch (e) {
      throw Exception('Error fetching league details: $e');
    }
  }

  Future<List<dynamic>> getLeagueStandings(int leagueId, int season) async {
    try {
      final data =
          await _makeRequest('/standings?league=$leagueId&season=$season');
      return data?.first['league']['standings'].first ?? [];
    } catch (e) {
      throw Exception('Error fetching standings: $e');
    }
  }

  Future<List<dynamic>> getTopScorers(int leagueId, int season) async {
    try {
      final data = await _makeRequest(
          '/players/topscorers?league=$leagueId&season=$season');
      return data ?? [];
    } catch (e) {
      throw Exception('Error fetching top scorers: $e');
    }
  }

  Future<Map<String, dynamic>> getClubDetails(int clubId) async {
    try {
      final data = await _makeRequest('/teams?id=$clubId');
      return data?.first ?? {};
    } catch (e) {
      throw Exception('Error fetching club details: $e');
    }
  }

  Future<List<dynamic>> getMatchEvents(int fixtureId) async {
    try {
      final data = await _makeRequest('/fixtures/events?fixture=$fixtureId');
      print('Events response: $data'); // Debug log
      return data ?? [];
    } catch (e) {
      throw Exception('Error fetching match events: $e');
    }
  }

  Future<List<dynamic>> getClubMatches(int clubId) async {
    try {
      final data = await _makeRequest('/fixtures?team=$clubId&last=10&next=10');
      return data ?? [];
    } catch (e) {
      throw Exception('Error fetching club matches: $e');
    }
  }

  Future<Map<String, dynamic>> getMatchDetails(int fixtureId) async {
    try {
      final data = await _makeRequest('/fixtures?id=$fixtureId');
      return data?.first ?? {};
    } catch (e) {
      throw Exception('Error fetching match details: $e');
    }
  }

  Future<List<dynamic>> getMatchLineups(int fixtureId) async {
    try {
      final data = await _makeRequest('/fixtures/lineups?fixture=$fixtureId');
      print('Raw Lineups API response: $data'); // Debug log

      // Process the data to ensure player photos are in the correct format
      if (data != null && data.isNotEmpty) {
        for (var team in data) {
          print('Processing team: ${team['team']?['name']}');

          if (team['startXI'] != null) {
            print('Processing startXI players:');
            for (var player in team['startXI']) {
              print('Player data before processing: $player');
            }
          }

          if (team['substitutes'] != null) {
            print('Processing substitute players:');
            for (var player in team['substitutes']) {
              print('Substitute data before processing: $player');
            }
          }
        }
      }

      return data ?? [];
    } catch (e) {
      print('Error fetching match lineups: $e');
      throw Exception('Error fetching match lineups: $e');
    }
  }

  Future<Map<String, dynamic>> getMatchStatistics(int fixtureId) async {
    try {
      print('Fetching statistics for fixture ID: $fixtureId');
      final data =
          await _makeRequest('/fixtures/statistics?fixture=$fixtureId');

      // Debug data structure
      if (data != null && data.isNotEmpty) {
        print('Statistics data structure: ${data.first.keys}');
        if (data.first['statistics'] != null) {
          print('Statistics teams: ${data.first['statistics'].length}');
        } else {
          print('No statistics found in response');
        }
      } else {
        print('Empty statistics response');
      }

      return data?.first ?? {};
    } catch (e) {
      print('Error fetching match statistics: $e');
      throw Exception('Error fetching match statistics: $e');
    }
  }

  Future<List<dynamic>> getMatchesBySeason(int leagueId, int season) async {
    try {
      final data =
          await _makeRequest('/fixtures?league=$leagueId&season=$season');
      return data ?? [];
    } catch (e) {
      throw Exception('Error fetching matches by season: $e');
    }
  }

  Future<List<dynamic>?> getAllLeagues() async {
    try {
      final response = await http.get(
        Uri.parse('https://v3.football.api-sports.io/leagues'),
        headers: {
          'x-rapidapi-host': 'v3.football.api-sports.io',
          'x-rapidapi-key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response'] != null) {
          return data['response'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching leagues: $e');
      return null;
    }
  }
}
