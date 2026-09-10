.recovery_hash_deviation <- function(deviation) {
  .recovery_fingerprint(list(
    schema_version = deviation$schema_version,
    method = as.vector(deviation$method),
    columns = deviation$columns[c("deviation", "status")],
    sample_ids = as.vector(deviation$sample_ids),
    dependencies = list(
      reference_sha256 = as.vector(deviation$dependencies$reference_sha256),
      samples = .recovery_project_table(
        deviation$dependencies$samples, c("sample_id", "input_sha256")
      )
    ),
    results = .recovery_project_table(deviation$results, c("sample_id", "result_sha256")),
    provenance = deviation$provenance[c("package_version", "created_at", "fingerprint_format")]
  ))
}

.recovery_hash_recovery <- function(recovery) {
  columns <- c(
    "episode_id", "status", "reason", "coverage", "first_perturbation_time", "first_return_time",
    "candidate_time", "confirmation_time", "rebound_time", "last_observed_time", "n_window_visits"
  )
  fields <- c(
    "evaluated", "coverage", "perturbation", "first_return", "candidate",
    "confirmation", "confirmation_run", "rebound", "blocking_events"
  )
  .recovery_fingerprint(list(
    schema_version = recovery$schema_version,
    definition = recovery$definition[c(
      "method", "threshold", "persistence", "max_gap", "horizon", "time_unit"
    )],
    episodes = .recovery_project_table(recovery$episodes, columns),
    evidence = lapply(recovery$evidence, function(value) value[fields]),
    dependencies = recovery$dependencies[c(
      "registration_sha256", "reference_sha256", "deviation_sha256", "sample_ids", "feature_ids"
    )],
    provenance = recovery$provenance[c("package_version", "created_at", "fingerprint_format")]
  ))
}
