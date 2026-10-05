import '../engine/engine.dart';

/// Plain-language failure explanation built only from visible state, with no
/// jargon required (MAS-BR-003, MAS-BR-012).
String explainFailure(Failure f, Ruleset rules) {
  final who = 'Request #${f.requestId}';
  switch (f.kind) {
    case FailureKind.capacity:
      return '$who needed ${f.requestSize} cells, but only ${f.freeCells} '
          'were free. Memory was simply full.';
    case FailureKind.fragmentation:
      return '$who needed ${f.requestSize} cells in a row. ${f.freeCells} '
          'cells were free, but the biggest gap was only '
          '${f.largestFreeBlock}. The free space was split into pieces '
          '(fragmentation).';
    case FailureKind.deadline:
      return '$who ran out of time. A gap big enough was free, but it was '
          'not placed before its deadline.';
    case FailureKind.rule:
      return 'The waiting list was full (${rules.maxQueue}), so '
          '$who was turned away.';
  }
}

/// Why a tap on a cell did not place the selected request.
String explainPlacementError(
  PlacementError error, {
  required int requestSize,
  required int cellCount,
  int? blockedBy,
  int? linkedTo,
}) {
  switch (error) {
    case PlacementError.outOfBounds:
      return 'It needs $requestSize cells in a row, but that runs past the '
          'end of memory ($cellCount cells).';
    case PlacementError.occupied:
      if (blockedBy != null && blockedBy < 0) {
        return 'Those cells are locked or held for another request. A '
            'request needs $requestSize free cells in a row.';
      }
      return 'Process #$blockedBy is in the way. A request needs '
          '$requestSize free cells in a row.';
    case PlacementError.notAdjacent:
      return 'A linked pair has to sit side by side. Place it directly '
          'above or below #$linkedTo.';
    case PlacementError.unknownRequest:
      return 'That request is no longer waiting.';
    case PlacementError.notPlaying:
      return 'The run is over.';
  }
}

String explainCompactionError(CompactionError error) {
  switch (error) {
    case CompactionError.noChargesLeft:
      return 'No compactions left this run.';
    case CompactionError.nothingToMove:
      return 'Nothing to compact: everything is already packed.';
    case CompactionError.notPlaying:
      return 'The run is over.';
  }
}

String explainActionError(ActionError error) {
  switch (error) {
    case ActionError.notPlaying:
      return 'The run is over.';
    case ActionError.unknownTarget:
      return 'That is no longer there.';
    case ActionError.notALeak:
      return 'Only a leaking process can be cleaned up.';
    case ActionError.unavailable:
      return 'Not available right now.';
    case ActionError.alreadyReserved:
      return 'A region is already reserved. Wait for it to be used or expire.';
    case ActionError.regionBusy:
      return 'Every cell in a reservation has to be free.';
    case ActionError.outOfBounds:
      return 'That region runs past the end of memory.';
  }
}

/// The consequence of the latest fault on the system, in plain words.
String explainHeat(int heat, Ruleset rules) {
  if (heat <= 0) return '';
  final parts = <String>[
    'New requests wait ${rules.heatDeadlinePenalty} '
        '${rules.heatDeadlinePenalty == 1 ? 'tick' : 'ticks'} less.',
  ];
  if (heat >= rules.heatQuarantineAt) {
    parts.add('A cell was locked for ${rules.quarantineTicks} ticks.');
  }
  return 'System heat $heat. ${parts.join(' ')} Clear a wave cleanly to cool '
      'it.';
}

String waveLabel(WaveInfo w) {
  switch (w.phase) {
    case WavePhase.calm:
      return 'Wave ${w.number}: normal traffic';
    case WavePhase.warning:
      return 'Wave ${w.number} storm in ${w.ticksToStorm}';
    case WavePhase.storm:
      return 'STORM ${w.number}: ${w.ticksLeftInStorm} '
          '${w.ticksLeftInStorm == 1 ? 'tick' : 'ticks'} left';
    case WavePhase.recovery:
      return 'Recovery: no arrivals';
  }
}

/// A short plain-language tag for a request family, or null for standard.
String? familyTag(Request r) {
  switch (r.family) {
    case RequestFamily.standard:
      return null;
    case RequestFamily.burst:
      return 'burst';
    case RequestFamily.resident:
      return 'resident';
    case RequestFamily.priority:
      return 'priority ×2';
    case RequestFamily.volatile:
      return 'volatile';
    case RequestFamily.pinned:
      return 'pinned';
    case RequestFamily.linked:
      return r.linkedWith == null
          ? 'linked: partner next'
          : 'linked to #${r.linkedWith}';
    case RequestFamily.leak:
      return 'leaks';
  }
}

/// How a request's lifetime reads: exact, or a range for volatile ones.
String lifetimeText(Request r) => r.lifetimeMin != null
    ? 'lives ${r.lifetimeMin}–${r.lifetimeMax}'
    : 'lives ${r.lifetime}';
