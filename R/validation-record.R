.recovery_validation_table <- function(value, component, id_columns, time_columns, key) {
  columns <- c(id_columns, time_columns)
  valid <- structure(rep(FALSE, length(columns)), names = columns)
  findings <- list()
  if (!methods::is(value, "DataFrame") || is.null(names(value)) ||
        anyNA(names(value)) || any(!nzchar(names(value))) || anyDuplicated(names(value))) {
    findings <- .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      component,
      "Stored {.field {component}} must be a DataFrame with unique, non-empty column names."
    )
    return(list(value = NULL, valid = valid, findings = findings, ids = character()))
  }

  absent <- setdiff(columns, names(value))
  if (length(absent)) {
    findings <- .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      component,
      "Stored {.field {component}} is missing required columns.",
      ids = absent
    )
  }
  ids <- if (key %in% names(value) && is.character(value[[key]]) &&
               is.null(dim(value[[key]]))) value[[key]] else as.character(seq_len(nrow(value)))
  for (column in intersect(columns, names(value))) {
    values <- value[[column]]
    if (column %in% id_columns) {
      valid[[column]] <- .recovery_valid_ids(values, unique = column == key)
    } else {
      valid[[column]] <- typeof(values) == "double" && !is.object(values) &&
        is.null(dim(values)) && all(is.finite(values))
    }
    if (!valid[[column]]) {
      findings <- c(findings, .recovery_finding(
        "REGISTRATION_RECORD_INVALID",
        paste0(component, "$", column),
        "Stored {.field {column}} has invalid normalized values or identities.",
        ids = ids
      ))
    }
  }
  if (!nrow(value)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      component,
      "Stored {.field {component}} must contain at least one row."
    ))
  }

  list(value = value, valid = valid, findings = findings, ids = ids)
}

.recovery_fields_ready <- function(table, columns) {
  all(table$valid[columns])
}

