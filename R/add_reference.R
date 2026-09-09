#' Attach an explicit personal baseline reference
#'
#' Calculate an equally weighted mean of selected baseline compositions within
#' each registered episode. Store the profiles, their descriptive support, and
#' input fingerprints in the named analysis.
#'
#' @param tse A formally valid `TreeSummarizedExperiment` containing a supported
#'   registration from [setup_recovery()]. Current sample and feature IDs must
#'   remain within its original scope. Reordering and filtering are allowed.
#' @param analysis_id The name of an existing registration, with no reference,
#'   deviation, or recovery stage already attached.
#' @param reference An explicit character vector of unique current, included
#'   sample IDs without missing, empty, or whitespace-padded values. An empty
#'   `character()` vector is allowed. Every selected sample must precede the
#'   start of its own episode's origin event, including when the registered
#'   origin boundary is `"end"`.
#' @param assay One literal, non-empty character name occurring exactly once in
#'   `assayNames(tse)`. No assay is selected automatically.
#' @param features `NULL` for all current features, or an explicit non-empty
#'   character vector of unique current feature IDs with the same ID rules as
#'   `reference`. The resolved feature order is retained.
#' @param preprocessing One non-empty character description of upstream
#'   preprocessing, stored exactly as supplied. The default `"unspecified"`
#'   makes no assertion about the scientific meaning of the measurements.
#'
#' @details
#' Only the selected assay block is materialized. Its values must be integer or
#' double, finite and non-negative, with a finite positive total for each selected
#' sample over the selected features. Each sample is divided by that total before
#' averaging. Base, sparse, and delayed matrix-like assays are supported when the
#' selected block can be converted to a numeric matrix. Unselected assay cells
#' are not validated. No pseudocount, feature filtering, time weighting or baseline
#' eligibility beyond the origin-event start rule is inferred.
#'
#' Source metadata consumed by the registration must still agree for all retained
#' original samples, including retained follow-up samples. Excluded samples must
#' remain excluded; their subject and time cells are ignored. A filtered object
#' with no samples can receive an empty reference if these checks remain available
#' and at least one feature remains.
#'
#' Every original episode receives a support row: `"missing_baseline"`,
#' `"single_sample"`, `"single_time"`, or `"multiple_times"`. The row reports
#' sample/time counts and the first and last registered times. The baseline
#' diameter is the largest pairwise Bray--Curtis distance between closed baseline
#' compositions; it is `NA_real_` with fewer than two samples. Duplicate times
#' retain equal sample weights. One selected feature is allowed but yields a
#' constant composition. Support describes the observations, not uncertainty or
#' evidence of recovery.
#'
#' The `reference` subrecord contains its definition, realized baseline membership
#' in registered sample order, episode support, and a double profile matrix with
#' columns only for episodes that have baselines. It also records package/time
#' provenance, a fingerprint of the registration, per-baseline source hashes,
#' and its own SHA-256 fingerprint using the versioned `recoverome_inputs_v1`
#' format. Source hashes describe selected abundances before closure, so scaling
#' the counts is a source change even when the composition is unchanged. Original
#' registration scope is preserved. Hashes detect ordinary dependency edits;
#' stored snapshots are not intended for manual editing.
#'
#' No reference is borrowed from another episode. Profiles describe the selected
#' measured compositions and do not estimate a latent healthy state. This function
#' does not compute deviations, recovery outcomes, intervals, or thresholds.
#' [validate_recovery()] currently checks registration only and reports analytical
#' stages as incompletely checked; reference dependency validation is not yet
#' implemented.
#'
#' @section Errors:
#' A repeated call is an error, including an identical selection. Use a new named
#' analysis to change a reference. All consumed inputs are checked before storing
#' the reference; an error leaves the input unchanged. Recoverome checks use the
#' condition classes and public-call attribution documented in [setup_recovery()].
#'
#' @return A TSE of the input class with one `reference` subrecord added under
#'   `S4Vectors::metadata(tse)$recoverome$analyses[[analysis_id]]`. Assays, trees,
#'   links, identities, `colData()`, other metadata and other analyses are unchanged.
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
#' referenced <- add_reference(
#'   registered,
#'   analysis_id = "antibiotic",
#'   reference = "s1",
#'   assay = "counts"
#' )
#' S4Vectors::metadata(referenced)$recoverome$analyses$antibiotic$reference$episodes
add_reference <- function(tse,
                          analysis_id,
                          reference,
                          assay,
                          features = NULL,
                          preprocessing = "unspecified") {
  error_call <- environment()
  .recovery_check_string(analysis_id, "analysis_id", call = error_call)
  if (!grepl("^[a-z][a-z0-9]*$", analysis_id)) {
    .recovery_abort(
      "{.arg analysis_id} must match ^[a-z][a-z0-9]*$.",
      component = "analysis_id",
      call = error_call
    )
  }
  .recovery_check_string(preprocessing, "preprocessing", call = error_call)

  context <- .recovery_reference_context(tse, analysis_id, error_call)
  selection <- .recovery_reference_selection(context, reference, features, error_call)
  values <- .recovery_reference_assay(tse, assay, selection, context, error_call)
  calculated <- .recovery_reference_profiles(
    values,
    selection$samples,
    context$record$episodes$episode_id
  )

  sample_ids <- selection$samples$sample_id
  input_sha256 <- vapply(seq_along(sample_ids), function(sample) {
    .recovery_hash_source(sample_ids[[sample]], selection$feature_ids, values[, sample])
  }, character(1))
  reference_record <- list(
    schema_version = 1L,
    definition = list(
      sample_ids = selection$sample_ids,
      assay = unname(assay),
      feature_ids = selection$feature_ids,
      preprocessing = unname(preprocessing),
      normalization = "closure_v1",
      estimator = "sample_mean_v1"
    ),
    baseline_samples = selection$samples[, c("sample_id", "episode_id"), drop = FALSE],
    episodes = calculated$episodes,
    profiles = calculated$profiles,
    dependencies = list(
      registration_sha256 = .recovery_hash_registration(context$record),
      samples = S4Vectors::DataFrame(sample_id = sample_ids, input_sha256 = input_sha256)
    ),
    provenance = list(
      package_version = as.character(utils::packageVersion("recoverome")),
      created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      fingerprint_format = "recoverome_inputs_v1"
    )
  )
  reference_record$fingerprint <- .recovery_hash_reference(reference_record)

  root <- context$root
  root$recoverome$analyses[[analysis_id]]$reference <- reference_record
  S4Vectors::metadata(tse) <- root

  tse
}
