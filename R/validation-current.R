.recovery_validation_scope <- function(current, original, axis) {
  findings <- list()
  if (!current$valid || is.null(original)) { return(list(state = "not_checked", findings = findings)) }

  removed <- setdiff(original, current$ids)
  added <- setdiff(current$ids, original)
  state <- if (!length(current$ids)) { "empty"
  } else if (length(removed) && length(added)) { "mixed"
  } else if (length(removed)) { "subset"
  } else if (length(added)) { "expanded"
  } else { "same" }

  component <- paste0(axis, "_ids")
  if (length(removed)) {
    findings <- c(findings, .recovery_finding(
      if (axis == "sample") "SAMPLE_SCOPE_REDUCED" else "FEATURE_SCOPE_REDUCED",
      component,
      "Original {.val {axis}} identities are absent; their historical scope is retained.",
      ids = removed,
      severity = "info"
    ))
  }
  if (length(added)) {
    findings <- c(findings, .recovery_finding(
      "SCOPE_EXPANDED",
      component,
      "Current {.val {axis}} identities include additions outside the registered scope.",
      ids = added,
      severity = "warning"
    ))
  }
  if (state == "empty") {
    findings <- c(findings, .recovery_finding(
      "SCOPE_EMPTY",
      component,
      "The current {.val {axis}} axis is empty.",
      severity = "info"
    ))
  }

  list(state = state, findings = findings)
}

.recovery_validation_ownership <- function(column_names, owned, analysis_id) {
  if (is.null(owned)) {
    return(list())
  }

  prefix <- paste0("rec_", analysis_id, "_")
  actual <- column_names[!is.na(column_names) & startsWith(column_names, prefix)]
  bad_counts <- owned[vapply(owned, function(column) {
    sum(column_names == column, na.rm = TRUE) != 1L
  }, logical(1))]
  invalid <- unique(c(setdiff(actual, owned), bad_counts, owned[!startsWith(owned, prefix)]))
  if (!length(invalid)) {
    return(list())
  }

  .recovery_finding(
    "RESERVED_COLUMNS_INVALID",
    "owned_columns",
    "Reserved columns and the exact ownership manifest do not agree.",
    ids = invalid
  )
}

.recovery_check_dependencies <- function(annotation, current, record) {
  findings <- list()
  changed <- FALSE
  complete <- TRUE
  columns <- record$source_columns
  samples <- record$samples
  if (is.null(columns)) {
    return(list(state = "not_checked", complete = FALSE, findings = findings))
  }

  sample_map <- current$valid && !is.null(samples) && samples$valid[["sample_id"]]
  included <- if (sample_map) intersect(samples$value$sample_id, current$ids) else character()
  original <- record$scope[["sample_ids"]]
  membership_map <- sample_map && !is.null(original) &&
    all(samples$value$sample_id %in% original)
  retained <- if (membership_map) intersect(original, current$ids) else character()
  if (!sample_map || !membership_map) {
    complete <- FALSE
  }

  fields <- c(subject = "subject_id", episode = "episode_id", time = "time")
  for (role in names(fields)) {
    column <- columns[[role]]
    count <- sum(names(annotation) == column, na.rm = TRUE)
    if (count != 1L) {
      changed <- TRUE
      complete <- FALSE
      findings <- c(findings, .recovery_finding(
        if (!count) "DEPENDENCY_COLUMN_MISSING" else "DEPENDENCY_COLUMN_AMBIGUOUS",
        paste0("colData$", column),
        "Consumed column {.field {column}} must occur exactly once in the current object.",
        ids = column,
        severity = "warning"
      ))
      next
    }

    values <- annotation[[column]]
    valid_type <- if (role == "time") {
      typeof(values) %in% c("integer", "double") && !is.object(values) && is.null(dim(values))
    } else {
      (is.character(values) || is.factor(values)) && is.null(dim(values))
    }
    ids <- if (role == "episode") retained else included
    if (!valid_type) {
      changed <- TRUE
      complete <- FALSE
      findings <- c(findings, .recovery_finding(
        "DEPENDENCY_VALUE_CHANGED",
        paste0("colData$", column),
        "Consumed column {.field {column}} has an unsupported current type or shape.",
        ids = ids,
        severity = "warning"
      ))
      next
    }
    if (!sample_map || (role == "episode" && !membership_map) ||
          !samples$valid[[fields[[role]]]]) {
      complete <- FALSE
      next
    }

    current_values <- values[match(ids, current$ids)]
    if (is.factor(current_values)) {
      current_values <- as.character(current_values)
    } else if (role == "time") {
      current_values <- as.double(current_values)
    }
    historical <- samples$value[[fields[[role]]]][match(ids, samples$value$sample_id)]
    equal <- (is.na(current_values) & is.na(historical)) |
      (!is.na(current_values) & !is.na(historical) & current_values == historical)
    if (any(!equal)) {
      changed <- TRUE
      findings <- c(findings, .recovery_finding(
        "DEPENDENCY_VALUE_CHANGED",
        paste0("colData$", column),
        "Consumed {.field {column}} values differ from the registration snapshot.",
        ids = ids[!equal],
        severity = "warning"
      ))
    }
  }

  state <- if (changed) {"changed"
  } else if (complete && length(included)) { "unchanged"
  } else { "not_checked"}

  list(state = state, complete = complete, findings = findings)
}
