#' Validate stored analyses, dependencies and historical scope
#'
#' Diagnose named registrations, references and deviations against the current
#' TreeSummarizedExperiment without changing the object or recomputing results.
#' Registration-only analyses do not read assay values.
#'
#' @param tse A [TreeSummarizedExperiment::TreeSummarizedExperiment] containing
#'   zero or more registrations created with [setup_recovery()], optionally with
#'   [add_reference()] and [add_deviation()] stages. Subsets with no current
#'   samples or features are supported for historical validation.
#' @param analysis_id `NULL` to inspect all named analyses, or one analysis ID
#'   matching `^[a-z][a-z0-9]*$`. An unknown name produces a report finding.
#'
#' @return A plain list with `report_schema_version = 1L`, and two
#'   [S4Vectors::DataFrame] components, including typed empty tables:
#'   \describe{
#'     \item{summary}{One row per selected readable analysis: `analysis_id`,
#'       `structural_valid`, `validation_complete`, `dependencies`,
#'       `sample_scope`, `feature_scope`, `n_registered`, and `n_retained`.}
#'     \item{diagnostics}{Findings with `analysis_id` (`NA` for global findings),
#'       `code`, `severity`, `component`, `message`, and an `ids` list-column
#'       containing complete character vectors of affected identities.}
#'   }
#'
#' @details
#' Interpret the summary fields together. `structural_valid` is `FALSE` for a
#' demonstrated broken structure, `TRUE` for a fully understood valid structure,
#' and `NA` when an unsupported schema or stage prevents that conclusion.
#' `validation_complete` records whether all required checks could run.
#' Unsupported records never receive a complete validation pass; other named
#' analyses are checked independently.
#'
#' `dependencies` is `"unchanged"`, `"changed"`, or `"not_checked"`. Comparisons
#' use IDs and the consumed source columns of retained original samples. Allowed
#' factors and integer times are normalized for comparison. A retained excluded
#' sample remains excluded only while its episode is `NA`; its subject and time
#' values are not dependencies. Removing a sample does not prove anything about
#' its unavailable metadata. If no originally included sample remains,
#' dependencies are `"not_checked"` unless a change is established independently.
#'
#' Each scope is `"same"` (including reordering), `"subset"`, `"expanded"`,
#' `"mixed"`, `"empty"`, or `"not_checked"`. Scope compares current IDs with the
#' full original container, including originally excluded samples. New IDs are
#' not enrolled. `n_registered` and `n_retained` count originally included samples;
#' unknown counts use `NA_integer_`.
#'
#' Episode and event references are checked against the historical snapshot.
#' Filtering away all observations of an episode does not break that history.
#' No record is repaired, sorted, recomputed, or timestamped by validation.
#' Registration-only validation reads no assay values. With analytical stages,
#' validation checks supported schema-1 reference/deviation/recovery records, canonical
#' fingerprint formats, saved parent/self fingerprints, consumed source hashes
#' and retained owned output hashes. It does not refit profiles, close samples
#' to recompute deviations, reconstruct missing output values, or rerun the
#' observed recovery rule. Recovery checks include episode/evidence invariants,
#' the complete parent chain and its own fingerprint. Unsupported stages remain
#' incomplete while earlier independent checks continue.
#'
#' Only fixed reference features and samples recorded as baseline or computed
#' deviation inputs are requested from an assay. Unselected features, excluded
#' samples and samples without a profile are not consumed. A numeric invalidity
#' or an external read failure in one sample does not hide other checkable source
#' hashes or outputs. Base, sparse and delayed matrix-like assays are supported
#' through public extraction/coercion; backend I/O is not controlled.
#'
#' Across stages, a known change takes precedence over unavailable comparisons;
#' `"not_checked"` takes precedence over `"unchanged"`. Unknown/incompatible
#' fingerprint formats prevent affected comparisons and never establish a change
#' solely from encoding. Removing required baseline inputs, fixed features or
#' realized deviation/recovery samples leaves historical records intact and makes
#' the affected checks incomplete. Reordering does not change dependencies.
#'
#' Analytical diagnostics include `REFERENCE_RECORD_INVALID` and
#' `DEVIATION_RECORD_INVALID` for malformed records; `FINGERPRINT_CHANGED` for
#' inconsistent saved self/parent chains; `ANALYTICAL_INPUT_CHANGED` for changed
#' sources; and `RESULT_INCONSISTENT` for altered, missing, ambiguous or invalid
#' owned results. These have error severity. Comparable fingerprint differences
#' alone do not make validation incomplete. Missing, ambiguous or invalid assay
#' inputs use `ASSAY_MISSING`, `ASSAY_AMBIGUOUS`, or `ASSAY_VALUES_INVALID` and
#' establish a change with incomplete comparisons. `ASSAY_READ_FAILED` and
#' `FINGERPRINT_FORMAT_UNSUPPORTED` report unavailable checks without asserting
#' an input change. Reference/deviation components and complete affected IDs
#' distinguish these findings from the registration diagnostics.
#'
#' `REFERENCE_INPUT_MISSING` and `DEVIATION_SAMPLE_MISSING` are historical
#' availability findings with info severity. `BASELINE_SUPPORT_LIMITED` describes
#' missing, single-sample or single-time support; it does not establish structural
#' failure or quantify uncertainty. Source changes and saved-result inconsistency
#' remain separate findings. The validator supplies no recovery classification,
#' scientific adequacy guarantee or repair operation.
#'
#' Diagnostic codes, column types and enumerated states are stable contracts;
#' message wording and diagnostic order are not. Severity describes an individual
#' finding and is not an overall success flag. Invalid argument types or syntax
#' raise `recoverome_error_input` through [cli::cli_abort()]. Missing analyses,
#' malformed stored records and formal S4 validity failures are report findings.
#'
#' @seealso [setup_recovery()], [add_reference()], [add_deviation()]
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
#'
#' validate_recovery(registered)$summary
#' validate_recovery(registered[, c(1, 3)])$diagnostics
validate_recovery <- function(tse, analysis_id = NULL) {
  .recovery_validate_input(tse, analysis_id, environment())
}

