import 'package:json_annotation/json_annotation.dart';
import '../manager_check_ticket.dart';

part 'manager_check_tickets_response.g.dart';

@JsonSerializable()
class ManagerCheckTicketsResponse {
  final bool? success;
  final String? message;
  final List<ManagerCheckTicket>? data;
  @JsonKey(fromJson: _toInt)
  final int? total;

  ManagerCheckTicketsResponse({
    this.success,
    this.message,
    this.data,
    this.total,
  });

  factory ManagerCheckTicketsResponse.fromJson(Map<String, dynamic> json) =>
      _$ManagerCheckTicketsResponseFromJson(json);

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
