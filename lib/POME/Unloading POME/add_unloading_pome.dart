import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/pome/unloading_pome_model.dart';
import 'package:flutter_vcf/models/pome/response/unloading_pome_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'input_unloading_pome.dart';
import 'unloading_pome.dart';

class AddUnloadingPOMEPage extends StatefulWidget {
  final String userId;
  final String token;
  final UnloadingPOMEStage stage;

  const AddUnloadingPOMEPage({
    super.key,
    required this.userId,
    required this.token,
    this.stage = UnloadingPOMEStage.start,
  });

  @override
  State<AddUnloadingPOMEPage> createState() => _AddUnloadingPOMEPageState();
}

class _AddUnloadingPOMEPageState extends State<AddUnloadingPOMEPage> {
  String? selectedRegistrationId;

  late Future<UnloadingPOMEResponse> futureVehicles =
      Future.value(UnloadingPOMEResponse(success: true, message: "", data: []));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ?? widget.token;
  }

  void _loadData() async {
    final token = await _getToken();
    final apiService = ApiService(AppConfig.createDio());

    setState(() {
      if (widget.stage == UnloadingPOMEStage.start) {
        futureVehicles = apiService.getUnloadingPomeData("Bearer $token");
      } else {
        futureVehicles = apiService.getFinishUnloadingPomeData("Bearer $token");
      }
    });
  }

  String _normalize(String? value) => (value ?? '').toLowerCase().trim();

  String _itemStage(UnloadingPomeModel item) {
    final stage = _normalize(item.stage);
    if (stage.isNotEmpty) return stage;

    final latestStatus = _normalize(item.latest_status);
    if (latestStatus.isNotEmpty) return latestStatus;

    return _normalize(item.regist_status);
  }

  bool _isReadyForCreate(UnloadingPomeModel item) {
    final stage = _itemStage(item);
    final unloadingStatus = _normalize(item.unloading_status);
    final unloading2Status = _normalize(item.unloading_2_status);

    if (widget.stage == UnloadingPOMEStage.start) {
      return (stage == widget.stage.mainStatus || stage == 'unloading') &&
          unloadingStatus.isEmpty;
    }

    return stage == widget.stage.mainStatus && unloading2Status.isEmpty;
  }

  void _logVehicles(String source, List<UnloadingPomeModel> items) {
    log(
      '[POME ${widget.stage.name}] $source count=${items.length}',
      name: 'unloading_pome_add',
    );
    for (final item in items) {
      log(
        '[POME ${widget.stage.name}] regId=${item.registration_id} ticket=${item.wb_ticket_no} plate=${item.plate_number} '
        'regist=${item.regist_status} latest=${item.latest_status} stage=${item.stage} '
        'unload1=${item.unloading_status} unload2=${item.unloading_2_status}',
        name: 'unloading_pome_add',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stage.addTitle),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),

      body: FutureBuilder<UnloadingPOMEResponse>(
        future: futureVehicles,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data?.data ?? [];
          _logVehicles('raw vehicles', data);

          final readyVehicles = data.where(_isReadyForCreate).toList();
          _logVehicles('filtered ready vehicles', readyVehicles);

          // Ambil plat 
          if (readyVehicles.isEmpty) {
            return Center(
              child: Text(
                widget.stage == UnloadingPOMEStage.start
                    ? "Tidak ada kendaraan yang siap Start Unloading POME."
                    : "Tidak ada kendaraan yang siap Finish Unloading POME.",
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          final validIds = readyVehicles
              .map((e) => e.registration_id)
              .whereType<String>()
              .toSet();

          if (selectedRegistrationId != null &&
              !validIds.contains(selectedRegistrationId)) {
            selectedRegistrationId = null;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Silakan pilih plat kendaraan yang siap diproses',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Plat Kendaraan',
                  ),
                  value: selectedRegistrationId,
                  items: readyVehicles.map((item) {
                    final registrationId = item.registration_id ?? '';
                    return DropdownMenuItem(
                      value: registrationId,
                      child: Text(
                        "${item.plate_number ?? '-'} (${item.wb_ticket_no ?? '-'})",
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedRegistrationId = value),
                ),

                const SizedBox(height: 25),

                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: const Text(
                      "Lanjut ke Input",
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: selectedRegistrationId == null
                        ? null
                        : () async {
                            final kendaraan = readyVehicles.firstWhere(
                              (item) => item.registration_id == selectedRegistrationId,
                            );

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InputUnloadingPOMEPage(
                                  model: kendaraan,
                                  token: widget.token,
                                  stage: widget.stage,
                                ),
                              ),
                            );

                            if (result != null) {
                              Navigator.pop(context, result);
                            }
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
