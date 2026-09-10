.recovery_sensitivity_rules <- function(rules, call) {
  columns <- c("scenario_id", "threshold", "persistence", "max_gap", "horizon")
  table <- is.data.frame(rules) || methods::is(rules, "DataFrame")
  if (!table || nrow(rules) == 0L || length(names(rules)) != length(columns) ||
        anyDuplicated(names(rules)) || !setequal(names(rules), columns)) {
    .recovery_abort(
      "{.arg rules} must be a nonempty table with exactly {.field {columns}}.",
      component = "rules", call = call
    )
  }
  ids <- rules$scenario_id
  if (!.recovery_valid_ids(ids, unique = TRUE)) {
    .recovery_abort(
      "{.field scenario_id} must contain unique, nonempty, unpadded character IDs.",
      component = "rules$scenario_id", ids = as.character(ids), call = call
    )
  }
  matrix_columns <- vapply(rules[columns[-1L]], function(value) !is.null(dim(value)), logical(1))
  if (any(matrix_columns)) {
    .recovery_abort(
      "Rule columns must be vectors, not matrices or arrays.",
      component = "rules", ids = ids, call = call
    )
  }
  values <- lapply(seq_len(nrow(rules)), function(row) {
    rule <- lapply(rules[columns[-1L]], `[`, row)
    # Preserve the shared rule validator's cause and expose the scenario identity.
    tryCatch(.recovery_rule(rule, call), recoverome_error = function(error) {
      .recovery_abort(
        c("Invalid rule in scenario {.val {ids[[row]]}}.", i = "{conditionMessage(error)}"),
        component = "rules", ids = ids[[row]], call = call, parent = error
      )
    })
  })
  normalized <- do.call(rbind, lapply(values, function(value) {
    do.call(S4Vectors::DataFrame, value)
  }))

  cbind(S4Vectors::DataFrame(scenario_id = as.vector(ids)), normalized)
}

.recovery_sensitivity_reason <- function(context) {
  report <- context$report
  codes <- report$diagnostics$code
  missing_assay <- "ASSAY_MISSING" %in% codes
  # The validator also calls an absent assay "changed". Distinguish availability
  # here without hiding an independently demonstrated source change.
  source_changed <- any(codes %in% c("ANALYTICAL_INPUT_CHANGED", "ASSAY_VALUES_INVALID",
                                     "ASSAY_AMBIGUOUS"))
  if (report$summary$dependencies == "changed" && (!missing_assay || source_changed)) {
    return("inputs_changed")
  }
  record <- context$record
  required_samples <- union(
    record$reference$baseline_samples$sample_id, record$deviation$sample_ids
  )
  missing <- !all(required_samples %in% context$sample_ids) ||
    !all(record$reference$definition$feature_ids %in% context$feature_ids) ||
    missing_assay
  if (missing) return("historical_inputs_unavailable")
  if (!isTRUE(report$summary$structural_valid) || !isTRUE(report$summary$validation_complete)) {
    return("validation_incomplete")
  }

  NA_character_
}
