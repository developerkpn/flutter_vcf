import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sales_api.dart';

class SalesInputLabPage extends StatefulWidget {
  const SalesInputLabPage({
    super.key,
    required this.token,
    required this.model,
  });

  final String token;
  final JsonMap model;

  @override
  State<SalesInputLabPage> createState() => _SalesInputLabPageState();
}

class _SalesInputLabPageState extends State<SalesInputLabPage> {
  final TextEditingController _ffaCtrl = TextEditingController();
  final TextEditingController _moistureCtrl = TextEditingController();
  final TextEditingController _dobiCtrl = TextEditingController();
  final TextEditingController _ivCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  final SalesApi _api = SalesApi();
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  bool _isLoadingDetail = false;
  bool _isCameraEnabled = false;
  bool _isInspectionConfirmed = false;
  bool _isInspectionLocked = false;

  File? _image1;
  File? _image2;
  File? _image3;
  File? _image4;

  @override
  void initState() {
    super.initState();
    _syncInspectionFromValue(widget.model['inspeksi']);
    _loadLabDetail();
  }

  @override
  void dispose() {
    _ffaCtrl.dispose();
    _moistureCtrl.dispose();
    _dobiCtrl.dispose();
    _ivCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _textOf(dynamic primary, [dynamic secondary]) {
    final first = (primary ?? '').toString();
    if (first.isNotEmpty) return first;
    return (secondary ?? '').toString();
  }

  bool _isInspectionDoneValue(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    return normalized == 'sudah inspeksi' || normalized == 'true';
  }

  void _syncInspectionFromValue(dynamic value) {
    if (!_isInspectionDoneValue(value)) return;

    _isInspectionConfirmed = true;
    _isInspectionLocked = true;
  }

  bool get _canEditQcData => _isInspectionConfirmed && !_isLoadingDetail && !_isSubmitting;

  Future<void> _loadLabDetail() async {
    final registrationId = _textOf(widget.model['registration_id']);
    if (registrationId.isEmpty) return;

    setState(() => _isLoadingDetail = true);

    try {
      final detail = await _api.getLabDetail(
        'Bearer ${widget.token}',
        registrationId,
      );

      if (!mounted) return;
      setState(() {
        _syncInspectionFromValue(detail['inspeksi']);
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  void _showInspectionConfirmation() {
    if (_isInspectionLocked || _isSubmitting || _isLoadingDetail) return;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Inspeksi'),
        content: const Text('Apakah anda yakin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isInspectionConfirmed = true;
                _isInspectionLocked = true;
              });
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  Future<void> _getImage(int index) async {
    if (!_isCameraEnabled || !_canEditQcData) return;

    final statuses = await [Permission.camera].request();
    if (!statuses[Permission.camera]!.isGranted) {
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      switch (index) {
        case 1:
          _image1 = file;
          break;
        case 2:
          _image2 = file;
          break;
        case 3:
          _image3 = file;
          break;
        case 4:
          _image4 = file;
          break;
      }
    });
  }

  bool _hasAtLeastOnePhoto() {
    return _image1 != null || _image2 != null || _image3 != null || _image4 != null;
  }

  bool _validateInputs() {
    if (!_isInspectionConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist inspeksi dulu sebelum input data lab')),
      );
      return false;
    }

    if (_ffaCtrl.text.isEmpty ||
        _moistureCtrl.text.isEmpty ||
        _dobiCtrl.text.isEmpty ||
        _ivCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi FFA, Moisture, DOBI & IV dulu')),
      );
      return false;
    }

    final ffa = double.tryParse(_ffaCtrl.text.replaceAll(',', '.'));
    final moisture = double.tryParse(_moistureCtrl.text.replaceAll(',', '.'));
    final dobi = double.tryParse(_dobiCtrl.text.replaceAll(',', '.'));
    final iv = double.tryParse(_ivCtrl.text.replaceAll(',', '.'));

    if (ffa == null || moisture == null || dobi == null || iv == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Input angka tidak valid')),
      );
      return false;
    }

    if (ffa < 0 ||
        ffa > 100 ||
        moisture < 0 ||
        moisture > 100 ||
        dobi < 0 ||
        dobi > 10 ||
        iv < 0 ||
        iv > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data yang dimasukin tidak sesuai standar')),
      );
      return false;
    }

    if (!_hasAtLeastOnePhoto()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ambil minimal 1 foto hasil lab sebelum lanjut'),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _submitApproved() async {
    if (!_validateInputs()) return;

    setState(() => _isSubmitting = true);

    try {
      final photos = <String>[];
      for (final image in [_image1, _image2, _image3, _image4]) {
        if (image != null) {
          final bytes = await image.readAsBytes();
          photos.add('data:image/jpeg;base64,${base64Encode(bytes)}');
        }
      }

      final payload = <String, dynamic>{
        'registration_id': widget.model['registration_id'],
        'regist_status': _textOf(widget.model['regist_status']).toLowerCase(),
        'ffa': double.parse(_ffaCtrl.text.replaceAll(',', '.')),
        'moisture': double.parse(_moistureCtrl.text.replaceAll(',', '.')),
        'dobi': double.parse(_dobiCtrl.text.replaceAll(',', '.')),
        'iv': double.parse(_ivCtrl.text.replaceAll(',', '.')),
        if (_isInspectionConfirmed) 'inspeksi': true,
        'remarks': _remarksCtrl.text.trim(),
        'status': 'approved',
        if (photos.isNotEmpty) 'photos': photos,
      };

      final response = await _api.submitLab('Bearer ${widget.token}', payload);

      if (!mounted) return;
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales Lab APPROVED berhasil dikirim')),
        );
        Navigator.pop(context, <String, dynamic>{
          'registration_id': widget.model['registration_id'],
          'plate_number': widget.model['plate_number'],
          'wb_ticket_no': widget.model['wb_ticket_no'],
          'lab_status': 'approved',
          'inspeksi': 'sudah inspeksi',
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_textOf(response['message'], 'Gagal submit Sales Lab'))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _confirmApprove() {
    if (!_validateInputs()) return;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve'),
        content: const Text('Setujui Sales Lab?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitApproved();
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Sales Lab'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _plateWidget(_textOf(widget.model['plate_number'], '-')),
              _readonlyBox('Nomor Tiket Timbang', _textOf(widget.model['wb_ticket_no'], '-')),
              _readonlyBox('Supir', _textOf(widget.model['driver_name'], '-')),
              _readonlyBox('Kode Komoditi', _textOf(widget.model['commodity_code'], '-')),
              _readonlyBox('Nama Komoditi', _textOf(widget.model['commodity_name'], '-')),
              _readonlyBox('Kode Vendor', _textOf(widget.model['vendor_code'], '-')),
              _readonlyBox('Nama Vendor', _textOf(widget.model['vendor_name'], '-')),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isInspectionConfirmed,
                      onChanged: _isInspectionLocked || _isLoadingDetail || _isSubmitting
                          ? null
                          : (_) => _showInspectionConfirmation(),
                    ),
                    const Text(
                      'INSPEKSI',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Input QC Data',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _canEditQcData ? Colors.black : Colors.black45,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: _numberField('FFA (%)', _ffaCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField('Moisture (%)', _moistureCtrl)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField('DOBI', _dobiCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField('IV', _ivCtrl)),
                ],
              ),
              const SizedBox(height: 8),
              _input('Remarks', _remarksCtrl, maxLines: 2),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _canEditQcData ? Colors.grey.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ambil Gambar Hasil Lab',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Checkbox(
                          value: _isCameraEnabled,
                          onChanged: !_canEditQcData
                              ? null
                              : (value) {
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
                      ],
                    ),
                    if (!_isInspectionConfirmed)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Checklist inspeksi dulu untuk membuka input QC, foto, dan approve.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _cameraBox(1, _image1)),
                        const SizedBox(width: 8),
                        Expanded(child: _cameraBox(2, _image2)),
                        const SizedBox(width: 8),
                        Expanded(child: _cameraBox(3, _image3)),
                        const SizedBox(width: 8),
                        Expanded(child: _cameraBox(4, _image4)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _button(
                    'Approve',
                    Colors.green,
                    _confirmApprove,
                    enabled: _canEditQcData,
                  ),
                ],
              ),
            ],
          ),
          if (_isSubmitting || _isLoadingDetail)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      _isLoadingDetail ? 'Memuat detail sales lab...' : 'Menyimpan data...',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _readonlyBox(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.black54),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _plateWidget(String plate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plat Kendaraan', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            plate,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        enabled: _canEditQcData,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        enabled: _canEditQcData,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _cameraBox(int index, File? file) {
    return GestureDetector(
      onTap: _isCameraEnabled && _canEditQcData ? () => _getImage(index) : null,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(8),
            color: _isCameraEnabled && _canEditQcData ? Colors.white : Colors.grey.shade400,
          ),
          child: file == null
              ? const Icon(Icons.camera_alt)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(file, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }

  Widget _button(
    String label,
    Color color,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
      ),
      onPressed: _isSubmitting || _isLoadingDetail || !enabled ? null : onPressed,
      child: Text(label),
    );
  }
}