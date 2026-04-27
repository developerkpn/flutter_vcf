import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/master/response/master_hole_response.dart';
import 'package:flutter_vcf/models/master/response/master_tank_response.dart';
import 'package:flutter_vcf/models/pk/response/lab_pk_detail_response.dart';
import 'package:flutter_vcf/models/pk/response/unloading_pk_detail_response.dart';
import 'package:flutter_vcf/models/pk/unloading_pk_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'unloading_pk.dart';

class InputUnloadingPKPage extends StatefulWidget {
  final String token;
  final UnloadingPkModel model;
  final UnloadingPKStage stage;

  const InputUnloadingPKPage({
    super.key,
    required this.token,
    required this.model,
    this.stage = UnloadingPKStage.start,
  });

  @override
  State<InputUnloadingPKPage> createState() => _InputUnloadingPKPageState();
}

class _InputUnloadingPKPageState extends State<InputUnloadingPKPage> {
  final TextEditingController remarksCtrl = TextEditingController();
  final double baseFont = 15;

  bool _isSubmitting = false;
  bool _isCameraEnabled = false;

  File? _image1, _image2, _image3, _image4;
  final ImagePicker picker = ImagePicker();

  late Dio _dio;
  late ApiService api;

  // Start stage: editable
  List<TankItem> tanks = [];
  List<HoleItem> holes = [];
  int? selectedTankId;
  int? selectedHoleId;

  // Finish stage: read-only from start detail
  int? startTankId;
  int? startHoleId;
  String? startTankName;
  String? startHoleName;
  String? startRemarks;
  List<String>? startPhotoUrls;
  List<UnloadingPkHistory> finishStartHistories = [];
  List<UnloadingPkHistory> startPreviousHistories = [];

  // Previous data (for cycle > 1 at start, or for finish previous attempt)
  int? previousTankId;
  int? previousHoleId;
  String? previousTankCode;
  String? previousTankName;
  String? previousHoleCode;
  String? previousHoleName;
  String? previousRemarks;
  List<String>? previousPhotoUrls;
  String? finishLabStatus;
  int? finishLabCounter;

  bool get _isFinishStage => widget.stage == UnloadingPKStage.finish;
  bool get _isStartStage => widget.stage == UnloadingPKStage.start;

  int get _photoCount =>
      [_image1, _image2, _image3, _image4].where((e) => e != null).length;

  bool get _hasAtLeastOneNewPhoto => _photoCount > 0;

  @override
  void initState() {
    super.initState();
    _dio = AppConfig.createDio(withLogging: !kReleaseMode);
    api = ApiService(_dio);
    if (_isFinishStage) {
      _loadStartDetail();
      _loadFinishLabState();
    } else {
      _loadMasterData();
      // Load previous data for start stage
      _loadPreviousStartData();
    }
  }

  @override
  void dispose() {
    remarksCtrl.dispose();
    super.dispose();
  }

  bool _hasStartHistoryData(UnloadingPkHistory? item) {
    if (item == null) return false;
    if ((item.unloadingId ?? '').isEmpty) return false;
    if (item.tankId != null || item.holeId != null) return true;
    if (_normalize(item.status).isNotEmpty) return true;
    if ((item.startTime ?? '').trim().isNotEmpty) return true;
    if ((item.endTime ?? '').trim().isNotEmpty) return true;
    if ((item.remarks ?? '').trim().isNotEmpty) return true;
    return item.photos?.isNotEmpty ?? false;
  }

  UnloadingPkHistory? _previousStartHistory(UnloadingPkDetailData? data) {
    final history = data?.unloadingHistory;
    if (history == null || history.isEmpty) return null;

    final activeCycle = _activeCycle();

    for (final item in history.reversed) {
      if ((item.cycle ?? 0) < activeCycle && _hasStartHistoryData(item)) {
        return item;
      }
    }

    return null;
  }

