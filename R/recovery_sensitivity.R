#' Compare explicit recovery rules without changing the analysis
#'
#' Apply each requested observation rule to a fixed personal reference and saved
#' deviations. Preserve every scenario and registered episode, including cases
#' that cannot currently be evaluated.
#'
#' @param tse A TreeSummarizedExperiment with a supported registration, reference
#'   and deviation stage. A saved recovery stage is optional and remains unchanged.
#' @param analysis_id One existing named analysis; there is no implicit selection.
#' @param rules A nonempty data.frame or S4Vectors DataFrame with exactly
#'   `scenario_id`, `threshold`, `persistence`, `max_gap`, and `horizon` columns.
#'   Scenario IDs are unique, nonempty, unpadded character strings. The other
#'   columns are ordinary finite numeric vectors: threshold lies in `[0, 1]` and
#'   durations are positive in the registered time unit. Identical rules with
#'   different IDs are retained. No grid or preferred rule is inferred.
#'
#' @details
#' The original TSE and all saved results remain unchanged. Baseline and sampling
#' sensitivity require explicitly registered new analyses; this function varies
#' only the four fields accepted by [add_recovery()].
#'
#' A scenario is `evaluated` when its required inputs remain available and the
#' selected analysis validates completely with unchanged dependencies. Legitimate
#' outcomes such as missing baseline remain evaluated results with their original
#' `not_evaluable` status and reason. Changed dependencies instead give every row
#' `evaluation_state = "not_evaluable"` and `evaluation_reason = "inputs_changed"`.
#' Missing required historical samples/features/assay give
#' `"historical_inputs_unavailable"`; otherwise incomplete checks give
#' `"validation_incomplete"`. Known changes take precedence. In these cases the
#' scenario outcome fields are typed missing; original recovery is never copied
#' into a new scenario as if it were newly evaluated evidence.
#'
#' The complete realized deviation scope and required reference inputs must be
#' retained. Reordering and removal of unused features are allowed. Added identities
#' are not enrolled and emit the same scope warning as [recovery_results()].
#' Malformed required records, unsupported required schemas and corrupted retained
#' outputs error using the existing extraction policy. Invalid rules error before
#' any scenario is calculated, with offending scenario IDs in condition data.
#'
#' @return An ordinary S4Vectors DataFrame, ordered by supplied scenario then
#'   registered episode. Atomic columns retain IDs, the four parameters,
#'   evaluation state/reason, reference support, observed outcome fields and fresh
#'   analysis-wide validation flags. `current_present` indicates whether the
#'   original episode has any retained included samples.
#'
#'   `metadata(result)$recoverome_sensitivity` contains schema version 1, the
#'   supplied rules, validation, extracted historical analysis context, per-scenario
#'   evidence and provenance. Evidence is NULL for unavailable scenarios. Context
#'   is a snapshot; it does not revalidate after table edits or conversions.
#'   A versioned checksum protects table/context consistency for [plot_sensitivity()]
#'   against ordinary edits, not adversarial rewriting. Keep the original result
#'   for plotting; convert a separate copy to data.frame/tibble for other work.
#' @seealso [add_recovery()], [recovery_results()], [plot_sensitivity()]
#' @export
#' @examples
#' data("recovery_examples", package = "recoverome")
#' example_data <- recovery_examples$observed_recovery
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = example_data$counts),
#'   colData = S4Vectors::DataFrame(example_data$col_data)
#' )
#' tse <- setup_recovery(
#'   tse, "observed", example_data$episodes, example_data$events,
#'   time_col = "day", time_unit = "days", time_origin = "days since enrolment"
#' )
#' tse <- add_reference(tse, "observed", "b1", assay = "counts")
#' tse <- add_deviation(tse, "observed")
#' rules <- data.frame(
#'   scenario_id = c("primary", "short_gap"), threshold = 0.25,
#'   persistence = 4, max_gap = c(3, 1), horizon = 10
#' )
#' sensitivity <- recovery_sensitivity(tse, "observed", rules)
#' sensitivity[, c("scenario_id", "status", "confirmation_time")]
#' plot_sensitivity(sensitivity)
recovery_sensitivity <- function(tse, analysis_id, rules) {
  error_call <- environment()
  rules <- .recovery_sensitivity_rules(rules, error_call)
  context <- .recovery_view_context(tse, analysis_id, "sample", error_call)
  if (is.null(context$stages$reference) || is.null(context$stages$deviation)) {
    .recovery_abort(
      "Analysis {.val {analysis_id}} requires a reference and saved deviations.",
      component = "analysis_id", ids = analysis_id, call = error_call
    )
  }
  reason <- .recovery_sensitivity_reason(context)
  samples <- .recovery_sample_view(context, "historical")$table
  samples <- samples[samples$included &
                       samples$sample_id %in% context$stages$deviation$sample_ids, ]
  results <- lapply(seq_len(nrow(rules)), function(row) {
    .recovery_sensitivity_scenario(context, samples, rules[row, ], reason, error_call)
  })
  table <- do.call(rbind, lapply(results, `[[`, "table"))
  table$analysis_id <- rep(unname(analysis_id), nrow(table))
  leading <- c("scenario_id", "analysis_id", "episode_id", "subject_id")
  table <- table[, c(leading, setdiff(names(table), leading)), drop = FALSE]
  evidence <- structure(lapply(results, `[[`, "evidence"), names = rules$scenario_id)
  metadata <- .recovery_sensitivity_metadata(context, analysis_id, rules, evidence)
  metadata$fingerprint <- .recovery_sensitivity_hash(table, metadata)
  S4Vectors::metadata(table)$recoverome_sensitivity <- metadata
  .recovery_view_additions(context, error_call)

  table
}
