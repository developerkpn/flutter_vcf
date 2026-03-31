// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lab_detail_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LabDetailResponse _$LabDetailResponseFromJson(Map<String, dynamic> json) =>
    LabDetailResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: json['data'] == null
          ? null
          : LabDetailData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LabDetailResponseToJson(LabDetailResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

LabDetailData _$LabDetailDataFromJson(Map<String, dynamic> json) =>
    LabDetailData(
      ffa: json['ffa'] as String?,
      moisture: json['moisture'] as String?,
      dobi: json['dobi'] as String?,
      iv: json['iv'] as String?,
      remarks: json['remarks'] as String?,
      status: json['status'] as String?,
      testedAt: json['tested_at'] as String?,
      testedBy: json['tested_by'] as String?,
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => LabPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LabDetailDataToJson(LabDetailData instance) =>
    <String, dynamic>{
      'ffa': instance.ffa,
      'moisture': instance.moisture,
      'dobi': instance.dobi,
      'iv': instance.iv,
      'remarks': instance.remarks,
      'status': instance.status,
      'tested_at': instance.testedAt,
      'tested_by': instance.testedBy,
      'photos': instance.photos,
    };

LabPhoto _$LabPhotoFromJson(Map<String, dynamic> json) => LabPhoto(
  photoId: json['photo_id'] as String?,
  sequence: (json['sequence'] as num?)?.toInt(),
  path: json['path'] as String?,
  url: json['url'] as String?,
);

Map<String, dynamic> _$LabPhotoToJson(LabPhoto instance) => <String, dynamic>{
  'photo_id': instance.photoId,
  'sequence': instance.sequence,
  'path': instance.path,
  'url': instance.url,
};
