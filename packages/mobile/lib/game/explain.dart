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
      return 'More than ${rules.maxQueue} requests were waiting at once.';
  }
}

/// Why a tap on a cell did not place the selected request.
String explainPlacementError(
  PlacementError error, {
  required int requestSize,
  required int cellCount,
  int? blockedBy,
}) {
  switch (error) {
    case PlacementError.outOfBounds:
      return 'It needs $requestSize cells in a row, but that runs past the '
          'end of memory ($cellCount cells).';
    case PlacementError.occupied:
      return 'Process #$blockedBy is in the way. A request needs '
          '$requestSize free cells in a row.';
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
