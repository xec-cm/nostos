.recovery_view_selector <- function(value, label, choices, call) {
  .recovery_check_string(value, label, call = call)
  if (!value %in% choices) {
    .recovery_abort(
      "{.arg {label}} must be exactly one of {.val {choices}}.",
      component = label, call = call
    )
  }
}

.recovery_view_reject <- function(findings, call) {
  if (!nrow(findings)) {
    return(invisible(NULL))
  }
  component <- findings$component[[1L]]
  .recovery_abort(
    c(
      "Cannot extract coherent saved results from {.field {component}}.",
      i = "{findings$message[[1L]]}"
    ),
    component = component,
    ids = findings$ids[[1L]],
    call = call
  )
}

.recovery_view_context <- function(tse, analysis_id, level, call) {
  report <- .recovery_validate_input(tse, analysis_id, call, allow_all = FALSE)
  findings <- report$diagnostics
  stage <- sub("\\$.*$", "", findings$component)
  analytical <- stage %in% c("reference", "deviation", "recovery")
  extra <- findings$code == "STAGE_UNSUPPORTED" & findings$component == "analysis"
  .recovery_view_reject(findings[findings$severity == "error" & !analytical & !extra, ], call)
  if (nrow(report$summary) != 1L) {
    .recovery_abort("The selected analysis is unavailable.", component = "analysis_id", call = call)
  }

  record <- S4Vectors::metadata(tse)$recoverome$analyses[[analysis_id]]
  present <- intersect(c("reference", "deviation", "recovery"), names(record))
  missing_parent <- ("deviation" %in% present && !"reference" %in% present) ||
    ("recovery" %in% present && !all(c("reference", "deviation") %in% present))
  if (missing_parent) {
    .recovery_abort(
      "A downstream result lacks its required parent record.",
      component = "analysis", ids = present, call = call
    )
  }
  required <- if (level == "plot") {
    c("reference", "deviation", "recovery")
  } else if (level == "sample" || "recovery" %in% present) {
    c("reference", "deviation", if (level == "episode") "recovery")
  } else {
    "reference"
  }
  unknown <- findings$code == "SCHEMA_UNSUPPORTED" & analytical
  optional <- unknown & !stage %in% required
  .recovery_view_reject(findings[unknown & !optional, ], call)
  uninterpreted <- unique(c(stage[optional], unlist(findings$ids[extra], use.names = FALSE)))
  allowed <- findings$code %in% c(
    "ASSAY_MISSING", "ASSAY_AMBIGUOUS", "ASSAY_VALUES_INVALID", "ASSAY_READ_FAILED",
    "ANALYTICAL_INPUT_CHANGED", "FINGERPRINT_FORMAT_UNSUPPORTED"
  )
  incoherent <- findings$severity == "error" & !allowed & !optional & !extra
  .recovery_view_reject(findings[incoherent, ], call)
  stages <- lapply(c("reference", "deviation", "recovery"), function(name) {
    if (name %in% uninterpreted) NULL else record[[name]]
  })
  names(stages) <- c("reference", "deviation", "recovery")

  list(
    record = record,
    stages = stages,
    report = report,
    uninterpreted = uninterpreted,
    sample_ids = colnames(tse),
    feature_ids = rownames(tse),
    annotation = SummarizedExperiment::colData(tse)
  )
}

.recovery_view_additions <- function(context, call) {
  sample_ids <- setdiff(context$sample_ids, context$record$scope$sample_ids)
  feature_ids <- setdiff(context$feature_ids, context$record$scope$feature_ids)
  if (!length(sample_ids) && !length(feature_ids)) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c("New identities are not enrolled in this saved analysis.",
      i = "{length(sample_ids)} added sample IDs and {length(feature_ids)} added feature IDs."),
    class = c("recoverome_warning_scope", "recoverome_warning"),
    component = "scope", ids = unique(c(sample_ids, feature_ids)),
    sample_ids = sample_ids, feature_ids = feature_ids, call = call
  )
}
