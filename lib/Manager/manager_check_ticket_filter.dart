import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/models/manager/manager_check_ticket.dart';

String normalizeManagerCheckStage(String? stage) {
  return (stage ?? '').trim().toLowerCase();
}

String normalizeManagerCheckStatus(String? status) {
  final normalized = (status ?? '').trim().toUpperCase();
  if (normalized == 'APPROVED') return 'APPROVE';
  if (normalized == 'REJECTED') return 'REJECT';
  if (normalized == 'CANCELED' || normalized == 'CANCELLED') return 'CANCEL';
  return normalized;
}

String? resolveManagerTicketIdentifier(ManagerCheckTicket ticket) {
  final registrationId = ticket.registration_id?.trim();
  if (registrationId != null && registrationId.isNotEmpty) {
    return registrationId;
  }

  final wbTicketNo = ticket.wb_ticket_no?.trim();
  if (wbTicketNo != null && wbTicketNo.isNotEmpty) {
    return wbTicketNo;
  }

  final processId = ticket.process_id?.trim();
  if (processId != null && processId.isNotEmpty) {
    return processId;
  }

  return null;
}

String _normalizeStatusToken(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
}

bool isRejectedOperatorStatus(String? status) {
  final normalized = _normalizeStatusToken(status);
  if (normalized.isEmpty) return false;

  // Common positive cases from backend naming conventions.
  if (normalized.contains('reject') || normalized.contains('cancel')) {
    return true;
  }

  return false;
}

bool _hasRejectedStatusInMap(Map<String, dynamic>? source) {
  if (source == null || source.isEmpty) return false;

  for (final entry in source.entries) {
    final key = entry.key.toLowerCase();
    if (!key.contains('status')) continue;

    if (isRejectedOperatorStatus(entry.value?.toString())) {
      return true;
    }
  }

  return false;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return null;
}

bool _hasRejectedStatusInRecords(List<Map<String, dynamic>>? records) {
  if (records == null || records.isEmpty) return false;

  for (final record in records) {
    if (_hasRejectedStatusInMap(record)) return true;
  }

  return false;
}

bool _hasRejectedStatusInPkCycleRecords(
  List<Map<String, dynamic>>? records,
  String stage,
) {
  if (records == null || records.isEmpty) return false;

  for (final record in records) {
    if (stage == 'lab') {
      final hasRootLabReject = isRejectedOperatorStatus(
        record['lab_status']?.toString(),
      );
      if (hasRootLabReject) return true;

      final labSection =
          _asMap(record['lab']) ??
          _asMap(record['lab_data']) ??
          _asMap(record['lab_record']);
      if (_hasRejectedStatusInMap(labSection)) return true;
      continue;
    }

    if (stage == 'unloading') {
      final hasRootUnloadingReject = isRejectedOperatorStatus(
        record['unloading_status']?.toString(),
      );
      if (hasRootUnloadingReject) return true;

      final unloadingSection =
          _asMap(record['unloading']) ??
          _asMap(record['unloading_data']) ??
          _asMap(record['unloading_record']);
      if (_hasRejectedStatusInMap(unloadingSection)) return true;
      continue;
    }

    if (_hasRejectedStatusInMap(record)) return true;
  }

  return false;
}

bool _isRejectedRegistStatusForStage({
  required String normalizedStage,
  required String registStatus,
}) {
  if (!isRejectedOperatorStatus(registStatus)) return false;

  if (normalizedStage == 'lab') {
    return registStatus.contains('lab') ||
        registStatus.contains('relab') ||
        registStatus.contains('resampling');
  }

  if (normalizedStage == 'unloading') {
    return registStatus.contains('unloading') ||
        registStatus.contains('reunloading') ||
        registStatus.contains('re_unloading');
  }

  return true;
}

bool _isRejectedStageTokenForStage({
  required String normalizedStage,
  required String token,
}) {
  if (!isRejectedOperatorStatus(token)) return false;

  if (normalizedStage == 'lab') {
    return token.contains('lab') ||
        token.contains('relab') ||
        token.contains('resampling');
  }

  if (normalizedStage == 'unloading') {
    return token.contains('unloading') ||
        token.contains('reunloading') ||
        token.contains('re_unloading');
  }

  return true;
}

