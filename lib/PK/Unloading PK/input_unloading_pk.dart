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
import 'package:flutter_vcf/models/pk/response/unloading_pk_detail_response.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class InputUnloadingPKPage extends StatefulWidget {
  final String token;
  final UnloadingPkModel model;
  const InputUnloadingPKPage({
    super.key,
    required this.token,
    required this.model,
  });

  @override
  State<InputUnloadingPKPage> createState() => _InputUnloadingPKPageState();
}

class _InputUnloadingPKPageState extends State<InputUnloadingPKPage> {
  final TextEditingController remarksCtrl = TextEditingController();
  final TextEditingController reRemarksCtrl = TextEditingController();
  final double baseFont = 15;

  bool _isSubmitting = false;
  String pageMode = 'normal';
  bool _isCameraEnabled = false;
  bool _isReloadingExisting = false;

  File? _image1, _image2, _image3, _image4;
  final ImagePicker picker = ImagePicker();

  late Dio _dio;
  late ApiService api;

  List<TankItem> tanks = [];
  List<HoleItem> holes = [];

  int? initialTankId;
  int? initialHoleId;
  String? initialRemarks;

  int? reSelectedTankId;
  int? reSelectedHoleId;

  List<String> _existingPhotos = [];

  bool unloadingStarted = false;
  bool disableHoldButton = false;

  @override
  void initState() {
    super.initState();
    _dio = AppConfig.createDio(withLogging: !kReleaseMode);
    api = ApiService(_dio);
    _loadMasterData().whenComplete(() => _loadExistingUnloading());
  }