.recovery_validation_record <- function(record) {
  findings <- list()
  result <- list(
    findings = findings,
    structural_valid = FALSE,
    complete = FALSE,
    supported = FALSE,
    samples = NULL,
    source_columns = NULL,
    scope = NULL,
    owned_columns = NULL
  )
  required <- c(
    "schema_version", "registration", "episodes", "events", "scope",
    "owned_columns", "provenance"
  )
  if (!.recovery_named_list(record) || !"schema_version" %in% names(record)) {
    result$findings <- .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "analysis",
      "An analysis must be a uniquely named list with a schema_version."
    )
    return(result)
  }
  if (!identical(record$schema_version, 1L)) {
    result$findings <- .recovery_finding(
      "SCHEMA_UNSUPPORTED",
      "schema_version",
      "The analysis schema is unsupported; its inner records were not interpreted."
    )
    result$structural_valid <- NA
    return(result)
  }

  result$supported <- TRUE
  absent <- setdiff(required, names(record))
  if (length(absent)) {
    findings <- .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "analysis",
      "The analysis is missing required registration fields.",
      ids = absent
    )
  }
  extra <- setdiff(names(record), c(required, "reference", "deviation", "recovery"))
  stages <- intersect(names(record), c("reference", "deviation", "recovery"))
  populated <- stages[vapply(record[stages], length, integer(1)) > 0L]
  unsupported <- c(extra, populated)
  if (length(unsupported)) {
    findings <- c(findings, .recovery_finding(
      "STAGE_UNSUPPORTED",
      "analysis",
      "The analysis contains fields or stages outside registration-only validation.",
      ids = unsupported
    ))
  }

  registration <- record[["registration"]]
  registration_fields <- c("source_columns", "time_unit", "time_origin", "samples")
  registration_readable <- .recovery_named_list(registration)
  registration_present <- if (registration_readable) names(registration) else character()
  registration_complete <- all(registration_fields %in% registration_present)
  if ((!registration_readable || !registration_complete) && "registration" %in% names(record)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "registration",
      "The registration must contain source_columns, time_unit, time_origin and samples."
    ))
  }
  source_valid <- FALSE
  if ("source_columns" %in% registration_present) {
    columns <- registration$source_columns
    source_valid <- is.character(columns) && is.null(dim(columns)) &&
      length(columns) == 3L && !anyNA(names(columns)) &&
      setequal(names(columns), c("subject", "episode", "time")) &&
      !anyDuplicated(columns) && all(vapply(columns, .recovery_valid_text, logical(1)))
    if (source_valid) {
      result$source_columns <- columns
    } else {
      findings <- c(findings, .recovery_finding(
        "REGISTRATION_RECORD_INVALID",
        "registration$source_columns",
        "Source bindings must name distinct subject, episode and time columns."
      ))
    }
  }
  if ("time_unit" %in% registration_present) {
    if (!.recovery_valid_text(registration$time_unit) ||
          !registration$time_unit %in% c("seconds", "minutes", "hours", "days")) {
      findings <- c(findings, .recovery_finding(
        "REGISTRATION_RECORD_INVALID",
        "registration$time_unit",
        "The stored time unit is invalid."
      ))
    }
  }
  if ("time_origin" %in% registration_present) {
    if (!.recovery_valid_text(registration$time_origin)) {
      findings <- c(findings, .recovery_finding(
        "REGISTRATION_RECORD_INVALID",
        "registration$time_origin",
        "The stored time origin must be one non-empty character description."
      ))
    }
  }

  samples <- .recovery_validation_table(
    if ("samples" %in% registration_present) registration$samples else NULL,
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
  if ("samples" %in% registration_present) {
    findings <- c(findings, samples$findings)
  }
  if ("episodes" %in% names(record)) {
    findings <- c(findings, episodes$findings)
  }
  if ("events" %in% names(record)) {
    findings <- c(findings, events$findings)
  }
  result$samples <- samples
  relations <- .recovery_validation_relations(samples, episodes, events)
  findings <- c(findings, relations$findings)

  scope <- record[["scope"]]
  scope_readable <- .recovery_named_list(scope)
  scope_present <- if (scope_readable) names(scope) else character()
  if ((!scope_readable || !all(c("sample_ids", "feature_ids") %in% scope_present)) &&
        "scope" %in% names(record)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "scope",
      "Original scope must contain sample_ids and feature_ids."
    ))
  }
  scope_valid <- c(sample_ids = FALSE, feature_ids = FALSE)
  if (scope_readable) {
    for (axis in intersect(names(scope_valid), scope_present)) {
      scope_valid[[axis]] <- .recovery_valid_ids(scope[[axis]], unique = TRUE) &&
        length(scope[[axis]]) > 0L
      if (!scope_valid[[axis]]) {
        findings <- c(findings, .recovery_finding(
          "REGISTRATION_RECORD_INVALID",
          paste0("scope$", axis),
          "Stored {.field {axis}} must contain explicit unique original identities."
        ))
      }
    }
    result$scope <- scope[names(scope_valid)[scope_valid]]
  }
  if (scope_valid[["sample_ids"]] && samples$valid[["sample_id"]]) {
    outside <- setdiff(samples$value$sample_id, scope$sample_ids)
    if (length(outside)) {
      findings <- c(findings, .recovery_finding(
        "REGISTRATION_RECORD_INVALID",
        "registration$samples$sample_id",
        "Registered samples are absent from the original sample scope.",
        ids = outside
      ))
    }
  }

  owned_valid <- .recovery_valid_ids(record[["owned_columns"]], unique = TRUE)
  if (owned_valid) {
    result$owned_columns <- record[["owned_columns"]]
    if (length(record[["owned_columns"]])) {
      findings <- c(findings, .recovery_finding(
        "STAGE_UNSUPPORTED",
        "owned_columns",
        "A populated ownership manifest requires an analytical-stage validator.",
        ids = record[["owned_columns"]]
      ))
      unsupported <- c(unsupported, "owned_columns")
    }
  } else if ("owned_columns" %in% names(record)) {
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
    if (provenance_valid) {
      timestamp_format <- "%Y-%m-%dT%H:%M:%SZ"
      parsed <- as.POSIXct(stamp, format = timestamp_format, tz = "UTC")
      provenance_valid <- !is.na(parsed) &&
        format(parsed, format = timestamp_format, tz = "UTC") == stamp
    }
  }
  if (!provenance_valid && "provenance" %in% names(record)) {
    findings <- c(findings, .recovery_finding(
      "REGISTRATION_RECORD_INVALID",
      "provenance",
      "Provenance must record a package version and an ISO-8601 UTC registration timestamp."
    ))
  }

  broken <- any(vapply(findings, function(x) {
    x$code %in% c("REGISTRATION_RECORD_INVALID", "RESERVED_COLUMNS_INVALID")
  }, logical(1)))
  result$findings <- findings
  result$structural_valid <- if (broken) FALSE else if (length(unsupported)) NA else TRUE
  result$complete <- !length(absent) && registration_complete && source_valid &&
    all(samples$valid) && all(episodes$valid) && all(events$valid) &&
    all(scope_valid) && owned_valid && relations$complete && !length(unsupported)

  result
}
