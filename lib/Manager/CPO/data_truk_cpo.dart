import 'package:flutter/material.dart';
import 'package:flutter_vcf/Manager/manager_check_ticket_filter.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rejected/manager_rejected_tickets_page.dart';
import 'tiket/sp_tiket_manager_cpo.dart';
import 'tiket/lb_tiket_manager_cpo.dart';
import 'tiket/un_tiket_manager_cpo.dart';

class DataTrukCpoPage extends StatefulWidget {
  const DataTrukCpoPage({super.key});

  @override
  State<DataTrukCpoPage> createState() => _DataTrukCpoPageState();
}

class _DataTrukCpoPageState extends State<DataTrukCpoPage> {
  // ----- QC SAMPLE CPO -----
  int sampleMasuk = 0;
  int sampleBelum = 0;
  int sampleSudah = 0;
  int sampleKeluar = 0;

  // ----- QC LAB CPO -----
  int labMasuk = 0;
  int labBelum = 0;
  int labSudah = 0;
  int labKeluar = 0;

  // ----- UNLOADING CPO -----
  int unloadMasuk = 0;
  int unloadBelum = 0;
  int unloadSudah = 0;
  int unloadKeluar = 0;

  int labRejectedCount = 0;
  int unloadRejectedCount = 0;

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  Future<void> loadStatistics() async {
    final api = ApiService(AppConfig.createDio());
    final prefs = await SharedPreferences.getInstance();

    String? savedToken =
        prefs.getString("jwt_token") ?? prefs.getString("token");

    if (savedToken == null || savedToken.isEmpty) return;

    String token = savedToken.startsWith("Bearer ")
        ? savedToken
        : "Bearer $savedToken";

    final now = DateTime.now();
    String from = "${now.year}-01-01";
    String to = "${now.year}-12-31";

    try {
      int nextLabRejectedCount = 0;
      int nextUnloadRejectedCount = 0;

      // SAMPLE
      final sampleStats = await api.getQcSamplingStats(
        token,
        dateFrom: from,
        dateTo: to,
      );

      setState(() {
        sampleMasuk = sampleStats.data?.statistics?.total_truk_masuk ?? 0;
        sampleBelum =
            sampleStats.data?.statistics?.truk_belum_ambil_sample ?? 0;
        sampleSudah =
            sampleStats.data?.statistics?.truk_sudah_ambil_sample ?? 0;
        sampleKeluar = sampleStats.data?.statistics?.total_truk_keluar ?? 0;
      });

      // LAB
      final labStats = await api.getQcLabCpoStatistics(
        token,
        dateFrom: from,
        dateTo: to,
      );

      labMasuk = labStats.data?.statistics?.total_truk_masuk ?? 0;
      labBelum = labStats.data?.statistics?.truk_belum_cek_lab ?? 0;
      labSudah = labStats.data?.statistics?.truk_sudah_cek_lab ?? 0;
      labKeluar = labStats.data?.statistics?.total_truk_keluar ?? 0;

      // UNLOADING
      final unloadStats = await api.getUnloadingCpoStatistics(
        token,
        dateFrom: from,
        dateTo: to,
      );

      unloadMasuk = unloadStats.data?.statistics?.total_truk_masuk ?? 0;
      unloadBelum = unloadStats.data?.statistics?.truk_belum_unloading ?? 0;
      unloadSudah = unloadStats.data?.statistics?.truk_sudah_unloading ?? 0;
      unloadKeluar = unloadStats.data?.statistics?.total_truk_keluar ?? 0;

      try {
        final labTicketsRes = await api.getManagerCheckTickets(
          token,
          'CPO',
          stage: 'lab',
        );
        final labTickets = labTicketsRes.data ?? [];

        final unloadingTicketsRes = await api.getManagerCheckTickets(
          token,
          'CPO',
          stage: 'unloading',
        );
        final unloadingTickets = unloadingTicketsRes.data ?? [];

        final labRejectedTickets = await filterRejectedOperatorTicketsByStage(
          api: api,
          authorizationToken: token,
          stage: 'lab',
          tickets: labTickets,
        );
        nextLabRejectedCount = labRejectedTickets.length;

        final unloadRejectedTickets =
            await filterRejectedOperatorTicketsByStage(
              api: api,
              authorizationToken: token,
              stage: 'unloading',
              tickets: unloadingTickets,
            );
        nextUnloadRejectedCount = unloadRejectedTickets.length;
      } catch (_) {
        // Keep dashboard stats visible even when rejected-count fetch fails.
      }

      setState(() {
        labRejectedCount = nextLabRejectedCount;
        unloadRejectedCount = nextUnloadRejectedCount;
      });
    } catch (e) {
      print("Gagal load statistik CPO: $e");
    }
  }

