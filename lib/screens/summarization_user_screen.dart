import 'package:flutter/material.dart';
import 'package:fball/linker/http_api.dart';
import 'package:fball/screens/video_player_screen.dart' as vps;

class SummarizationScreen extends StatefulWidget {
  const SummarizationScreen({super.key});

  @override
  State<SummarizationScreen> createState() => _SummarizationScreenState();
}

class _SummarizationScreenState extends State<SummarizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _summaries = [];
  final TextEditingController _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    setState(() => _isLoading = true);

    try {
      final summaries = await HttpApi.fetchSummaries();
      print('=== Summaries Data ===');
      print('Number of summaries: ${summaries.length}');
      for (var summary in summaries) {
        print('Summary:');
        print('- Title: ${summary['title']}');
        print('- Description: ${summary['description']}');
        print('- Video URL: ${summary['video_url']}');
        print('- Duration: ${summary['duration']}');
        print('- Date: ${summary['date']}');
        print('-------------------');
      }
      print('=====================');

      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading summaries: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ: ${e.toString()}',
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitMatch() async {
    if (_linkController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال رابط'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await HttpApi.downloadVideo(_linkController.text.trim());

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تحميل الفيديو بنجاح: ${result['title']}'),
            backgroundColor: Colors.green,
          ),
        );
        _linkController.clear();

        // ✅ Reload summaries
        await _loadSummaries();

        // ✅ Switch to Summaries tab
        _tabController.animateTo(0);
      } else {
        throw Exception(result['error'] ?? 'Unknown error');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSummariesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summaries.isEmpty) {
      return Center(
        child: Text(
          'لا توجد ملخصات متاحة حالياً',
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _summaries.length,
      itemBuilder: (context, index) {
        final summary = _summaries[index];
        print('Summary data: $summary');
        return GestureDetector(
          onTap: () {
            print('=== Video Playback Debug Info ===');
            print('Summary data: $summary');
            print('Video URL from summary: ${summary['video_url']}');
            print('Video title: ${summary['title']}');
            print('Video description: ${summary['description']}');
            print('Video duration: ${summary['duration']}');
            print('Video date: ${summary['date']}');
            print('==============================');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    vps.VideoPlayerScreen(videoUrl: summary['video_url']),
              ),
            );
          },
          child: Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        summary['thumbnail_url'] ??
                            'https://via.placeholder.com/320x180.png?text=No+Thumbnail',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image,
                              color: Colors.white, size: 64),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary['description'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            summary['duration'],
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            summary['date'],
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummarizeMatch() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'ادخل رابط الفيديو',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25),
                    TextField(
                      controller: _linkController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://example.com/video',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            const Icon(Icons.link, color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () => _linkController.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _submitMatch,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'إرسال الرابط',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'ملخصات المباريات',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'ملخصات',
              icon: Icon(
                Icons.list,
                color: Colors.white,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummariesList(),
        ],
      ),
    );
  }
}
