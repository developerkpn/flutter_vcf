import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_vcf/config.dart';

List<String> extractOperatorPhotoSources(List<dynamic> roots) {
  final photos = <String>{};

  for (final root in roots) {
    _collectPhotoSources(root, photos, null);
  }

  return photos.toList();
}

void _collectPhotoSources(
  dynamic value,
  Set<String> collector,
  String? parentKey,
) {
  if (value == null) return;

  if (value is Map) {
    value.forEach((key, val) {
      _collectPhotoSources(val, collector, key.toString());
    });
    return;
  }

  if (value is List) {
    for (final item in value) {
      _collectPhotoSources(item, collector, parentKey);
    }
    return;
  }

  if (value is! String) return;

  final normalizedKey = (parentKey ?? '').trim().toLowerCase();
  final source = value.trim();
  if (source.isEmpty || source == '-') return;

  if (_isPhotoKey(normalizedKey) || _looksLikeImageSource(source)) {
    collector.add(source);
  }
}

bool _isPhotoKey(String key) {
  const photoKeys = {
    'photos',
    'photo',
    'photo_data',
    'photo_url',
    'photo_path',
    'url',
    'path',
    'image',
    'image_url',
    'image_path',
    'images',
    'attachments',
    'files',
  };

  if (photoKeys.contains(key)) return true;

  return key.contains('photo') || key.contains('image');
}

bool _looksLikeImageSource(String value) {
  final lower = value.toLowerCase();

  if (lower.startsWith('data:image/')) return true;
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('/photo') ||
        lower.contains('/image') ||
        lower.contains('/upload');
  }

  return false;
}

class OperatorPhotoPreviewSection extends StatelessWidget {
  final List<String> photoSources;
  final String title;

  const OperatorPhotoPreviewSection({
    super.key,
    required this.photoSources,
    this.title = 'Operator Photos',
  });

  @override
  Widget build(BuildContext context) {
    if (photoSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: photoSources
                    .map(
                      (source) => Container(
                        width: 70,
                        height: 100,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _OperatorReadonlyPhoto(source: source),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorReadonlyPhoto extends StatelessWidget {
  final String source;

  const _OperatorReadonlyPhoto({required this.source});

  @override
  Widget build(BuildContext context) {
    final raw = source.trim();

    if (raw.toLowerCase().startsWith('data:image/')) {
      final bytes = _decodeDataUri(raw);
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
    }

    final imageUrl = _resolveImageUrl(raw);

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.black38),
        );
      },
    );
  }

  Uint8List? _decodeDataUri(String value) {
    try {
      final parts = value.split(',');
      final payload = parts.length > 1 ? parts.last : value;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  String _resolveImageUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return value;
    }

    try {
      final base = Uri.parse(AppConfig.apiBaseUrl);
      return base.resolve(value).toString();
    } catch (_) {
      return value;
    }
  }
}
