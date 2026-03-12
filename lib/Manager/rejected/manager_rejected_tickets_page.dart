import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/Manager/manager_check_ticket_filter.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/manager/manager_check_detail.dart';
import 'package:flutter_vcf/models/manager/manager_check_ticket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerRejectedTicketsPage extends StatefulWidget {
  final String commodity;
  final String stage;
  final String token;

  const ManagerRejectedTicketsPage({
    super.key,
    required this.commodity,
    required this.stage,
    required this.token,
  });

  @override
  State<ManagerRejectedTicketsPage> createState() =>
      _ManagerRejectedTicketsPageState();
}

class _LabCycleView {
  final int cycleNo;
  final Map<String, dynamic> values;

  const _LabCycleView({required this.cycleNo, required this.values});
}

class _LabCycleExtraction {
  final List<_LabCycleView> cycles;
  final Set<String> consumedKeys;

  const _LabCycleExtraction({required this.cycles, required this.consumedKeys});
}

class _UnloadingCycleView {
  final int cycleNo;
  final Map<String, dynamic> values;

  const _UnloadingCycleView({required this.cycleNo, required this.values});
}

class _UnloadingCycleExtraction {
  final List<_UnloadingCycleView> cycles;
  final Set<String> consumedKeys;

  const _UnloadingCycleExtraction({
    required this.cycles,
    required this.consumedKeys,
  });
}

class _ManagerRejectedTicketsPageState
    extends State<ManagerRejectedTicketsPage> {
  late final ApiService _api;

  List<ManagerCheckTicket> _tickets = [];
  bool _isLoading = false;

  String get _normalizedStage => normalizeManagerCheckStage(widget.stage);

  String get _stageLabel => _normalizedStage == 'lab' ? 'Lab' : 'Unloading';

  String get _commodityLabel => widget.commodity.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _api = ApiService(AppConfig.createDio());
    _fetchTickets();
  }

  Future<String> _resolveAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('jwt_token') ?? prefs.getString('token');
    final raw = (stored ?? widget.token).trim();
    return raw.startsWith('Bearer ') ? raw : 'Bearer $raw';
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);

    try {
      final authToken = await _resolveAuthToken();
      final stageScopedRes = await _api.getManagerCheckTickets(
        authToken,
        _commodityLabel,
        stage: _normalizedStage,
      );

      var sourceTickets = stageScopedRes.data ?? const <ManagerCheckTicket>[];
      if (sourceTickets.isEmpty) {
        final fallbackRes = await _api.getManagerCheckTickets(
          authToken,
          _commodityLabel,
        );
        sourceTickets = fallbackRes.data ?? const <ManagerCheckTicket>[];
      }

      final filtered = await filterRejectedOperatorTicketsByStage(
        api: _api,
        authorizationToken: authToken,
        stage: _normalizedStage,
        tickets: sourceTickets,
      );

      if (!mounted) return;
      setState(() {
        _tickets = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil tiket rejected: $e')),
      );
    }
  }

  Future<void> _openDetail(ManagerCheckTicket ticket) async {
    final authToken = await _resolveAuthToken();
    if (!mounted) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerRejectedDetailPage(
          api: _api,
          authToken: authToken,
          commodity: _commodityLabel,
          stage: _normalizedStage,
          ticket: ticket,
        ),
      ),
    );

    if (updated == true) {
      _fetchTickets();
    }
  }

  Widget _buildTicketCard(ManagerCheckTicket ticket) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _openDetail(ticket),
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
                      'WB: ${ticket.wb_ticket_no ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.cancel_outlined,
                          size: 14,
                          color: Colors.red,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'REJECTED OPERATOR',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
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
                ticket.plate_number ?? '-',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Driver: ${ticket.driver_name ?? '-'}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Vendor: ${ticket.vendor_name ?? '-'}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Stage: ${ticket.current_stage ?? _normalizedStage}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                'Created: ${ticket.created_at ?? '-'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('List Tiket Rejected $_stageLabel $_commodityLabel'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchTickets),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? Center(
              child: Text(
                'Tidak ada tiket rejected operator untuk $_stageLabel.',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchTickets,
              child: ListView.builder(
                itemCount: _tickets.length,
                itemBuilder: (_, i) => _buildTicketCard(_tickets[i]),
              ),
            ),
    );
  }
}

class ManagerRejectedDetailPage extends StatefulWidget {
  final ApiService api;
  final String authToken;
  final String commodity;
  final String stage;
  final ManagerCheckTicket ticket;

  const ManagerRejectedDetailPage({
    super.key,
    required this.api,
    required this.authToken,
    required this.commodity,
    required this.stage,
    required this.ticket,
  });

  @override
  State<ManagerRejectedDetailPage> createState() =>
      _ManagerRejectedDetailPageState();
}

