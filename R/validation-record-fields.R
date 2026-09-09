.recovery_record_registration <- function(record) {
  registration <- record[["registration"]]
  readable <- .recovery_named_list(registration)
  present <- if (readable) names(registration) else character()
  required <- c("source_columns", "time_unit", "time_origin", "samples")
  complete <- all(required %in% present)
  result <- list(
    findings = list(),
    source_columns = NULL,
    samples = NULL,
    samples_present = FALSE,
    complete = FALSE
  )
  if ((!readable || !complete) && "registration" %in% names(record)) {
    result$findings <- .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "registration",
      "The registration must contain source_columns, time_unit, time_origin and samples."
    )
  }
  if (!readable) {
    return(result)
  }

  columns <- registration[["source_columns"]]
  source_valid <- is.character(columns) && is.null(dim(columns)) &&
    length(columns) == 3L && !anyNA(names(columns)) &&
    setequal(names(columns), c("subject", "episode", "time")) &&
    !anyDuplicated(columns) && all(vapply(columns, .recovery_valid_text, logical(1)))
  findings <- result$findings
  if ("source_columns" %in% present && !source_valid) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "registration$source_columns",
      "Source bindings must name distinct subject, episode and time columns."
    ))
  }
  if ("time_unit" %in% present &&
        (!.recovery_valid_text(registration$time_unit) ||
           !registration$time_unit %in% c("seconds", "minutes", "hours", "days"))) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "registration$time_unit",
      "The stored time unit is invalid."
    ))
  }
  if ("time_origin" %in% present && !.recovery_valid_text(registration$time_origin)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "registration$time_origin",
      "The stored time origin must be one non-empty character description."
    ))
  }

  list(
    findings = findings,
    source_columns = if (source_valid) columns else NULL,
    samples = registration[["samples"]],
    samples_present = "samples" %in% present,
    complete = complete && source_valid
  )
}

.recovery_record_tables <- function(record, registration) {
  samples <- .recovery_validation_table(
    registration$samples,
    "registration$samples",
    id_columns = c("sample_id", "subject_id", "episode_id"),
    time_columns = "time",
    key = "sample_id"
  )
  episodes <- .recovery_validation_table(
    record[["episodes"]],
    "episodes",
    id_columns = c("episode_id", "subject_id", "origin_event_id", "origin_boundary"),
    time_columns = character(),
    key = "episode_id"
  )
  events <- .recovery_validation_table(
    record[["events"]],
    "events",
    id_columns = c("event_id", "episode_id"),
    time_columns = c("start_time", "end_time"),
    key = "event_id"
  )

  findings <- list()
  if (registration$samples_present) {
    findings <- c(findings, samples$findings)
  }
  if ("episodes" %in% names(record)) {
    findings <- c(findings, episodes$findings)
  }
  if ("events" %in% names(record)) {
    findings <- c(findings, events$findings)
  }
  relations <- .recovery_validation_relations(samples, episodes, events)

  list(
    findings = c(findings, relations$findings),
    samples = samples,
    complete = all(samples$valid) && all(episodes$valid) && all(events$valid) &&
      relations$complete
  )
}

.recovery_record_scope <- function(record, samples) {
  scope <- record[["scope"]]
  readable <- .recovery_named_list(scope)
  present <- if (readable) names(scope) else character()
  valid <- c(sample_ids = FALSE, feature_ids = FALSE)
  findings <- list()
  if ((!readable || !all(names(valid) %in% present)) && "scope" %in% names(record)) {
    findings <- .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "scope",
      "Original scope must contain sample_ids and feature_ids."
    )
  }
  if (!readable) {
    return(list(findings = findings, value = NULL, complete = FALSE))
  }

  for (axis in intersect(names(valid), present)) {
    valid[[axis]] <- .recovery_valid_ids(scope[[axis]], unique = TRUE) &&
      length(scope[[axis]]) > 0L
    if (valid[[axis]]) {
      next
    }
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      paste0("scope$", axis),
      "Stored {.field {axis}} must contain explicit unique original identities."
    ))
  }

  can_match_samples <- valid[["sample_ids"]] && samples$valid[["sample_id"]]
  outside <- character()
  if (can_match_samples) {
    outside <- setdiff(samples$value$sample_id, scope$sample_ids)
  }
  if (length(outside)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "registration$samples$sample_id",
      "Registered samples are absent from the original sample scope.",
      ids = outside
    ))
  }

  list(findings = findings, value = scope[names(valid)[valid]], complete = all(valid))
}

.recovery_record_metadata <- function(record) {
  findings <- list()
  owned <- record[["owned_columns"]]
  owned_valid <- .recovery_valid_ids(owned, unique = TRUE)
  unsupported <- owned_valid && length(owned) > 0L
  if (unsupported) {
    findings <- .recovery_finding(
      "STAGE_UNSUPPORTED",
      "owned_columns",
      "A populated ownership manifest requires an analytical-stage validator.",
      ids = owned
    )
  }
  if (!owned_valid && "owned_columns" %in% names(record)) {
    findings <- c(findings, .recovery_finding(
      "RESERVED_COLUMNS_INVALID",
      "owned_columns",
      "The ownership manifest must be a character vector of unique column names."
    ))
  }

  provenance <- record[["provenance"]]
  provenance_valid <- .recovery_named_list(provenance) &&
    all(c("package_version", "registered_at") %in% names(provenance)) &&
    .recovery_valid_text(provenance$package_version) &&
    .recovery_valid_text(provenance$registered_at)
  if (provenance_valid) {
    stamp <- provenance$registered_at
    provenance_valid <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", stamp)
  }
  if (provenance_valid) {
    timestamp_format <- "%Y-%m-%dT%H:%M:%SZ"
    parsed <- strptime(stamp, format = timestamp_format, tz = "UTC")
    provenance_valid <- !is.na(parsed) &&
      format(parsed, format = timestamp_format, tz = "UTC") == stamp
  }
  if (!provenance_valid && "provenance" %in% names(record)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "provenance",
      "Provenance must record a package version and an ISO-8601 UTC registration timestamp."
    ))
  }

  list(
    findings = findings,
    owned_columns = if (owned_valid) owned else NULL,
    unsupported = unsupported,
    complete = owned_valid
  )
}
