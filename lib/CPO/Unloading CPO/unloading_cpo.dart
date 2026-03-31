import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/response/unloading_cpo_response.dart';
import 'package:flutter_vcf/models/unloading_cpo_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_unloading_cpo.dart';
import 'input_unloading_cpo.dart';

enum UnloadingCPOStage { start, finish }

extension UnloadingCPOStageX on UnloadingCPOStage {
  String get mainStatus =>
      this == UnloadingCPOStage.start ? 'start_unloading' : 'finish_unloading';

  String get holdStatus =>
      this == UnloadingCPOStage.start
          ? 'start_unloading_hold'
          : 'finish_unloading_hold';

  String get title =>
      this == UnloadingCPOStage.start
          ? 'Dashboard Start Unloading CPO'
          : 'Dashboard Finish Unloading CPO';

  String get addTitle =>
      this == UnloadingCPOStage.start
          ? 'Tambah Start Unloading CPO'
          : 'Tambah Finish Unloading CPO';

  String get inputTitle =>
      this == UnloadingCPOStage.start
          ? 'Input Start Unloading CPO'
          : 'Input Finish Unloading CPO';
}

class UnloadingCPOPage extends StatefulWidget {
  final String userId;
  final String token;
  final UnloadingCPOStage stage;

  const UnloadingCPOPage({
    super.key,
    required this.userId,
    required this.token,
    this.stage = UnloadingCPOStage.start,
  });

  @override
  State<UnloadingCPOPage> createState() => _UnloadingCPOPageState();
}