class _ManagerRejectedDetailPageState extends State<ManagerRejectedDetailPage> {
  ManagerCheckDetail? _detail;
  Map<String, dynamic>? _operatorData;
  final TextEditingController _remarksCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  String get _stageLabel => widget.stage == 'lab' ? 'Lab' : 'Unloading';

  String? _resolveDetailIdentifier() {
    final registrationId = widget.ticket.registration_id?.trim();
    if (registrationId != null && registrationId.isNotEmpty) {
      return registrationId;
    }

    final wbTicketNo = widget.ticket.wb_ticket_no?.trim();
    if (wbTicketNo != null && wbTicketNo.isNotEmpty) {
      return wbTicketNo;
    }

    final processId = widget.ticket.process_id?.trim();
    if (processId != null && processId.isNotEmpty) {
      return processId;
    }

    return null;
  }

  String _normalizeKey(String key) {
    return key.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  void _collectPreferredKeys({
    required Map<String, dynamic> source,
    required Map<String, dynamic> target,
    required String prefix,
    required List<String> keys,
  }) {
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      normalized[_normalizeKey(entry.key)] = entry.value;
    }

    for (final key in keys) {
      final value = normalized[_normalizeKey(key)];
      if (_hasValue(value)) {
        target['${prefix}_${_normalizeKey(key)}'] = value;
      }
    }
  }

