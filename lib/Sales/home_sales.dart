import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login.dart';
import 'sales_api.dart';
import 'sales_lab_page.dart';
import 'sales_loading_page.dart';

class HomeSalesPage extends StatefulWidget {
  const HomeSalesPage({
    super.key,
    required this.userId,
    required this.token,
    required this.showLab,
    required this.showStartLoading,
    required this.showFinishLoading,
  });

  final String userId;
  final String token;
  final bool showLab;
  final bool showStartLoading;
  final bool showFinishLoading;

  @override
  State<HomeSalesPage> createState() => _HomeSalesPageState();
}

class _HomeSalesPageState extends State<HomeSalesPage> {
  final SalesApi _api = SalesApi();

  bool _isLoading = true;
  String? _errorMessage;
  JsonMap _labStats = const <String, dynamic>{};
  JsonMap _loadingStats = const <String, dynamic>{};
  String? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? widget.token;
  }

  int _readInt(JsonMap data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      JsonMap labStats = const <String, dynamic>{};
      JsonMap loadingStats = const <String, dynamic>{};

      if (widget.showLab) {
        labStats = await _api.getLabStatistics('Bearer $token');
      }
      if (widget.showStartLoading || widget.showFinishLoading) {
        loadingStats = await _api.getLoadingStatistics('Bearer $token');
      }

      if (!mounted) return;
      setState(() {
        _labStats = labStats;
        _loadingStats = loadingStats;
        _lastUpdate = DateTime.now().toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengambil data: $error';
        _isLoading = false;
      });
    }
  }

  void _openMenu(String value) {
    if (value == 'LAB') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalesLabPage(userId: widget.userId, token: widget.token),
        ),
      );
      return;
    }

    if (value == 'START_LOADING') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalesLoadingPage(
            userId: widget.userId,
            token: widget.token,
            stage: SalesLoadingStage.start,
          ),
        ),
      );
      return;
    }

    if (value == 'FINISH_LOADING') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalesLoadingPage(
            userId: widget.userId,
            token: widget.token,
            stage: SalesLoadingStage.finish,
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(title),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black54),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<MapEntry<String, String>> rows,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black54),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final row in rows) _buildInfoRow(row.key, row.value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];

    if (widget.showLab) {
      cards.add(
        _buildCard(
          icon: Icons.science,
          iconColor: Colors.green,
          title: 'Sales Lab',
          rows: [
            MapEntry('Total Truk Masuk', _readInt(_labStats, ['total_truk_masuk']).toString()),
            MapEntry(
              'Belum Cek Lab',
              _readInt(_labStats, ['truk_belum_cek_lab', 'belum_cek_lab']).toString(),
            ),
            MapEntry(
              'Sudah Cek Lab',
              _readInt(_labStats, ['truk_sudah_cek_lab', 'sudah_cek_lab']).toString(),
            ),
            MapEntry(
              'Total Truk Keluar',
              _readInt(_labStats, ['total_truk_keluar']).toString(),
            ),
          ],
        ),
      );
    }

    if (widget.showStartLoading || widget.showFinishLoading) {
      cards.add(
        _buildCard(
          icon: Icons.local_shipping,
          iconColor: Colors.black,
          title: 'Sales Loading',
          rows: [
            MapEntry('Total Truk Masuk', _readInt(_loadingStats, ['total_truk_masuk']).toString()),
            MapEntry(
              'Belum Loading',
              _readInt(
                _loadingStats,
                ['truk_belum_loading', 'belum_loading', 'truk_belum_unloading'],
              ).toString(),
            ),
            MapEntry(
              'Sudah Loading',
              _readInt(
                _loadingStats,
                ['truk_sudah_loading', 'sudah_loading'],
              ).toString(),
            ),
            MapEntry(
              'Total Truk Keluar',
              _readInt(_loadingStats, ['total_truk_keluar']).toString(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home VCF', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
            tooltip: 'Pilih menu sales',
            onSelected: _openMenu,
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              if (widget.showLab) {
                items.add(const PopupMenuItem<String>(value: 'LAB', child: Text('Sales Lab')));
              }
              if (widget.showStartLoading) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'START_LOADING',
                    child: Text('Start Loading Sales'),
                  ),
                );
              }
              if (widget.showFinishLoading) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'FINISH_LOADING',
                    child: Text('Finish Loading Sales'),
                  ),
                );
              }
              return items;
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu VCF', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hai, Sales ${widget.userId} 👋',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Last Update : ${_lastUpdate ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...cards,
                ],
              ),
      ),
    );
  }
}