  @override
  void dispose() {
    remarksCtrl.dispose();
    reRemarksCtrl.dispose();
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

  Future<void> _loadExistingUnloading() async {
    try {
      final res = await api.getUnloadingPkDetail(
        "Bearer ${widget.token}",
        widget.model.registrationId ?? "",
      );
      final d = res.data;

      final samplingCount = await _countSamplingData();

      if (!mounted) return;

      if (d == null) {
        setState(() {
          pageMode = 'normal';
          unloadingStarted = false;
          reSelectedTankId = null;
          reSelectedHoleId = null;
          _existingPhotos = [];
          initialTankId = null;
          initialHoleId = null;
          initialRemarks = null;
          remarksCtrl.text = "";
          reRemarksCtrl.text = "";
          _isCameraEnabled = false;
        });
        return;
      }

      final regStatus = (d.registStatus ?? "").toLowerCase().trim();
      final unloadingStatus = (d.unloadingStatus ?? "").toLowerCase().trim();
      final unloadingExists =
          d.tankId != null ||
          d.holeId != null ||
          (d.remarks?.isNotEmpty ?? false) ||
          (d.photos != null && d.photos!.isNotEmpty);

      setState(() {
        reSelectedTankId = null;
        reSelectedHoleId = null;
        reRemarksCtrl.text = "";
        _existingPhotos = [];
        initialTankId = null;
        initialHoleId = null;
        initialRemarks = null;
        remarksCtrl.text = "";
        unloadingStarted = unloadingExists;
        pageMode = 'normal';
        _isCameraEnabled = false;

        if (unloadingExists) {
          initialTankId = d.tankId;
          initialHoleId = d.holeId;
          initialRemarks = d.remarks ?? "";
          remarksCtrl.text = d.remarks ?? "";
          final allPhotos = (d.photos ?? [])
              .map((p) => p.url ?? "")
              .where((u) => u.isNotEmpty)
              .toList();
          _existingPhotos = allPhotos.length > 4
              ? allPhotos.sublist(allPhotos.length - 4)
              : allPhotos;
        }

        if (unloadingStatus == "hold" && regStatus == "qc_resampling") {
          pageMode = 'hold_resampling';
          disableHoldButton = true;
        } else if (unloadingStatus == "hold" &&
            (regStatus == "unloading" || regStatus == "qc_reunloading")) {
          pageMode = 'hold_unloading';
          disableHoldButton = samplingCount > 2;
        } else {
          pageMode = 'normal';
         disableHoldButton = samplingCount > 2;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error load detail unloading: $e")),
      );
    }
  }

  Future<int> _countSamplingData() async {
    try {
      final registrationId = widget.model.registrationId ?? "";
      if (registrationId.isEmpty) return 0;

      final res = await _dio.get(
        "/qc/sampling/pk/$registrationId",
        options: Options(
          headers: {"Authorization": "Bearer ${widget.token}"},
        ),
      );

      final body = res.data;
      if (body is! Map<String, dynamic>) return 0;

      final data = body["data"];
      if (data is! Map<String, dynamic>) return 0;

      final records = data["sampling_records"];
      if (records is List) return records.length;

      final samplingCount = data["sampling_count"];
      if (samplingCount is num) return samplingCount.toInt();
      if (samplingCount is String) return int.tryParse(samplingCount) ?? 0;

      return 0;
    } catch (e) {
      debugPrint("Error Count Sampling Data: $e");
      return 0;
    }
  }

  String _tankLabel(int? id) {
    if (id == null) return "-";
    final t = tanks.firstWhere(
      (x) => x.id == id,
      orElse: () => TankItem(id: id, tank_code: "T$id", tank_name: "Tank $id"),
    );
    return "${t.tank_code} — ${t.tank_name}";
  }

  String _holeLabel(int? id) {
    if (id == null) return "-";
    final h = holes.firstWhere(
      (x) => x.id == id,
      orElse: () => HoleItem(id: id, hole_code: "H$id", hole_name: "Hole $id"),
    );
    return "${h.hole_code} — ${h.hole_name}";
  }

  Future<void> _getImage(int index) async {
    if (!_isCameraEnabled) return;
    if (!(pageMode == 'hold_unloading' || pageMode == 'normal')) return;

    final statuses = await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();

    if (!statuses[Permission.camera]!.isGranted) {
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

  List<String> _collectPhotosBase64({int max = 4}) {
    final imgs = [
      _image1,
      _image2,
      _image3,
      _image4,
    ].where((e) => e != null).toList();

    final picked = imgs.take(max).map((f) {
      final bytes = f!.readAsBytesSync();
      return "data:image/jpeg;base64,${base64Encode(bytes)}";
    }).toList();

    return picked;
  }

  Future<bool> _startUnloading() async {
    if (pageMode == 'hold_resampling') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Sedang menunggu resampling. Tidak dapat mengubah data.",
          ),
        ),
      );
      return false;
    }

    int? chosenTank;
    int? chosenHole;

    if (pageMode == 'normal' || pageMode == 'hold_unloading') {
      chosenTank = reSelectedTankId;
      chosenHole = reSelectedHoleId;
    } else {
      chosenTank = initialTankId;
      chosenHole = initialHoleId;
    }

    if (chosenTank == null || chosenHole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih Tank dan Hole dulu")));
      return false;
    }

    final imgs = [
      _image1,
      _image2,
      _image3,
      _image4,
    ].where((e) => e != null).toList();

    if (imgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ambil minimal 1 foto dulu")),
      );
      return false;
    }

    return true;
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

  Future<void> _reloadExistingPhotos() async {
    if (_isReloadingExisting) return;
    setState(() => _isReloadingExisting = true);
    try {
      await _loadExistingUnloading();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar berhasil dimuat ulang')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat ulang gambar: $e')),
        );
    } finally {
      if (mounted) setState(() => _isReloadingExisting = false);
    }
  }

  Future<void> _confirmAndSubmit(String status) async {
    if (status == "hold" && disableHoldButton) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Resampling sudah maksimal")),
      );
      return;
    }

    if (!await _startUnloading()) return;

    await _showConfirmDialog(
      title: "Konfirmasi Simpan",
      message: "Apakah anda yakin menyimpan data Unloading PK?",
      onConfirm: () => _submit(status),
    );
  }

  Future<void> _confirmAndFinish() async {
    if (!await _startUnloading()) return;
    await _showConfirmDialog(
      title: "Konfirmasi Selesai",
      message: "Apakah anda yakin menyelesaikan unloading PK?",
      onConfirm: () => _submit("approved"),
    );
  }

  Future<void> _submit(String status) async {
    if (_isSubmitting) return;
    if (pageMode == 'hold_resampling') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sedang menunggu resampling. Tidak dapat submit."),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final photos = _collectPhotosBase64(max: 4);

      int? payloadTankId;
      int? payloadHoleId;
      String payloadRemarks = "";

      if (pageMode == 'hold_unloading' || pageMode == 'normal') {
        payloadTankId = reSelectedTankId;
        payloadHoleId = reSelectedHoleId;
        payloadRemarks = reRemarksCtrl.text.trim();
      } else {
        payloadTankId = reSelectedTankId ?? initialTankId;
        payloadHoleId = reSelectedHoleId ?? initialHoleId;
        payloadRemarks = reRemarksCtrl.text.trim().isNotEmpty
            ? reRemarksCtrl.text.trim()
            : remarksCtrl.text.trim();
      }

      final payload = {
        "registration_id": widget.model.registrationId,
        "status": status,
        "tank_id": payloadTankId,
        "hole_id": payloadHoleId,
        "remarks": payloadRemarks,
        if (photos.isNotEmpty) "photos": photos,
      };

      final res = await api.submitUnloadingPk(
        "Bearer ${widget.token}",
        payload,
      );

      if (!mounted) return;

      if (res.success == true) {
        final statusLabel = status == "hold" ? "RESAMPLING" : status.toUpperCase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unloading PK $statusLabel berhasil"),
          ),
        );
        Navigator.pop(context, {
          "registration_id": widget.model.registrationId,
          "plate_number": widget.model.plateNumber,
          "wb_ticket_no": widget.model.wbTicketNo,
          "status": status,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? "Gagal submit unloading PK")),
        );
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.response?.data['message'] ?? e.message}"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _initialPhotoThumb(String url) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade300,
          border: Border.all(color: Colors.black26),
        ),
        child: url.isEmpty
            ? const Icon(Icons.image_not_supported)
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 20),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _showPhotoPreviewDialog(String url) async {
    final mq = MediaQuery.of(context).size;
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: mq.width * 0.9,
          height: mq.height * 0.75,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoBox(int index, File? f) {
    final bool canTap =
        _isCameraEnabled &&
        (pageMode == 'hold_unloading' || pageMode == 'normal');

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

  Widget _fieldReadOnly(String label, String? value) {
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
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black26),
            ),
            child: Text(value ?? "-", style: TextStyle(fontSize: baseFont)),
          ),
        ],
      ),
    );
  }

  Widget _btn(String text, Color c, VoidCallback onTap, {bool enabled = true}) {
    return ElevatedButton(
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
  }

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
          "Input Unloading PK",
          style: TextStyle(fontSize: baseFont + 4, color: Colors.black),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...info.entries.map((e) => _fieldReadOnly(e.key, e.value)).toList(),
            const SizedBox(height: 12),

            if (unloadingStarted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "UNLOADING SEBELUMNYA",
                    style: TextStyle(
                      fontSize: baseFont + 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _isReloadingExisting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Reload existing photos',
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () async => await _reloadExistingPhotos(),
                        ),
                ],
              ),
              const SizedBox(height: 8),
              _fieldReadOnly("Pilih Tank", _tankLabel(initialTankId)),
              const SizedBox(height: 8),
              _fieldReadOnly("Pilih Hole", _holeLabel(initialHoleId)),
              const SizedBox(height: 8),
              _fieldReadOnly("Remarks", initialRemarks),
              const SizedBox(height: 12),
              if (_existingPhotos.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: List.generate(4, (i) {
                      final hasPhoto = i < _existingPhotos.length;
                      final url = hasPhoto ? _existingPhotos[i] : '';

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                          child: hasPhoto
                              ? GestureDetector(
                                  onTap: () => _showPhotoPreviewDialog(url),
                                  child: _initialPhotoThumb(url),
                                )
                              : _initialPhotoThumb(url),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            if (pageMode == 'hold_unloading' || pageMode == 'normal') ...[
              Text(
                "INPUT UNLOADING",
                style: TextStyle(
                  fontSize: baseFont + 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: reSelectedTankId,
                decoration: const InputDecoration(
                  labelText: "Pilih Tank",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: tanks
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text("${t.tank_code} — ${t.tank_name}"),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => reSelectedTankId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: reSelectedHoleId,
                decoration: const InputDecoration(
                  labelText: "Pilih Hole",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: holes
                    .map(
                      (h) => DropdownMenuItem(
                        value: h.id,
                        child: Text("${h.hole_code} — ${h.hole_name}"),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => reSelectedHoleId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reRemarksCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Remarks (Re-Unloading)",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: TextStyle(fontSize: baseFont),
              ),
              const SizedBox(height: 12),
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
                  setState(() => _isCameraEnabled = v ?? false);
                  if (v == false) {
                    setState(() {
                      _image1 = _image2 = _image3 = _image4 = null;
                    });
                  }
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _btn(
                    "Resampling",
                    Colors.orange,
                    () => _confirmAndSubmit("hold"),
                    enabled: !disableHoldButton,
                  ),
                  _btn("Finish", Colors.blue, _confirmAndFinish, enabled: true),
                  _btn(
                    "Reject",
                    Colors.red,
                    () => _confirmAndSubmit("rejected"),
                    enabled: true,
                  ),
                ],
              ),
            ],

            if (pageMode == 'hold_resampling') ...[
              const SizedBox(height: 8),
              Text(
                "Mode: RESAMPLING. Menunggu resampling & re-lab. Tidak dapat mengubah data.",
                style: TextStyle(fontSize: baseFont - 1, color: Colors.black54),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
