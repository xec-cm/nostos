.recovery_rule <- function(rule, call) {
  fields <- c("threshold", "persistence", "max_gap", "horizon")
  if (!.recovery_named_list(rule) || !setequal(names(rule), fields)) {
    .recovery_abort(
      "{.arg rule} must be a plain list with exactly {.field {fields}}.",
      component = "rule", call = call
    )
  }
  valid <- vapply(rule[fields], function(value) {
    typeof(value) %in% c("integer", "double") && !is.object(value) &&
      is.null(dim(value)) && length(value) == 1L && is.finite(value)
  }, logical(1))
  if (!all(valid)) {
    .recovery_abort(
      "Rule fields must be ordinary finite numeric scalars: {.field {fields[!valid]}}.",
      component = "rule", ids = fields[!valid], call = call
    )
  }
  values <- lapply(rule[fields], as.double)
  valid <- c(
    threshold = values$threshold >= 0 && values$threshold <= 1,
    persistence = values$persistence > 0,
    max_gap = values$max_gap > 0,
    horizon = values$horizon > 0
  )
  if (!all(valid)) {
    .recovery_abort(
      c(
        "Rule fields are outside their allowed ranges: {.field {fields[!valid]}}.",
        i = "threshold must be in [0, 1]; persistence, max_gap and horizon must be positive."
      ),
      component = "rule", ids = fields[!valid], call = call
    )
  }

  values
}

.recovery_outcome_context <- function(tse, analysis_id, call) {
  report <- .recovery_validate_input(tse, analysis_id, call, allow_all = FALSE)
  summary <- report$summary
  usable <- nrow(summary) == 1L && isTRUE(summary$structural_valid) &&
    isTRUE(summary$validation_complete) && summary$dependencies != "changed"
  if (!usable) {
    .recovery_abort(
      c(
        "Analysis {.val {analysis_id}} cannot supply fully checked, current dependencies.",
        i = "Inspect {.fun validate_recovery} before calculating a new outcome."
      ),
      component = "analysis_id", ids = analysis_id, call = call
    )
  }

  root <- S4Vectors::metadata(tse)
  record <- root$recoverome$analyses[[analysis_id]]
  if ("recovery" %in% names(record)) {
    .recovery_abort(
      "Analysis {.val {analysis_id}} already has recovery outcomes; use a new analysis name.",
      class = "recoverome_error_collision", component = "recovery", call = call
    )
  }
  if (!all(c("reference", "deviation") %in% names(record))) {
    .recovery_abort(
      "Analysis {.val {analysis_id}} requires both a reference and deviations.",
      component = "analysis_id", ids = analysis_id, call = call
    )
  }
  if (!setequal(colnames(tse), record$deviation$sample_ids) ||
        !summary$feature_scope %in% c("same", "subset")) {
    .recovery_abort(
      c(
        "Recovery requires the complete realized deviation sample scope.",
        i = "Reordering and removal of unselected original features are allowed."
      ),
      component = "scope", call = call
    )
  }

  samples <- record$registration$samples
  samples <- samples[samples$sample_id %in% record$deviation$sample_ids, , drop = FALSE]
  annotation <- SummarizedExperiment::colData(tse)
  rows <- match(samples$sample_id, colnames(tse))
  samples$deviation <- annotation[[record$deviation$columns[["deviation"]]]][rows]
  status <- annotation[[record$deviation$columns[["status"]]]][rows]
  has_reference <- samples$episode_id %in% colnames(record$reference$profiles)
  expected <- ifelse(has_reference, "computed", "missing_baseline")
  if (any(status != expected)) {
    .recovery_abort(
      "Included sample statuses do not agree with their episode references.",
      component = "deviation", ids = samples$sample_id[status != expected], call = call
    )
  }

  list(root = root, record = record, samples = samples)
}
