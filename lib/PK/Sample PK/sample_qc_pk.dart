import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/pk/response/qc_sampling_pk_vehicles_response.dart';
import 'add_sample_qc_pk.dart';
import 'add_pk_data.dart';

class SampleQCPKPage extends StatefulWidget {
  final String userId;
  final String token;

  const SampleQCPKPage({super.key, required this.userId, required this.token});

  @override
  State<SampleQCPKPage> createState() => _SampleQCPKPageState();
}

class _SampleQCPKPageState extends State<SampleQCPKPage> {
  List<Map<String, dynamic>> tickets = [];
  bool isLoading = false;

  static const String _kCacheKey = 'cached_tickets_sampling_pk';

  late ApiService api;

  @override
  void initState() {
    super.initState();
    api = ApiService(AppConfig.createDio());
    loadCachedTickets().then((_) => fetchTickets());
  }

  Future<void> loadCachedTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> data = jsonDecode(raw);
        setState(() {
          tickets = data.map((e) => Map<String, dynamic>.from(e)).toList();
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
    return prefs.getString('jwt_token') ?? widget.token;
  }

  Future<void> fetchTickets() async {
    setState(() => isLoading = true);

    try {
      final token = await getToken();
      final res = await api.getQcSamplingPkVehicles("Bearer $token");

      final List<QcSamplingPkVehicle> vehicles =
          res.data ?? <QcSamplingPkVehicle>[];

      final filtered =
          vehicles
              .where(
                (e) => e.has_sampling_data == true || (e.counter ?? 0) > 0,
              )
              .toList();

      final list = filtered.map((e) {
        final String registStatus = (e.regist_status).toLowerCase().trim();
        final int samplingCounter = (e.counter ?? 0).clamp(0, 2);
        final String backendLabel =
            (e.counter_status_label ?? '').toLowerCase().trim();

        final String status = registStatus == "qc_resampling"
            ? (samplingCounter == 2 ? "resampling_2" : "resampling_1")
            : registStatus == "qc_relab"
                ? (samplingCounter == 2 ? "relab_2" : "relab_1")
                : backendLabel.startsWith("resampling_") ||
                        backendLabel.startsWith("relab_") ||
                        backendLabel.startsWith("reunloading_")
                    ? backendLabel
                    : samplingCounter == 2
                        ? "resampling_2"
                        : samplingCounter == 1
                            ? "resampling_1"
                            : (registStatus == "random_check"
                                ? "PENDING_MANAGER_APPROVAL"
                                : "DONE");

        return {
          "registration_id": e.registration_id,
          "tiket_no": e.wb_ticket_no,
          "plat": e.plate_number,
          "vendor_code": e.vendor_code ?? "",
          "vendor_name": e.vendor_name ?? "",
          "commodity_code": e.commodity_code,
          "commodity_name": e.commodity_name,
          "is_resampling": samplingCounter > 0 || e.is_resampling == true,
          "resampling_counter": samplingCounter,
          "status": status,
        };
      }).toList();

      setState(() {
        tickets = list.cast<Map<String, dynamic>>();
        isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      await saveTicketsCache();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetch: $e")));
      await loadCachedTickets();
    }
  }

  bool _isResamplingStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == "resampling_1" ||
        normalized == "resampling_2" ||
        normalized == "re-sampling";
  }

  bool _isRelabStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == "relab_1" || normalized == "relab_2";
  }

  bool _isReunloadingStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == "reunloading_1" || normalized == "reunloading_2";
  }

  Color _getStatusColor(Map item) {
    final status = ((item["status"] as String?) ?? "").toLowerCase().trim();
    if (_isResamplingStatus(status)) {
      return Colors.purple;
    }
    if (_isRelabStatus(status)) {
      return Colors.indigo;
    }
    if (_isReunloadingStatus(status)) {
      return Colors.orange;
    }
    if (status == "pending_manager_approval") {
      return Colors.yellow.shade700;
    }
    return Colors.green;
  }

  Color _getStatusBg(Map item) {
    return _getStatusColor(item).withOpacity(0.15);
  }

  IconData _getStatusIcon(Map item) {
    final status = ((item["status"] as String?) ?? "").toLowerCase().trim();
    if (status == "resampling_2") {
      return Icons.loop;
    }
    if (status == "resampling_1" || status == "re-sampling") {
      return Icons.refresh;
    }
    if (status == "relab_2") {
      return Icons.science_outlined;
    }
    if (status == "relab_1") {
      return Icons.biotech_outlined;
    }
    if (status == "reunloading_2") {
      return Icons.loop;
    }
    if (status == "reunloading_1") {
      return Icons.refresh;
    }
    if (status == "pending_manager_approval") {
      return Icons.error_outline;
    }
    return Icons.check_circle_outline;
  }

  String _getStatusLabel(Map item) {
    final status = ((item["status"] as String?) ?? "").toLowerCase().trim();
    if (status == "resampling_2") {
      return "RESAMPLING 2";
    }
    if (status == "resampling_1" || status == "re-sampling") {
      return "RESAMPLING 1";
    }
    if (status == "relab_2") {
      return "RE-LAB 2";
    }
    if (status == "relab_1") {
      return "RE-LAB 1";
    }
    if (status == "reunloading_2") {
      return "REUNLOADING 2";
    }
    if (status == "reunloading_1") {
      return "REUNLOADING 1";
    }
    if (status == "pending_manager_approval") {
      return "Pending Manager Approval";
    }
    return status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Sampling PK"),
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
                "Belum ada kendaraan PK yang sudah sample.",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchTickets,
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (_, i) {
                  final item = tickets[i];

                  return InkWell(
                    onTap: () {
                      // Hanya tiket yang statusnya RE-SAMPLING yang boleh dibuka untuk re-sample
                      if (_isResamplingStatus(item["status"] as String? ?? "")) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddPKDataPage(
                              userId: widget.userId,
                              token: widget.token,
                              registrationId: item["registration_id"],
                              platKendaraan: item["plat"],
                              tiketNo: item["tiket_no"],
                              vendorCode: item["vendor_code"] ?? "-",
                              vendorName: item["vendor_name"] ?? "-",
                              commodityCode: item["commodity_code"] ?? "-",
                              commodityName: item["commodity_name"] ?? "-",
                            ),
                          ),
                        ).then((value) {
                          if (value == true) {
                            fetchTickets();
                          }
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item["plat"] ?? "-",
                                  style: const TextStyle(fontSize: 15),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusBg(item),
                                    border: Border.all(
                                      color: _getStatusColor(item),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getStatusIcon(item),
                                        size: 16,
                                        color: _getStatusColor(item),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusLabel(item),
                                        style: TextStyle(
                                          color: _getStatusColor(item),
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
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddSampleQCPKPage(userId: widget.userId, token: widget.token),
            ),
          ).then((value) {
            if (value == true) {
              fetchTickets();
            }
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
