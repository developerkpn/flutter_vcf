import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_vcf/models/master/response/master_hole_response.dart';
import 'package:flutter_vcf/models/master/response/master_tank_response.dart';

import 'sales_api.dart';
import 'sales_loading_page.dart';

class SalesInputLoadingPage extends StatefulWidget {
  const SalesInputLoadingPage({
    super.key,
    required this.model,
    required this.token,
    this.stage = SalesLoadingStage.start,
  });

  final JsonMap model;
  final String token;
  final SalesLoadingStage stage;

  @override
  State<SalesInputLoadingPage> createState() => _SalesInputLoadingPageState();
}

class _SalesInputLoadingPageState extends State<SalesInputLoadingPage> {
  final TextEditingController _remarksCtrl = TextEditingController();
  final double _baseFont = 15;
  final ImagePicker _picker = ImagePicker();
  final SalesApi _salesApi = SalesApi();

  late Dio _dio;
  late ApiService _api;

  File? _image1;
  File? _image2;
  File? _image3;
  File? _image4;

  bool _isCameraEnabled = false;
  bool _loadingStarted = false;
  bool _isSubmitting = false;

  List<TankItem> _tanks = const <TankItem>[];
  List<HoleItem> _holes = const <HoleItem>[];
  int? _selectedTankId;
  int? _selectedHoleId;

  bool get _isFinishStage => widget.stage == SalesLoadingStage.finish;
  bool get _selectionReadOnly => _isFinishStage;

  @override
  void initState() {
    super.initState();
    _dio = AppConfig.createDio(withLogging: true);
    _api = ApiService(_dio);
    _loadMasterData();
    _loadExistingLoadingData();
  }

  String _textOf(dynamic primary, [dynamic secondary]) {
    final first = (primary ?? '').toString();
    if (first.isNotEmpty) return first;
    return (secondary ?? '').toString();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<void> _loadExistingLoadingData() async {
    if (_isFinishStage) {
      await _loadStartLoadingDetail();
    }
  }

  Future<void> _loadStartLoadingDetail() async {
    try {
      final detail = await _salesApi.getStartLoadingDetail(
        'Bearer ${widget.token}',
        _textOf(widget.model['registration_id']),
      );

      if (!mounted) return;
      setState(() {
        _selectedTankId = _parseInt(detail['tank_id']);
        _selectedHoleId = _parseInt(detail['hole_id']);
        _remarksCtrl.text = _textOf(detail['remarks']);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error load start loading: $error')),
      );
    }
  }

  Future<void> _loadMasterData() async {
    try {
      final tankResponse = await _api.getAllTanks('Bearer ${widget.token}');
      final holeResponse = await _api.getAllHoles('Bearer ${widget.token}');

      if (!mounted) return;
      setState(() {
        _tanks = tankResponse.data;
        _holes = holeResponse.data;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal load data tank & hole')),
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

    if (!mounted) return;

    if (!statuses[Permission.camera]!.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akses kamera ditolak')),
      );
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      if (index == 1) _image1 = file;
      if (index == 2) _image2 = file;
      if (index == 3) _image3 = file;
      if (index == 4) _image4 = file;
    });
  }

  List<String> _collectPhotosBase64() {
    final images = <File?>[_image1, _image2, _image3, _image4]
        .where((item) => item != null)
        .cast<File>()
        .toList();
    return images.map((file) {
      final bytes = file.readAsBytesSync();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }).toList();
  }

  bool _hasAtLeastOneNewPhoto() {
    return _image1 != null || _image2 != null || _image3 != null || _image4 != null;
  }

  bool _ensureAtLeastOneNewPhoto(String actionLabel) {
    if (_hasAtLeastOneNewPhoto()) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ambil minimal 1 foto baru sebelum $actionLabel')),
    );
    return false;
  }

  Future<bool> _startLoading() async {
    if (_loadingStarted) return true;

    if (_selectedTankId == null || _selectedHoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Tank dan Hole dulu')),
      );
      return false;
    }

    if (!_hasAtLeastOneNewPhoto()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambil minimal 1 foto dulu')),
      );
      return false;
    }

    setState(() => _loadingStarted = true);
    return true;
  }

