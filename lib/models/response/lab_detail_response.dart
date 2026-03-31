import 'package:json_annotation/json_annotation.dart';
part 'lab_detail_response.g.dart';

@JsonSerializable()
class LabDetailResponse {
  final bool success;
  final String? message;
  final LabDetailData? data;

  LabDetailResponse({required this.success, this.message, this.data});

  factory LabDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$LabDetailResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LabDetailResponseToJson(this);
}

@JsonSerializable()
class LabDetailData {
  final String? ffa;
  final String? moisture;
  final String? dobi;
  final String? iv;
  final String? remarks;
  final String? status;

  @JsonKey(name: "tested_at")
  final String? testedAt;

  @JsonKey(name: "tested_by")
  final String? testedBy;

  final List<LabPhoto>? photos;

  LabDetailData({
    this.ffa,
    this.moisture,
    this.dobi,
    this.iv,
    this.remarks,
    this.status,
    this.testedAt,
    this.testedBy,
    this.photos,
  });

  factory LabDetailData.fromJson(Map<String, dynamic> json) =>
      _$LabDetailDataFromJson(json);
  Map<String, dynamic> toJson() => _$LabDetailDataToJson(this);
}

@JsonSerializable()
class LabPhoto {
  @JsonKey(name: 'photo_id')
  final String? photoId;
  final int? sequence;
  final String? path;
  final String? url;

  LabPhoto({
    this.photoId,
    this.sequence,
    this.path,
    this.url,
  });

  factory LabPhoto.fromJson(Map<String, dynamic> json) =>
      _$LabPhotoFromJson(json);

  Map<String, dynamic> toJson() => _$LabPhotoToJson(this);
}
