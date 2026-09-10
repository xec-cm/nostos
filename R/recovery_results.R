#' Extract saved recovery results and their historical context
#'
#' Project one named analysis into an ordinary DataFrame, retaining explicit
#' identities, result availability and fresh analysis-level validation flags.
#' Extraction never modifies the TSE or recomputes a reference, deviation or
#' recovery outcome.
#'
#' @param tse A TreeSummarizedExperiment containing a named recovery analysis.
#' @param analysis_id One existing analysis ID. There is no implicit selection.
#' @param level Exactly `"episode"` (default) or `"sample"`.
#' @param scope Exactly `"current"` (default) or `"historical"`. Current scope
#'   selects retained original samples, or episodes with retained included
#'   samples. Historical scope includes all originally registered identities.
#'
#' @details
#' Rows follow registration order, regardless of current TSE order. Sample
#' membership and times come from the saved registration, not edited colData.
#' Originally excluded samples have missing subject, episode and time fields.
#' New sample and feature IDs are not enrolled. Their presence emits one
#' `recoverome_warning_scope` condition, containing complete `sample_ids` and
#' `feature_ids` vectors. Zero-row selections retain the same typed columns.
#'
#' At sample level, `result_state` is `"available"` for retained samples in the
#' realized deviation scope, including legitimate missing-baseline or excluded
#' results; `"removed"` for computed samples no longer present; and
#' `"not_computed"` otherwise. Removed deviations and statuses are both missing:
#' hashes cannot reconstruct them. Episode results are available whenever a
#' recovery record exists, including historical episodes with no current samples.
#' Without recovery they are not computed, with typed missing outcome fields.
#'
#' Validate the selected analysis once. Changed or unavailable current inputs
#' do not erase readable saved results. Broken identities, required records,
#' retained outputs or parent/self fingerprints error. An unknown recovery
#' schema can be left uninterpreted for sample views; an unknown deviation
#' schema can be left uninterpreted for episode views before recovery. Unknown
#' fingerprint formats leave checks incomplete but permit readable results.
#' Validation may read the relevant assay blocks; extraction is not assay-free.
#'
#' @return An [S4Vectors::DataFrame] with atomic columns. Both levels start with
#'   `analysis_id`, `view_scope`, `current_present`, `result_state`,
#'   `structural_valid`, `validation_complete`, and `dependencies`. Validation
#'   flags describe the whole selected analysis, not individual rows.
#'
#'   Sample views append `sample_id`, `subject_id`, `episode_id`, `time`,
#'   `relative_time`, `included`, `is_reference`, `deviation`, `deviation_status`.
#'   Episode views append `episode_id`, `subject_id`, `reference_support`,
#'   `n_baseline_samples`, `n_baseline_times`, `baseline_diameter`, and the saved
#'   recovery fields: `status`, `reason`, `coverage`, `first_perturbation_time`,
#'   `first_return_time`, `candidate_time`, `confirmation_time`, `rebound_time`,
#'   `last_observed_time`, `n_window_visits`. Missing stages produce typed NA.
#'
#'   `S4Vectors::metadata(view)$recoverome_view` contains schema version 1,
#'   selection, the full validation report, registration context, scopes,
#'   definitions, provenance/fingerprints, full recovery evidence and names of
#'   uninterpreted stages. It is an extraction-time snapshot. Filtering or editing
#'   a returned table does not refresh it. Call this accessor again to revalidate
#'   against a TSE. `as.data.frame()` preserves atomic columns; conversion to a
#'   data.frame or tibble does not promise to preserve this metadata.
#' @seealso [setup_recovery()], [add_reference()], [add_deviation()],
#'   [add_recovery()], [validate_recovery()]
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
#'   time_col = example_data$time_col, time_unit = example_data$time_unit,
#'   time_origin = example_data$time_origin
#' )
#' tse <- add_reference(tse, "observed", "b1", assay = "counts")
#' tse <- add_deviation(tse, "observed")
#' tse <- add_recovery(tse, "observed", list(
#'   threshold = 0.25, persistence = 4, max_gap = 3, horizon = 10
#' ))
#' recovery_results(tse, "observed")
#' filtered <- tse[, colnames(tse) != "s3"]
#' view <- recovery_results(filtered, "observed", level = "sample", scope = "historical")
#' as.data.frame(view)[, c("sample_id", "result_state", "deviation")]
#' S4Vectors::metadata(view)$recoverome_view$validation$summary
recovery_results <- function(tse, analysis_id, level = "episode", scope = "current") {
  error_call <- environment()
  .recovery_view_selector(level, "level", c("sample", "episode"), error_call)
  .recovery_view_selector(scope, "scope", c("current", "historical"), error_call)
  context <- .recovery_view_context(tse, analysis_id, level, error_call)
  values <- switch(level,
    sample = .recovery_sample_view(context, scope),
    episode = .recovery_episode_view(context, scope)
  )
  summary <- context$report$summary
  count <- nrow(values$table)
  header <- S4Vectors::DataFrame(
    analysis_id = rep(unname(analysis_id), count),
    view_scope = rep(unname(scope), count),
    current_present = values$present,
    result_state = values$state,
    structural_valid = rep(summary$structural_valid, count),
    validation_complete = rep(summary$validation_complete, count),
    dependencies = rep(summary$dependencies, count)
  )
  view <- cbind(header, values$table)
  S4Vectors::metadata(view)$recoverome_view <- .recovery_view_metadata(
    context, unname(analysis_id), unname(level), unname(scope)
  )
  .recovery_view_additions(context, error_call)

  view
}
