import 'package:json_annotation/json_annotation.dart';

part 'unloading_cpo_detail_response.g.dart';

// Helper function to parse int from String or int
int? _parseIntFromDynamic(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

@JsonSerializable()
class UnloadingCpoDetailResponse {
  final bool success;
  final String message;
  final UnloadingCpoDetail? data;

  UnloadingCpoDetailResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory UnloadingCpoDetailResponse.fromJson(Map<String, dynamic> json)
      => _$UnloadingCpoDetailResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UnloadingCpoDetailResponseToJson(this);
}

@JsonSerializable()
class UnloadingCpoDetail {
  @JsonKey(name: "tank_id", fromJson: _parseIntFromDynamic)
  final int? tankId;

  @JsonKey(name: "hole_id", fromJson: _parseIntFromDynamic)
  final int? holeId;

  final String? remarks;

  final List<UnloadingPhoto>? photos;

  UnloadingCpoDetail({
    this.tankId,
    this.holeId,
    this.remarks,
    this.photos,
  });

  factory UnloadingCpoDetail.fromJson(Map<String, dynamic> json)
      => _$UnloadingCpoDetailFromJson(json);

  Map<String, dynamic> toJson() => _$UnloadingCpoDetailToJson(this);
}

@JsonSerializable()
class UnloadingPhoto {
  final String? url;
  final String? path;

  UnloadingPhoto({
    this.url,
    this.path,
  });

  factory UnloadingPhoto.fromJson(Map<String, dynamic> json)
      => _$UnloadingPhotoFromJson(json);

  Map<String, dynamic> toJson() => _$UnloadingPhotoToJson(this);
}
