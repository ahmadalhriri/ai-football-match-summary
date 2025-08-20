import 'package:flutter/material.dart';
import '../services/football_api_service.dart';
import '../constants/app_constants.dart';

class ClubDetailsScreen extends StatefulWidget {
  final String clubName;
  final int clubId;

  const ClubDetailsScreen({
    super.key,
    required this.clubName,
    required this.clubId,
  });

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FootballApiService _apiService = FootballApiService();
  Map<String, dynamic>? _clubDetails;
  List<dynamic>? _matches;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClubData();
  }

  Future<void> _loadClubData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clubDetails = await _apiService.getClubDetails(widget.clubId);
      final matches = await _apiService.getClubMatches(widget.clubId);

      setState(() {
        _clubDetails = clubDetails;
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
        title:
            Text(AppConstants.clubsArabic[widget.clubName] ?? widget.clubName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Matches'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: Theme.of(context).textTheme.bodyLarge))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildMatchesTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    if (_clubDetails == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildClubHeader(),
          const SizedBox(height: 24),
          _buildClubInfo(),
          const SizedBox(height: 24),
          _buildVenueInfo(),
        ],
      ),
    );
  }

  Widget _buildClubHeader() {
    return Column(
      children: [
        Image.network(
          _clubDetails!['team']['logo'] ?? '',
          height: 120,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.sports_soccer, size: 120);
          },
        ),
        const SizedBox(height: 16),
        Text(
          _clubDetails!['team']['name'] ?? 'Unknown Team',
          style: Theme.of(context).textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        if (_clubDetails!['team']['country'] != null) ...[
          const SizedBox(height: 8),
          Text(
            _clubDetails!['team']['country'],
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ],
    );
  }

  Widget _buildClubInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Club Information',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Founded',
                _clubDetails!['team']['founded']?.toString() ?? 'N/A'),
            _buildInfoRow(
                'National', _clubDetails!['team']['national'] ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueInfo() {
    if (_clubDetails!['venue'] == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Venue',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', _clubDetails!['venue']['name'] ?? 'N/A'),
            _buildInfoRow(
                'Address', _clubDetails!['venue']['address'] ?? 'N/A'),
            _buildInfoRow('City', _clubDetails!['venue']['city'] ?? 'N/A'),
            _buildInfoRow('Capacity',
                _clubDetails!['venue']['capacity']?.toString() ?? 'N/A'),
            _buildInfoRow(
                'Surface', _clubDetails!['venue']['surface'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (_matches == null) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: _matches!.length,
      itemBuilder: (context, index) {
        final match = _matches![index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Image.network(
              match['teams']['home']['id'] == widget.clubId
                  ? match['teams']['away']['logo']
                  : match['teams']['home']['logo'],
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.sports_soccer, size: 40);
              },
            ),
            title: Text(
              match['teams']['home']['id'] == widget.clubId
                  ? 'vs ${match['teams']['away']['name']}'
                  : 'vs ${match['teams']['home']['name']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Text(
              '${match['fixture']['date']} ${match['fixture']['time']}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: Text(
              match['goals']['home'] != null && match['goals']['away'] != null
                  ? '${match['goals']['home']} - ${match['goals']['away']}'
                  : 'VS',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            onTap: () {
              // TODO: Navigate to match details
            },
          ),
        );
      },
    );
  }
}