  int _readCycleNo(Map<String, dynamic> source, int fallbackIndex) {
    final possibleKeys = ['cycle', 'cycle_no', 'cycle_number', 'counter'];
    for (final key in possibleKeys) {
      final raw = source[key] ?? source[_normalizeKey(key)];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }

    return fallbackIndex;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _buildPkCycleDataFromManagerDetail(
    ManagerCheckDetail? detail,
  ) {
    final result = <String, dynamic>{};
    if (detail == null) return result;

    final samplingRecords = detail.sampling_records ?? const [];
    final labRecords = detail.lab_records ?? const [];
    final cycleRecords = detail.pk_cycle_records ?? const [];

    result['sampling_records_count'] = samplingRecords.length;
    result['lab_records_count'] = labRecords.length;
    result['pk_cycle_total'] = cycleRecords.length;

    for (var i = 0; i < cycleRecords.length; i++) {
      final record = _asMap(cycleRecords[i]);
      if (record.isEmpty) continue;

      final cycleNo = _readCycleNo(record, i);
      final cycleKey = 'cycle_$cycleNo';

      _collectPreferredKeys(
        source: record,
        target: result,
        prefix: cycleKey,
        keys: const [
          'regist_status',
          'status',
          'lab_status',
          'unloading_status',
          'remarks',
        ],
      );

      final labSection = _asMap(
        record['lab'] ?? record['lab_data'] ?? record['lab_record'],
      );
      if (labSection.isNotEmpty) {
        _collectPreferredKeys(
          source: labSection,
          target: result,
          prefix: '${cycleKey}_lab',
          keys: const [
            'counter',
            'status',
            'lab_status',
            'ffa',
            'moisture',
            'dirt',
            'oil_content',
            'remarks',
            'tested_at',
            'tested_by',
          ],
        );
      }

      final unloadingSection = _asMap(
        record['unloading'] ??
            record['unloading_data'] ??
            record['unloading_record'],
      );
      if (unloadingSection.isNotEmpty) {
        _collectPreferredKeys(
          source: unloadingSection,
          target: result,
          prefix: '${cycleKey}_unloading',
          keys: const [
            'status',
            'unloading_status',
            'tank_id',
            'tank_name',
            'hole_id',
            'hole_name',
            'start_time',
            'end_time',
            'duration_minutes',
            'remarks',
          ],
        );
      }
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final identifier = _resolveDetailIdentifier();
    if (identifier == null || identifier.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifier tiket tidak ditemukan')),
      );
      return;
    }

    final registrationId = widget.ticket.registration_id?.trim();
    final isPkCommodity = widget.commodity.toUpperCase() == 'PK';

    try {
      final detailRes = await widget.api.getManagerCheckTicketDetail(
        widget.authToken,
        identifier,
        widget.stage,
      );

      final stageData = widget.stage == 'lab'
          ? detailRes.data?.lab_data
          : detailRes.data?.unloading_data;
      final managerData = <String, dynamic>{
        ...?stageData,
        ..._buildPkCycleDataFromManagerDetail(detailRes.data),
      };

      final hasManagerData = managerData != null && managerData.isNotEmpty;
      Map<String, dynamic>? fallbackData;
      String? fallbackWarning;

      if (!hasManagerData &&
          registrationId != null &&
          registrationId.isNotEmpty) {
        try {
          fallbackData = await _loadFallbackOperatorData(
            widget.authToken,
            registrationId,
          );
        } on DioException catch (e) {
          fallbackWarning =
              'Data operator belum tersedia (${e.response?.statusCode ?? '-'}).';
        } catch (_) {
          fallbackWarning = 'Data operator belum tersedia.';
        }
      }

      if (!hasManagerData && isPkCommodity && fallbackData == null) {
        fallbackWarning =
            'Data cycle PK belum tersedia di detail manager untuk stage ini.';
      }

      if (!mounted) return;
      setState(() {
        _detail = detailRes.data;
        _operatorData = hasManagerData ? managerData : fallbackData;
        _isLoading = false;
      });

      if (fallbackWarning != null && fallbackData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fallbackWarning),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on DioException catch (e) {
      Map<String, dynamic>? fallbackData;
      try {
        if (registrationId != null && registrationId.isNotEmpty) {
          fallbackData = await _loadFallbackOperatorData(
            widget.authToken,
            registrationId,
          );
        }
      } catch (_) {
        fallbackData = null;
      }

      if (!mounted) return;

      setState(() {
        _detail = null;
        _operatorData = fallbackData;
        _isLoading = false;
      });

      if (fallbackData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Detail manager tidak ditemukan, menampilkan data operator.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final statusCode = e.response?.statusCode;
      final message = statusCode == 404
          ? 'Identifier tiket tidak ditemukan (HTTP 404)'
          : statusCode == null
          ? 'Gagal memuat detail rejected: ${e.message}'
          : 'Gagal memuat detail rejected (HTTP $statusCode)';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail rejected: $e')),
      );
    }
  }

  Future<Map<String, dynamic>?> _loadFallbackOperatorData(
    String authToken,
    String registrationId,
  ) async {
    final commodity = widget.commodity.toUpperCase();

    if (widget.stage == 'lab') {
      if (commodity == 'CPO') {
        final res = await widget.api.getLabCpoDetail(authToken, registrationId);
        final d = res.data;
        if (d == null) return null;

        return {
          'ffa': d.ffa,
          'moisture': d.moisture,
          'dobi': d.dobi,
          'iv': d.iv,
          'status': d.status,
          'remarks': d.remarks,
          'tested_by': d.testedBy,
          'tested_at': d.testedAt,
        };
      }

      if (commodity == 'POME') {
        final res = await widget.api.getLabPomeDetail(
          authToken,
          registrationId,
        );
        final d = res.data;
        if (d == null) return null;

        return {
          'ffa': d.ffa,
          'moisture': d.moisture,
          'status': d.status,
          'remarks': d.remarks,
          'tested_by': d.testedBy,
          'tested_at': d.testedAt,
        };
      }

      if (commodity == 'PK') {
        final res = await widget.api.getLabPkDetail(authToken, registrationId);
        final d = res.data;
        if (d == null) return null;

        final records = [...?d.labRecords];
        records.sort((a, b) => (a.counter ?? 0).compareTo(b.counter ?? 0));
        final latest = records.isNotEmpty ? records.last : null;

        final cycleData = <String, dynamic>{};
        for (final record in records) {
          final counter = record.counter ?? 0;
          final cycleKey = counter == 0 ? 'lab_awal' : 'relab_$counter';
          cycleData['${cycleKey}_status'] = record.status;
          cycleData['${cycleKey}_ffa'] = record.ffa;
          cycleData['${cycleKey}_moisture'] = record.moisture;
          cycleData['${cycleKey}_dirt'] = record.dirt;
          cycleData['${cycleKey}_oil_content'] = record.oilContent;
          cycleData['${cycleKey}_remarks'] = record.remarks;
          cycleData['${cycleKey}_tested_at'] = record.testedAt;
          cycleData['${cycleKey}_tested_by'] = record.testedBy;
        }

        return {
          'lab_total_records': records.length,
          'counter': latest?.counter,
          'status': latest?.status,
          'ffa': latest?.ffa,
          'moisture': latest?.moisture,
          'dirt': latest?.dirt,
          'oil_content': latest?.oilContent,
          'remarks': latest?.remarks,
          'tested_by': latest?.testedBy,
          'tested_at': latest?.testedAt,
          ...cycleData,
        };
      }

      return null;
    }

    if (commodity == 'CPO') {
      final res = await widget.api.getUnloadingCpoDetail(
        authToken,
        registrationId,
      );
      final d = res.data;
      if (d == null) return null;

      return {
        'tank_id': d.tankId,
        'hole_id': d.holeId,
        'remarks': d.remarks,
        'photos_count': d.photos?.length,
      };
    }

    if (commodity == 'POME') {
      final res = await widget.api.getUnloadingPomeDetail(
        authToken,
        registrationId,
      );
      final d = res.data;
      if (d == null) return null;

      return {
        'tank_id': d.tankId,
        'tank_name': d.tank_name,
        'hole_id': d.holeId,
        'hole_name': d.hole_name,
        'unloading_status': d.unloadingStatus,
        'start_time': d.start_time,
        'end_time': d.end_time,
        'duration_minutes': d.durationMinutes,
        'remarks': d.remarks,
      };
    }

    if (commodity == 'PK') {
      final res = await widget.api.getUnloadingPkDetail(
        authToken,
        registrationId,
      );
      final d = res.data;
      if (d == null) return null;

      return {
        'tank_id': d.tankId,
        'tank_name': d.tankName,
        'hole_id': d.holeId,
        'hole_name': d.holeName,
        'unloading_status': d.unloadingStatus,
        'start_time': d.startTime,
        'end_time': d.endTime,
        'duration_minutes': d.durationMinutes,
        'remarks': d.remarks,
      };
    }

    return null;
  }

  Future<void> _submitDecision(String status) async {
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

    final payload = <String, dynamic>{
      'registration_id': registrationId,
      'check_status': status.toUpperCase(),
      'remarks': _remarksCtrl.text.trim(),
    };

    setState(() => _isSubmitting = true);

    try {
      if (widget.stage == 'lab') {
        await widget.api.submitManagerLabCheck(widget.authToken, payload);
      } else {
        await widget.api.submitManagerUnloadingCheck(widget.authToken, payload);
      }

      if (!mounted) return;
      final decisionLabel = status == 'REJECT' ? 'CANCEL' : status;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Keputusan manager tersimpan: $decisionLabel'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (e.response?.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiket sudah diproses manager sebelumnya'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal submit keputusan manager: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal submit keputusan manager: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmAndSubmitDecision(String status) async {
    if (_isSubmitting) return;

    final isReject = status.toUpperCase() == 'REJECT';
    final decisionLabel = isReject ? 'REJECT (CANCEL)' : 'APPROVE';
    final confirmationMessage = isReject
        ? 'Apakah Anda yakin ingin REJECT tiket ini?\n\nTiket akan di-CANCEL setelah keputusan ini dikirim.'
        : 'Apakah Anda yakin ingin APPROVE tiket ini?';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Konfirmasi Keputusan'),
          content: Text(confirmationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isReject ? Colors.red : Colors.green,
              ),
              child: Text(
                decisionLabel,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _submitDecision(status);
    }
  }

  String _toLabel(String key) {
    const special = <String, String>{
      'ffa': 'FFA',
      'dobi': 'DOBI',
      'iv': 'IV',
      'id': 'ID',
      'pk': 'PK',
      'cpo': 'CPO',
      'pome': 'POME',
    };

    final normalized = key.replaceAll('-', '_').trim().toLowerCase();
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              special[part] ?? '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _valueAsText(dynamic value) {
    if (value == null) return '-';
    if (value is List) return '${value.length} item';
    if (value is Map) return value.toString();
    return value.toString();
  }

  dynamic _firstAvailableValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (_hasValue(value)) return value;
    }
    return null;
  }

  String _displayStatusLabel(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    switch (normalized) {
      case 'approved':
      case 'approve':
        return 'APPROVED';
      case 'rejected':
      case 'reject':
      case 'cancel':
        return 'REJECTED';
      case 'hold':
        return 'HOLD';
      case 'pending_manager_approval':
        return 'PENDING MANAGER';
      case 'pending':
        return 'PENDING';
      default:
        return normalized.toUpperCase().replaceAll('_', ' ');
    }
  }

  Color _statusColor(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized.contains('approve')) return Colors.green;
    if (normalized.contains('reject') || normalized.contains('cancel')) {
      return Colors.red;
    }
    if (normalized.contains('hold')) return Colors.orange;
    if (normalized.contains('pending')) return Colors.blueGrey;
    return Colors.black54;
  }

  IconData _statusIcon(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized.contains('approve')) return Icons.check_circle;
    if (normalized.contains('reject') || normalized.contains('cancel')) {
      return Icons.cancel;
    }
    if (normalized.contains('hold')) return Icons.pause_circle;
    if (normalized.contains('pending')) return Icons.hourglass_top;
    return Icons.info_outline;
  }

