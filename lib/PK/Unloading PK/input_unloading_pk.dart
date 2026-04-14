import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/master/response/master_hole_response.dart';
import 'package:flutter_vcf/models/master/response/master_tank_response.dart';
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

  // Previous data (for cycle > 1 at start, or for finish previous attempt)
  int? previousTankId;
  int? previousHoleId;
  String? previousTankCode;
  String? previousTankName;
  String? previousHoleCode;
  String? previousHoleName;
  String? previousRemarks;
  List<String>? previousPhotoUrls;

  bool get _isFinishStage => widget.stage == UnloadingPKStage.finish;
  bool get _isStartStage => widget.stage == UnloadingPKStage.start;

  int get _photoCount =>
      [_image1, _image2, _image3, _image4].where((e) => e != null).length;

  @override
  void initState() {
    super.initState();
    _dio = AppConfig.createDio(withLogging: !kReleaseMode);
    api = ApiService(_dio);
    if (_isFinishStage) {
      _loadStartDetail();
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
      
      // Extract previous submission data
      final previousTank = d.previousTankId ?? d.tankId;
      final previousHole = d.previousHoleId ?? d.holeId;
      final previousRemarkText = d.remarks ?? "";
      final previousPhotos = d.photos?.map((p) => p.url ?? "").toList() ?? [];

      setState(() {
        previousTankId = previousTank;
        previousHoleId = previousHole;
        previousTankCode = d.previousTankCode ?? d.tankCode;
        previousTankName = d.previousTankName ?? d.tankName;
        previousHoleCode = d.previousHoleCode ?? d.holeCode;
        previousHoleName = d.previousHoleName ?? d.holeName;
        previousRemarks = previousRemarkText;
        previousPhotoUrls = previousPhotos.isNotEmpty ? previousPhotos : null;
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
      if (!mounted) return;
      setState(() {
        // Current start data
        startTankId = d?.tankId;
        startHoleId = d?.holeId;
        startTankName = d?.tankName;
        startHoleName = d?.holeName;
        startRemarks = d?.remarks ?? "";
        
        // Previous start data (from previous cycle/reunloading)
        // With fallback to current if no previous exists
        previousTankId = d?.previousTankId ?? d?.tankId;
        previousHoleId = d?.previousHoleId ?? d?.holeId;
        previousTankCode = d?.previousTankCode ?? d?.tankCode;
        previousTankName = d?.previousTankName ?? d?.tankName;
        previousHoleCode = d?.previousHoleCode ?? d?.holeCode;
        previousHoleName = d?.previousHoleName ?? d?.holeName;
        previousRemarks = d?.remarks ?? "";
        
        // Load photos from previous finish attempt (if any)
        final photos = d?.photos?.map((p) => p.url ?? "").toList() ?? [];
        previousPhotoUrls = photos.isNotEmpty ? photos : null;
        
        // Also load tank/hole names for display
        if (d?.tankCode != null || d?.tankName != null) {
          tanks = [
            TankItem(
              id: d!.tankId ?? 0,
              tank_code: d.tankCode ?? "",
              tank_name: d.tankName ?? "",
            ),
          ];
        }
        if (d?.holeCode != null || d?.holeName != null) {
          holes = [
            HoleItem(
              id: d!.holeId ?? 0,
              hole_code: d.holeCode ?? "",
              hole_name: d.holeName ?? "",
            ),
          ];
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load detail start unloading: $e")),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Akses kamera ditolak")),
      );
      return;
    }

    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final f = File(picked.path);
    setState(() {
      switch (index) {
        case 1: _image1 = f; break;
        case 2: _image2 = f; break;
        case 3: _image3 = f; break;
        case 4: _image4 = f; break;
      }
    });
  }

  List<String> _collectPhotosBase64() {
    return [_image1, _image2, _image3, _image4]
        .where((e) => e != null)
        .map((f) {
      final bytes = f!.readAsBytesSync();
      return "data:image/jpeg;base64,${base64Encode(bytes)}";
    }).toList();
  }

  String _tankLabel(int? id) {
    if (id == null) return "-";
    final t = tanks.cast<TankItem?>().firstWhere(
      (x) => x?.id == id,
      orElse: () => null,
    );
    if (t == null) return id.toString();
    return "${t.tank_code} — ${t.tank_name}";
  }

  String _holeLabel(int? id) {
    if (id == null) return "-";
    final h = holes.cast<HoleItem?>().firstWhere(
      (x) => x?.id == id,
      orElse: () => null,
    );
    if (h == null) return id.toString();
    return "${h.hole_code} — ${h.hole_name}";
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih Tank dan Hole dulu")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── FINISH UNLOADING ──────────────────────────────────────────────────────

  Future<void> _confirmFinish(String status) async {
    if (status == "approved" && _photoCount < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Finish harus input 4 foto")),
      );
      return;
    }
    if (status == "hold" && _photoCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Resampling minimal 1 foto"),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reject minimal 1 foto"),
        ),
      );
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
      final res = await api.finishUnloadingPk("Bearer ${widget.token}", payload);
      if (!mounted) return;

      if (res.success == true) {
        final label = status == "hold"
            ? "RESAMPLING"
            : status == "approved"
                ? "FINISH"
                : "REJECTED";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unloading PK $label berhasil")),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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
  }) =>
      ElevatedButton(
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

            // ── PREVIOUS DATA (if available) ────────────────────────────────
            if (previousTankId != null && _isStartStage) ...[
              Container(
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
                      'Data Submission Sebelumnya',
                      style: TextStyle(
                        fontSize: baseFont,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _fieldReadOnly("Tank (Sebelumnya)", 
                        "$previousTankName (ID: $previousTankId)"),
                    const SizedBox(height: 8),
                    _fieldReadOnly("Hole (Sebelumnya)", 
                        "$previousHoleName (ID: $previousHoleId)"),
                    const SizedBox(height: 8),
                    _fieldReadOnly("Remarks (Sebelumnya)", previousRemarks),
                    if (previousPhotoUrls != null && previousPhotoUrls!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Foto Sebelumnya (${previousPhotoUrls!.length})',
                        style: TextStyle(fontSize: baseFont, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: previousPhotoUrls!.length,
                          itemBuilder: (_, idx) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                previousPhotoUrls![idx],
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
              ),
              const SizedBox(height: 16),
            ],

            // ── TANK & HOLE ─────────────────────────────────────────────────
            if (_isFinishStage) ...[
              // Show previous tank & hole if available
              if (previousTankId != null || previousHoleId != null) ...[
                Container(
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
                        'Tank & Hole Sebelumnya',
                        style: TextStyle(
                          fontSize: baseFont,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _fieldReadOnly("Tank (Sebelumnya)", 
                          previousTankName != null 
                              ? "$previousTankName${previousTankCode != null ? ' (${previousTankCode})' : ''}"
                              : "-"),
                      const SizedBox(height: 8),
                      _fieldReadOnly("Hole (Sebelumnya)", 
                          previousHoleName != null 
                              ? "$previousHoleName${previousHoleCode != null ? ' (${previousHoleCode})' : ''}"
                              : "-"),
                      const SizedBox(height: 8),
                      _fieldReadOnly("Remarks (Sebelumnya)", previousRemarks),
                      if (previousPhotoUrls != null && previousPhotoUrls!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Foto Sebelumnya (${previousPhotoUrls!.length})',
                          style: TextStyle(
                            fontSize: baseFont,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: previousPhotoUrls!.length,
                            itemBuilder: (_, idx) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  previousPhotoUrls![idx],
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
                ),
                const SizedBox(height: 16),
              ],
              
              // Current tank & hole
              Container(
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
                      'Tank & Hole (Start Sekarang)',
                      style: TextStyle(
                        fontSize: baseFont,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _fieldReadOnly("Tank", _tankLabel(startTankId)),
                    const SizedBox(height: 8),
                    _fieldReadOnly("Hole", _holeLabel(startHoleId)),
                    const SizedBox(height: 8),
                    _fieldReadOnly("Remarks", startRemarks),
                  ],
                ),
              ),
            ] else ...[
              DropdownButtonFormField<int>(
                value: selectedTankId,
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
                value: selectedHoleId,
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
                  ),
                  _btn(
                    "Finish",
                    Colors.blue,
                    () => _confirmFinish("approved"),
                  ),
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
