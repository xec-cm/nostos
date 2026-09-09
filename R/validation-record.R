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
  result <- list(
    findings = list(),
    structural_valid = FALSE,
    complete = FALSE,
    supported = FALSE,
    samples = NULL,
    source_columns = NULL,
    scope = NULL,
    owned_columns = NULL
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

  required <- c(
    "schema_version", "registration", "episodes", "events", "scope",
    "owned_columns", "provenance"
  )
  absent <- setdiff(required, names(record))
  findings <- list()
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

  registration <- .recovery_record_registration(record)
  tables <- .recovery_record_tables(record, registration)
  scope <- .recovery_record_scope(record, tables$samples)
  metadata <- .recovery_record_metadata(record)
  findings <- c(
    findings,
    registration$findings,
    tables$findings,
    scope$findings,
    metadata$findings
  )

  broken <- any(vapply(findings, function(x) {
    x$code %in% c("REGISTRATION_RECORD_INVALID", "RESERVED_COLUMNS_INVALID")
  }, logical(1)))
  unsupported <- length(unsupported) > 0L || metadata$unsupported
  structural_valid <- if (broken) FALSE else if (unsupported) NA else TRUE
  complete <- !length(absent) && registration$complete && tables$complete &&
    scope$complete && metadata$complete && !unsupported

  list(
    findings = findings,
    structural_valid = structural_valid,
    complete = complete,
    supported = TRUE,
    samples = tables$samples,
    source_columns = registration$source_columns,
    scope = scope$value,
    owned_columns = metadata$owned_columns
  )
}
