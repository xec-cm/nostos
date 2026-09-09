.recovery_current_sources <- function(current, reference, deviation) {
  result <- list(assay_state = "unavailable", states = character(), hashes = character())
  if (is.null(reference) || !reference$readable || !current$container_valid ||
        is.null(reference$assay)) {
    return(result)
  }
  count <- sum(SummarizedExperiment::assayNames(current$tse) == reference$assay, na.rm = TRUE)
  if (count != 1L) {
    result$assay_state <- if (!count) "missing" else "ambiguous"
    return(result)
  }
  result$assay_state <- "present"
  if (is.null(reference$features) || !current$features$valid || !current$samples$valid ||
        !all(reference$features %in% current$features$ids)) {
    return(result)
  }

  requested <- unique(c(
    intersect(reference$inputs$ids, reference$input_ids),
    intersect(deviation$inputs$ids, deviation$input_ids)
  ))
  retained <- intersect(requested, current$samples$ids)
  if (!length(retained)) {
    return(result)
  }
  source <- tryCatch(
    SummarizedExperiment::assay(current$tse, reference$assay, withDimnames = FALSE),
    error = identity
  )
  result$states <- structure(rep("unreadable", length(retained)), names = retained)
  result$hashes <- structure(rep(NA_character_, length(retained)), names = retained)
  if (inherits(source, "condition")) {
    return(result)
  }
  feature_rows <- match(reference$features, current$features$ids)
  sample_rows <- match(retained, current$samples$ids)
  hashable <- reference$format_ready || (!is.null(deviation) && deviation$format_ready)
  for (row in seq_along(retained)) {
    checked <- .recovery_current_sample(
      source, feature_rows, sample_rows[[row]], retained[[row]], reference$features, hashable
    )
    result$states[[row]] <- checked$state
    result$hashes[[row]] <- checked$hash
  }

  result
}

.recovery_current_sample <- function(source,
                                     feature_rows,
                                     sample_row,
                                     sample_id,
                                     features,
                                     hashable) {
  # Catch only external extraction/coercion failures, keeping other samples checkable.
  values <- tryCatch(as.matrix(source[feature_rows, sample_row, drop = FALSE]), error = identity)
  if (inherits(values, "condition")) {
    return(list(state = "unreadable", hash = NA_character_))
  }
  numeric <- is.matrix(values) && typeof(values) %in% c("integer", "double") &&
    identical(dim(values), c(length(features), 1L))
  if (!numeric || any(!is.finite(values)) || any(values < 0)) {
    return(list(state = "invalid", hash = NA_character_))
  }
  total <- sum(values)
  if (!is.finite(total) || total <= 0) {
    return(list(state = "invalid", hash = NA_character_))
  }

  list(
    state = "valid",
    hash = if (hashable) .recovery_hash_source(sample_id, features, values) else NA_character_
  )
}

.recovery_compare_sources <- function(stage, parsed, reference, current, sources) {
  result <- .recovery_check_part()
  inputs <- parsed$inputs
  if (!is.null(parsed$input_ids) && !is.null(inputs$ids)) {
    selected <- inputs$ids %in% parsed$input_ids
    inputs$ids <- inputs$ids[selected]
    inputs$hashes <- inputs$hashes[selected]
    inputs$valid <- inputs$valid[selected]
  }
  component <- paste0(stage, "$dependencies$samples")
  if (sources$assay_state %in% c("missing", "ambiguous")) {
    result$findings <- .recovery_finding(
      if (sources$assay_state == "missing") "ASSAY_MISSING" else "ASSAY_AMBIGUOUS",
      component, "The selected assay is missing or ambiguous for {.field {stage}} inputs."
    )
    result$dependencies <- "changed"
    result$complete <- FALSE
  }

  available <- !is.null(reference) && reference$readable &&
    !is.null(reference$features) && !is.null(inputs$ids) && !is.null(parsed$input_ids) &&
    current$container_valid && current$samples$valid && current$features$valid
  if (stage == "reference" && current$samples$valid) {
    removed <- setdiff(parsed$baseline_ids, current$samples$ids)
    if (length(removed)) {
      result$findings <- c(result$findings, .recovery_finding(
        "REFERENCE_INPUT_MISSING", "reference$baseline_samples",
        "Recorded baseline inputs are absent from the current object.",
        ids = removed, severity = "info"
      ))
    }
  }
  if (!is.null(reference$features) && current$features$valid) {
    missing_features <- setdiff(reference$features, current$features$ids)
    if (length(missing_features)) {
      result$findings <- c(result$findings, .recovery_finding(
        "REFERENCE_INPUT_MISSING", "reference$definition$feature_ids",
        "Fixed reference features are absent; the original feature set is preserved.",
        ids = missing_features, severity = "info"
      ))
      available <- FALSE
    }
  }
  if (!available || sources$assay_state != "present") {
    result$complete <- FALSE
    if (result$dependencies != "changed") {
      result$dependencies <- "not_checked"
    }
    return(result)
  }

  retained <- intersect(inputs$ids, current$samples$ids)
  rows <- match(retained, inputs$ids)
  states <- sources$states[retained]
  invalid <- retained[!is.na(states) & states == "invalid"]
  unreadable <- retained[is.na(states) | states == "unreadable"]
  if (length(invalid)) {
    result$findings <- c(result$findings, .recovery_finding(
      "ASSAY_VALUES_INVALID", component,
      "Consumed samples contain invalid abundances or non-positive/non-finite selected totals.",
      ids = invalid
    ))
    result$dependencies <- "changed"
  }
  if (length(unreadable)) {
    result$findings <- c(result$findings, .recovery_finding(
      "ASSAY_READ_FAILED", component,
      "The external assay could not supply these selected sample blocks.", ids = unreadable
    ))
  }
  comparable <- !is.na(states) & states == "valid" &
    !is.na(inputs$valid[rows]) & inputs$valid[rows] & parsed$format_ready
  changed <- retained[comparable & !is.na(sources$hashes[retained]) &
                        sources$hashes[retained] != inputs$hashes[rows]]
  if (length(changed)) {
    result$findings <- c(result$findings, .recovery_finding(
      "ANALYTICAL_INPUT_CHANGED", component,
      "Current source abundances differ from the recorded {.field {stage}} inputs.", ids = changed
    ))
    result$dependencies <- "changed"
  }
  result$complete <- result$complete && length(retained) == length(inputs$ids) &&
    all(comparable) && parsed$format_ready
  if (!result$complete && result$dependencies != "changed") {
    result$dependencies <- "not_checked"
  }

  result
}
