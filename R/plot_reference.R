#' Inspect recorded personal baseline support
#'
#' Show baseline samples against registered relative time, their available
#' distances to the fixed profile, and a separate recorded support summary.
#'
#' @inheritParams recovery_results
#' @details
#' Current scope selects episodes with any retained originally included sample;
#' historical scope selects all registered episodes. Within each selected episode,
#' the original baseline IDs and times remain visible, including removed inputs.
#' The support summary retains recorded sample and distinct-time counts, support
#' state and baseline diameter. It is never recalculated after filtering. A single
#' sample has no estimable pairwise variation; simultaneous samples do not supply
#' independent temporal replication or establish baseline stability.
#'
#' When deviations exist, use only their retained stored baseline values. Before
#' deviation, a current baseline distance may be derived from the exact assay
#' values verified against the recorded input fingerprint and the saved profile.
#' This never refits the mean-composition profile. Derived values are explicitly
#' labeled. Unavailable or changed inputs have identity/time markers on a separate
#' rail, not fabricated distances. Assay, fixed feature scope and preprocessing
#' remain visible in the plot context.
#'
#' The analysis is validated once. Unsupported or incoherent present analytical
#' records error under the existing extraction policy. Changed sources and
#' incomplete checks remain visible. New identities are not enrolled and follow
#' the structured scope-warning policy of [recovery_results()].
#'
#' @return An ordinary unprinted [ggplot2::ggplot] object; customize it with
#'   `+ ggplot2::labs(...)` or `+ ggplot2::theme(...)`. Empty selections or an
#'   absent reference produce an informative plot retaining scope and validation
#'   context. The TSE and its saved records are unchanged.
#' @seealso [add_reference()], [plot_sampling()], [plot_recovery_overview()]
#' @export
#' @examples
#' data("recovery_examples", package = "nostos")
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
#' plot_reference(tse, "observed")
plot_reference <- function(tse, analysis_id, scope = "current") {
  data <- .recovery_diagnostic_context(tse, analysis_id, scope, environment())
  title <- "Recorded personal baseline support"
  if (!nrow(data$episodes)) {
    return(.recovery_diagnostic_empty(data, title, "No episodes in the selected scope"))
  }
  reference <- data$context$stages$reference
  if (is.null(reference)) {
    return(.recovery_diagnostic_empty(data, title, "Reference not computed"))
  }
  baseline <- data$samples[data$samples$is_reference, ]
  baseline$distance <- baseline$deviation
  baseline$value_source <- ifelse(
    is.na(baseline$distance), "Distance unavailable", "Stored deviation"
  )
  if (is.null(data$context$stages$deviation)) {
    baseline$distance <- .recovery_baseline_distances(tse, data, baseline)
    baseline$value_source <- ifelse(is.na(baseline$distance), "Distance unavailable",
                                    "Current verified baseline distance")
  }
  baseline$availability <- ifelse(baseline$current_present, "Retained sample", "Removed sample")

  .recovery_reference_display(data, baseline, reference, title)
}

.recovery_baseline_distances <- function(tse, data, baseline) {
  distance <- rep(NA_real_, nrow(baseline))
  reference <- data$context$stages$reference
  definition <- reference$definition
  diagnostics <- data$context$report$diagnostics
  unsupported <- diagnostics$code == "FINGERPRINT_FORMAT_UNSUPPORTED" &
    startsWith(diagnostics$component, "reference")
  if (any(unsupported) || !all(definition$feature_ids %in% data$context$feature_ids) ||
        sum(SummarizedExperiment::assayNames(tse) == definition$assay, na.rm = TRUE) != 1L) {
    return(distance)
  }
  source <- tryCatch(SummarizedExperiment::assay(tse, definition$assay, withDimnames = FALSE),
                     error = identity)
  if (inherits(source, "condition")) return(distance)

  affected <- diagnostics$code %in% c("ANALYTICAL_INPUT_CHANGED", "ASSAY_VALUES_INVALID",
                                      "ASSAY_READ_FAILED") &
    startsWith(diagnostics$component, "reference")
  unavailable <- unlist(diagnostics$ids[affected], use.names = FALSE)
  usable <- baseline$current_present & !baseline$sample_id %in% unavailable
  features <- match(definition$feature_ids, data$context$feature_ids)
  hashes <- reference$dependencies$samples
  for (row in which(usable)) {
    id <- baseline$sample_id[[row]]
    column <- match(id, data$context$sample_ids)
    values <- tryCatch(as.matrix(source[features, column, drop = FALSE]), error = identity)
    if (inherits(values, "condition")) next
    # Compare the same retrieved values that would be plotted, never a rebuilt profile.
    hash <- .recovery_hash_source(id, definition$feature_ids, values)
    if (!identical(hash, hashes$input_sha256[match(id, hashes$sample_id)])) next
    composition <- as.double(values) / sum(values)
    profile <- reference$profiles[, baseline$episode_id[[row]]]
    distance[[row]] <- sum(abs(composition - profile)) / sum(composition + profile)
  }

  distance
}
