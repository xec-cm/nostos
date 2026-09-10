.recovery_reference_evidence <- function(reference, record, call) {
  baseline <- reference$baseline_samples
  .recovery_reference_table(
    baseline,
    c("sample_id", "episode_id"),
    "reference$baseline_samples",
    call
  )
  registered <- record$registration$samples
  selected <- registered[registered$sample_id %in% reference$definition$sample_ids, , drop = FALSE]
  valid_baseline <- .recovery_valid_ids(baseline$sample_id, unique = TRUE) &&
    .recovery_valid_ids(baseline$episode_id) &&
    identical(as.vector(baseline$sample_id), as.vector(selected$sample_id)) &&
    identical(as.vector(baseline$episode_id), as.vector(selected$episode_id)) &&
    setequal(baseline$sample_id, reference$definition$sample_ids)
  if (!valid_baseline) {
    .recovery_abort(
      "Realized baselines must agree with their declared selection and registered episodes.",
      class = "recoverome_error_namespace",
      component = "reference$baseline_samples",
      call = call
    )
  }

  episodes <- reference$episodes
  .recovery_reference_table(
    episodes,
    c("episode_id", "support", "n_samples", "n_times", "first_time",
      "last_time", "baseline_diameter"),
    "reference$episodes",
    call
  )
  support <- .recovery_reference_support(episodes)
  valid_episodes <- all(support) &&
    identical(as.vector(episodes$episode_id), as.vector(record$episodes$episode_id))
  if (!valid_episodes) {
    .recovery_abort(
      "Reference episodes must retain registered IDs and normalized support, counts and times.",
      class = "recoverome_error_namespace",
      component = "reference$episodes",
      call = call
    )
  }

  profiles <- reference$profiles
  available <- episodes$episode_id[episodes$episode_id %in% baseline$episode_id]
  valid_profiles <- is.matrix(profiles) && is.double(profiles) &&
    identical(as.character(rownames(profiles)), as.vector(reference$definition$feature_ids)) &&
    identical(as.character(colnames(profiles)), as.vector(available))
  if (!valid_profiles) {
    .recovery_abort(
      "Reference profiles must be double matrices matching fixed features and baseline episodes.",
      class = "recoverome_error_namespace",
      component = "reference$profiles",
      call = call
    )
  }

  totals <- colSums(profiles)
  if (any(!is.finite(profiles)) || any(profiles < 0) ||
        any(!is.finite(totals)) || any(totals <= 0)) {
    .recovery_abort(
      "Stored reference profiles must have finite non-negative values and positive totals.",
      class = "recoverome_error_namespace",
      component = "reference$profiles",
      call = call
    )
  }

  dependencies <- reference$dependencies
  if (!.recovery_named_list(dependencies) ||
        !setequal(names(dependencies), c("registration_sha256", "samples")) ||
        !.recovery_valid_sha256(dependencies$registration_sha256) ||
        length(dependencies$registration_sha256) != 1L) {
    .recovery_abort(
      "Reference dependencies must record the parent fingerprint and baseline source hashes.",
      class = "recoverome_error_namespace",
      component = "reference$dependencies",
      call = call
    )
  }
  inputs <- dependencies$samples
  .recovery_reference_table(
    inputs,
    c("sample_id", "input_sha256"),
    "reference$dependencies$samples",
    call
  )
  if (!.recovery_valid_ids(inputs$sample_id, unique = TRUE) ||
        !identical(as.vector(inputs$sample_id), as.vector(baseline$sample_id)) ||
        !.recovery_valid_sha256(inputs$input_sha256)) {
    .recovery_abort(
      "Reference input fingerprints must identify every realized baseline in registered order.",
      class = "recoverome_error_namespace",
      component = "reference$dependencies$samples",
      call = call
    )
  }
}