bool isRejectedOperatorTicketHintForStage({
  required String stage,
  required ManagerCheckTicket ticket,
}) {
  final normalizedStage = normalizeManagerCheckStage(stage);

  final registStatus = _normalizeStatusToken(ticket.regist_status);
  if (_isRejectedStageTokenForStage(
    normalizedStage: normalizedStage,
    token: registStatus,
  )) {
    return true;
  }

  final currentStage = _normalizeStatusToken(ticket.current_stage);
  if (_isRejectedStageTokenForStage(
    normalizedStage: normalizedStage,
    token: currentStage,
  )) {
    return true;
  }

  final latestStatus = _normalizeStatusToken(ticket.latest_check_status);
  if (_isRejectedStageTokenForStage(
    normalizedStage: normalizedStage,
    token: latestStatus,
  )) {
    return true;
  }

  return false;
}

bool isRejectedOperatorDetailForStage({
  required String stage,
  required dynamic detail,
}) {
  final normalizedStage = normalizeManagerCheckStage(stage);
  final registStatus = _normalizeStatusToken(detail?.regist_status?.toString());

  // Rejection should be routed to the originating stage.
  if (_isRejectedRegistStatusForStage(
    normalizedStage: normalizedStage,
    registStatus: registStatus,
  )) {
    return true;
  }

  if (normalizedStage == 'lab') {
    if (_hasRejectedStatusInMap(detail?.lab_data as Map<String, dynamic>?)) {
      return true;
    }

    if (_hasRejectedStatusInRecords(
      detail?.lab_records as List<Map<String, dynamic>>?,
    )) {
      return true;
    }

    if (_hasRejectedStatusInPkCycleRecords(
      detail?.pk_cycle_records as List<Map<String, dynamic>>?,
      normalizedStage,
    )) {
      return true;
    }

    return false;
  }

  if (normalizedStage == 'unloading') {
    if (_hasRejectedStatusInMap(
      detail?.unloading_data as Map<String, dynamic>?,
    )) {
      return true;
    }

    if (_hasRejectedStatusInPkCycleRecords(
      detail?.pk_cycle_records as List<Map<String, dynamic>>?,
      normalizedStage,
    )) {
      return true;
    }

    return false;
  }

  return false;
}

bool hasFinalManagerDecisionForStage({
  required String stage,
  required dynamic detail,
}) {
  final finalStatus = resolveFinalManagerDecisionForStage(
    stage: stage,
    detail: detail,
  );
  return finalStatus == 'APPROVE' ||
      finalStatus == 'REJECT' ||
      finalStatus == 'CANCEL';
}

String resolveFinalManagerDecisionForStage({
  required String stage,
  required dynamic detail,
}) {
  final normalizedStage = normalizeManagerCheckStage(stage);
  final managerChecks = detail?.manager_checks;
  if (managerChecks is! List || managerChecks.isEmpty) {
    return '';
  }

  String resolved = '';
  for (final check in managerChecks) {
    final dynamic entry = check;
    final checkStage = normalizeManagerCheckStage(entry?.stage?.toString());
    if (checkStage.isNotEmpty && checkStage != normalizedStage) {
      continue;
    }

    final normalizedStatus = normalizeManagerCheckStatus(
      entry?.check_status?.toString(),
    );
    if (normalizedStatus == 'APPROVE' ||
        normalizedStatus == 'REJECT' ||
        normalizedStatus == 'CANCEL') {
      resolved = normalizedStatus;
    }
  }

  return resolved;
}

bool isPendingManagerCheckTicket(ManagerCheckTicket ticket) {
  final latestStatus = normalizeManagerCheckStatus(ticket.latest_check_status);

  if (latestStatus == 'PENDING') return true;
  if (latestStatus == 'APPROVE' ||
      latestStatus == 'REJECT' ||
      latestStatus == 'CANCEL') {
    return false;
  }

  if (ticket.has_manager_check == true) return false;
  if (ticket.has_manager_check == false) return true;

  // Fallback for payloads that only expose has_manager_check.
  return latestStatus.isEmpty;
}

