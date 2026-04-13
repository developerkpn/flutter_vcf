import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/pk/response/unloading_pk_response.dart';
import 'package:flutter_vcf/models/pk/unloading_pk_model.dart' as model;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_unloading_pk.dart';
import 'input_unloading_pk.dart';

enum UnloadingPKStage { start, finish }

extension UnloadingPKStageX on UnloadingPKStage {
  String get title =>
      this == UnloadingPKStage.start
          ? 'Dashboard Start Unloading PK'
          : 'Dashboard Finish Unloading PK';

  String get emptyMessage =>
      this == UnloadingPKStage.start
          ? 'Belum ada kendaraan untuk Start Unloading.'
          : 'Belum ada kendaraan untuk Finish Unloading.';

  List<String> get activeStatuses =>
      this == UnloadingPKStage.start
        ? [
            'finish_unloading',
            'finish_reunloading_1',
            'finish_reunloading_2',
            'qc_resampling',
            'qc_relab',
          ]
          : [
              'finish_unloading',
              'finish_reunloading_1',
              'finish_reunloading_2',
              'qc_resampling',
              'qc_relab',
              'finish_unloading_rejected',
              'done',
              'completed',
              'wb_out',
            ];

  bool get hasAddButton => true;
}

class UnloadingPKPage extends StatefulWidget {
  final String userId;
  final String token;
  final UnloadingPKStage stage;

  const UnloadingPKPage({
    super.key,
    required this.userId,
    required this.token,
    this.stage = UnloadingPKStage.start,
  });

  @override
  State<UnloadingPKPage> createState() => _UnloadingPKPageState();
}

class _UnloadingPKPageState extends State<UnloadingPKPage> {
  int? selectedIndex;

