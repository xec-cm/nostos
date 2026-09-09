.recovery_reference_context <- function(tse, analysis_id, call) {
  if (!methods::is(tse, "TreeSummarizedExperiment")) {
    .recovery_abort(
      "{.arg tse} must be a {.cls TreeSummarizedExperiment}.",
      component = "tse",
      call = call
    )
  }
  validity <- methods::validObject(tse, test = TRUE)
  if (!identical(validity, TRUE)) {
    .recovery_abort(
      c("{.arg tse} fails formal S4 validity.", x = "{paste(validity, collapse = '; ')}"),
      component = "tse",
      call = call
    )
  }

  root <- S4Vectors::metadata(tse)
  namespace <- .recovery_validation_namespace(root)
  if (!namespace$readable) {
    finding <- namespace$findings[[1L]]
    .recovery_abort(
      "{finding$message}",
      class = "recoverome_error_namespace",
      component = finding$component,
      ids = finding$ids,
      call = call
    )
  }
  if (!analysis_id %in% names(namespace$analyses)) {
    .recovery_abort(
      "Analysis {.val {analysis_id}} must already be registered.",
      component = "analysis_id",
      ids = analysis_id,
      call = call
    )
  }
  record <- namespace$analyses[[analysis_id]]
  occupied <- intersect(c("reference", "deviation", "recovery"), names(record))
  if (length(occupied)) {
    .recovery_abort(
      c(
        "Analysis {.val {analysis_id}} already contains stage(s) {.val {occupied}}.",
        i = "Register a new analysis name to attach a different reference."
      ),
      class = "recoverome_error_collision",
      component = "analysis_id",
      ids = analysis_id,
      call = call
    )
  }

  current <- list(
    container_valid = TRUE,
    samples = .recovery_validation_axis(colnames(tse), ncol(tse), "sample"),
    features = .recovery_validation_axis(rownames(tse), nrow(tse), "feature"),
    annotation = SummarizedExperiment::colData(tse)
  )
  checked <- .recovery_validate_analysis(analysis_id, namespace$analyses, current)
  summary <- checked$summary
  usable <- isTRUE(summary$structural_valid) && summary$validation_complete &&
    summary$dependencies != "changed" &&
    summary$sample_scope %in% c("same", "subset", "empty") &&
    summary$feature_scope %in% c("same", "subset", "empty")
  if (!usable) {
    findings <- c(current$samples$findings, current$features$findings, checked$findings)
    problems <- vapply(findings, function(finding) finding$severity != "info", logical(1))
    finding <- findings[problems][[1L]]
    stored_problem <- finding$code %in% c(
      "REGISTRATION_RECORD_INVALID", "SCHEMA_UNSUPPORTED", "STAGE_UNSUPPORTED"
    )
    error_class <- if (stored_problem) "recoverome_error_namespace" else "recoverome_error_input"
    .recovery_abort(
      c(
        "Analysis {.val {analysis_id}} cannot supply a current registration.",
        x = "{finding$message}"
      ),
      class = error_class,
      component = finding$component,
      ids = finding$ids,
      call = call
    )
  }

  list(root = root, record = record, samples = current$samples$ids, features = current$features$ids)
}

.recovery_reference_ids <- function(value, label, call) {
  if (!.recovery_valid_ids(value, unique = TRUE)) {
    .recovery_abort(
      "{.arg {label}} must be a unique character vector of non-missing, non-empty, unpadded IDs.",
      component = label,
      ids = if (is.character(value)) as.vector(value) else character(),
      call = call
    )
  }

  as.vector(value)
}

.recovery_reference_selection <- function(context, reference, features, call) {
  sample_ids <- .recovery_reference_ids(reference, "reference", call)
  feature_ids <- if (is.null(features)) {
    context$features
  } else {
    .recovery_reference_ids(features, "features", call)
  }
  if (!length(feature_ids)) {
    .recovery_abort(
      "{.arg features} must resolve to at least one retained feature.",
      component = "features",
      call = call
    )
  }
  .recovery_bad_rows(
    !feature_ids %in% context$features,
    "features",
    "contains IDs absent from the current object",
    ids = feature_ids,
    call = call
  )

  record <- context$record
  samples <- record$registration$samples
  eligible <- intersect(context$samples, samples$sample_id)
  .recovery_bad_rows(
    !sample_ids %in% eligible,
    "reference",
    "contains IDs absent from the current included samples",
    ids = sample_ids,
    call = call
  )
  selected <- samples[samples$sample_id %in% sample_ids, , drop = FALSE]
  episode_rows <- match(selected$episode_id, record$episodes$episode_id)
  event_ids <- record$episodes$origin_event_id[episode_rows]
  event_rows <- match(event_ids, record$events$event_id)
  .recovery_bad_rows(
    selected$time >= record$events$start_time[event_rows],
    "reference",
    "must precede the start of their episode's origin event, even when its origin is the end",
    ids = selected$sample_id,
    call = call
  )

  list(sample_ids = sample_ids, feature_ids = as.vector(feature_ids), samples = selected)
}

.recovery_reference_assay <- function(tse, assay, selection, context, call) {
  .recovery_check_string(assay, "assay", call = call)
  count <- sum(SummarizedExperiment::assayNames(tse) == assay, na.rm = TRUE)
  if (count != 1L) {
    .recovery_abort(
      "{.arg assay} {.val {assay}} must name exactly one current assay.",
      component = "assay",
      ids = assay,
      call = call
    )
  }

  sample_ids <- selection$samples$sample_id
  feature_ids <- selection$feature_ids
  if (!length(sample_ids)) {
    return(matrix(
      numeric(),
      nrow = length(feature_ids),
      ncol = 0L,
      dimnames = list(feature_ids, NULL)
    ))
  }

  # Subset the backing assay before coercion, including for delayed storage.
  source <- SummarizedExperiment::assay(tse, assay, withDimnames = FALSE)
  values <- as.matrix(source[
    match(feature_ids, context$features),
    match(sample_ids, context$samples),
    drop = FALSE
  ])
  if (!is.matrix(values) || !typeof(values) %in% c("integer", "double")) {
    .recovery_abort(
      "Selected {.arg assay} values must form an integer or double matrix.",
      component = "assay",
      ids = sample_ids,
      call = call
    )
  }
  .recovery_bad_rows(
    colSums(!is.finite(values) | values < 0) > 0,
    "assay",
    "contains non-finite or negative selected abundances",
    ids = sample_ids,
    call = call
  )
  totals <- colSums(values)
  .recovery_bad_rows(
    !is.finite(totals) | totals <= 0,
    "assay",
    "must have finite, strictly positive totals over the selected features",
    ids = sample_ids,
    call = call
  )

  matrix(as.double(values), nrow = length(feature_ids), dimnames = list(feature_ids, sample_ids))
}
