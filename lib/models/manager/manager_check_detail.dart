import 'package:json_annotation/json_annotation.dart';
import 'manager_check.dart';

part 'manager_check_detail.g.dart';

@JsonSerializable()
class ManagerCheckDetail {
  final String? registration_id;
  final String? wb_ticket_no;
  final String? plate_number;
  final String? driver_name;
  final String? vendor_name;
  final String? commodity_type;
  final String? regist_status;
  final String? requested_stage;
  final String? current_stage;
  final Map<String, dynamic>? sampling_data;
  final List<Map<String, dynamic>>? sampling_records;
  final Map<String, dynamic>? lab_data;
  final List<Map<String, dynamic>>? lab_records;
  final Map<String, dynamic>? unloading_data;
  final List<Map<String, dynamic>>? pk_cycle_records;
  final List<ManagerCheck>? manager_checks;

  ManagerCheckDetail({
    this.registration_id,
    this.wb_ticket_no,
    this.plate_number,
    this.driver_name,
    this.vendor_name,
    this.commodity_type,
    this.regist_status,
    this.requested_stage,
    this.current_stage,
    this.sampling_data,
    this.sampling_records,
    this.lab_data,
    this.lab_records,
    this.unloading_data,
    this.pk_cycle_records,
    this.manager_checks,
  });

  factory ManagerCheckDetail.fromJson(Map<String, dynamic> json) =>
      _$ManagerCheckDetailFromJson(json);
  Map<String, dynamic> toJson() => _$ManagerCheckDetailToJson(this);
}
