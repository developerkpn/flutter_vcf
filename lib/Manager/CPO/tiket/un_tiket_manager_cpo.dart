import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/models/response/unloading_cpo_response.dart';
import 'package:flutter_vcf/models/unloading_cpo_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnTiketManagerCPOPage extends StatefulWidget {
  final String userId;
  final String token;

  const UnTiketManagerCPOPage({
    super.key,
    required this.userId,
    required this.token,
    
  });

  @override
  State<UnTiketManagerCPOPage> createState() => _UnTiketManagerCPOPageState();
}

class _UnTiketManagerCPOPageState extends State<UnTiketManagerCPOPage> {
  final apiService = ApiService(
    Dio(BaseOptions(contentType: "application/json")),
  );

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ??
           prefs.getString("token") ??
           widget.token;
  }

  String normalizedStatus(String? s) {
    final v = (s ?? "").toLowerCase().trim();
    if (v == "approved" || v == "wb_out" || v == "done") return "done";
    return v;
  }

  String displayStatus(String status) {
    switch (status) {
      case "done":
        return "DONE";
      default:
        return status.toUpperCase();
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "done":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case "done":
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Unloading Manager CPO"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),

      body: FutureBuilder<UnloadingCPOResponse>(
        future: _getToken().then((t) => apiService.getPosts("Bearer $t")),
        builder: (context, snapshot) {
          // LOADING
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // ERROR
          if (snapshot.hasError) {
            log("${snapshot.error}");
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final trucks = snapshot.data?.data ?? [];

          final doneTrucks = trucks.where((e) {
            final normalized = normalizedStatus(
              (e.unloading_status ?? "").isNotEmpty
                  ? e.unloading_status
                  : e.regist_status,
            );
            return normalized == "done";
          }).toList();

          if (doneTrucks.isEmpty) {
            return const Center(
              child: Text(
                "Belum ada tiket unloading APPROVED / DONE.",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: doneTrucks.length,
            itemBuilder: (_, index) {
              final t = doneTrucks[index];
              final status = normalizedStatus(
                (t.unloading_status ?? "").isNotEmpty
                    ? t.unloading_status
                    : t.regist_status,
              );

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        "Nomor Tiket Timbang : ${t.wb_ticket_no ?? '-'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.plate_number ?? "-",
                            style: const TextStyle(fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor(status).withOpacity(0.15),
                              border:
                                  Border.all(color: statusColor(status)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  statusIcon(status),
                                  size: 16,
                                  color: statusColor(status),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  displayStatus(status),
                                  style: TextStyle(
                                    color: statusColor(status),
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
          );
        },
      ),
    );
  }
}
