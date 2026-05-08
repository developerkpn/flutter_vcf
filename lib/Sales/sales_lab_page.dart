import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_sales_lab_page.dart';
import 'sales_api.dart';

class SalesLabPage extends StatefulWidget {
  const SalesLabPage({
    super.key,
    required this.userId,
    required this.token,
  });

  final String userId;
  final String token;

  @override
  State<SalesLabPage> createState() => _SalesLabPageState();
}

class _SalesLabPageState extends State<SalesLabPage> {
  final SalesApi _api = SalesApi();

  List<JsonMap> _tickets = const <JsonMap>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? widget.token;
  }

  String _normalize(dynamic value) => (value ?? '').toString().toLowerCase().trim();

  String _resolveDisplayStatus(JsonMap ticket) {
    final regist = _normalize(ticket['regist_status']);
    final lab = _normalize(ticket['lab_status']);

    if (regist == 'random_check') {
      return 'pending_manager_approval';
    }

    if (lab == 'approved') {
      return lab;
    }

    if (regist == 'approved' || regist == 'wb_out') {
      return 'approved';
    }

    return 'pending';
  }

  bool _shouldShowOnDashboard(JsonMap ticket) {
    final regist = _normalize(ticket['regist_status']);
    final lab = _normalize(ticket['lab_status']);

    if (regist == 'random_check') return true;
    return lab == 'approved' || regist == 'approved' || regist == 'wb_out';
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final vehicles = await _api.getLabVehicles(
        'Bearer $token',
      );

      if (!mounted) return;
      setState(() {
        _tickets = vehicles.where(_shouldShowOnDashboard).toList();
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

  Future<void> _openAddPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesAddLabPage(
          userId: widget.userId,
          token: widget.token,
        ),
      ),
    );

    if (result != null) {
      _fetchTickets();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending_manager_approval':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'pending_manager_approval':
        return Icons.error_outline;
      default:
        return Icons.hourglass_bottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Sales Lab'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTickets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? const Center(
              child: Text(
                'Belum ada tiket Sales Lab',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _tickets.length,
              itemBuilder: (_, index) {
                final ticket = _tickets[index];
                final status = _resolveDisplayStatus(ticket);
                final statusColor = _statusColor(status);
                final statusIcon = _statusIcon(status);
                final statusLabel = status == 'pending_manager_approval'
                    ? 'Pending Manager Approval'
                    : status == 'pending'
                    ? 'PENDING'
                    : status.toUpperCase();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text('Tiket: ${ticket['wb_ticket_no'] ?? '-'}'),
                    subtitle: Text('Plat: ${ticket['plate_number'] ?? '-'}'),
                    trailing: Chip(
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      side: BorderSide(color: statusColor),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _openAddPage,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}