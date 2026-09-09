.recovery_check_outputs <- function(parsed, current) {
  result <- .recovery_check_part()
  outputs <- parsed$outputs
  if (!current$container_valid || !current$samples$valid) {
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    return(result)
  }

  if (is.null(parsed$sample_ids)) {
    result$complete <- FALSE
    result$dependencies <- "not_checked"
  }
  removed <- setdiff(parsed$sample_ids, current$samples$ids)
  if (length(removed)) {
    result$findings <- .recovery_finding(
      "DEVIATION_SAMPLE_MISSING", "deviation$sample_ids",
      "Realized deviation samples are absent; their historical scope is preserved.",
      ids = removed, severity = "info"
    )
    result$complete <- FALSE
    result$dependencies <- "not_checked"
  }
  recorded_ids <- union(parsed$sample_ids, outputs$ids)
  retained <- intersect(recorded_ids, current$samples$ids)
  columns <- parsed$columns
  column_ready <- vapply(columns, function(column) {
    sum(names(current$annotation) == column, na.rm = TRUE) == 1L
  }, logical(1))
  if (!all(column_ready)) {
    result$findings <- c(result$findings, .recovery_finding(
      "RESULT_INCONSISTENT", "deviation$columns",
      "Retained authoritative deviation columns are missing or ambiguous.", ids = retained
    ))
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "changed"
  }

  values <- status <- NULL
  if (column_ready[["deviation"]]) {
    values <- current$annotation[[columns[["deviation"]]]]
  }
  if (column_ready[["status"]]) {
    status <- current$annotation[[columns[["status"]]]]
  }
  value_type <- is.double(values) && !is.object(values) && is.null(dim(values))
  status_type <- is.character(status) && is.null(dim(status))
  if ((column_ready[["deviation"]] && !value_type) || (column_ready[["status"]] && !status_type)) {
    result$findings <- c(result$findings, .recovery_finding(
      "RESULT_INCONSISTENT", "deviation$columns",
      "Deviation values must remain double and their statuses character vectors.", ids = retained
    ))
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "changed"
  }
  if (!value_type || !status_type) {
    return(result)
  }

  rows <- match(retained, current$samples$ids)
  values <- values[rows]
  status <- status[rows]
  valid_status <- !is.na(status) & status %in% c("computed", "missing_baseline", "excluded")
  valid_values <- (status == "computed" & is.finite(values) & values >= 0 & values <= 1) |
    (status %in% c("missing_baseline", "excluded") & is.na(values))
  comparable <- valid_status & !is.na(valid_values) & valid_values
  if (any(!comparable)) {
    result$findings <- c(result$findings, .recovery_finding(
      "RESULT_INCONSISTENT", "deviation$columns",
      "Retained deviations or statuses have invalid values.", ids = retained[!comparable]
    ))
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "changed"
  }
  if (is.null(outputs$ids) || !parsed$format_ready) {
    result$complete <- FALSE
    if (result$dependencies != "changed") {
      result$dependencies <- "not_checked"
    }
    return(result)
  }

  expected_rows <- match(retained, outputs$ids)
  comparable <- comparable & !is.na(expected_rows) &
    !is.na(outputs$valid[expected_rows]) & outputs$valid[expected_rows]
  compared <- which(comparable)
  actual <- vapply(compared, function(row) {
    .recovery_hash_result(retained[[row]], values[[row]], status[[row]])
  }, character(1))
  changed <- retained[compared][actual != outputs$hashes[expected_rows[compared]]]
  if (length(changed)) {
    result$findings <- c(result$findings, .recovery_finding(
      "RESULT_INCONSISTENT", "deviation$results",
      "Retained authoritative results differ from their recorded fingerprints.", ids = changed
    ))
    result$structural_valid <- FALSE
    result$dependencies <- "changed"
  }
  result$complete <- result$complete && all(comparable)
  if (!result$complete && result$dependencies != "changed") {
    result$dependencies <- "not_checked"
  }

  result
}
