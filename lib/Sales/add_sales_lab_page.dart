import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'input_sales_lab_page.dart';
import 'sales_api.dart';

class SalesAddLabPage extends StatefulWidget {
  const SalesAddLabPage({
    super.key,
    required this.userId,
    required this.token,
  });

  final String userId;
  final String token;

  @override
  State<SalesAddLabPage> createState() => _SalesAddLabPageState();
}

class _SalesAddLabPageState extends State<SalesAddLabPage> {
  final SalesApi _api = SalesApi();

  String? _selectedRegistrationId;
  List<JsonMap> _tickets = const <JsonMap>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? widget.token;
  }

  String _normalize(dynamic value) => (value ?? '').toString().toLowerCase().trim();

  bool _isReadyForInput(JsonMap ticket) {
    final regist = _normalize(ticket['regist_status']);
    final labStatus = _normalize(ticket['lab_status']);
    return labStatus.isEmpty && !regist.contains('cancel');
  }

  Future<void> _fetchVehicles() async {
    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final vehicles = await _api.getLabVehicles('Bearer $token');

      if (!mounted) return;
      setState(() {
        _tickets = vehicles.where(_isReadyForInput).toList();
        _isLoading = false;
      });

      if (_tickets.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada kendaraan yang siap diuji lab.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal fetch data: $error')),
      );
    }
  }

  Future<void> _openInputPage(JsonMap ticket) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesInputLabPage(
          token: widget.token,
          model: ticket,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Sales Lab'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVehicles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? const Center(child: Text('Tidak ada kendaraan.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Plat Kendaraan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Plat Kendaraan',
                    ),
                    initialValue: _selectedRegistrationId,
                    items: _tickets.map((ticket) {
                      final registrationId = ticket['registration_id']?.toString() ?? '';
                      final plateNumber = ticket['plate_number']?.toString() ?? '-';
                      final ticketNo = ticket['wb_ticket_no']?.toString() ?? '-';
                      return DropdownMenuItem<String>(
                        value: registrationId,
                        child: Text('$plateNumber ($ticketNo)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedRegistrationId = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Mulai Sales Lab'),
                      onPressed: _selectedRegistrationId == null
                          ? null
                          : () {
                              final ticket = _tickets.firstWhere(
                                (item) => item['registration_id'] == _selectedRegistrationId,
                              );
                              _openInputPage(ticket);
                            },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}