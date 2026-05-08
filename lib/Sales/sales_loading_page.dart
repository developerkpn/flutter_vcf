import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_sales_loading_page.dart';
import 'sales_api.dart';

enum SalesLoadingStage { start, finish }

extension SalesLoadingStageX on SalesLoadingStage {
  String get mainStatus =>
      this == SalesLoadingStage.start ? 'start_loading' : 'finish_loading';

  String get title =>
      this == SalesLoadingStage.start ? 'Dashboard Start Loading Sales' : 'Dashboard Finish Loading Sales';

  String get addTitle =>
      this == SalesLoadingStage.start ? 'Tambah Start Loading Sales' : 'Tambah Finish Loading Sales';

  String get inputTitle =>
      this == SalesLoadingStage.start ? 'Input Start Loading Sales' : 'Input Finish Loading Sales';
}

class SalesLoadingPage extends StatefulWidget {
  const SalesLoadingPage({
    super.key,
    required this.userId,
    required this.token,
    this.stage = SalesLoadingStage.start,
  });

  final String userId;
  final String token;
  final SalesLoadingStage stage;

  @override
  State<SalesLoadingPage> createState() => _SalesLoadingPageState();
}

class _SalesLoadingPageState extends State<SalesLoadingPage> {
  final SalesApi _api = SalesApi();
  final Map<String, JsonMap> _dashboardOverrides = <String, JsonMap>{};

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? widget.token;
  }

  String _normalize(dynamic value) => (value ?? '').toString().toLowerCase().trim();

  String _itemKey(JsonMap item) {
    final registrationId = _normalize(item['registration_id']);
    if (registrationId.isNotEmpty) return registrationId;
    return _normalize(item['wb_ticket_no']);
  }

  String _itemStage(JsonMap item) {
    final stage = _normalize(item['stage']);
    if (stage.isNotEmpty) return stage;

    final latestStatus = _normalize(item['latest_status']);
    if (latestStatus.isNotEmpty) return latestStatus;

    return _normalize(item['regist_status']);
  }

  String _loadingStatus(JsonMap item) {
    return _normalize(
      item['loading_status'] ?? item['start_loading_status'] ?? item['unloading_status'],
    );
  }

  String _loading2Status(JsonMap item) {
    return _normalize(
      item['finish_loading_status'] ??
          item['loading_2_status'] ??
          item['unloading_2_status'],
    );
  }

  Future<List<JsonMap>> _fetchVehicles(String token) {
    if (widget.stage == SalesLoadingStage.start) {
      return _api.getStartLoadingVehicles(token);
    }

    return _api.getFinishLoadingVehicles(
      token,
      includeCompleted: true,
    );
  }

  Future<List<JsonMap>> _fetchDashboardVehicles(String token) async {
    if (widget.stage == SalesLoadingStage.finish) {
      final vehicles = await _fetchVehicles(token);
      final merged = <String, JsonMap>{
        for (final item in vehicles)
          if (_itemKey(item).isNotEmpty) _itemKey(item): item,
      };
      merged.addAll(_dashboardOverrides);
      return merged.values.toList();
    }

    final responses = await Future.wait(<Future<List<JsonMap>>>[
      _api.getStartLoadingVehicles(token),
      _api.getFinishLoadingVehicles(
        token,
        includeCompleted: true,
      ),
    ]);

    final merged = <String, JsonMap>{};
    for (final response in responses) {
      for (final item in response) {
        final key = _normalize(item['registration_id']).isNotEmpty
            ? item['registration_id'].toString()
            : item['wb_ticket_no']?.toString() ?? '';
        if (key.isNotEmpty) {
          merged[key] = item;
        }
      }
    }

    return merged.values.toList();
  }

  String _displayStatusForItem(JsonMap item) {
    final latestStatus = _normalize(item['latest_status']);
    final stage = _itemStage(item);
    final loadingStatus = _loadingStatus(item);
    final loading2Status = _loading2Status(item);

    if (latestStatus == 'random_check' || stage == 'random_check') {
      return 'random_check';
    }

    if (widget.stage == SalesLoadingStage.start) {
      if (loadingStatus == 'approved' ||
          latestStatus == 'finish_loading' ||
          stage == 'finish_loading' ||
          latestStatus == 'wb_out') {
        return 'approved';
      }
      return 'pending';
    }

    if (latestStatus == 'wb_out' || loading2Status == 'approved') {
      return 'approved';
    }
    return 'pending';
  }

  bool _shouldShowOnDashboard(JsonMap item) {
    final stage = _itemStage(item);
    final latestStatus = _normalize(item['latest_status']);
    final loadingStatus = _loadingStatus(item);
    final loading2Status = _loading2Status(item);

    if (widget.stage == SalesLoadingStage.start) {
      if (latestStatus == 'random_check' || stage == 'random_check') return true;
      if (loadingStatus == 'approved' ||
          latestStatus == 'finish_loading' ||
          stage == 'finish_loading' ||
          latestStatus == 'wb_out') {
        return true;
      }
      return false;
    }

    if (latestStatus == 'wb_out' || loading2Status == 'approved') {
      return true;
    }
    return false;
  }

  String _displayStatus(String status) {
    if (status == 'random_check') return 'Pending Manager Approval';
    if (status == 'approved' || status == 'wb_out') return 'APPROVED';
    return 'PENDING';
  }

  Color _statusColor(String status) {
    if (status == 'random_check') {
      return Colors.yellow.shade700;
    }
    if (status == 'approved' || status == 'wb_out') {
      return Colors.green;
    }
    return Colors.grey;
  }

  IconData _statusIcon(String status) {
    if (status == 'random_check') {
      return Icons.error_outline;
    }
    if (status == 'approved' || status == 'wb_out') {
      return Icons.check_circle_outline;
    }
    return Icons.help_outline;
  }

  Future<void> _openAddPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesAddLoadingPage(
          userId: widget.userId,
          token: widget.token,
          stage: widget.stage,
        ),
      ),
    );

    if (result != null && mounted) {
      if (widget.stage == SalesLoadingStage.finish && result is JsonMap) {
        await _mergeFinishApprovedDetail(result);
      }

      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _mergeFinishApprovedDetail(JsonMap result) async {
    final registrationId = _normalize(result['registration_id']);
    if (registrationId.isEmpty) return;

    try {
      final token = await _getToken();
      final detail = await _api.getFinishLoadingDetail(
        'Bearer $token',
        registrationId,
      );

      if (!mounted) return;
      setState(() {
        _dashboardOverrides[registrationId] = detail;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dashboardOverrides[registrationId] = <String, dynamic>{
          ...result,
          'finish_loading_status': 'approved',
        };
      });
    }
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
      body: FutureBuilder<List<JsonMap>>(
        future: _getToken().then((token) => _fetchDashboardVehicles('Bearer $token')),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tickets = (snapshot.data ?? const <JsonMap>[])
              .where(_shouldShowOnDashboard)
              .toList();

          if (tickets.isEmpty) {
            return Center(
              child: Text(
                widget.stage == SalesLoadingStage.start
                    ? 'Belum ada hasil Start Loading.'
                    : 'Belum ada hasil Finish Loading.',
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (_, index) {
              final item = tickets[index];
              final status = _displayStatusForItem(item);

              return Card(
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
                        'Nomor Tiket Timbang : ${item['wb_ticket_no'] ?? '-'}',
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
                            item['plate_number']?.toString() ?? '-',
                            style: const TextStyle(fontSize: 15),
                          ),
                          Chip(
                            backgroundColor: _statusColor(status).withValues(alpha: 0.15),
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