#' Attach deviations from a fixed personal reference
#'
#' Compute sample-level Bray--Curtis dissimilarities from the personal profiles
#' stored by [add_reference()]. Verify the reference and its input dependencies
#' before adding results; the stored reference is never recomputed.
#'
#' @param tse A formally valid `TreeSummarizedExperiment` with a supported named
#'   registration and reference. Every selected reference feature and baseline
#'   sample must remain available. Current identities must be a subset of the
#'   original registration; reordering is allowed.
#' @param analysis_id The existing analysis name, with no deviation or recovery
#'   stage and neither proposed result column already present.
#'
#' @details
#' The reference schema, recorded fingerprint format, complete reference
#' fingerprint, registration dependency and all baseline source hashes must be
#' verifiable and agree. Retained source metadata consumed by registration must
#' still match, including metadata of included samples without a profile. Removed
#' non-baseline samples and unselected original features are allowed. A changed
#' baseline is an error even when scaling its counts preserves its composition.
#'
#' The selected assay must remain unambiguous. Only its fixed reference features
#' and retained included samples with a profile are requested before conversion
#' to a numeric matrix. This block includes the baselines and is used for both
#' input verification and calculation. Base, sparse and delayed matrix-like
#' assays are supported when the requested block can be converted to an ordinary
#' integer or double matrix. Backend I/O and bounded memory are not controlled.
#'
#' Each consumed sample must have finite, non-negative abundances and a finite,
#' positive sum over the fixed features. Its composition is divided by that sum;
#' deviation is the Bray--Curtis dissimilarity from its episode's stored profile.
#' Invalid abundances are errors, not missing-result statuses. Unselected
#' features, excluded samples and samples without a profile are not consumed.
#'
#' Exactly two columns are added to `colData(tse)`, matched by current sample ID:
#' `rec_<analysis_id>_deviation` is double and
#' `rec_<analysis_id>_deviation_status` is character. Status is `"computed"` for
#' included samples with a profile, `"missing_baseline"` for included samples
#' without one, or `"excluded"` for originally excluded samples. The latter two
#' have `NA_real_` deviation. Baseline samples are included in the calculation.
#' One-feature references are allowed and necessarily give zero deviations.
#'
#' The analysis records the method `"bray_relative_v1"`, exact column ownership,
#' current sample scope, reference fingerprint, source hashes for computed samples
#' and result hashes for all current samples, with package/version/UTC provenance.
#' Numeric results remain authoritative only in the two owned columns; metadata
#' does not duplicate them. Filtering subsequently retains this history while
#' selecting the columns normally. It never refits profiles or recomputes results.
#'
#' A deviation describes composition over the fixed features. It supplies no
#' threshold, uncertainty interval or classification of recovery or health.
#' `"missing_baseline"` is an explicit lack of a reference, not structural failure.
#' [validate_recovery()] still supplies registration-only diagnostics; analytical
#' dependency diagnostics are a later implementation stage.
#'
#' @section Errors:
#' Reusing either result column or an existing deviation/recovery stage is an
#' error, including an identical call. Use a new named analysis to change a
#' reference or rerun its dependent results. All checks and calculations finish
#' before storing outputs; failed calls leave the input unchanged. Recoverome
#' checks use the condition classes and public-call attribution documented in
#' [setup_recovery()].
#'
#' @return A TSE of the input class with two new sample columns and one `deviation`
#'   subrecord under `S4Vectors::metadata(tse)$recoverome$analyses[[analysis_id]]`.
#'   The reference, assays, trees, links, identities, unrelated annotations and
#'   other analyses are preserved.
#' @export
#' @examples
#' data("recovery_examples", package = "recoverome")
#' example_data <- recovery_examples$single_episode
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = example_data$counts),
#'   colData = S4Vectors::DataFrame(example_data$col_data)
#' )
#' registered <- setup_recovery(
#'   tse,
#'   analysis_id = "antibiotic",
#'   episodes = example_data$episodes,
#'   events = example_data$events,
#'   time_col = example_data$time_col,
#'   time_unit = example_data$time_unit,
#'   time_origin = example_data$time_origin
#' )
#' referenced <- add_reference(registered, "antibiotic", "s1", assay = "counts")
#' deviated <- add_deviation(referenced, "antibiotic")
#' SummarizedExperiment::colData(deviated)[, c(
#'   "rec_antibiotic_deviation", "rec_antibiotic_deviation_status"
#' )]
add_deviation <- function(tse, analysis_id) {
  error_call <- environment()
  .recovery_check_string(analysis_id, "analysis_id", call = error_call)
  if (!grepl("^[a-z][a-z0-9]*$", analysis_id)) {
    .recovery_abort(
      "{.arg analysis_id} must match ^[a-z][a-z0-9]*$.",
      component = "analysis_id",
      call = error_call
    )
  }

  context <- .recovery_reference_context(tse, analysis_id, error_call, allow_reference = TRUE)
  reference <- .recovery_deviation_reference(context$record, error_call)
  sources <- .recovery_deviation_sources(tse, context, reference, error_call)
  calculated <- .recovery_deviation_values(context, reference, sources)

  columns <- c(
    deviation = paste0("rec_", analysis_id, "_deviation"),
    status = paste0("rec_", analysis_id, "_deviation_status")
  )
  sample_ids <- context$samples
  result_sha256 <- vapply(seq_along(sample_ids), function(sample) {
    .recovery_hash_result(
      sample_ids[[sample]],
      calculated$deviation[[sample]],
      calculated$status[[sample]]
    )
  }, character(1))
  deviation_record <- list(
    schema_version = 1L,
    method = "bray_relative_v1",
    columns = columns,
    sample_ids = sample_ids,
    dependencies = list(
      reference_sha256 = reference$fingerprint,
      samples = S4Vectors::DataFrame(
        sample_id = sources$samples$sample_id,
        input_sha256 = sources$input_sha256
      )
    ),
    results = S4Vectors::DataFrame(sample_id = sample_ids, result_sha256 = result_sha256),
    provenance = list(
      package_version = as.character(utils::packageVersion("recoverome")),
      created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      fingerprint_format = "recoverome_inputs_v1"
    )
  )

  annotation <- context$annotation
  annotation[[columns[["deviation"]]]] <- calculated$deviation
  annotation[[columns[["status"]]]] <- calculated$status
  root <- context$root
  root$recoverome$analyses[[analysis_id]]$deviation <- deviation_record
  root$recoverome$analyses[[analysis_id]]$owned_columns <- c(
    context$record$owned_columns,
    unname(columns)
  )
  SummarizedExperiment::colData(tse) <- annotation
  S4Vectors::metadata(tse) <- root

  tse
}
