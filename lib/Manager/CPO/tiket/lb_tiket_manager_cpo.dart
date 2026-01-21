import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_vcf/api_service.dart';

import 'package:flutter_vcf/models/qc_lab_cpo_vehicle.dart';

class LbTiketManagerCPOPage extends StatefulWidget {
  final String userId;
  final String token;

  const LbTiketManagerCPOPage({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<LbTiketManagerCPOPage> createState() => _LbTiketManagerCPOPageState();
}

class _LbTiketManagerCPOPageState extends State<LbTiketManagerCPOPage> {
  List<QcLabCpoVehicle> tickets = [];
  bool isLoading = false;

  late ApiService api;

  @override
  void initState() {
    super.initState();
    api = ApiService(Dio());
    fetchTickets();
  }

  /* ---------------- TOKEN ---------------- */

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ??
           prefs.getString("token") ??
           widget.token;
  }

  /* ---------------- FETCH DATA ---------------- */

  Future<void> fetchTickets() async {
    setState(() => isLoading = true);

    try {
      final token = await getToken();
      final res = await api.getQcLabCpoVehicles("Bearer $token");

      final vehicles = (res.data ?? []).where((v) {
        final labStatus = (v.lab_status ?? "").toLowerCase();

        // MANAGER: hanya APPROVED & DONE
        return labStatus == "approved" || labStatus == "done";
      }).toList();

      setState(() {
        tickets = vehicles;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetch: $e")),
      );
    }
  }

  /* ---------------- UI HELPERS ---------------- */

  Color _statusColor(String s) {
    switch (s) {
      case "approved":
        return Colors.green;
      case "done":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case "approved":
        return Icons.check_circle_outline;
      case "done":
        return Icons.task_alt;
      default:
        return Icons.hourglass_bottom;
    }
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Tiket Manager QC Lab CPO"),
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
                    "Belum ada tiket APPROVED / DONE",
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (_, i) {
                    final t = tickets[i];
                    final status = (t.lab_status ?? "").toLowerCase();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          "Tiket Timbang: ${t.wb_ticket_no ?? '-'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "Plat: ${t.plate_number ?? '-'}",
                        ),
                        trailing: Chip(
                          backgroundColor:
                              _statusColor(status).withOpacity(0.15),
                          side: BorderSide(color: _statusColor(status)),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(status),
                                color: _statusColor(status),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
