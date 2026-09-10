.recovery_outcome_hashes <- function(parsed, stored, registration, reference, deviation) {
  self <- if (parsed$format_ready && parsed$hash_ready) {
    .recovery_hash_recovery(parsed$value)
  } else {
    NULL
  }
  parts <- list(.recovery_compare_hash(self, parsed$fingerprint, "recovery$fingerprint"))
  actual <- list(registration_sha256 = NULL, reference_sha256 = NULL, deviation_sha256 = NULL)
  if (parsed$format_ready && isTRUE(registration$hash_ready)) {
    actual$registration_sha256 <- .recovery_hash_registration(stored)
  }
  if (parsed$format_ready && !is.null(reference) &&
        reference$format_ready && reference$hash_ready) {
    actual$reference_sha256 <- .recovery_hash_reference(reference$value)
  }
  if (parsed$format_ready && !is.null(deviation) &&
        deviation$format_ready && deviation$hash_ready) {
    actual$deviation_sha256 <- .recovery_hash_deviation(deviation$value)
  }
  for (field in names(actual)) {
    parts[[field]] <- .recovery_compare_hash(
      actual[[field]], parsed$parent_hashes[[field]], paste0("recovery$dependencies$", field)
    )
  }

  .recovery_merge_checks(parts)
}

.recovery_outcome_links <- function(parsed, stored, registration, reference, deviation, current) {
  parts <- list()
  if (is.null(reference) || is.null(deviation)) {
    parts$parents <- .recovery_outcome_problem("recovery$dependencies")
  }
  if (!is.null(parsed$sample_ids) && !is.null(deviation$sample_ids) &&
        !identical(parsed$sample_ids, deviation$sample_ids)) {
    parts$samples <- .recovery_outcome_problem("recovery$dependencies$sample_ids", complete = TRUE)
  }
  if (!is.null(parsed$feature_ids) && !is.null(reference$features) &&
        !identical(parsed$feature_ids, reference$features)) {
    parts$features <- .recovery_outcome_problem(
      "recovery$dependencies$feature_ids", complete = TRUE
    )
  }
  if (parsed$table_ready && !is.null(registration$episodes) &&
        .recovery_fields_ready(registration$episodes, "episode_id") &&
        !identical(parsed$value$episodes$episode_id, registration$episodes$value$episode_id)) {
    parts$episodes <- .recovery_outcome_problem("recovery$episodes$episode_id", complete = TRUE)
  }
  if (parsed$evidence_ready && parsed$table_ready &&
        !identical(names(parsed$value$evidence), parsed$value$episodes$episode_id)) {
    parts$evidence <- .recovery_outcome_problem("recovery$evidence", complete = TRUE)
  }
  if (parsed$definition_ready && isTRUE(registration$hash_ready) &&
        !identical(parsed$value$definition$time_unit, stored$registration$time_unit)) {
    parts$unit <- .recovery_outcome_problem("recovery$definition$time_unit", complete = TRUE)
  }

  missing <- .recovery_check_part()
  if (!is.null(parsed$sample_ids) && current$samples$valid) {
    removed <- setdiff(parsed$sample_ids, current$samples$ids)
    if (length(removed)) {
      missing$complete <- FALSE
      missing$dependencies <- "not_checked"
      missing$findings <- .recovery_finding(
        "RECOVERY_INPUT_MISSING", "recovery$dependencies$sample_ids",
        "Recorded recovery inputs are absent; episode outcomes retain their historical scope.",
        ids = removed, severity = "info"
      )
    }
  }
  parts$missing <- missing

  .recovery_merge_checks(parts)
}