  List<MapEntry<String, dynamic>> _operatorRows() {
    final source = _operatorData ?? const <String, dynamic>{};
    final preferred = widget.stage == 'lab'
        ? <String>[
            'sampling_records_count',
            'lab_records_count',
            'pk_cycle_total',
            'lab_total_records',
            'counter',
            'status',
            'lab_status',
            'ffa',
            'moisture',
            'dobi',
            'iv',
            'dirt',
            'oil_content',
            'remarks',
            'tested_by',
            'tested_at',
            'lab_awal_status',
            'lab_awal_ffa',
            'lab_awal_moisture',
            'lab_awal_dirt',
            'lab_awal_oil_content',
            'lab_awal_remarks',
            'lab_awal_tested_by',
            'lab_awal_tested_at',
            'relab_1_status',
            'relab_1_ffa',
            'relab_1_moisture',
            'relab_1_dirt',
            'relab_1_oil_content',
            'relab_1_remarks',
            'relab_1_tested_by',
            'relab_1_tested_at',
            'relab_2_status',
            'relab_2_ffa',
            'relab_2_moisture',
            'relab_2_dirt',
            'relab_2_oil_content',
            'relab_2_remarks',
            'relab_2_tested_by',
            'relab_2_tested_at',
            'cycle_0_regist_status',
            'cycle_0_lab_status',
            'cycle_0_unloading_status',
            'cycle_0_lab_ffa',
            'cycle_0_lab_moisture',
            'cycle_0_lab_dirt',
            'cycle_0_lab_oil_content',
            'cycle_0_unloading_tank_id',
            'cycle_0_unloading_hole_id',
            'cycle_1_regist_status',
            'cycle_1_lab_status',
            'cycle_1_unloading_status',
            'cycle_1_lab_ffa',
            'cycle_1_lab_moisture',
            'cycle_1_lab_dirt',
            'cycle_1_lab_oil_content',
            'cycle_1_unloading_tank_id',
            'cycle_1_unloading_hole_id',
            'cycle_2_regist_status',
            'cycle_2_lab_status',
            'cycle_2_unloading_status',
            'cycle_2_lab_ffa',
            'cycle_2_lab_moisture',
            'cycle_2_lab_dirt',
            'cycle_2_lab_oil_content',
            'cycle_2_unloading_tank_id',
            'cycle_2_unloading_hole_id',
          ]
        : <String>[
            'sampling_records_count',
            'lab_records_count',
            'pk_cycle_total',
            'tank_id',
            'tank_name',
            'hole_id',
            'hole_name',
            'unloading_status',
            'start_time',
            'end_time',
            'duration_minutes',
            'remarks',
            'cycle_0_regist_status',
            'cycle_0_unloading_status',
            'cycle_0_unloading_tank_id',
            'cycle_0_unloading_hole_id',
            'cycle_0_lab_status',
            'cycle_1_regist_status',
            'cycle_1_unloading_status',
            'cycle_1_unloading_tank_id',
            'cycle_1_unloading_hole_id',
            'cycle_1_lab_status',
            'cycle_2_regist_status',
            'cycle_2_unloading_status',
            'cycle_2_unloading_tank_id',
            'cycle_2_unloading_hole_id',
            'cycle_2_lab_status',
          ];

    final byKey = <String, dynamic>{};
    for (final entry in source.entries) {
      byKey[entry.key.toLowerCase()] = entry.value;
    }

    final rows = <MapEntry<String, dynamic>>[];

    for (final key in preferred) {
      final value = byKey[key];
      if (_hasValue(value)) {
        rows.add(MapEntry(key, value));
      }
    }

    for (final entry in source.entries) {
      final key = entry.key.toLowerCase();
      if (preferred.contains(key)) continue;
      if (!_hasValue(entry.value)) continue;
      rows.add(MapEntry(key, entry.value));
    }

    return rows;
  }

