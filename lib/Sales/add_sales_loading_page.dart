import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'input_sales_loading_page.dart';
import 'sales_api.dart';
import 'sales_loading_page.dart';

class SalesAddLoadingPage extends StatefulWidget {
  const SalesAddLoadingPage({
    super.key,
    required this.userId,
    required this.token,
    this.stage = SalesLoadingStage.start,
  });

  final String userId;
  final String token;
  final SalesLoadingStage stage;

  @override
  State<SalesAddLoadingPage> createState() => _SalesAddLoadingPageState();
}

class _SalesAddLoadingPageState extends State<SalesAddLoadingPage> {
  final SalesApi _api = SalesApi();

  String? _selectedRegistrationId;
  List<JsonMap> _readyVehicles = const <JsonMap>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? widget.token;
  }

  String _normalize(dynamic value) => (value ?? '').toString().toLowerCase().trim();

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

  bool _isReadyForCreate(JsonMap item) {
    final stage = _itemStage(item);
    final loadingStatus = _loadingStatus(item);
    final loading2Status = _loading2Status(item);

    if (widget.stage == SalesLoadingStage.start) {
      return (stage == widget.stage.mainStatus || stage == 'loading') && loadingStatus.isEmpty;
    }

    return stage == widget.stage.mainStatus && loading2Status.isEmpty;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final vehicles = widget.stage == SalesLoadingStage.start
          ? await _api.getStartLoadingVehicles('Bearer $token')
          : await _api.getFinishLoadingVehicles('Bearer $token');

      if (!mounted) return;
      setState(() {
        _readyVehicles = vehicles.where(_isReadyForCreate).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _readyVehicles.isEmpty
          ? Center(
              child: Text(
                widget.stage == SalesLoadingStage.start
                    ? 'Tidak ada kendaraan yang siap Start Loading.'
                    : 'Tidak ada kendaraan yang siap Finish Loading.',
                style: const TextStyle(color: Colors.black54, fontSize: 15),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Silakan pilih plat kendaraan yang siap diproses',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Plat Kendaraan',
                    ),
                    initialValue: _selectedRegistrationId,
                    items: _readyVehicles.map((item) {
                      final registrationId = item['registration_id']?.toString() ?? '';
                      final plateNumber = item['plate_number']?.toString() ?? '-';
                      final ticketNumber = item['wb_ticket_no']?.toString() ?? '-';
                      return DropdownMenuItem<String>(
                        value: registrationId,
                        child: Text('$plateNumber ($ticketNumber)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedRegistrationId = value);
                    },
                  ),
                  const SizedBox(height: 25),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      label: const Text(
                        'Lanjut ke Input',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      onPressed: _selectedRegistrationId == null
                          ? null
                          : () async {
                              final kendaraan = _readyVehicles.firstWhere(
                                (item) => item['registration_id'] == _selectedRegistrationId,
                              );

                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SalesInputLoadingPage(
                                    model: kendaraan,
                                    token: widget.token,
                                    stage: widget.stage,
                                  ),
                                ),
                              );

                              if (!context.mounted) return;
                              if (result != null) {
                                Navigator.pop(context, result);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}