  Future<void> _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: _baseFont)),
        content: Text(message, style: TextStyle(fontSize: _baseFont)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
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
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndFinish() async {
    if (!_ensureAtLeastOneNewPhoto('approve loading')) return;
    if (!await _startLoading()) return;

    await _showConfirmDialog(
      title: 'Konfirmasi Selesai',
      message: 'Apakah anda yakin menyelesaikan loading?',
      onConfirm: _finishLoading,
    );
  }

  Future<void> _finishLoading() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final photos = _collectPhotosBase64();

    final payload = <String, dynamic>{
      'registration_id': widget.model['registration_id'],
      'status': 'approved',
      'tank_id': _selectedTankId,
      'hole_id': _selectedHoleId,
      'remarks': _remarksCtrl.text.trim(),
      if (photos.isNotEmpty) 'photos': photos,
    };

    try {
      final response = widget.stage == SalesLoadingStage.start
          ? await _salesApi.submitStartLoading('Bearer ${widget.token}', payload)
          : await _salesApi.submitFinishLoading('Bearer ${widget.token}', payload);

      if (!mounted) return;
      if (response['success'] == true) {
        Navigator.pop(context, <String, dynamic>{
          'registration_id': widget.model['registration_id'],
          'plate_number': widget.model['plate_number'],
          'wb_ticket_no': widget.model['wb_ticket_no'],
          'status': 'approved',
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_textOf(response['message'], 'Gagal finish'))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finish: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          widget.stage.inputTitle,
          style: TextStyle(
            fontSize: _baseFont + 4,
            color: Colors.black,
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _fieldReadOnly('Plat Kendaraan', _textOf(widget.model['plate_number'])),
            _fieldReadOnly('Nomor Tiket Timbang', _textOf(widget.model['wb_ticket_no'])),
            _fieldReadOnly('Supir', _textOf(widget.model['driver_name'])),
            _fieldReadOnly('Kode Komoditi', _textOf(widget.model['commodity_code'])),
            _fieldReadOnly('Nama Komoditi', _textOf(widget.model['commodity_name'])),
            _fieldReadOnly('Kode Vendor', _textOf(widget.model['vendor_code'])),
            _fieldReadOnly('Nama Vendor', _textOf(widget.model['vendor_name'])),
            const SizedBox(height: 12),
            if (_isFinishStage)
              _fieldReadOnly('Tank', _tankLabel(_selectedTankId))
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedTankId,
                decoration: _dec('Pilih Tank'),
                items: _tanks.map((tank) {
                  return DropdownMenuItem<int>(
                    value: tank.id,
                    child: Text('${tank.tank_code} - ${tank.tank_name}'),
                  );
                }).toList(),
                onChanged: _selectionReadOnly
                    ? null
                    : (value) => setState(() => _selectedTankId = value),
              ),
            const SizedBox(height: 12),
            if (_isFinishStage)
              _fieldReadOnly('Hole', _holeLabel(_selectedHoleId))
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedHoleId,
                decoration: _dec('Pilih Hole'),
                items: _holes.map((hole) {
                  return DropdownMenuItem<int>(
                    value: hole.id,
                    child: Text('${hole.hole_code} - ${hole.hole_name}'),
                  );
                }).toList(),
                onChanged: _selectionReadOnly
                    ? null
                    : (value) => setState(() => _selectedHoleId = value),
              ),
            const SizedBox(height: 12),
            if (_isFinishStage)
              _fieldReadOnly('Remarks', _remarksCtrl.text)
            else
              TextField(
                controller: _remarksCtrl,
                maxLines: 3,
                decoration: _dec('Remarks'),
                style: TextStyle(fontSize: _baseFont),
              ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _isCameraEnabled,
              title: Text(
                'Ambil Foto (Camera)',
                style: TextStyle(fontSize: _baseFont + 1, fontWeight: FontWeight.w500),
              ),
              onChanged: (value) {
                setState(() {
                  _isCameraEnabled = value ?? false;
                  if (!_isCameraEnabled) {
                    _image1 = null;
                    _image2 = null;
                    _image3 = null;
                    _image4 = null;
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
                  Expanded(child: _box(1, _image1)),
                  const SizedBox(width: 8),
                  Expanded(child: _box(2, _image2)),
                  const SizedBox(width: 8),
                  Expanded(child: _box(3, _image3)),
                  const SizedBox(width: 8),
                  Expanded(child: _box(4, _image4)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: SizedBox(
                width: 140,
                child: _button('Approve', Colors.blue, _confirmAndFinish),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    );
  }

  String _tankLabel(int? tankId) {
    if (tankId == null) return '-';
    final tank = _tanks.cast<TankItem?>().firstWhere(
      (item) => item?.id == tankId,
      orElse: () => null,
    );
    if (tank == null) return tankId.toString();
    return '${tank.tank_code} - ${tank.tank_name}';
  }

  String _holeLabel(int? holeId) {
    if (holeId == null) return '-';
    final hole = _holes.cast<HoleItem?>().firstWhere(
      (item) => item?.id == holeId,
      orElse: () => null,
    );
    if (hole == null) return holeId.toString();
    return '${hole.hole_code} - ${hole.hole_name}';
  }

  Widget _fieldReadOnly(String label, String? value) {
    if (label == 'Plat Kendaraan') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: _baseFont)),
            const SizedBox(height: 6),
            Text(
              value ?? '',
              style: TextStyle(
                fontSize: _baseFont + 1,
                fontWeight: FontWeight.w600,
                color: Colors.black,
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
          Text(label, style: TextStyle(fontSize: _baseFont)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value ?? '', style: TextStyle(fontSize: _baseFont)),
          ),
        ],
      ),
    );
  }

  Widget _button(String text, Color color, VoidCallback onTap, {bool enabled = true}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: _isSubmitting || !enabled ? null : onTap,
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _box(int index, File? file) {
    return GestureDetector(
      onTap: _isCameraEnabled ? () => _getImage(index) : null,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(10),
            color: _isCameraEnabled ? Colors.white : Colors.grey.shade300,
          ),
          child: file == null
              ? const Icon(Icons.camera_alt, size: 30)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }
}