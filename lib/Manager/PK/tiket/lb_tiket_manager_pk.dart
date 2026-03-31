import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/Manager/manager_check_ticket_filter.dart';
import 'package:flutter_vcf/Manager/widgets/operator_photo_preview_section.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/manager/manager_check_detail.dart';
import 'package:flutter_vcf/models/manager/manager_check_ticket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LbTiketManagerPKPage extends StatefulWidget {
  final String userId;
  final String token;

  const LbTiketManagerPKPage({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<LbTiketManagerPKPage> createState() => _LbTiketManagerPKPageState();
}

class _LbTiketManagerPKPageState extends State<LbTiketManagerPKPage> {
  List<ManagerCheckTicket> tickets = [];
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
    return prefs.getString("jwt_token") ??
        prefs.getString("token") ??
        widget.token;
  }

  String _stageLabel(String? stage) {
    switch (stage) {
      case 'sampling':
        return 'Sampling';
      case 'lab':
        return 'Lab';
      case 'unloading':
        return 'Unloading';
      default:
        return stage ?? '-';
    }
  }

  Future<void> fetchTickets() async {
    setState(() => isLoading = true);
    try {
      final token = await getToken();
      final rawToken = (token ?? widget.token).trim();
      final authToken = rawToken.startsWith('Bearer ')
          ? rawToken
          : 'Bearer $rawToken';
      final res = await api.getManagerCheckTickets(
        authToken,
        "PK",
        stage: "lab",
      );

      final randomStageTickets = await filterRandomCheckTicketsByStage(
        api: api,
        authorizationToken: authToken,
        stage: 'lab',
        tickets: res.data ?? [],
      );

      if (!mounted) return;
      setState(() {
        tickets = randomStageTickets;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal fetch data: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Lab PK"),
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
                "Tidak ada tiket lab untuk di-check.",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchTickets,
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (_, i) {
                  final ticket = tickets[i];
                  final rawLatestStatus = (ticket.latest_check_status ?? '')
                      .toUpperCase()
                      .trim();
                  final latestStatus = rawLatestStatus == 'APPROVED'
                      ? 'APPROVE'
                      : rawLatestStatus == 'REJECTED'
                      ? 'REJECT'
                      : rawLatestStatus;
                  final isFinalChecked =
                      latestStatus == 'APPROVE' || latestStatus == 'REJECT';
                  final hasManagerCheck = ticket.has_manager_check == true;
                  final isChecked = hasManagerCheck && isFinalChecked;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (isChecked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Already checked: ${latestStatus.isNotEmpty ? latestStatus : 'DONE'}",
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ManagerLabCheckInputPage(
                              token: widget.token,
                              ticket: ticket,
                              onComplete: () {
                                fetchTickets();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "WB: ${ticket.wb_ticket_no ?? '-'}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (hasManagerCheck)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          latestStatus.isNotEmpty
                                              ? latestStatus
                                              : "Checked",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ticket.plate_number ?? "-",
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Driver: ${ticket.driver_name ?? '-'}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              "Vendor: ${ticket.vendor_name ?? '-'}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            // Previous stage checks history
                            if (ticket.previous_checks != null &&
                                ticket.previous_checks!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: ticket.previous_checks!.map((check) {
                                  final isApproved =
                                      check.check_status == "APPROVE";
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isApproved
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isApproved
                                            ? Colors.green.shade400
                                            : Colors.red.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isApproved
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 14,
                                          color: isApproved
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${_stageLabel(check.stage)}: ${check.check_status}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isApproved
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// =============================================================================
// NESTED INPUT PAGE FOR MANAGER LAB CHECK (PK - FFA, Moisture, Dirt, Oil Content)
// =============================================================================

class _ManagerLabCheckInputPage extends StatefulWidget {
  final String token;
  final ManagerCheckTicket ticket;
  final VoidCallback onComplete;

  const _ManagerLabCheckInputPage({
    required this.token,
    required this.ticket,
    required this.onComplete,
  });

  @override
  State<_ManagerLabCheckInputPage> createState() =>
      _ManagerLabCheckInputPageState();
}

class _ManagerLabCheckInputPageState extends State<_ManagerLabCheckInputPage> {
  ManagerCheckDetail? detail;
  Map<String, dynamic>? operatorLabData;
  List<String> operatorPhotoSources = [];
  bool isLoading = true;
  bool isSubmitting = false;

  final TextEditingController remarksCtrl = TextEditingController();
  final TextEditingController mgrFfaCtrl = TextEditingController();
  final TextEditingController mgrMoistureCtrl = TextEditingController();
  final TextEditingController mgrDirtCtrl = TextEditingController();
  final TextEditingController mgrOilContentCtrl = TextEditingController();

  late ApiService api;

  @override
  void initState() {
    super.initState();
    api = ApiService(AppConfig.createDio());
    _loadDetail();
  }

  @override
  void dispose() {
    remarksCtrl.dispose();
    mgrFfaCtrl.dispose();
    mgrMoistureCtrl.dispose();
    mgrDirtCtrl.dispose();
    mgrOilContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final registrationId = widget.ticket.registration_id;
    if (registrationId == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration ID is missing"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final res = await api.getManagerCheckTicketDetail(
        "Bearer ${widget.token}",
        registrationId,
        "lab",
      );

      Map<String, dynamic>? fallbackLabData;
        List<String> fallbackPhotoSources = [];
      final managerLabData = res.data?.lab_data;
      final managerLabDataEmpty =
          managerLabData == null || managerLabData.isEmpty;

      if (managerLabDataEmpty) {
        try {
          final labRes = await api.getLabPkDetail(
            "Bearer ${widget.token}",
            registrationId,
          );
          final records = labRes.data?.labRecords ?? [];
          if (records.isNotEmpty) {
            final sorted = [...records]
              ..sort((a, b) => (a.counter ?? 0).compareTo(b.counter ?? 0));
            final latest = sorted.last;
            fallbackLabData = {
              'counter': latest.counter,
              'ffa': latest.ffa,
              'moisture': latest.moisture,
              'dirt': latest.dirt,
              'oil_content': latest.oilContent,
              'tested_by': latest.testedBy,
              'tested_at': latest.testedAt,
            };
            fallbackPhotoSources = (latest.photos ?? [])
                .map((p) => p.url ?? p.path ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {
          fallbackLabData = null;
        }
      }

      final primaryPhotoSources = managerLabDataEmpty
          ? <String>[]
          : extractOperatorPhotoSources([
              managerLabData,
              res.data?.lab_records,
              res.data?.pk_cycle_records,
            ]);

      if (fallbackPhotoSources.isEmpty && primaryPhotoSources.isEmpty) {
        try {
          final labRes = await api.getLabPkDetail(
            "Bearer ${widget.token}",
            registrationId,
          );
          final records = labRes.data?.labRecords ?? [];
          if (records.isNotEmpty) {
            final sorted = [...records]
              ..sort((a, b) => (a.counter ?? 0).compareTo(b.counter ?? 0));
            final latest = sorted.last;
            fallbackPhotoSources = (latest.photos ?? [])
                .map((p) => p.url ?? p.path ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        detail = res.data;
        operatorLabData = managerLabDataEmpty
            ? fallbackLabData
            : managerLabData;
        operatorPhotoSources = primaryPhotoSources.isNotEmpty
            ? primaryPhotoSources
            : fallbackPhotoSources;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal load detail: $e")));
    }
  }

  Future<void> _submit(String status) async {
    final registrationId = widget.ticket.registration_id?.trim();
    if (registrationId == null || registrationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration ID tidak ditemukan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final requestData = <String, dynamic>{
        'registration_id': registrationId,
        'check_status': status.toUpperCase(),
        'remarks': remarksCtrl.text.trim(),
      };

      final mgrFfa = _toDoubleOrNull(mgrFfaCtrl.text);
      final mgrMoisture = _toDoubleOrNull(mgrMoistureCtrl.text);
      final mgrDirt = _toDoubleOrNull(mgrDirtCtrl.text);
      final mgrOilContent = _toDoubleOrNull(mgrOilContentCtrl.text);

      if (mgrFfa != null) requestData['mgr_ffa'] = mgrFfa;
      if (mgrMoisture != null) requestData['mgr_moisture'] = mgrMoisture;
      if (mgrDirt != null) requestData['mgr_dirt'] = mgrDirt;
      if (mgrOilContent != null) requestData['mgr_oil_content'] = mgrOilContent;

      await api.submitManagerLabCheck("Bearer ${widget.token}", requestData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Check submitted: $status"),
          backgroundColor: Colors.green,
        ),
      );
      widget.onComplete();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);

      if (e.response?.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This ticket has already been checked"),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
        return;
      }

      final errorMessage =
          e.response?.data?['message'] ?? e.message ?? 'Unknown error';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $errorMessage"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _managerInputField(
    String label,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  double? _toDoubleOrNull(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Lab Check"),
        backgroundColor: Colors.brown,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticket Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Ticket Info",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          _readOnlyField(
                            "WB Ticket",
                            widget.ticket.wb_ticket_no ?? "-",
                          ),
                          _readOnlyField(
                            "Plate Number",
                            widget.ticket.plate_number ?? "-",
                          ),
                          _readOnlyField(
                            "Driver",
                            widget.ticket.driver_name ?? "-",
                          ),
                          _readOnlyField(
                            "Vendor",
                            widget.ticket.vendor_name ?? "-",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Operator Lab Data Card (PK: FFA, Moisture, Dirt, Oil Content)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Operator Lab Values",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          _readOnlyField(
                            "Counter (Resample)",
                            "${operatorLabData?['counter'] ?? '-'}",
                          ),
                          _readOnlyField(
                            "FFA",
                            "${operatorLabData?['ffa'] ?? '-'}",
                          ),
                          _readOnlyField(
                            "Moisture",
                            "${operatorLabData?['moisture'] ?? '-'}",
                          ),
                          _readOnlyField(
                            "Dirt",
                            "${operatorLabData?['dirt'] ?? '-'}",
                          ),
                          _readOnlyField(
                            "Oil Content",
                            "${operatorLabData?['oil_content'] ?? '-'}",
                          ),
                          _readOnlyField(
                            "Tested By",
                            "${operatorLabData?['tested_by'] ?? '-'}",
                          ),
                          _readOnlyField(
                            "Tested At",
                            "${operatorLabData?['tested_at'] ?? '-'}",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  OperatorPhotoPreviewSection(
                    photoSources: operatorPhotoSources,
                  ),

                  if (operatorPhotoSources.isNotEmpty)
                    const SizedBox(height: 16),

                  // Manager lab input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Input Manager Lab",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          _managerInputField("Manager FFA", mgrFfaCtrl),
                          _managerInputField(
                            "Manager Moisture",
                            mgrMoistureCtrl,
                          ),
                          _managerInputField("Manager Dirt", mgrDirtCtrl),
                          _managerInputField(
                            "Manager Oil Content",
                            mgrOilContentCtrl,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Remarks Field
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Remarks",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          TextFormField(
                            controller: remarksCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: "Enter remarks (optional)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // APPROVE / REJECT Buttons
                  if (isSubmitting)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _submit("REJECT"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              "REJECT",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _submit("APPROVE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              "APPROVE",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
