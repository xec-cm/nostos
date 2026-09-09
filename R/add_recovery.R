#' Attach episode outcomes under an explicit observed recovery rule
#'
#' Identify an observed return after a detected deviation and its confirmation
#' by later visits, using the fixed deviations from [add_deviation()]. Store the
#' rule, episode outcomes, supporting identities and dependency fingerprints.
#'
#' @param tse A TreeSummarizedExperiment with supported registration, reference
#'   and deviation stages. Their required dependencies must remain available and
#'   unchanged. Current sample identities must equal the realized deviation scope;
#'   reordering and removal of unselected original features are allowed.
#' @param analysis_id The name of the existing analysis, with no recovery stage.
#' @param rule A plain named list containing exactly `threshold` (in `[0, 1]`),
#'   `persistence`, `max_gap` and `horizon` (strictly positive). Each is an ordinary
#'   finite integer/double scalar. Durations use the registered time unit. There
#'   are no defaults; choose and justify the rule before inspecting outcomes.
#'
#' @details
#' Visits group included samples at exactly equal registered times. A visit is
#' within the threshold only when all its deviations are <= threshold. Detection
#' starts at the origin event's start; return and confirmation start at the
#' selected origin boundary. Both windows end at the inclusive horizon.
#'
#' A return must follow a detected outside visit strictly. Confirmation is the
#' first observation in a within-band run spanning at least persistence, with
#' consecutive gaps <= max_gap. Outside observations and larger gaps break runs.
#' The first confirmed run is retained; a later outside observation through the
#' horizon records a rebound without erasing confirmation. Simultaneous samples
#' cannot establish persistence. No time is rounded or interpolated.
#'
#' Episodes without a baseline are not evaluable. Otherwise any other registered
#' event of the same subject overlapping the closed interval from the origin
#' event's start through origin + horizon prevents evaluation, including events
#' from another episode or after an apparent confirmation. Otherwise absence of
#' visits in `[0, horizon]` prevents evaluation. Reasons follow that precedence.
#'
#' Remaining statuses distinguish no detected perturbation, no observed return,
#' unconfirmed return and confirmed return. Coverage describes all included times
#' at or after the origin, including times beyond the horizon. Such later visits
#' cannot contribute a recovery or rebound value. Confirmation concerns observed
#' support, not continuous or permanent recovery, health or causal effects.
#'
#' All checks and calculations finish before writing. Repeated addition errors,
#' even with the same rule; use a new analysis name for another definition.
#' Filtering later preserves outcomes and evidence exactly. [validate_recovery()]
#' diagnoses unavailable supporting observations or changed dependencies without
#' recomputing outcomes. The version-1 validation report remains unchanged.
#'
#' @return The TSE with one `recovery` record under the named analysis in
#'   `S4Vectors::metadata(tse)$recoverome$analyses`. Its `episodes` DataFrame has one
#'   row per registered episode with status, reason, coverage, detected/return/
#'   candidate/confirmation/rebound times, last observed time and window visit
#'   count. Times are relative to the registered origin; missing times are
#'   `NA_real_`. The `evidence` list retains selected sample IDs and blocking event
#'   IDs. No columns are added to colData; all parent records, assays, trees,
#'   identities and unrelated metadata are preserved.
#' @seealso [setup_recovery()], [add_reference()], [add_deviation()], [validate_recovery()]
#' @export
#' @examples
#' data("recovery_examples", package = "recoverome")
#' example_data <- recovery_examples$observed_recovery
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = example_data$counts),
#'   colData = S4Vectors::DataFrame(example_data$col_data)
#' )
#' tse <- recoverome::setup_recovery(
#'   tse,
#'   analysis_id = "observed",
#'   episodes = example_data$episodes,
#'   events = example_data$events,
#'   time_col = example_data$time_col,
#'   time_unit = example_data$time_unit,
#'   time_origin = example_data$time_origin
#' )
#' tse <- recoverome::add_reference(tse, "observed", reference = "b1", assay = "counts")
#' tse <- recoverome::add_deviation(tse, "observed")
#' rule <- list(threshold = 0.25, persistence = 4, max_gap = 3, horizon = 10)
#' recovered <- recoverome::add_recovery(tse, "observed", rule)
#' outcome <- S4Vectors::metadata(recovered)$recoverome$analyses$observed$recovery
#' outcome$episodes[, c("status", "candidate_time", "confirmation_time", "rebound_time")]
add_recovery <- function(tse, analysis_id, rule) {
  error_call <- environment()
  values <- .recovery_rule(rule, error_call)
  context <- .recovery_outcome_context(tse, analysis_id, error_call)
  record <- context$record
  calculated <- lapply(seq_len(nrow(record$episodes)), function(row) {
    .recovery_episode_outcome(
      record$episodes[row, , drop = FALSE], record, context$samples, values, error_call
    )
  })
  episodes <- do.call(rbind, lapply(calculated, function(value) {
    do.call(S4Vectors::DataFrame, value$outcome)
  }))
  evidence <- lapply(calculated, `[[`, "evidence")
  names(evidence) <- record$episodes$episode_id
  recovery <- list(
    schema_version = 1L,
    definition = c(
      list(method = "observed_run_v1"), values, list(time_unit = record$registration$time_unit)
    ),
    episodes = episodes,
    evidence = evidence,
    dependencies = list(
      registration_sha256 = .recovery_hash_registration(record),
      reference_sha256 = .recovery_hash_reference(record$reference),
      deviation_sha256 = .recovery_hash_deviation(record$deviation),
      sample_ids = as.vector(record$deviation$sample_ids),
      feature_ids = as.vector(record$reference$definition$feature_ids)
    ),
    provenance = list(
      package_version = as.character(utils::packageVersion("recoverome")),
      created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      fingerprint_format = "recoverome_inputs_v1"
    )
  )
  recovery$fingerprint <- .recovery_hash_recovery(recovery)
  root <- context$root
  root$recoverome$analyses[[analysis_id]]$recovery <- recovery
  S4Vectors::metadata(tse) <- root

  tse
}