String resolveLatestManagerCheckStatus(ManagerCheckTicket ticket) {
  final stageScopedStatus = normalizeManagerCheckStatus(
    ticket.latest_check_status,
  );
  if (stageScopedStatus.isNotEmpty) {
    return stageScopedStatus;
  }

  final hasStageManagerCheck =
      ticket.has_manager_check == true ||
      (ticket.manager_checks_count ?? 0) > 0;
  if (!hasStageManagerCheck) {
    return '';
  }

  return normalizeManagerCheckStatus(
    ticket.latest_manager_check_status_overall,
  );
}

bool hasFinalManagerDecisionOnTicket(ManagerCheckTicket ticket) {
  final latestStatus = resolveLatestManagerCheckStatus(ticket);
  return latestStatus == 'APPROVE' ||
      latestStatus == 'REJECT' ||
      latestStatus == 'CANCEL';
}

bool isRejectedTicketCancelledByManager(ManagerCheckTicket ticket) {
  final latestStatus = resolveLatestManagerCheckStatus(ticket);
  if (latestStatus == 'REJECT' || latestStatus == 'CANCEL') {
    return true;
  }

  final registStatus = _normalizeStatusToken(ticket.regist_status);
  final stageStatus = _normalizeStatusToken(ticket.latest_check_status);
  final overallStatus = _normalizeStatusToken(
    ticket.latest_manager_check_status_overall,
  );

  return registStatus.contains('cancel') ||
      stageStatus.contains('cancel') ||
      overallStatus.contains('cancel');
}

int countActionableRejectedOperatorTickets(List<ManagerCheckTicket> tickets) {
  return tickets.where((ticket) {
    if (hasFinalManagerDecisionOnTicket(ticket)) {
      return false;
    }

    if (isRejectedTicketCancelledByManager(ticket)) {
      return false;
    }

    return true;
  }).length;
}

bool isManagerTicketForStage(ManagerCheckTicket ticket, String stage) {
  final targetStage = normalizeManagerCheckStage(stage);
  final currentStage = _normalizeStatusToken(ticket.current_stage);

  // Keep compatibility for payloads without current_stage.
  if (currentStage.isEmpty) return true;

  if (currentStage == _normalizeStatusToken(targetStage)) return true;

  // PK relab/reunloading can surface with stage aliases.
  if (targetStage == 'lab') {
    return currentStage.contains('lab') ||
        currentStage.contains('relab') ||
        currentStage.contains('resampling');
  }

  if (targetStage == 'unloading') {
    return currentStage.contains('unloading') ||
        currentStage.contains('re_unloading') ||
        currentStage.contains('reunloading');
  }

  if (targetStage == 'sampling') {
    return currentStage.contains('sampling');
  }

  return false;
}

bool _matchesStageToken(String? stageToken, String stage) {
  final normalizedStage = normalizeManagerCheckStage(stage);
  final token = _normalizeStatusToken(stageToken);
  if (token.isEmpty) return false;

  if (token == _normalizeStatusToken(normalizedStage)) return true;

  if (normalizedStage == 'lab') {
    return token.contains('lab') ||
        token.contains('relab') ||
        token.contains('resampling');
  }

  if (normalizedStage == 'unloading') {
    return token.contains('unloading') ||
        token.contains('re_unloading') ||
        token.contains('reunloading');
  }

  if (normalizedStage == 'sampling') {
    return token.contains('sampling');
  }

  return false;
}

bool _matchesStageByDetail({
  required String stage,
  required ManagerCheckTicket ticket,
  dynamic detail,
}) {
  final stageSignals = <String?>[
    detail?.requested_stage?.toString(),
    detail?.current_stage?.toString(),
    ticket.current_stage,
  ];

  final hasAnyStageSignal = stageSignals.any(
    (token) => _normalizeStatusToken(token).isNotEmpty,
  );

  if (!hasAnyStageSignal) {
    // Strict mode for random-check queue: no stage signal means unknown stage,
    // so skip to avoid leaking tickets into wrong manager stage pages.
    return false;
  }

  for (final token in stageSignals) {
    if (_matchesStageToken(token, stage)) {
      return true;
    }
  }

  return false;
}

