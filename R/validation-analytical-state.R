# These parts combine availability and findings, without treating severity as a pass flag.
.recovery_check_part <- function() {
  list(structural_valid = TRUE, complete = TRUE, dependencies = "unchanged", findings = list())
}

.recovery_merge_checks <- function(parts) {
  structural <- vapply(parts, `[[`, logical(1), "structural_valid")
  states <- vapply(parts, `[[`, character(1), "dependencies")
  list(
    structural_valid = if (any(!structural, na.rm = TRUE)) {
      FALSE
    } else {
      if (anyNA(structural)) NA else TRUE
    },
    complete = all(vapply(parts, `[[`, logical(1), "complete")),
    dependencies = if ("changed" %in% states) {
      "changed"
    } else {
      if ("not_checked" %in% states) "not_checked" else "unchanged"
    },
    findings = unname(unlist(lapply(parts, `[[`, "findings"), recursive = FALSE))
  )
}

.recovery_stage_header <- function(value, stage) {
  result <- .recovery_check_part()
  result$readable <- FALSE
  if (!.recovery_named_list(value) || !"schema_version" %in% names(value)) {
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    result$findings <- .recovery_finding(
      paste0(toupper(stage), "_RECORD_INVALID"), stage,
      "Stored {.field {stage}} must be a uniquely named record with schema_version."
    )
    return(result)
  }
  if (!identical(value$schema_version, 1L)) {
    result$structural_valid <- NA
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    result$findings <- .recovery_finding(
      "SCHEMA_UNSUPPORTED", paste0(stage, "$schema_version"),
      "The {.field {stage}} schema is unsupported; its contents were not interpreted."
    )
    return(result)
  }

  result$readable <- TRUE
  result
}

.recovery_stage_problem <- function(stage, component, ids = character()) {
  .recovery_finding(
    paste0(toupper(stage), "_RECORD_INVALID"), component,
    "Stored {.field {component}} has missing, invalid or inconsistent contract fields.",
    ids = ids
  )
}

.recovery_stage_table <- function(value, columns) {
  methods::is(value, "DataFrame") &&
    identical(tryCatch(methods::validObject(value, test = TRUE), error = identity), TRUE) &&
    !is.null(names(value)) && !anyNA(names(value)) && all(nzchar(names(value))) &&
    !anyDuplicated(names(value)) && all(columns %in% names(value))
}

.recovery_hash_rows <- function(value, hash_column, stage, component) {
  result <- .recovery_check_part()
  result$ids <- NULL
  result$hashes <- NULL
  result$valid <- logical()
  if (!.recovery_stage_table(value, c("sample_id", hash_column))) {
    result$findings <- .recovery_stage_problem(stage, component)
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    return(result)
  }

  ids_valid <- .recovery_valid_ids(value$sample_id, unique = TRUE)
  hashes <- value[[hash_column]]
  hashes_valid <- is.character(hashes) && is.null(dim(hashes))
  if (ids_valid) {
    result$ids <- as.vector(value$sample_id)
  }
  if (hashes_valid) {
    result$hashes <- as.vector(hashes)
    result$valid <- vapply(hashes, .recovery_valid_sha256, logical(1))
  }
  if (!ids_valid || !hashes_valid || !all(result$valid)) {
    result$findings <- .recovery_stage_problem(stage, component)
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "not_checked"
  }

  result
}

.recovery_stage_provenance <- function(value, stage, compatible) {
  result <- .recovery_check_part()
  result$format_ready <- FALSE
  fields <- c("package_version", "created_at", "fingerprint_format")
  readable <- .recovery_named_list(value)
  valid <- readable && setequal(names(value), fields) &&
    .recovery_valid_text(value$package_version) && .recovery_valid_text(value$created_at)
  if (valid) {
    stamp <- value$created_at
    timestamp_format <- "%Y-%m-%dT%H:%M:%SZ"
    parsed <- strptime(stamp, format = timestamp_format, tz = "UTC")
    valid <- !is.na(parsed) && format(parsed, format = timestamp_format, tz = "UTC") == stamp
  }
  if (!valid) {
    result$findings <- .recovery_stage_problem(stage, paste0(stage, "$provenance"))
    result$structural_valid <- FALSE
    result$complete <- FALSE
  }
  result$format_ready <- readable &&
    identical(value$fingerprint_format, "recoverome_inputs_v1") && compatible
  if (!result$format_ready) {
    result$findings <- c(result$findings, .recovery_finding(
      "FINGERPRINT_FORMAT_UNSUPPORTED", paste0(stage, "$provenance$fingerprint_format"),
      "The {.field {stage}} fingerprint format is not comparable in this environment."
    ))
    if (isTRUE(result$structural_valid)) {
      result$structural_valid <- NA
    }
    result$complete <- FALSE
    result$dependencies <- "not_checked"
  }

  result
}
