import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import '../../login.dart';
import 'unloading_pome.dart';

class HomeUnloadingPOMEPage extends StatefulWidget {
  final String userId;
  final String token;

  const HomeUnloadingPOMEPage({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<HomeUnloadingPOMEPage> createState() => _HomeUnloadingPOMEPageState();
}

class _HomeUnloadingPOMEPageState extends State<HomeUnloadingPOMEPage> {
  bool isLoading = true;
  String? errorMessage;

  int totalMasuk = 0;
  int belumUnloading = 0;
  int sudahUnloading = 0;
  int totalKeluar = 0;
  String? lastUpdate;

  late ApiService api;

  @override
  void initState() {
    super.initState();
    api = ApiService(AppConfig.createDio());
    fetchUnloadingStatistics();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ?? widget.token;
  }

  Future<void> fetchUnloadingStatistics() async {
    try {
      final token = await _getToken();

    
      final res = await api.getUnloadingPomeStatistics(
        "Bearer $token",
        dateFrom: "2025-01-01",
        dateTo: "2025-12-31",
      );

      final stats = res.data?.statistics;
      // final period = res.data?.period;

      setState(() {
        totalMasuk = stats?.total_truk_masuk ?? 0;
        belumUnloading = stats?.truk_belum_unloading ?? 0;
        sudahUnloading = stats?.total_truk_keluar ?? stats?.truk_sudah_unloading ?? 0;
        totalKeluar = stats?.total_truk_keluar ?? 0;
        // lastUpdate = period?.to ?? "-";
        lastUpdate = DateTime.now().toString();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Gagal mengambil data: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home VCF", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
            tooltip: 'Pilih menu unloading',
            onSelected: (String value) {
              if (value == 'START_POME') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UnloadingPOMEPage(
                      userId: widget.userId,
                      token: widget.token,
                      stage: UnloadingPOMEStage.start,
                    ),
                  ),
                );
              }

              if (value == 'FINISH_POME') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UnloadingPOMEPage(
                      userId: widget.userId,
                      token: widget.token,
                      stage: UnloadingPOMEStage.finish,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'START_POME',
                child: Text('Start Unloading POME'),
              ),
              PopupMenuItem<String>(
                value: 'FINISH_POME',
                child: Text('Finish Unloading POME'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUnloadingStatistics,
          )
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text("Menu VCF",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hai, Unloading POME 👋",
                          style: Theme.of(context).textTheme.titleMedium),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Last Update : ${lastUpdate ?? '-'}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Card Info
                      Card(
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
                                children: const [
                                  Icon(Icons.local_shipping, color: Colors.black),
                                  SizedBox(width: 8),
                                    Text("Start Unloading POME",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildInfoRow("Total Truk Masuk", "$totalMasuk"),
                              _buildInfoRow("Truk Belum Start Unloading", "$belumUnloading"),
                              _buildInfoRow("Truk Sudah WB Out", "$sudahUnloading"),
                              _buildInfoRow("Total Truk Keluar", "$totalKeluar"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  static Widget _buildInfoRow(String title, String value) {
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
}