.recovery_validate_input <- function(tse, analysis_id, error_call, allow_all = TRUE) {
  if (!methods::is(tse, "TreeSummarizedExperiment")) {
    .recovery_abort(
      "{.arg tse} must be a {.cls TreeSummarizedExperiment}.",
      component = "tse",
      call = error_call
    )
  }
  if (!is.null(analysis_id) || !allow_all) {
    .recovery_check_string(analysis_id, "analysis_id", call = error_call)
    if (!grepl("^[a-z][a-z0-9]*$", analysis_id)) {
      .recovery_abort(
        "{.arg analysis_id} must match ^[a-z][a-z0-9]*$.",
        component = "analysis_id",
        call = error_call
      )
    }
    analysis_id <- unname(analysis_id)
  }

  # Some TSE validity methods throw even when validObject(test = TRUE) is used.
  validity <- tryCatch(methods::validObject(tse, test = TRUE), error = identity)
  container_valid <- identical(validity, TRUE)
  findings <- list()
  if (!container_valid) {
    details <- if (inherits(validity, "condition")) conditionMessage(validity) else validity
    findings <- .recovery_finding(
      "OBJECT_S4_INVALID",
      "tse",
      "The object fails formal S4 validity: {paste(details, collapse = '; ')}.",
      .envir = list(details = details)
    )
  }
  namespace <- .recovery_validation_namespace(S4Vectors::metadata(tse))
  findings <- c(findings, namespace$findings)
  if (!namespace$readable) {
    return(.recovery_validation_report(findings = findings))
  }

  analyses <- namespace$analyses
  selected <- if (is.null(analysis_id)) names(analyses) else analysis_id
  if (!length(selected)) {
    findings <- c(findings, .recovery_finding(
      "NO_ANALYSES",
      "recoverome$analyses",
      "The object contains no registered analyses.",
      severity = "info"
    ))
    return(.recovery_validation_report(findings = findings))
  }

  samples <- features <- list(ids = NULL, valid = FALSE)
  if (container_valid) {
    samples <- .recovery_validation_axis(colnames(tse), ncol(tse), "sample")
    features <- .recovery_validation_axis(rownames(tse), nrow(tse), "feature")
    findings <- c(findings, samples$findings, features$findings)
  }
  annotation <- if (container_valid) SummarizedExperiment::colData(tse) else NULL
  current <- list(
    container_valid = container_valid,
    samples = samples,
    features = features,
    annotation = annotation,
    tse = tse
  )

  summaries <- vector("list", length(selected))
  for (index in seq_along(selected)) {
    selected_id <- selected[[index]]
    result <- .recovery_validate_analysis(selected_id, analyses, current, analytical = TRUE)
    summaries[[index]] <- result$summary
    local_findings <- lapply(result$findings, function(finding) {
      finding$analysis_id <- selected_id
      finding
    })
    findings <- c(findings, local_findings)
  }

  .recovery_validation_report(summaries, findings)
}
