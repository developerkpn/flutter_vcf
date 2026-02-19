import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';

import 'package:flutter_vcf/models/pk/response/qc_lab_pk_vehicles_response.dart';
import 'input_lab_pk.dart';
import 'add_lab_pk.dart';

class QCLabPKPage extends StatefulWidget {
  final String userId;

  const QCLabPKPage({super.key, required this.userId});

  @override
  State<QCLabPKPage> createState() => _QCLabPKPageState();
}

class _QCLabPKPageState extends State<QCLabPKPage> {
  List<QcLabPkVehicle> tickets = [];
  bool isLoading = false;

  late ApiService api;

  @override
  void initState() {
    super.initState();
    api = ApiService(AppConfig.createDio());
    fetchTickets();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> fetchTickets() async {
    setState(() => isLoading = true);

    try {
      final token = await getToken();
      final res = await api.getQcLabPkVehicles("Bearer $token");

      final vehicles = (res.data ?? []).where((v) {
        final status = (v.labStatus ?? "").toLowerCase();
        final isRelab = v.isRelab == true;
        final registStatus = (v.registStatus ?? '').toLowerCase().trim();
        final isRelabStage = isRelab || registStatus.startsWith('qc_relab');

        final processed = ["approved", "rejected", "hold"].contains(status);
        final isRandomCheck = !isRelabStage && registStatus == 'random_check';

        if (!isRelabStage && (processed || isRandomCheck)) return true;

        return isRelabStage;
      }).toList();

      setState(() {
        tickets = vehicles;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  String getPkStatus(QcLabPkVehicle v) {
    final lab = (v.labStatus ?? "").toLowerCase();
    final regist = (v.registStatus ?? '').toLowerCase().trim();
    final isRelabStage = v.isRelab == true || regist.startsWith('qc_relab');

    if (!isRelabStage && regist == 'random_check') {
      return 'pending_manager_approval';
    }

    if (["approved", "hold", "rejected"].contains(lab)) {
      return lab;
    }

    if (isRelabStage) {
      if (v.counter == 2) return "resampling_2";
      return "resampling_1";
    }

    return "pending";
  }

  bool isClickable(String status) {
    // hold + resampling_1 + resampling_2 dapat diklik
    return ["hold", "resampling_1", "resampling_2"].contains(status);
  }

  String statusLabel(String s) {
    switch (s) {
      case 'pending_manager_approval':
        return 'Pending Manager Approval';
      case 'resampling_1':
        return 'RE-LAB 1';
      case 'resampling_2':
        return 'RE-LAB 2';
      default:
        return s.toUpperCase();
    }
  }

  Color statusColor(String s) {
    switch (s) {
      case "approved":
        return Colors.green;
      case "hold":
        return Colors.orange;
      case "rejected":
        return Colors.red;
      case "resampling_1":
      case "resampling_2":
        return Colors.purple;
      case "pending_manager_approval":
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String s) {
    switch (s) {
      case "approved":
        return Icons.check_circle_outline;
      case "hold":
        return Icons.pause_circle_outline;
      case "rejected":
        return Icons.cancel_outlined;
      case "resampling_1":
        return Icons.refresh;
      case "resampling_2":
        return Icons.loop;
      case "pending_manager_approval":
        return Icons.error_outline;
      default:
        return Icons.hourglass_bottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard QC Lab PK"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchTickets),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tickets.isEmpty
          ? const Center(
              child: Text(
                "Belum ada tiket QC Lab PK",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: tickets.length,
              itemBuilder: (_, i) {
                final t = tickets[i];
                final status = getPkStatus(t);

                return GestureDetector(
                  onTap: () {
                    if (isClickable(status)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InputLabPKPage(model: t),
                        ),
                      ).then((value) {
                        if (value != null) fetchTickets();
                      });
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text("Tiket: ${t.wbTicketNo ?? '-'}"),
                      subtitle: Text("Plat: ${t.plateNumber ?? '-'}"),
                      trailing: Chip(
                        backgroundColor: statusColor(status).withOpacity(0.15),
                        side: BorderSide(color: statusColor(status)),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon(status),
                              color: statusColor(status),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel(status),
                              style: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLabPKPage(userId: widget.userId),
            ),
          ).then((value) {
            if (value != null) fetchTickets();
          });
        },
      ),
    );
  }
}