  Map<String, dynamic> _normalizedOperatorData() {
    final source = _operatorData ?? const <String, dynamic>{};
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      normalized[_normalizeKey(entry.key)] = entry.value;
    }
    return normalized;
  }

  _LabCycleExtraction _extractLabCycles(Map<String, dynamic> source) {
    final buckets = <int, Map<String, dynamic>>{};
    final consumed = <String>{};

    void upsert({
      required int cycleNo,
      required String sourceKey,
      required String field,
      required dynamic value,
    }) {
      if (!_hasValue(value)) return;
      final bucket = buckets.putIfAbsent(cycleNo, () => <String, dynamic>{});
      if (!_hasValue(bucket[field])) {
        bucket[field] = value;
      }
      consumed.add(sourceKey);
    }

    for (final entry in source.entries) {
      final key = entry.key;
      final value = entry.value;

      final cycleLabMatch = RegExp(r'^cycle_(\d+)_lab_(.+)$').firstMatch(key);
      if (cycleLabMatch != null) {
        final cycleNo = int.tryParse(cycleLabMatch.group(1) ?? '');
        final rawField = cycleLabMatch.group(2);
        if (cycleNo != null && rawField != null && rawField.isNotEmpty) {
          upsert(
            cycleNo: cycleNo,
            sourceKey: key,
            field: rawField == 'lab_status' ? 'status' : rawField,
            value: value,
          );
        }
        continue;
      }

      final cycleStatusMatch = RegExp(
        r'^cycle_(\d+)_(status|lab_status)$',
      ).firstMatch(key);
      if (cycleStatusMatch != null) {
        final cycleNo = int.tryParse(cycleStatusMatch.group(1) ?? '');
        if (cycleNo != null) {
          upsert(
            cycleNo: cycleNo,
            sourceKey: key,
            field: 'status',
            value: value,
          );
        }
        continue;
      }

      final labAwalMatch = RegExp(r'^lab_awal_(.+)$').firstMatch(key);
      if (labAwalMatch != null) {
        final rawField = labAwalMatch.group(1);
        if (rawField != null && rawField.isNotEmpty) {
          upsert(
            cycleNo: 0,
            sourceKey: key,
            field: rawField == 'lab_status' ? 'status' : rawField,
            value: value,
          );
        }
        continue;
      }

      final relabMatch = RegExp(r'^relab_(\d+)_(.+)$').firstMatch(key);
      if (relabMatch != null) {
        final cycleNo = int.tryParse(relabMatch.group(1) ?? '');
        final rawField = relabMatch.group(2);
        if (cycleNo != null && rawField != null && rawField.isNotEmpty) {
          upsert(
            cycleNo: cycleNo,
            sourceKey: key,
            field: rawField == 'lab_status' ? 'status' : rawField,
            value: value,
          );
        }
      }
    }

    final plainCycleNo = _tryParseInt(source['counter']) ?? 0;
    for (final key in const [
      'status',
      'lab_status',
      'ffa',
      'moisture',
      'dobi',
      'iv',
      'dirt',
      'oil_content',
      'remarks',
      'tested_by',
      'tested_at',
      'lab_id',
      'process_id',
    ]) {
      final value = source[key];
      if (!_hasValue(value)) continue;
      upsert(
        cycleNo: plainCycleNo,
        sourceKey: key,
        field: key == 'lab_status' ? 'status' : key,
        value: value,
      );
    }

    final cycles =
        buckets.entries
            .map(
              (entry) => _LabCycleView(cycleNo: entry.key, values: entry.value),
            )
            .toList()
          ..sort((a, b) => a.cycleNo.compareTo(b.cycleNo));

    return _LabCycleExtraction(cycles: cycles, consumedKeys: consumed);
  }

  _UnloadingCycleExtraction _extractUnloadingCycles(
    Map<String, dynamic> source,
  ) {
    final buckets = <int, Map<String, dynamic>>{};
    final consumed = <String>{};

    void upsert({
      required int cycleNo,
      required String sourceKey,
      required String field,
      required dynamic value,
    }) {
      if (!_hasValue(value)) return;
      final bucket = buckets.putIfAbsent(cycleNo, () => <String, dynamic>{});
      if (!_hasValue(bucket[field])) {
        bucket[field] = value;
      }
      consumed.add(sourceKey);
    }

    for (final entry in source.entries) {
      final key = entry.key;
      final value = entry.value;

      final cycleUnloadingMatch = RegExp(
        r'^cycle_(\d+)_unloading_(.+)$',
      ).firstMatch(key);
      if (cycleUnloadingMatch != null) {
        final cycleNo = int.tryParse(cycleUnloadingMatch.group(1) ?? '');
        final rawField = cycleUnloadingMatch.group(2);
        if (cycleNo != null && rawField != null && rawField.isNotEmpty) {
          upsert(
            cycleNo: cycleNo,
            sourceKey: key,
            field: rawField == 'unloading_status' ? 'status' : rawField,
            value: value,
          );
        }
        continue;
      }

      final cycleStatusMatch = RegExp(
        r'^cycle_(\d+)_(unloading_status|status|regist_status)$',
      ).firstMatch(key);
      if (cycleStatusMatch != null) {
        final cycleNo = int.tryParse(cycleStatusMatch.group(1) ?? '');
        final rawField = cycleStatusMatch.group(2) ?? 'status';
        if (cycleNo != null) {
          upsert(
            cycleNo: cycleNo,
            sourceKey: key,
            field: rawField == 'unloading_status' ? 'status' : rawField,
            value: value,
          );
        }
      }
    }

    final rootCycleNo =
        _tryParseInt(source['counter']) ?? _tryParseInt(source['cycle']) ?? 0;

    for (final key in const [
      'unloading_status',
      'status',
      'tank_id',
      'tank_name',
      'hole_id',
      'hole_name',
      'start_time',
      'end_time',
      'duration_minutes',
      'remarks',
      'process_id',
      'counter',
    ]) {
      final value = source[key];
      if (!_hasValue(value)) continue;
      upsert(
        cycleNo: rootCycleNo,
        sourceKey: key,
        field: key == 'unloading_status' ? 'status' : key,
        value: value,
      );
    }

    final cycles =
        buckets.entries
            .map(
              (entry) =>
                  _UnloadingCycleView(cycleNo: entry.key, values: entry.value),
            )
            .toList()
          ..sort((a, b) => a.cycleNo.compareTo(b.cycleNo));

    return _UnloadingCycleExtraction(cycles: cycles, consumedKeys: consumed);
  }

  String _displayNameWithId({dynamic name, dynamic id}) {
    final nameText = _valueAsText(name);
    final idText = _valueAsText(id);

    if (nameText != '-' && idText != '-') {
      return '$nameText (ID: $idText)';
    }

    if (nameText != '-') return nameText;
    return idText;
  }

  bool _isLabOnlyKeyForUnloading(String key) {
    final normalized = key.toLowerCase();
    if (normalized.contains('_lab_')) return true;
    if (normalized.startsWith('lab_') || normalized.startsWith('relab_')) {
      return true;
    }

    return normalized.contains('ffa') ||
        normalized.contains('moisture') ||
        normalized.contains('dobi') ||
        normalized.contains('iv') ||
        normalized.contains('dirt') ||
        normalized.contains('oil_content') ||
        normalized.contains('tested_');
  }

  Widget _buildUnloadingLatestCard(_UnloadingCycleView cycle) {
    final values = cycle.values;
    final rawStatus = _firstAvailableValue(values, const [
      'status',
      'regist_status',
    ])?.toString();
    final statusText = _hasValue(rawStatus)
        ? _displayStatusLabel(rawStatus!)
        : 'BELUM ADA STATUS';
    final statusColor = _statusColor(rawStatus ?? 'pending');
    final statusIcon = _statusIcon(rawStatus ?? 'pending');

    final tankValue = _displayNameWithId(
      name: values['tank_name'],
      id: values['tank_id'],
    );
    final holeValue = _displayNameWithId(
      name: values['hole_name'],
      id: values['hole_id'],
    );

    final details = <MapEntry<String, String>>[
      MapEntry('Pilih Tank', tankValue),
      MapEntry('Pilih Hole', holeValue),
      MapEntry('Start Time', _valueAsText(values['start_time'])),
      MapEntry('End Time', _valueAsText(values['end_time'])),
      MapEntry('Duration (Menit)', _valueAsText(values['duration_minutes'])),
      MapEntry('Remarks', _valueAsText(values['remarks'])),
    ];

    if (_hasValue(values['process_id'])) {
      details.add(MapEntry('Process ID', _valueAsText(values['process_id'])));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Unloading Terbaru (Cycle ${cycle.cycleNo})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...details
              .where((entry) => entry.value != '-')
              .map((entry) => _readOnlyField(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildUnloadingOperatorSection() {
    final source = _normalizedOperatorData();
    if (source.isEmpty) {
      return const Text(
        'Data operator belum tersedia.',
        style: TextStyle(color: Colors.black54),
      );
    }

    final extraction = _extractUnloadingCycles(source);
    final latestCycle = extraction.cycles.isNotEmpty
        ? extraction.cycles.last
        : null;

    final summaryChips = <Widget>[];
    if (_hasValue(source['pk_cycle_total'])) {
      summaryChips.add(
        _buildSummaryChip(
          'Total Cycle',
          _valueAsText(source['pk_cycle_total']),
        ),
      );
    }
    if (latestCycle != null) {
      summaryChips.add(
        _buildSummaryChip('Cycle Aktif', latestCycle.cycleNo.toString()),
      );
    }

    final hiddenKeys = <String>{
      'sampling_records_count',
      'lab_records_count',
      'pk_cycle_total',
      'lab_total_records',
      'counter',
    };

    final remainingRows = <MapEntry<String, dynamic>>[];
    for (final entry in source.entries) {
      if (hiddenKeys.contains(entry.key)) continue;
      if (extraction.consumedKeys.contains(entry.key)) continue;
      if (_isLabOnlyKeyForUnloading(entry.key)) continue;
      if (!_hasValue(entry.value)) continue;
      remainingRows.add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summaryChips.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: summaryChips),
          const SizedBox(height: 12),
        ],
        const Text(
          'Menampilkan data unloading terbaru (replace data lama).',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        if (latestCycle != null)
          _buildUnloadingLatestCard(latestCycle)
        else if (remainingRows.isEmpty)
          const Text(
            'Data unloading operator belum tersedia.',
            style: TextStyle(color: Colors.black54),
          ),
        if (remainingRows.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Info Tambahan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...remainingRows.map(
            (entry) =>
                _readOnlyField(_toLabel(entry.key), _valueAsText(entry.value)),
          ),
        ],
      ],
    );
  }

  List<MapEntry<String, String>> _labMetricDefinitions() {
    switch (widget.commodity.toUpperCase()) {
      case 'CPO':
        return const [
          MapEntry('ffa', 'FFA (%)'),
          MapEntry('moisture', 'Moisture (%)'),
          MapEntry('dobi', 'DOBI'),
          MapEntry('iv', 'IV'),
        ];
      case 'POME':
        return const [
          MapEntry('ffa', 'FFA (%)'),
          MapEntry('moisture', 'Moisture (%)'),
        ];
      case 'PK':
      default:
        return const [
          MapEntry('ffa', 'FFA (%)'),
          MapEntry('moisture', 'Moisture (%)'),
          MapEntry('dirt', 'Dirt (%)'),
          MapEntry('oil_content', 'Oil Content (%)'),
        ];
    }
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.25)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _gridReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black26),
          ),
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildLabCycleCard(_LabCycleView cycle) {
    final values = cycle.values;
    final title = cycle.cycleNo == 0 ? 'Lab Biasa' : 'Re-Lab ${cycle.cycleNo}';

    final rawStatus = _firstAvailableValue(values, const ['status']);
    final statusText = _hasValue(rawStatus)
        ? _displayStatusLabel(rawStatus.toString())
        : 'BELUM ADA STATUS';
    final statusColor = _statusColor(rawStatus?.toString() ?? 'pending');
    final statusIcon = _statusIcon(rawStatus?.toString() ?? 'pending');

    final metricDefs = _labMetricDefinitions();
    final metricRows = metricDefs
        .where((metric) => _hasValue(values[metric.key]))
        .map(
          (metric) => MapEntry(metric.value, _valueAsText(values[metric.key])),
        )
        .toList();

    final metricRowWidgets = <Widget>[];
    for (var i = 0; i < metricRows.length; i += 2) {
      final left = metricRows[i];
      final right = i + 1 < metricRows.length ? metricRows[i + 1] : null;

      metricRowWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _gridReadOnlyField(left.key, left.value)),
            const SizedBox(width: 8),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _gridReadOnlyField(right.key, right.value),
            ),
          ],
        ),
      );

      if (i + 2 < metricRows.length) {
        metricRowWidgets.add(const SizedBox(height: 8));
      }
    }

    final details = <MapEntry<String, dynamic>>[];
    for (final key in const [
      'remarks',
      'tested_by',
      'tested_at',
      'lab_id',
      'process_id',
      'counter',
    ]) {
      final value = values[key];
      if (_hasValue(value)) {
        details.add(MapEntry(key, value));
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (metricRows.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...metricRowWidgets,
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...details.map(
              (entry) => _readOnlyField(
                _toLabel(entry.key),
                _valueAsText(entry.value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultOperatorSection() {
    final rows = _operatorRows();
    if (rows.isEmpty) {
      return const Text(
        'Data operator belum tersedia.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map(
            (entry) =>
                _readOnlyField(_toLabel(entry.key), _valueAsText(entry.value)),
          )
          .toList(),
    );
  }

  Widget _buildLabOperatorSection() {
    final source = _normalizedOperatorData();
    if (source.isEmpty) {
      return const Text(
        'Data operator belum tersedia.',
        style: TextStyle(color: Colors.black54),
      );
    }

    final extraction = _extractLabCycles(source);

    final summaryChips = <Widget>[];
    void addSummary(String label, String key) {
      final value = source[key];
      if (_hasValue(value)) {
        summaryChips.add(_buildSummaryChip(label, _valueAsText(value)));
      }
    }

    addSummary('Sampling', 'sampling_records_count');
    addSummary('Lab Records', 'lab_records_count');
    addSummary('Total Cycle', 'pk_cycle_total');
    addSummary('Total Lab', 'lab_total_records');

    final hiddenKeys = <String>{
      'sampling_records_count',
      'lab_records_count',
      'pk_cycle_total',
      'lab_total_records',
      'counter',
    };

    final remainingRows = <MapEntry<String, dynamic>>[];
    for (final entry in source.entries) {
      if (hiddenKeys.contains(entry.key)) continue;
      if (extraction.consumedKeys.contains(entry.key)) continue;
      if (!_hasValue(entry.value)) continue;
      remainingRows.add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summaryChips.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: summaryChips),
          const SizedBox(height: 12),
        ],
        if (extraction.cycles.isEmpty)
          _buildDefaultOperatorSection()
        else
          ...extraction.cycles.map(_buildLabCycleCard),
        if (remainingRows.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Info Tambahan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...remainingRows.map(
            (entry) =>
                _readOnlyField(_toLabel(entry.key), _valueAsText(entry.value)),
          ),
        ],
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Rejected $_stageLabel'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Truk',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          _readOnlyField(
                            'WB Ticket',
                            widget.ticket.wb_ticket_no ?? '-',
                          ),
                          _readOnlyField(
                            'Plate Number',
                            widget.ticket.plate_number ?? '-',
                          ),
                          _readOnlyField(
                            'Driver',
                            widget.ticket.driver_name ?? '-',
                          ),
                          _readOnlyField(
                            'Vendor',
                            widget.ticket.vendor_name ?? '-',
                          ),
                          _readOnlyField(
                            'Regist Status',
                            _detail?.regist_status ?? '-',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data Operator $_stageLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          if (widget.stage == 'lab')
                            _buildLabOperatorSection()
                          else
                            _buildUnloadingOperatorSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remarks Manager',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          TextFormField(
                            controller: _remarksCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Masukkan catatan (opsional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isSubmitting)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _confirmAndSubmitDecision('REJECT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'REJECT (CANCEL)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _confirmAndSubmitDecision('APPROVE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'APPROVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
