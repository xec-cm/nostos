.recovery_sensitivity_scenario <- function(context, samples, rule, reason, call) {
  # Clear only the local projection: never reuse old outcomes as scenario results.
  projection <- context
  projection$stages$recovery <- NULL
  view <- .recovery_episode_view(projection, "historical")
  table <- view$table
  evidence <- NULL
  if (is.na(reason)) {
    values <- as.list(rule[, c("threshold", "persistence", "max_gap", "horizon")])
    record <- context$record
    calculated <- lapply(seq_len(nrow(record$episodes)), function(row) {
      .recovery_episode_outcome(record$episodes[row, ], record, samples, values, call)
    })
    outcomes <- do.call(rbind, lapply(calculated, function(value) {
      do.call(S4Vectors::DataFrame, value$outcome)
    }))
    fields <- setdiff(names(outcomes), "episode_id")
    table[fields] <- outcomes[fields]
    evidence <- structure(lapply(calculated, `[[`, "evidence"), names = table$episode_id)
  }
  summary <- context$report$summary
  header <- rule[rep(1L, nrow(table)), , drop = FALSE]
  header$evaluation_state <- rep(if (is.na(reason)) "evaluated" else "not_evaluable", nrow(table))
  header$evaluation_reason <- rep(reason, nrow(table))
  table <- cbind(header, table)
  table$structural_valid <- rep(summary$structural_valid, nrow(table))
  table$validation_complete <- rep(summary$validation_complete, nrow(table))
  table$dependencies <- rep(summary$dependencies, nrow(table))
  table$current_present <- view$present

  list(table = table, evidence = evidence)
}

.recovery_sensitivity_metadata <- function(context, analysis_id, rules, evidence) {
  analysis <- .recovery_view_metadata(context, unname(analysis_id), "episode", "historical")
  list(
    schema_version = 1L,
    rules = rules,
    validation = context$report,
    analysis = analysis,
    evidence = evidence,
    provenance = list(
      package_version = as.character(utils::packageVersion("recoverome")),
      created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      method = "observed_run_v1",
      fingerprint_format = "recoverome_sensitivity_snapshot_v1",
      parents = analysis$provenance[c("registration", "reference", "deviation")]
    )
  )
}

.recovery_sensitivity_hash <- function(table, context) {
  context$fingerprint <- NULL
  # Snapshot tables and context only; never serialize assay backends or the TSE.
  digest::digest(list(columns = as.list(table), context = context),
                 algo = "sha256", serializeVersion = 2)
}