bool _isPkCycleAliasStageToken(String? stageToken, String stage) {
  final token = _normalizeStatusToken(stageToken);
  if (token.isEmpty) return false;

  final normalizedStage = normalizeManagerCheckStage(stage);

  if (normalizedStage == 'lab') {
    return token.contains('relab') || token.contains('resampling');
  }

  if (normalizedStage == 'unloading') {
    return token.contains('reunloading') || token.contains('re_unloading');
  }

  return false;
}

bool isPkCycleAliasTicketForStage({
  required ManagerCheckTicket ticket,
  required String stage,
  dynamic detail,
}) {
  final stageTokens = <String?>[
    ticket.current_stage,
    detail?.current_stage?.toString(),
    detail?.requested_stage?.toString(),
  ];

  for (final stageToken in stageTokens) {
    if (_isPkCycleAliasStageToken(stageToken, stage)) {
      return true;
    }
  }

  return false;
}

List<ManagerCheckTicket> filterPendingManagerTicketsByStage(
  List<ManagerCheckTicket> tickets,
  String stage,
) {
  return tickets
      .where(
        (ticket) =>
            isPendingManagerCheckTicket(ticket) &&
            isManagerTicketForStage(ticket, stage),
      )
      .toList();
}

int countPendingManagerTicketsByStage(
  List<ManagerCheckTicket>? tickets,
  String stage,
) {
  if (tickets == null || tickets.isEmpty) return 0;
  return filterPendingManagerTicketsByStage(tickets, stage).length;
}

List<ManagerCheckTicket> dedupeManagerCheckTickets(
  List<ManagerCheckTicket> source,
) {
  final Map<String, ManagerCheckTicket> map = {};

  String keyOf(ManagerCheckTicket ticket) {
    final identifier = resolveManagerTicketIdentifier(ticket);
    if (identifier != null && identifier.isNotEmpty) return identifier;
    return '${ticket.wb_ticket_no ?? '-'}|${ticket.plate_number ?? '-'}';
  }

  int priorityOf(ManagerCheckTicket ticket) {
    final latest = normalizeManagerCheckStatus(ticket.latest_check_status);
    if (latest == 'PENDING') return 3;
    if (latest == 'APPROVE' || latest == 'REJECT') return 2;
    if (ticket.has_manager_check == true) return 1;
    return 0;
  }

  for (final ticket in source) {
    final key = keyOf(ticket);
    final current = map[key];
    if (current == null || priorityOf(ticket) > priorityOf(current)) {
      map[key] = ticket;
    }
  }

  return map.values.toList();
}

List<ManagerCheckTicket> dedupeManagerCheckTicketsByEntry(
  List<ManagerCheckTicket> source,
) {
  final seen = <String>{};
  final result = <ManagerCheckTicket>[];

  for (final ticket in source) {
    final key =
        resolveManagerTicketIdentifier(ticket) ??
        '${ticket.wb_ticket_no ?? '-'}|${ticket.plate_number ?? '-'}';

    if (seen.add(key)) {
      result.add(ticket);
    }
  }

  return result;
}

List<ManagerCheckTicket> filterRejectedCandidatesByStage(
  List<ManagerCheckTicket> tickets,
  String stage,
) {
  // Do not pre-filter by stage token or latest_check_status here.
  // Backend can emit stage aliases that do not always map 1:1 to the
  // requested stage (especially PK relab/reunloading transitions).
  // Stage validation is done later through detail/hint checks.
  return List<ManagerCheckTicket>.from(tickets);
}

bool _isPkCommodityTicket({
  required ManagerCheckTicket ticket,
  dynamic detail,
}) {
  final ticketCommodity = (ticket.commodity_type ?? '').trim().toUpperCase();
  final detailCommodity = (detail?.commodity_type?.toString() ?? '')
      .trim()
      .toUpperCase();
  return ticketCommodity == 'PK' || detailCommodity == 'PK';
}

