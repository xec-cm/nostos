.recovery_validate_analysis <- function(analysis_id, analyses, current) {
  summary <- .recovery_validation_summary(analysis_id)
  if (!analysis_id %in% names(analyses)) {
    summary$structural_valid <- FALSE
    summary$validation_complete <- FALSE
    findings <- .recovery_finding(
      "ANALYSIS_NOT_FOUND",
      "analysis_id",
      "Requested analysis {.val {analysis_id}} does not exist.",
      ids = analysis_id
    )
    return(list(summary = summary, findings = findings))
  }

  record <- .recovery_validation_record(analyses[[analysis_id]])
  current_valid <- current$container_valid && current$samples$valid && current$features$valid
  summary$structural_valid <- if (current_valid) record$structural_valid else FALSE
  summary$validation_complete <- current_valid && record$complete

  counts <- .recovery_validation_counts(record$samples, current$samples)
  summary$n_registered <- counts$n_registered
  summary$n_retained <- counts$n_retained
  findings <- c(record$findings, counts$findings)

  # Apply known global failures before skipping unsupported comparisons.
  if (!record$supported || !current$container_valid) {
    return(list(summary = summary, findings = findings))
  }

  sample_scope <- .recovery_validation_scope(
    current$samples,
    record$scope[["sample_ids"]],
    "sample"
  )
  feature_scope <- .recovery_validation_scope(
    current$features,
    record$scope[["feature_ids"]],
    "feature"
  )
  dependencies <- .recovery_check_dependencies(current$annotation, current$samples, record)
  ownership <- .recovery_validation_ownership(
    names(current$annotation),
    record$owned_columns,
    analysis_id
  )

  summary$sample_scope <- sample_scope$state
  summary$feature_scope <- feature_scope$state
  summary$dependencies <- dependencies$state
  summary$validation_complete <- summary$validation_complete && dependencies$complete
  if (length(ownership)) {
    summary$structural_valid <- FALSE
  }
  findings <- c(
    findings, sample_scope$findings, feature_scope$findings,
    dependencies$findings, ownership
  )

  list(summary = summary, findings = findings)
}

.recovery_validation_counts <- function(samples, current) {
  result <- list(
    n_registered = NA_integer_,
    n_retained = NA_integer_,
    findings = list()
  )
  if (is.null(samples) || !samples$valid[["sample_id"]]) {
    return(result)
  }

  result$n_registered <- as.integer(nrow(samples$value))
  if (!current$valid) {
    return(result)
  }

  result$n_retained <- as.integer(sum(samples$value$sample_id %in% current$ids))
  if (result$n_registered > 0L && result$n_retained == 0L) {
    result$findings <- .recovery_finding(
      "REGISTERED_SAMPLES_ABSENT",
      "registration$samples",
      "No originally included sample remains in the current object.",
      severity = "info"
    )
  }

  result
}
