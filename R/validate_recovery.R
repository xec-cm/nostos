#' Validate registration structure, dependencies and historical scope
#'
#' Diagnose named registrations against the current TreeSummarizedExperiment
#' without changing the object, rewriting history, or reading assay values.
#'
#' @param tse A [TreeSummarizedExperiment::TreeSummarizedExperiment] containing
#'   zero or more registrations created with [setup_recovery()]. Subsets with
#'   no current samples or features are supported for historical validation.
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
#' Registration validation does not inspect assay values or certify analytical
#' eligibility, baseline estimates, deviations, or recovery outcomes. Populated
#' analytical stages require a later validator and produce `STAGE_UNSUPPORTED`.
#'
#' Diagnostic codes, column types and enumerated states are stable contracts;
#' message wording and diagnostic order are not. Severity describes an individual
#' finding and is not an overall success flag. Invalid argument types or syntax
#' raise `recoverome_error_input` through [cli::cli_abort()]. Missing analyses,
#' malformed stored records and formal S4 validity failures are report findings.
#'
#' @seealso [setup_recovery()]
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
  error_call <- environment()
  if (!methods::is(tse, "TreeSummarizedExperiment")) {
    .recovery_abort(
      "{.arg tse} must be a {.cls TreeSummarizedExperiment}.",
      component = "tse",
      call = error_call
    )
  }
  if (!is.null(analysis_id)) {
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
  summaries <- list()
  for (selected_id in selected) {
    summary <- .recovery_validation_summary(selected_id)
    if (!selected_id %in% names(analyses)) {
      summary$structural_valid <- FALSE
      summary$validation_complete <- FALSE
      local_findings <- .recovery_finding(
        "ANALYSIS_NOT_FOUND",
        "analysis_id",
        "Requested analysis {.val {selected_id}} does not exist.",
        ids = selected_id
      )
    } else {
      record <- .recovery_validation_record(analyses[[selected_id]])
      local_findings <- record$findings
      summary$structural_valid <- record$structural_valid
      summary$validation_complete <- record$complete
      if (!is.null(record$samples) && record$samples$valid[["sample_id"]]) {
        summary$n_registered <- as.integer(nrow(record$samples$value))
        if (container_valid && samples$valid) {
          summary$n_retained <- as.integer(sum(record$samples$value$sample_id %in% samples$ids))
          if (summary$n_registered > 0L && summary$n_retained == 0L) {
            local_findings <- c(local_findings, .recovery_finding(
              "REGISTERED_SAMPLES_ABSENT",
              "registration$samples",
              "No originally included sample remains in the current object.",
              severity = "info"
            ))
          }
        }
      }
      if (record$supported && container_valid) {
        sample_scope <- .recovery_validation_scope(
          samples,
          record$scope[["sample_ids"]],
          "sample"
        )
        feature_scope <- .recovery_validation_scope(
          features,
          record$scope[["feature_ids"]],
          "feature"
        )
        dependencies <- .recovery_check_dependencies(
          SummarizedExperiment::colData(tse),
          samples,
          record
        )
        ownership <- .recovery_validation_ownership(
          names(SummarizedExperiment::colData(tse)),
          record$owned_columns,
          selected_id
        )
        summary$sample_scope <- sample_scope$state
        summary$feature_scope <- feature_scope$state
        summary$dependencies <- dependencies$state
        summary$validation_complete <- summary$validation_complete && dependencies$complete
        if (length(ownership)) {
          summary$structural_valid <- FALSE
        }
        local_findings <- c(
          local_findings, sample_scope$findings, feature_scope$findings,
          dependencies$findings, ownership
        )
      }
    }

    if (!container_valid || !samples$valid || !features$valid) {
      summary$structural_valid <- FALSE
      summary$validation_complete <- FALSE
    }
    local_findings <- lapply(local_findings, function(finding) {
      finding$analysis_id <- selected_id
      finding
    })
    summaries[[length(summaries) + 1L]] <- summary
    findings <- c(findings, local_findings)
  }

  .recovery_validation_report(summaries, findings)
}