  final apiService = ApiService(AppConfig.createDio());

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ?? widget.token;
  }

  String _registStatus(model.UnloadingPkModel t) =>
      (t.registStatus ?? '').toLowerCase().trim();

  String _counterLabel(model.UnloadingPkModel t) =>
      (t.counterStatusLabel ?? '').toLowerCase().trim();

  int _cycle(model.UnloadingPkModel t) =>
      (t.cycle ?? t.counter ?? t.resamplingCounter ?? 0).clamp(0, 2);

  int _counter(model.UnloadingPkModel t) =>
      (t.counter ?? t.resamplingCounter ?? 0).clamp(0, 2);

  String _stageStatus(model.UnloadingPkModel t) {
    final s = _registStatus(t);
    final label = _counterLabel(t);
    final cycle = _cycle(t);
    final counter = _counter(t);

    if (s == 'qc_resampling') {
      return counter >= 2 ? 'resampling_2' : 'resampling_1';
    }
    if (s == 'qc_relab') {
      return counter >= 2 ? 'relab_2' : 'relab_1';
    }
    if (label.startsWith('resampling_') || label.startsWith('relab_')) {
      return label;
    }
    if (label.startsWith('reunloading_')) {
      return label;
    }
    if (s == 'start_reunloading_2' || s == 'finish_reunloading_2' || cycle >= 2) {
      return 'reunloading_2';
    }
    if (s == 'start_reunloading_1' || s == 'finish_reunloading_1' || cycle == 1) {
      return 'reunloading_1';
    }
    if (label == 'unloading') {
      return 'unloading';
    }
    return s;
  }

  bool _shouldShow(model.UnloadingPkModel t) {
    final s = _registStatus(t);
    final stage = _stageStatus(t);
    final cycle = _cycle(t);
    
    // Untuk Finish stage: jangan tampilkan reunloading tickets yang belum di-approve di Start
    // (approvalnya ditandai dengan adanya start_time)
    if (widget.stage == UnloadingPKStage.finish && stage.startsWith('reunloading_')) {
      final hasStartTime = (t.startTime ?? '').isNotEmpty;
      if (!hasStartTime) return false;
    }
    
    return widget.stage.activeStatuses.contains(s) ||
        stage == 'unloading' ||
        stage.startsWith('resampling_') ||
        stage.startsWith('relab_') ||
        stage.startsWith('reunloading_') ||
        cycle > 0;
  }

  bool _isClickable(model.UnloadingPkModel t) {
    final s = _registStatus(t);
    final stage = _stageStatus(t);
    if (widget.stage == UnloadingPKStage.start) {
      // Cannot click if already approved (finished reunloading)
      if (s == 'finish_reunloading_1' || s == 'finish_reunloading_2') {
        return false;
      }
      return stage.startsWith('reunloading_');
    }
    return stage == 'unloading' || stage.startsWith('reunloading_');
  }

  String _displayStatus(model.UnloadingPkModel t) {
    final s = _registStatus(t);
    final stage = _stageStatus(t);

    if (widget.stage == UnloadingPKStage.start) {
      if (s == 'finish_unloading') {
        return 'APPROVE START UNLOADING';
      }
      if (s == 'finish_reunloading_1') {
        return 'APPROVE START REUNLOADING 1';
      }
      if (s == 'finish_reunloading_2') {
        return 'APPROVE START REUNLOADING 2';
      }
    }

    if (stage == 'resampling_2') return 'RESAMPLING 2';
    if (stage == 'resampling_1') return 'RESAMPLING 1';
    if (stage == 'relab_2') return 'RE-LAB 2';
    if (stage == 'relab_1') return 'RE-LAB 1';
    if (stage == 'reunloading_2') return 'REUNLOADING 2';
    if (stage == 'reunloading_1') return 'REUNLOADING 1';
    if (stage == 'unloading') return 'MENUNGGU FINISH';

    if (widget.stage == UnloadingPKStage.start) {
      if (s == 'start_unloading' ||
          s == 'start_reunloading_1' ||
          s == 'start_reunloading_2') {
        return 'MENUNGGU START';
      }
    }

    switch (s) {
      case 'start_unloading':
        return 'MENUNGGU START';
      case 'start_reunloading_1':
        return 'MENUNGGU START';
      case 'start_reunloading_2':
        return 'MENUNGGU START';
      case 'finish_unloading':
        return 'MENUNGGU FINISH';
      case 'qc_resampling':
        return 'RESAMPLING';
      case 'finish_unloading_rejected':
        return 'REJECTED';
      case 'done':
      case 'completed':
        return 'DONE';
      case 'wb_out':
        return 'APPROVE UNLOADING';
      default:
        return s.toUpperCase();
    }
  }

  Color _statusColor(model.UnloadingPkModel t) {
    final s = _registStatus(t);
    final stage = _stageStatus(t);

    if (widget.stage == UnloadingPKStage.start &&
        (s == 'finish_reunloading_1' || s == 'finish_reunloading_2')) {
      return Colors.green;
    }

    if (stage == 'resampling_1' || stage == 'resampling_2') {
      return Colors.purple;
    }
    if (stage == 'relab_1' || stage == 'relab_2') {
      return Colors.indigo;
    }
    if (stage == 'reunloading_1' || stage == 'reunloading_2') {
      return Colors.orange;
    }
    if (stage == 'unloading') {
      return widget.stage == UnloadingPKStage.start ? Colors.green : Colors.blue;
    }

    if (widget.stage == UnloadingPKStage.start) {
      if (s == 'start_unloading' ||
          s == 'start_reunloading_1' ||
          s == 'start_reunloading_2') {
        return Colors.orange;
      }
      if (s == 'finish_unloading' ||
          s == 'finish_reunloading_1' ||
          s == 'finish_reunloading_2') {
        return Colors.green;
      }
    }

    switch (s) {
      case 'finish_unloading':
        return Colors.blue;
      case 'finish_reunloading_1':
      case 'finish_reunloading_2':
        return Colors.orange;
      case 'qc_resampling':
        return Colors.deepPurple;
      case 'finish_unloading_rejected':
        return Colors.red;
      case 'done':
      case 'completed':
        return Colors.green;
      case 'wb_out':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(model.UnloadingPkModel t) {
    final s = _registStatus(t);
    final stage = _stageStatus(t);

    if (stage == 'resampling_2') return Icons.loop;
    if (stage == 'resampling_1') return Icons.refresh;
    if (stage == 'relab_2') return Icons.science_outlined;
    if (stage == 'relab_1') return Icons.biotech_outlined;
    if (stage == 'reunloading_2') return Icons.loop;
    if (stage == 'reunloading_1') return Icons.refresh;
    if (stage == 'unloading') return Icons.check_circle_outline;

    if (widget.stage == UnloadingPKStage.start) {
      if (s == 'start_unloading' ||
          s == 'start_reunloading_1' ||
          s == 'start_reunloading_2') {
        return Icons.hourglass_top;
      }
      if (s == 'finish_unloading' ||
          s == 'finish_reunloading_1' ||
          s == 'finish_reunloading_2') {
        return Icons.check_circle_outline;
      }
    }

    switch (s) {
      case 'finish_unloading':
      case 'finish_reunloading_1':
      case 'finish_reunloading_2':
        return Icons.check_circle_outline;
      case 'qc_resampling':
        return Icons.refresh;
      case 'finish_unloading_rejected':
        return Icons.cancel_outlined;
      case 'done':
      case 'completed':
        return Icons.task_alt;
      case 'wb_out':
        return Icons.verified;
      default:
        return Icons.local_shipping;
    }
  }

  Future<void> _openAddPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddUnloadingPKPage(userId: widget.userId, token: widget.token, stage: widget.stage),
      ),
    );
    if (result != null) setState(() {});
  }

  Future<void> _openInputPage(model.UnloadingPkModel data, int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InputUnloadingPKPage(
          model: data,
          token: widget.token,
          stage: widget.stage,
        ),
      ),
    );
    if (result != null) {
      setState(() => selectedIndex = index);
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
      body: FutureBuilder<UnloadingPkResponse>(
        future: _getToken().then(
          (t) => apiService.getUnloadingPk(
            "Bearer $t",
            includeRejected: true,
          ),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            log("${snapshot.error}");
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final allData = snapshot.data?.data ?? [];
          final trucks = allData.where(_shouldShow).toList();

          if (trucks.isEmpty) {
            return Center(
              child: Text(
                widget.stage.emptyMessage,
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: trucks.length,
            itemBuilder: (_, index) {
              final t = trucks[index];
              final clickable = _isClickable(t);
              final color = _statusColor(t);

              return GestureDetector(
                onTap: () {
                  if (clickable) {
                    _openInputPage(t, index);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Status ${_displayStatus(t)} tidak dapat dibuka.",
                        ),
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
                          "Nomor Tiket Timbang : ${t.wbTicketNo ?? '-'}",
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
                              t.plateNumber ?? "-",
                              style: const TextStyle(fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                border: Border.all(color: color),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(_statusIcon(t), size: 16, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    _displayStatus(t),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
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
      floatingActionButton: widget.stage.hasAddButton
          ? FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: _openAddPage,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
