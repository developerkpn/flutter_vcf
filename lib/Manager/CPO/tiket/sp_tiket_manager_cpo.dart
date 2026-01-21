import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/models/response/qc_sampling_cpo_vehicles_response.dart';

class SpTiketManagerCPOPage extends StatefulWidget {
  final String userId;
  final String token;

  const SpTiketManagerCPOPage({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<SpTiketManagerCPOPage> createState() => _SpTiketManagerCPOPageState();
}

class _SpTiketManagerCPOPageState extends State<SpTiketManagerCPOPage> {
  List<Map<String, dynamic>> tickets = [];
  bool isLoading = false;

  static const String _kCacheKey = 'cached_sp_tiket_manager_cpo';

  late ApiService api;

  @override
  void initState() {
    super.initState();
    final dio = Dio();
    api = ApiService(dio);
    loadCachedTickets().then((_) => fetchTickets());
  }

  /* ---------------- CACHE ---------------- */

  Future<void> loadCachedTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List data = jsonDecode(raw);
        setState(() {
          tickets = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> saveTicketsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonEncode(tickets));
  }


  Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();

  final token =
      prefs.getString("jwt_token") ??
      prefs.getString("token") ??
      widget.token;

  print("DEBUG TOKEN: $token");
  return token;
}



  /* ---------------- FETCH DATA ---------------- */

  Future<void> fetchTickets() async {
    setState(() => isLoading = true);
    try {
      final token = await getToken();
      final res = await api.getQcSamplingCpoVehicles("Bearer $token");

      final list = res.data
              ?.where((e) => e.has_sampling_data == true)
              .map((e) => {
                  "registration_id": e.registration_id ?? "-",
                  "tiket_no": e.wb_ticket_no ?? "-",
                  "plat": e.plate_number ?? "-",
                  "status": "DONE", // hardcode
                })
              .toList() ??
          [];

      setState(() {
        tickets = list.cast<Map<String, dynamic>>();
        isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      await saveTicketsCache();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal fetch data: $e")),
      );
      await loadCachedTickets();
    }
  }

  /* ---------------- UI HELPERS ---------------- */

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.orange;
      case "done":
      default:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Icons.verified_outlined;
      case "done":
      default:
        return Icons.check_circle_outline;
    }
  }

  String _getStatusText(String status) {
    return status.toUpperCase();
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Tiket Manager CPO"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchTickets,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tickets.isEmpty
              ? const Center(
                  child: Text(
                    "Belum ada tiket APPROVED / DONE.",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchTickets,
                  child: ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (_, i) {
                      final item = tickets[i];
                      final status = item["status"] ?? "done";
                      final color = _getStatusColor(status);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Nomor Tiket Timbang : ${item["tiket_no"]}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item["plat"] ?? "-",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      border: Border.all(color: color),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getStatusIcon(status),
                                          size: 16,
                                          color: color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getStatusText(status),
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