class _UnloadingCPOPageState extends State<UnloadingCPOPage> {
  final apiService = ApiService(AppConfig.createDio());

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? widget.token;
  }

  Future<UnloadingCPOResponse> _fetchVehicles(String token) {
    if (widget.stage == UnloadingCPOStage.start) {
      return apiService.getPosts(
        token,
        includeRejected: true,
        includeCancel: true,
      );
    }

    return apiService.getFinishUnloadingCpoVehicles(
      token,
      includeRejected: true,
      includeCancel: true,
      includeCompleted: true,
    );
  }

  Future<List<UnloadingCpoModel>> _fetchDashboardVehicles(String token) async {
    if (widget.stage == UnloadingCPOStage.finish) {
      final response = await _fetchVehicles(token);
      return response.data ?? [];
    }

    final responses = await Future.wait([
      apiService.getPosts(
        token,
        includeRejected: true,
        includeCancel: true,
      ),
      apiService.getFinishUnloadingCpoVehicles(
        token,
        includeRejected: true,
        includeCancel: true,
        includeCompleted: true,
      ),
    ]);

    final merged = <String, UnloadingCpoModel>{};

    for (final item in responses[0].data ?? <UnloadingCpoModel>[]) {
      final key = item.registration_id ?? item.wb_ticket_no ?? '';
      if (key.isNotEmpty) {
        merged[key] = item;
      }
    }

    for (final item in responses[1].data ?? <UnloadingCpoModel>[]) {
      final key = item.registration_id ?? item.wb_ticket_no ?? '';
      if (key.isNotEmpty) {
        merged[key] = item;
      }
    }

    return merged.values.toList();
  }

  String _normalize(String? value) => (value ?? '').toLowerCase().trim();

  String _itemStage(UnloadingCpoModel item) {
    final stage = _normalize(item.stage);
    if (stage.isNotEmpty) return stage;

    final latestStatus = _normalize(item.latest_status);
    if (latestStatus.isNotEmpty) return latestStatus;

    return _normalize(item.regist_status);
  }

  String _displayStatusForItem(UnloadingCpoModel item) {
    final latestStatus = _normalize(item.latest_status);
    final stage = _itemStage(item);
    final unloadingStatus = _normalize(item.unloading_status);
    final unloading2Status = _normalize(item.unloading_2_status);

    if (latestStatus == 'random_check' || stage == 'random_check') {
      return 'random_check';
    }

    if (widget.stage == UnloadingCPOStage.start) {
      if (latestStatus == widget.stage.holdStatus || unloadingStatus == 'hold') {
        return widget.stage.holdStatus;
      }
      if (latestStatus == 'start_unloading_rejected' || unloadingStatus == 'rejected') {
        return 'cancel';
      }
      if (latestStatus == 'start_unloading_cancel' || unloadingStatus == 'cancel') {
        return 'cancel';
      }
      if (unloadingStatus == 'approved' ||
          latestStatus == 'finish_unloading' ||
          stage == 'finish_unloading' ||
          latestStatus == 'wb_out') {
        return 'approved';
      }
      return stage;
    }

    if (latestStatus == 'finish_unloading_rejected' || unloading2Status == 'rejected') {
      return 'cancel';
    }
    if (latestStatus == 'finish_unloading_cancel' || unloading2Status == 'cancel') {
      return 'cancel';
    }
    if (latestStatus == 'wb_out' || unloading2Status == 'approved') {
      return 'approved';
    }
    return stage;
  }

  bool _shouldShowOnDashboard(UnloadingCpoModel item) {
    final stage = _itemStage(item);
    final latestStatus = _normalize(item.latest_status);
    final unloadingStatus = _normalize(item.unloading_status);
    final unloading2Status = _normalize(item.unloading_2_status);

    if (widget.stage == UnloadingCPOStage.start) {
      if (latestStatus == 'random_check' || stage == 'random_check') return true;
      if (latestStatus == widget.stage.holdStatus || unloadingStatus == 'hold') return true;
      if (latestStatus == 'start_unloading_rejected' || unloadingStatus == 'rejected') {
        return true;
      }
      if (latestStatus == 'start_unloading_cancel' || unloadingStatus == 'cancel') {
        return true;
      }
      if (unloadingStatus == 'approved' ||
          latestStatus == 'finish_unloading' ||
          stage == 'finish_unloading' ||
          latestStatus == 'wb_out') {
        return true;
      }
      return false;
    }

    if (latestStatus == 'finish_unloading_rejected' || unloading2Status == 'rejected') {
      return true;
    }
    if (latestStatus == 'finish_unloading_cancel' || unloading2Status == 'cancel') {
      return true;
    }
    if (latestStatus == 'wb_out' || unloading2Status == 'approved') {
      return true;
    }
    return false;
  }

  void _logDashboardVehicles(String source, List<UnloadingCpoModel> items) {
    log(
      '[CPO ${widget.stage.name}] $source count=${items.length}',
      name: 'unloading_cpo_dashboard',
    );
    for (final item in items) {
      final displayStatus = _displayStatusForItem(item);
      log(
        '[CPO ${widget.stage.name}] regId=${item.registration_id} ticket=${item.wb_ticket_no} plate=${item.plate_number} '
        'regist=${item.regist_status} latest=${item.latest_status} stage=${item.stage} '
        'unload1=${item.unloading_status} unload2=${item.unloading_2_status} display=$displayStatus',
        name: 'unloading_cpo_dashboard',
      );
    }
  }

  String _displayStatus(String status) {
    if (status == widget.stage.holdStatus) {
      return 'HOLD';
    }
    if (status.contains('hold')) {
      return 'HOLD';
    }
    if (status.contains('rejected')) {
      return 'REJECTED';
    }
    if (status == 'random_check') {
      return 'Pending Manager Approval';
    }
    if (status.contains('cancel')) {
      return 'CANCEL';
    }
    if (status == 'approved' || status == 'wb_out') {
      return 'APPROVED';
    }
    return status.toUpperCase();
  }

  Color _statusColor(String status) {
    if (status == widget.stage.holdStatus) return Colors.orange;
    if (status.contains('hold')) return Colors.orange;
    if (status.contains('rejected') || status.contains('cancel')) return Colors.red;
    if (status == 'random_check') return Colors.yellow.shade700;
    if (status == 'approved' || status == 'wb_out') return Colors.green;
    return Colors.grey;
  }

  IconData _statusIcon(String status) {
    if (status == widget.stage.holdStatus) return Icons.pause_circle_outline;
    if (status.contains('hold')) return Icons.pause_circle_outline;
    if (status.contains('rejected') || status.contains('cancel')) return Icons.cancel_outlined;
    if (status == 'random_check') return Icons.error_outline;
    if (status == 'approved' || status == 'wb_out') return Icons.check_circle_outline;
    return Icons.help_outline;
  }

  bool _isEditableStatus(String status) {
    return widget.stage == UnloadingCPOStage.start && status == widget.stage.holdStatus;
  }

  Future<void> _openAddPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddUnloadingCPOPage(
          userId: widget.userId,
          token: widget.token,
          stage: widget.stage,
        ),
      ),
    );

    if (result != null) setState(() {});
  }

  Future<void> _openInputPage(UnloadingCpoModel model) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InputUnloadingCPOPage(
          model: model,
          token: widget.token,
          stage: widget.stage,
        ),
      ),
    );

    if (result != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stage.title),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<List<UnloadingCpoModel>>(
        future: _getToken().then((t) => _fetchDashboardVehicles('Bearer $t')),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            log('${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final trucks = snapshot.data ?? [];
          _logDashboardVehicles('raw dashboard vehicles', trucks);
          final filtered = trucks.where(_shouldShowOnDashboard).toList();
          _logDashboardVehicles('filtered dashboard vehicles', filtered);

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                widget.stage == UnloadingCPOStage.start
                    ? 'Belum ada hasil Start Unloading.'
                    : 'Belum ada hasil Finish Unloading.',
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final item = filtered[index];
              final status = _displayStatusForItem(item);

              return GestureDetector(
                onTap: () {
                  if (_isEditableStatus(status)) {
                    _openInputPage(item);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status selesai - tidak dapat dibuka'),
                      ),
                    );
                  }
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          'Nomor Tiket Timbang : ${item.wb_ticket_no ?? '-'}',
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
                              item.plate_number ?? '-',
                              style: const TextStyle(fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                border: Border.all(color: _statusColor(status)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _statusIcon(status),
                                    size: 16,
                                    color: _statusColor(status),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _displayStatus(status),
                                    style: TextStyle(
                                      color: _statusColor(status),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _openAddPage,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
