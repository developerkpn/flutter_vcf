// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manager_check_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagerCheckDetail _$ManagerCheckDetailFromJson(Map<String, dynamic> json) =>
    ManagerCheckDetail(
      registration_id: json['registration_id'] as String?,
      wb_ticket_no: json['wb_ticket_no'] as String?,
      plate_number: json['plate_number'] as String?,
      driver_name: json['driver_name'] as String?,
      vendor_name: json['vendor_name'] as String?,
      commodity_type: json['commodity_type'] as String?,
      regist_status: json['regist_status'] as String?,
      requested_stage: json['requested_stage'] as String?,
      current_stage: json['current_stage'] as String?,
      sampling_data: json['sampling_data'] as Map<String, dynamic>?,
      sampling_records: (json['sampling_records'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      lab_data: json['lab_data'] as Map<String, dynamic>?,
      lab_records: (json['lab_records'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      unloading_data: json['unloading_data'] as Map<String, dynamic>?,
      pk_cycle_records: (json['pk_cycle_records'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      manager_checks: (json['manager_checks'] as List<dynamic>?)
          ?.map((e) => ManagerCheck.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ManagerCheckDetailToJson(ManagerCheckDetail instance) =>
    <String, dynamic>{
      'registration_id': instance.registration_id,
      'wb_ticket_no': instance.wb_ticket_no,
      'plate_number': instance.plate_number,
      'driver_name': instance.driver_name,
      'vendor_name': instance.vendor_name,
      'commodity_type': instance.commodity_type,
      'regist_status': instance.regist_status,
      'requested_stage': instance.requested_stage,
      'current_stage': instance.current_stage,
      'sampling_data': instance.sampling_data,
      'sampling_records': instance.sampling_records,
      'lab_data': instance.lab_data,
      'lab_records': instance.lab_records,
      'unloading_data': instance.unloading_data,
      'pk_cycle_records': instance.pk_cycle_records,
      'manager_checks': instance.manager_checks,
    };
