.recovery_analysis_stages <- function(analysis_id, stored, registration, current, result) {
  present <- intersect(c("reference", "deviation", "recovery"), names(stored))
  if (!length(present)) {
    return(result)
  }

  compatible <- .recovery_hash_compatible()
  reference <- deviation <- NULL
  parts <- list()
  if ("reference" %in% present) {
    reference <- .recovery_parse_reference(stored$reference, registration, compatible)
    parts$reference <- reference$check
  }
  if ("deviation" %in% present) {
    deviation <- .recovery_parse_deviation(
      stored$deviation, analysis_id, registration, reference, compatible
    )
    parts$deviation <- deviation$check
  }
  if (!is.null(deviation) && is.null(reference)) {
    missing <- .recovery_check_part()
    missing$structural_valid <- FALSE
    missing$complete <- FALSE
    missing$dependencies <- "not_checked"
    missing$findings <- .recovery_stage_problem(
      "deviation", "deviation$dependencies$reference_sha256"
    )
    parts$missing_reference <- missing
  }

  parts$hashes <- .recovery_stored_hashes(reference, deviation, stored, registration)
  sources <- .recovery_current_sources(current, reference, deviation)
  if (!is.null(reference) && reference$readable) {
    parts$reference_sources <- .recovery_compare_sources(
      "reference", reference, reference, current, sources
    )
  }
  if (!is.null(deviation) && deviation$readable) {
    parts$deviation_sources <- .recovery_compare_sources(
      "deviation", deviation, reference, current, sources
    )
    parts$outputs <- .recovery_check_outputs(deviation, current)
  }

  if ("recovery" %in% present) {
    parts$recovery <- .recovery_validate_outcomes(
      stored$recovery, stored, registration, reference, deviation, current, compatible
    )
  }

  base <- .recovery_check_part()
  base$structural_valid <- result$summary$structural_valid
  base$complete <- result$summary$validation_complete
  base$dependencies <- result$summary$dependencies
  base$findings <- result$findings
  unsupported <- any(vapply(base$findings, function(x) x$code == "STAGE_UNSUPPORTED", logical(1)))
  if (unsupported && base$dependencies != "changed") {
    base$dependencies <- "not_checked"
  }
  changes <- .recovery_analytical_metadata(result$findings, present)
  parts <- c(list(base, changes), parts)
  combined <- .recovery_merge_checks(parts)
  result$summary$structural_valid <- combined$structural_valid
  result$summary$validation_complete <- combined$complete
  result$summary$dependencies <- combined$dependencies
  result$findings <- combined$findings

  result
}

.recovery_analytical_metadata <- function(findings, stages) {
  result <- .recovery_check_part()
  changes <- Filter(function(x) {
    x$code %in% c(
      "DEPENDENCY_COLUMN_MISSING", "DEPENDENCY_COLUMN_AMBIGUOUS", "DEPENDENCY_VALUE_CHANGED"
    )
  }, findings)
  for (stage in stages) {
    for (finding in changes) {
      result$findings <- c(result$findings, .recovery_finding(
        "ANALYTICAL_INPUT_CHANGED", paste0(stage, "$dependencies"),
        "Consumed registration source {.field {finding$component}} changed for {.field {stage}}.",
        ids = finding$ids
      ))
    }
  }
  if (length(changes)) {
    result$dependencies <- "changed"
  }

  result
}
