.recovery_validate_outcomes <- function(value,
                                        stored,
                                        registration,
                                        reference,
                                        deviation,
                                        current,
                                        compatible) {
  parsed <- .recovery_parse_outcomes(value, compatible)
  if (!parsed$readable) {
    return(parsed$check)
  }
  parts <- list(parsed$check)
  parts$hashes <- .recovery_outcome_hashes(parsed, stored, registration, reference, deviation)
  parts$links <- .recovery_outcome_links(
    parsed, stored, registration, reference, deviation, current
  )
  if (parsed$table_ready && parsed$definition_ready) {
    parts$invariants <- .recovery_outcome_invariants(value$episodes, value$definition)
  }
  if (parsed$table_ready && parsed$evidence_ready) {
    parts$evidence <- .recovery_evidence_links(parsed, registration)
  }

  .recovery_merge_checks(parts)
}

.recovery_outcome_problem <- function(component, ids = character(), complete = FALSE) {
  result <- .recovery_check_part()
  result$structural_valid <- FALSE
  result$complete <- complete
  result$dependencies <- if (complete) "unchanged" else "not_checked"
  result$findings <- .recovery_stage_problem("recovery", component, ids)

  result
}

.recovery_parse_outcomes <- function(value, compatible) {
  header <- .recovery_stage_header(value, "recovery")
  result <- list(
    check = header, readable = header$readable, value = value,
    definition_ready = FALSE, table_ready = FALSE, evidence_ready = FALSE,
    sample_ids = NULL, feature_ids = NULL, parent_hashes = list(), fingerprint = NULL,
    format_ready = FALSE, hash_ready = FALSE
  )
  if (!header$readable) {
    return(result)
  }

  fields <- c("schema_version", "definition", "episodes", "evidence",
              "dependencies", "provenance", "fingerprint")
  parts <- list(header)
  valid_fields <- setequal(names(value), fields)
  if (!valid_fields) {
    parts$fields <- .recovery_outcome_problem("recovery")
  }
  definition <- .recovery_outcome_definition(value$definition)
  episodes <- .recovery_outcome_table(value$episodes)
  evidence <- .recovery_outcome_evidence(value$evidence)
  parts <- c(parts, list(definition$check, episodes$check, evidence$check))
  result$definition_ready <- definition$valid
  result$table_ready <- episodes$ready
  result$evidence_ready <- evidence$ready

  dependencies <- value$dependencies
  hash_fields <- c("registration_sha256", "reference_sha256", "deviation_sha256")
  valid_dependencies <- .recovery_named_list(dependencies) &&
    setequal(names(dependencies), c(hash_fields, "sample_ids", "feature_ids"))
  if (.recovery_named_list(dependencies)) {
    hashes <- dependencies[intersect(hash_fields, names(dependencies))]
    valid_hashes <- vapply(hashes, function(hash) {
      .recovery_valid_sha256(hash) && length(hash) == 1L
    }, logical(1))
    result$parent_hashes <- lapply(hashes[valid_hashes], as.vector)
    if (.recovery_valid_ids(dependencies$sample_ids, unique = TRUE)) {
      result$sample_ids <- as.vector(dependencies$sample_ids)
    }
    if (.recovery_valid_ids(dependencies$feature_ids, unique = TRUE) &&
          length(dependencies$feature_ids) > 0L) {
      result$feature_ids <- as.vector(dependencies$feature_ids)
    }
  }
  valid_dependencies <- valid_dependencies && length(result$parent_hashes) == 3L &&
    !is.null(result$sample_ids) && !is.null(result$feature_ids)
  if (!valid_dependencies) {
    parts$dependencies <- .recovery_outcome_problem("recovery$dependencies")
  }
  if (.recovery_valid_sha256(value$fingerprint) && length(value$fingerprint) == 1L) {
    result$fingerprint <- as.vector(value$fingerprint)
  } else {
    parts$fingerprint <- .recovery_outcome_problem("recovery$fingerprint")
  }
  provenance <- .recovery_stage_provenance(value$provenance, "recovery", compatible)
  parts$provenance <- provenance
  result$format_ready <- provenance$format_ready
  result$hash_ready <- valid_fields && definition$ready && episodes$ready && evidence$ready &&
    valid_dependencies && isTRUE(provenance$structural_valid)
  result$check <- .recovery_merge_checks(parts)

  result
}

.recovery_outcome_definition <- function(value) {
  fields <- c("method", "threshold", "persistence", "max_gap", "horizon", "time_unit")
  ready <- .recovery_named_list(value) && setequal(names(value), fields)
  if (ready) {
    numbers <- vapply(value[c("threshold", "persistence", "max_gap", "horizon")], function(x) {
      is.double(x) && !is.object(x) && is.null(dim(x)) && length(x) == 1L && is.finite(x)
    }, logical(1))
    ready <- all(numbers) && .recovery_valid_text(value$method) &&
      .recovery_valid_text(value$time_unit)
  }
  valid <- ready && value$method == "observed_run_v1" &&
    value$threshold >= 0 && value$threshold <= 1 && value$persistence > 0 &&
    value$max_gap > 0 && value$horizon > 0
  check <- if (valid) .recovery_check_part() else .recovery_outcome_problem("recovery$definition")

  list(ready = ready, valid = valid, check = check)
}

.recovery_outcome_table <- function(value) {
  chars <- c("episode_id", "status", "reason", "coverage")
  times <- c("first_perturbation_time", "first_return_time", "candidate_time",
             "confirmation_time", "rebound_time", "last_observed_time")
  ready <- .recovery_stage_table(value, c(chars, times, "n_window_visits"))
  if (ready) {
    chars_ready <- vapply(value[chars], function(x) is.character(x) && is.null(dim(x)), logical(1))
    times_ready <- vapply(value[times], function(x) {
      is.double(x) && !is.object(x) && is.null(dim(x)) && all(is.na(x) | is.finite(x))
    }, logical(1))
    count <- value$n_window_visits
    ready <- all(chars_ready) && all(times_ready) && is.integer(count) &&
      !is.object(count) && is.null(dim(count)) && !anyNA(count)
  }
  valid <- ready && .recovery_valid_ids(value$episode_id, unique = TRUE) && nrow(value) > 0L
  check <- if (valid) .recovery_check_part() else .recovery_outcome_problem("recovery$episodes")

  list(ready = ready, check = check)
}

.recovery_outcome_evidence <- function(value) {
  fields <- c("evaluated", "coverage", "perturbation", "first_return", "candidate",
              "confirmation", "confirmation_run", "rebound", "blocking_events")
  ready <- .recovery_named_list(value)
  if (ready) {
    ready <- all(vapply(value, function(row) {
      .recovery_named_list(row) && setequal(names(row), fields) &&
        all(vapply(row[fields], .recovery_valid_ids, logical(1), unique = TRUE))
    }, logical(1)))
  }
  check <- if (ready) .recovery_check_part() else .recovery_outcome_problem("recovery$evidence")

  list(ready = ready, check = check)
}