Future<List<ManagerCheckTicket>> filterRandomCheckTicketsByStage({
  required ApiService api,
  required String authorizationToken,
  required String stage,
  required List<ManagerCheckTicket> tickets,
}) async {
  final normalizedStage = normalizeManagerCheckStage(stage);
  final token = authorizationToken.trim().startsWith('Bearer ')
      ? authorizationToken.trim()
      : 'Bearer ${authorizationToken.trim()}';

  final candidates = dedupeManagerCheckTickets(
    tickets.where((ticket) => isPendingManagerCheckTicket(ticket)).toList(),
  );

  final resolved = await Future.wait(
    candidates.map((ticket) async {
      final identifier = resolveManagerTicketIdentifier(ticket);
      if (identifier == null || identifier.isEmpty) return null;

      try {
        final detail = await api.getManagerCheckTicketDetail(
          token,
          identifier,
          normalizedStage,
        );

        if (!_matchesStageByDetail(
          stage: normalizedStage,
          ticket: ticket,
          detail: detail.data,
        )) {
          return null;
        }

        final registStatus = (detail.data?.regist_status ?? '')
            .trim()
            .toLowerCase();
        if (registStatus == 'random_check') {
          return ticket;
        }
      } catch (_) {
        // Intentionally ignore detail failures to avoid showing false positives.
      }

      return null;
    }),
  );

  return resolved.whereType<ManagerCheckTicket>().toList();
}

Future<List<ManagerCheckTicket>> filterRejectedOperatorTicketsByStage({
  required ApiService api,
  required String authorizationToken,
  required String stage,
  required List<ManagerCheckTicket> tickets,
}) async {
  final normalizedStage = normalizeManagerCheckStage(stage);
  final token = authorizationToken.trim().startsWith('Bearer ')
      ? authorizationToken.trim()
      : 'Bearer ${authorizationToken.trim()}';

  final candidates = dedupeManagerCheckTicketsByEntry(
    filterRejectedCandidatesByStage(tickets, normalizedStage),
  );

  final resolved = await Future.wait(
    candidates.map((ticket) async {
      final identifier = resolveManagerTicketIdentifier(ticket);
      if (identifier == null || identifier.isEmpty) return null;

      try {
        final detail = await api.getManagerCheckTicketDetail(
          token,
          identifier,
          normalizedStage,
        );
        final isPkCommodity = _isPkCommodityTicket(
          ticket: ticket,
          detail: detail.data,
        );

        final isPkCycleAlias = isPkCycleAliasTicketForStage(
          ticket: ticket,
          stage: normalizedStage,
          detail: detail.data,
        );

        if (isRejectedOperatorDetailForStage(
          stage: normalizedStage,
          detail: detail.data,
        )) {
          // Do not use broad stage-level final-decision guard for PK relab /
          // reunloading aliases, because previous cycle checks can be present
          // and should not hide current rejected cycles.
          if (!isPkCommodity && !isPkCycleAlias) {
            final finalDecision = resolveFinalManagerDecisionForStage(
              stage: normalizedStage,
              detail: detail.data,
            );

            // Keep canceled tickets visible in rejected list history,
            // but remove manager-approved tickets from rejected queue/list.
            if (finalDecision == 'APPROVE') {
              return null;
            }
          }

          return ticket;
        }

        // Fallback for payload variants where rejected state is reflected
        // in ticket stage token but not surfaced in detail fields yet.
        if (isRejectedOperatorTicketHintForStage(
          stage: normalizedStage,
          ticket: ticket,
        )) {
          return ticket;
        }
      } catch (_) {
        // When detail endpoint fails for rejected stage (e.g. relab/reunloading
        // transition), rely on ticket stage hints so manager queue is not empty.
        if (isRejectedOperatorTicketHintForStage(
          stage: normalizedStage,
          ticket: ticket,
        )) {
          return ticket;
        }

        // For PK relab/reunloading aliases, the detail endpoint can be delayed
        // while ticket list already reflects the stage. Keep candidate so the
        // manager still sees rejected cycles.
        if (isPkCycleAliasTicketForStage(
          ticket: ticket,
          stage: normalizedStage,
        )) {
          return ticket;
        }
      }

      return null;
    }),
  );

  return resolved.whereType<ManagerCheckTicket>().toList();
}