  List<String>? _photoUrlsFromPhotos(List<UnloadingPkPhoto>? photos) {
    final urls = (photos ?? [])
        .map((p) => p.url ?? p.path ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
    return urls.isEmpty ? null : urls;
  }

  String _normalize(String? value) => (value ?? '').toLowerCase().trim();

    int _effectiveCounter() =>
      (finishLabCounter ??
              widget.model.counter ??
              widget.model.resamplingCounter ??
              0)
          .clamp(0, 2);

  String _effectiveLabStatus() => _normalize(finishLabStatus ?? widget.model.labStatus);

    bool get _isResamplingDisabledAtFinish =>
      _isFinishStage &&
      _effectiveLabStatus() == 'approved' &&
        _effectiveCounter() == 2;

  LabPkRecord? _latestLabRecord(List<LabPkRecord>? records) {
    if (records == null || records.isEmpty) return null;

    final sorted = List<LabPkRecord>.from(records);
    sorted.sort((a, b) {
      final counterCompare = (a.counter ?? 0).compareTo(b.counter ?? 0);
      if (counterCompare != 0) return counterCompare;
      return (a.testedAt ?? '').compareTo(b.testedAt ?? '');
    });

    return sorted.last;
  }

  int _activeCycle() {
    final registStatus = _normalize(widget.model.registStatus);
    final counterLabel = _normalize(widget.model.counterStatusLabel);
    final cycle =
        widget.model.cycle ??
        widget.model.counter ??
        widget.model.resamplingCounter ??
        0;

    if (registStatus.contains('reunloading_2') ||
        counterLabel.startsWith('reunloading_2') ||
        cycle >= 2) {
      return 2;
    }

    if (registStatus.contains('reunloading_1') ||
        counterLabel.startsWith('reunloading_1') ||
        cycle >= 1) {
      return 1;
    }

    return 0;
  }

  String _cycleStartTitleFor(int cycle) {
    switch (cycle) {
      case 1:
        return 'Start Re-Unloading 1';
      case 2:
        return 'Start Re-Unloading 2';
      default:
        return 'Start Unloading Awal';
    }
  }

  UnloadingPkHistory? _startHistoryByCycle(
    List<UnloadingPkHistory> history,
    int cycle,
  ) {
    for (final item in history.reversed) {
      if ((item.cycle ?? 0) == cycle && _hasStartHistoryData(item)) {
        return item;
      }
    }

    return null;
  }

  List<UnloadingPkHistory> _startHistoriesUntilActiveCycle(
    UnloadingPkDetailData? data,
  ) {
    final history = data?.unloadingHistory;
    if (history == null || history.isEmpty) return const [];

    final activeCycle = _activeCycle();
    final result = <UnloadingPkHistory>[];

    for (var cycle = 0; cycle <= activeCycle; cycle++) {
      final item = _startHistoryByCycle(history, cycle);
      if (item != null) {
        result.add(item);
      }
    }

    return result;
  }

  List<UnloadingPkHistory> _startHistoriesBeforeActiveCycle(
    UnloadingPkDetailData? data,
  ) {
    final history = data?.unloadingHistory;
    if (history == null || history.isEmpty) return const [];

    final activeCycle = _activeCycle();
    final result = <UnloadingPkHistory>[];

    for (var cycle = 0; cycle < activeCycle; cycle++) {
      final item = _startHistoryByCycle(history, cycle);
      if (item != null) {
        result.add(item);
      }
    }

    return result;
  }

  UnloadingPkHistory? _startHistoryForCycle(UnloadingPkDetailData? data) {
    final history = data?.unloadingHistory;
    if (history == null || history.isEmpty) return null;

    return _startHistoryByCycle(history, _activeCycle());
  }

  Future<void> _loadMasterData() async {
    try {
      final tankResp = await api.getAllTanks("Bearer ${widget.token}");
      final holeResp = await api.getAllHoles("Bearer ${widget.token}");
      if (!mounted) return;
      setState(() {
        tanks = tankResp.data;
        holes = holeResp.data;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal load data tank & hole")),
      );
    }
  }

  Future<void> _loadPreviousStartData() async {
    try {
      final res = await api.getUnloadingPkDetail(
        "Bearer ${widget.token}",
        widget.model.registrationId ?? "",
      );
      final d = res.data;
      if (!mounted || d == null) return;

      final previousHistories = _startHistoriesBeforeActiveCycle(d);
      final previousHistory = _previousStartHistory(d);

      setState(() {
        startPreviousHistories = previousHistories;
        previousTankId =
            previousHistory?.tankId ?? d.previousTankId ?? d.tankId;
        previousHoleId =
            previousHistory?.holeId ?? d.previousHoleId ?? d.holeId;
        previousTankCode =
            previousHistory?.tankCode ?? d.previousTankCode ?? d.tankCode;
        previousTankName =
            previousHistory?.tankName ?? d.previousTankName ?? d.tankName;
        previousHoleCode =
            previousHistory?.holeCode ?? d.previousHoleCode ?? d.holeCode;
        previousHoleName =
            previousHistory?.holeName ?? d.previousHoleName ?? d.holeName;
        previousRemarks = previousHistory?.remarks ?? d.remarks ?? "";
        previousPhotoUrls =
            _photoUrlsFromPhotos(previousHistory?.photos) ??
            _photoUrlsFromPhotos(d.photos);
      });
    } catch (_) {
      // Silently fail - previous data is optional
    }
  }

  Future<void> _loadStartDetail() async {
    try {
      final res = await api.getUnloadingPkDetail(
        "Bearer ${widget.token}",
        widget.model.registrationId ?? "",
      );
      final d = res.data;
      final startHistories = _startHistoriesUntilActiveCycle(d);
      final cycleStartHistory = _startHistoryForCycle(d);
      if (!mounted) return;
      setState(() {
        startTankId = cycleStartHistory?.tankId;
        startHoleId = cycleStartHistory?.holeId;
        startTankName = cycleStartHistory?.tankName;
        startHoleName = cycleStartHistory?.holeName;
        startRemarks = cycleStartHistory?.remarks ?? "";
        startPhotoUrls = _photoUrlsFromPhotos(cycleStartHistory?.photos);
        finishStartHistories = startHistories;

        previousTankId = null;
        previousHoleId = null;
        previousTankCode = null;
        previousTankName = null;
        previousHoleCode = null;
        previousHoleName = null;
        previousRemarks = null;
        previousPhotoUrls = null;

        if (startTankId != null || startTankName != null) {
          tanks = [
            TankItem(
              id: startTankId ?? 0,
              tank_code: cycleStartHistory?.tankCode ?? "",
              tank_name: startTankName ?? "",
            ),
          ];
        } else {
          tanks = [];
        }
        if (startHoleId != null || startHoleName != null) {
          holes = [
            HoleItem(
              id: startHoleId ?? 0,
              hole_code: cycleStartHistory?.holeCode ?? "",
              hole_name: startHoleName ?? "",
            ),
          ];
        } else {
          holes = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load detail start unloading: $e")),
      );
    }
  }

  Future<void> _loadFinishLabState() async {
    try {
      final res = await api.getLabPkDetail(
        "Bearer ${widget.token}",
        widget.model.registrationId ?? "",
      );
      final latestRecord = _latestLabRecord(res.data?.labRecords);
      if (!mounted || latestRecord == null) return;

      setState(() {
        finishLabStatus = latestRecord.status;
        finishLabCounter = latestRecord.counter;
      });
    } catch (_) {
      // Keep fallback from unloading model when lab detail is unavailable.
    }
  }

  String _historyTankLabel(UnloadingPkHistory item) {
    final tankCode = (item.tankCode ?? '').trim();
    final tankName = (item.tankName ?? '').trim();

    if (tankCode.isNotEmpty && tankName.isNotEmpty) {
      return '$tankCode — $tankName';
    }
    if (tankName.isNotEmpty) return tankName;
    if (tankCode.isNotEmpty) return tankCode;
    if (item.tankId != null) return 'Tank ID: ${item.tankId}';
    return '-';
  }

  String _historyHoleLabel(UnloadingPkHistory item) {
    final holeCode = (item.holeCode ?? '').trim();
    final holeName = (item.holeName ?? '').trim();

    if (holeCode.isNotEmpty && holeName.isNotEmpty) {
      return '$holeCode — $holeName';
    }
    if (holeName.isNotEmpty) return holeName;
    if (holeCode.isNotEmpty) return holeCode;
    if (item.holeId != null) return 'Hole ID: ${item.holeId}';
    return '-';
  }

  Widget _buildFinishStartHistoryCard(UnloadingPkHistory item) {
    final photoUrls = _photoUrlsFromPhotos(item.photos);
    final cycle = (item.cycle ?? 0).clamp(0, 2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade500),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cycleStartTitleFor(cycle),
            style: TextStyle(
              fontSize: baseFont,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          _fieldReadOnly('Tank', _historyTankLabel(item)),
          const SizedBox(height: 8),
          _fieldReadOnly('Hole', _historyHoleLabel(item)),
          const SizedBox(height: 8),
          _fieldReadOnly('Remarks', item.remarks),
          if (photoUrls != null && photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Foto Start (${photoUrls.length})',
              style: TextStyle(fontSize: baseFont, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photoUrls.length,
                itemBuilder: (_, idx) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrls[idx],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _getImage(int index) async {
    if (!_isCameraEnabled) return;

    final statuses = await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();

    if (!statuses[Permission.camera]!.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Akses kamera ditolak")));
      return;
    }

    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final f = File(picked.path);
    setState(() {
      switch (index) {
        case 1:
          _image1 = f;
          break;
        case 2:
          _image2 = f;
          break;
        case 3:
          _image3 = f;
          break;
        case 4:
          _image4 = f;
          break;
      }
    });
  }

  List<String> _collectPhotosBase64() {
    return [_image1, _image2, _image3, _image4].where((e) => e != null).map((
      f,
    ) {
      final bytes = f!.readAsBytesSync();
      return "data:image/jpeg;base64,${base64Encode(bytes)}";
    }).toList();
  }

  Future<void> _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: baseFont)),
        content: Text(message, style: TextStyle(fontSize: baseFont)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Tidak"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Ya"),
          ),
        ],
      ),
    );
  }

  // ─── START UNLOADING ───────────────────────────────────────────────────────

  Future<void> _confirmStartApprove() async {
    if (selectedTankId == null || selectedHoleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih Tank dan Hole dulu")));
      return;
    }
    if (!_hasAtLeastOneNewPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ambil minimal 1 foto baru sebelum approve unloading"),
        ),
      );
      return;
    }
    await _showConfirmDialog(
      title: "Konfirmasi Start Unloading",
      message: "Apakah anda yakin memulai unloading PK?",
      onConfirm: _submitStart,
    );
  }

  Future<void> _submitStart() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final photos = _collectPhotosBase64();

    final payload = {
      "registration_id": widget.model.registrationId,
      "tank_id": selectedTankId,
      "hole_id": selectedHoleId,
      "remarks": remarksCtrl.text.trim(),
      if (photos.isNotEmpty) "photos": photos,
    };

    try {
      final res = await api.startUnloadingPk("Bearer ${widget.token}", payload);
      if (!mounted) return;

      if (res.success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Start Unloading PK berhasil")),
        );
        Navigator.pop(context, {
          "registration_id": widget.model.registrationId,
          "plate_number": widget.model.plateNumber,
          "wb_ticket_no": widget.model.wbTicketNo,
          "status": "start",
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? "Gagal start unloading PK")),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.response?.data['message'] ?? e.message}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── FINISH UNLOADING ──────────────────────────────────────────────────────

  Future<void> _confirmFinish(String status) async {
    if (status == 'hold' && _isResamplingDisabledAtFinish) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Resampling tidak tersedia saat lab sudah approve di counter 2.',
          ),
        ),
      );
      return;
    }

    if (!_hasAtLeastOneNewPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ambil minimal 1 foto baru sebelum lanjut unloading"),
        ),
      );
      return;
    }

    if (status == "approved" && _photoCount < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Finish harus input 4 foto")),
      );
      return;
    }
    if (status == "hold" && _photoCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Resampling minimal 1 foto")),
      );
      return;
    }
    if (status == "hold" && _photoCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Resampling hanya jika foto kurang dari 4"),
        ),
      );
      return;
    }
    if (status == "rejected" && _photoCount < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reject minimal 1 foto")));
      return;
    }

    final titles = {
      "approved": "Konfirmasi Finish Unloading",
      "hold": "Konfirmasi Resampling",
      "rejected": "Konfirmasi Reject",
    };
    final messages = {
      "approved": "Apakah anda yakin menyelesaikan finish unloading PK?",
      "hold": "Apakah anda yakin melakukan resampling?",
      "rejected": "Apakah anda yakin reject unloading PK ini?",
    };

    await _showConfirmDialog(
      title: titles[status]!,
      message: messages[status]!,
      onConfirm: () => _submitFinish(status),
    );
  }

  Future<void> _submitFinish(String status) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final photos = _collectPhotosBase64();

    final payload = {
      "registration_id": widget.model.registrationId,
      "status": status,
      if (photos.isNotEmpty) "photos": photos,
    };

    try {
      final res = await api.finishUnloadingPk(
        "Bearer ${widget.token}",
        payload,
      );
      if (!mounted) return;

      if (res.success == true) {
        final label = status == "hold"
            ? "RESAMPLING"
            : status == "approved"
            ? "FINISH"
            : "REJECTED";
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Unloading PK $label berhasil")));
        Navigator.pop(context, {
          "registration_id": widget.model.registrationId,
          "plate_number": widget.model.plateNumber,
          "wb_ticket_no": widget.model.wbTicketNo,
          "status": status,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? "Gagal finish unloading PK")),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.response?.data['message'] ?? e.message}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── UI HELPERS ────────────────────────────────────────────────────────────

  Widget _fieldReadOnly(String label, String? value) {
    if (label == "Plat Kendaraan") {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: baseFont)),
            const SizedBox(height: 6),
            Text(
              value ?? "",
              style: TextStyle(
                fontSize: baseFont + 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: baseFont)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value ?? "-", style: TextStyle(fontSize: baseFont)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _photoBox(int index, File? f) {
    final canTap = _isCameraEnabled;
    return GestureDetector(
      onTap: canTap ? () => _getImage(index) : null,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(10),
            color: canTap ? Colors.white : Colors.grey.shade300,
          ),
          child: f == null
              ? const Icon(Icons.camera_alt, size: 30)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(f, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }

  Widget _btn(
    String text,
    Color c,
    VoidCallback onTap, {
    bool enabled = true,
  }) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: enabled ? c : Colors.grey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    onPressed: _isSubmitting || !enabled ? null : onTap,
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, color: Colors.white),
    ),
  );

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final info = {
      "Plat Kendaraan": widget.model.plateNumber,
      "Nomor Tiket Timbang": widget.model.wbTicketNo,
      "Supir": widget.model.driverName,
      "Kode Komoditi": widget.model.commodityCode,
      "Nama Komoditi": widget.model.commodityName,
      "Kode Vendor": widget.model.vendorCode,
      "Nama Vendor": widget.model.vendorName,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          _isFinishStage
              ? "Input Finish Unloading PK"
              : "Input Start Unloading PK",
          style: TextStyle(fontSize: baseFont + 4, color: Colors.black),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...info.entries.map((e) => _fieldReadOnly(e.key, e.value)),
            const SizedBox(height: 12),

            // ── PREVIOUS START DATA (cumulative by cycle) ───────────────────
            if (_isStartStage && startPreviousHistories.isNotEmpty) ...[
              Text(
                'Data Submission Sebelumnya',
                style: TextStyle(
                  fontSize: baseFont,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < startPreviousHistories.length; index++) ...[
                _buildFinishStartHistoryCard(startPreviousHistories[index]),
                if (index < startPreviousHistories.length - 1)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
            ],

            // ── TANK & HOLE ─────────────────────────────────────────────────
            if (_isFinishStage) ...[
              if (finishStartHistories.isNotEmpty) ...[
                for (
                  var index = 0;
                  index < finishStartHistories.length;
                  index++
                ) ...[
                  _buildFinishStartHistoryCard(finishStartHistories[index]),
                  if (index < finishStartHistories.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
              if (finishStartHistories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Data start untuk cycle ini belum dibuat.',
                    style: TextStyle(fontSize: baseFont, color: Colors.black54),
                  ),
                ),
            ] else ...[
              DropdownButtonFormField<int>(
                initialValue: selectedTankId,
                decoration: _dec("Pilih Tank"),
                items: tanks
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          "${t.tank_code} — ${t.tank_name}",
                          style: TextStyle(fontSize: baseFont),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedTankId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedHoleId,
                decoration: _dec("Pilih Hole"),
                items: holes
                    .map(
                      (h) => DropdownMenuItem(
                        value: h.id,
                        child: Text(
                          "${h.hole_code} — ${h.hole_name}",
                          style: TextStyle(fontSize: baseFont),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedHoleId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                maxLines: 3,
                decoration: _dec("Remarks"),
                style: TextStyle(fontSize: baseFont),
              ),
            ],

            const SizedBox(height: 12),

            // ── FOTO ────────────────────────────────────────────────────────
            CheckboxListTile(
              value: _isCameraEnabled,
              title: Text(
                "Ambil Foto (Camera)",
                style: TextStyle(
                  fontSize: baseFont + 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onChanged: (v) {
                setState(() {
                  _isCameraEnabled = v ?? false;
                  if (!_isCameraEnabled) {
                    _image1 = _image2 = _image3 = _image4 = null;
                  }
                });
              },
            ),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Expanded(child: _photoBox(1, _image1)),
                  const SizedBox(width: 8),
                  Expanded(child: _photoBox(2, _image2)),
                  const SizedBox(width: 8),
                  Expanded(child: _photoBox(3, _image3)),
                  const SizedBox(width: 8),
                  Expanded(child: _photoBox(4, _image4)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── BUTTONS ─────────────────────────────────────────────────────
            if (!_isFinishStage)
              Center(
                child: SizedBox(
                  width: 160,
                  child: _btn("Approve", Colors.blue, _confirmStartApprove),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btn(
                    "Resampling",
                    Colors.orange,
                    () => _confirmFinish("hold"),
                    enabled: !_isResamplingDisabledAtFinish,
                  ),
                  _btn("Finish", Colors.blue, () => _confirmFinish("approved")),
                  _btn(
                    "Reject",
                    Colors.red,
                    () => _confirmFinish("rejected"),
                    enabled: true,
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