  String _rejectedButtonText(int count) {
    if (count <= 0) return 'Cek Rejected';
    return 'Cek Rejected ($count)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: true,
        title: const Text(
          "DASHBOARD QC CPO",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: loadStatistics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _bigBox(
              icon: Icons.science,
              title: "QC Sample CPO",
              items: [
                ["Total Truk Masuk", "$sampleMasuk"],
                ["Truk Belum Ambil Sample", "$sampleBelum"],
                ["Truk Sudah Ambil Sample", "$sampleSudah"],
                ["Total Truk Keluar", "$sampleKeluar"],
              ],
              buttonText: "Input Sample",
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token =
                    prefs.getString("jwt_token") ??
                    prefs.getString("token") ??
                    "";

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SpTiketManagerCPOPage(userId: "manager", token: token),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            _bigBox(
              icon: Icons.biotech,
              title: "QC Lab CPO",
              items: [
                ["Total Truk Masuk", "$labMasuk"],
                ["Truk Belum Cek LAB", "$labBelum"],
                ["Truk Sudah Cek LAB", "$labSudah"],
                ["Total Truk Keluar", "$labKeluar"],
              ],
              buttonText: "Input QC Lab",
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token =
                    prefs.getString("jwt_token") ??
                    prefs.getString("token") ??
                    "";

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LbTiketManagerCPOPage(userId: "manager", token: token),
                  ),
                );
              },
              secondaryButtonText: _rejectedButtonText(labRejectedCount),
              onSecondaryPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token =
                    prefs.getString("jwt_token") ??
                    prefs.getString("token") ??
                    "";

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManagerRejectedTicketsPage(
                      commodity: "CPO",
                      stage: "lab",
                      token: token,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            _bigBox(
              icon: Icons.local_shipping,
              title: "Unloading CPO",
              items: [
                ["Total Truk Masuk", "$unloadMasuk"],
                ["Truk Belum Unloading", "$unloadBelum"],
                ["Truk Sudah Unloading", "$unloadSudah"],
                ["Total Truk Keluar", "$unloadKeluar"],
              ],
              buttonText: "Input Unloading",
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token =
                    prefs.getString("jwt_token") ??
                    prefs.getString("token") ??
                    "";

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UnTiketManagerCPOPage(userId: "manager", token: token),
                  ),
                );
              },
              secondaryButtonText: _rejectedButtonText(unloadRejectedCount),
              onSecondaryPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token =
                    prefs.getString("jwt_token") ??
                    prefs.getString("token") ??
                    "";

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManagerRejectedTicketsPage(
                      commodity: "CPO",
                      stage: "unloading",
                      token: token,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigBox({
    required IconData icon,
    required String title,
    required List<List<String>> items,
    required String buttonText,
    required VoidCallback onPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          for (var item in items) _dashboardBox(title: item[0], value: item[1]),
          const SizedBox(height: 10),
          if (secondaryButtonText != null && onSecondaryPressed != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPressed,
                    child: Text(buttonText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSecondaryPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: Text(secondaryButtonText),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }

  Widget _dashboardBox({required String title, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
