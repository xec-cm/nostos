.recovery_deviation_sources <- function(tse, context, reference, call) {
  feature_ids <- reference$definition$feature_ids
  baseline_ids <- reference$baseline_samples$sample_id
  .recovery_bad_rows(
    !feature_ids %in% context$features,
    "reference$definition$feature_ids",
    "requires every fixed reference feature to remain available",
    ids = feature_ids,
    call = call
  )
  .recovery_bad_rows(
    !baseline_ids %in% context$samples,
    "reference$baseline_samples",
    "requires every baseline input to remain available before computing deviations",
    ids = baseline_ids,
    call = call
  )

  registered <- context$record$registration$samples
  retained_ids <- intersect(context$samples, registered$sample_id)
  samples <- registered[match(retained_ids, registered$sample_id), , drop = FALSE]
  samples <- samples[samples$episode_id %in% colnames(reference$profiles), , drop = FALSE]
  values <- .recovery_assay_block(
    tse,
    reference$definition$assay,
    feature_ids,
    samples$sample_id,
    context,
    call
  )

  # Baselines are among these computed samples; use the same block for both jobs.
  input_sha256 <- vapply(seq_len(ncol(values)), function(sample) {
    .recovery_hash_source(samples$sample_id[[sample]], feature_ids, values[, sample])
  }, character(1))
  baseline_rows <- match(baseline_ids, samples$sample_id)
  changed <- input_sha256[baseline_rows] != reference$dependencies$samples$input_sha256
  .recovery_bad_rows(
    changed,
    "reference$dependencies$samples",
    "differs from the recorded baseline abundances",
    ids = baseline_ids,
    call = call
  )

  list(values = values, samples = samples, input_sha256 = input_sha256)
}

.recovery_deviation_values <- function(context, reference, sources) {
  sample_ids <- context$samples
  deviation <- rep(NA_real_, length(sample_ids))
  status <- rep("excluded", length(sample_ids))
  included <- sample_ids %in% context$record$registration$samples$sample_id
  status[included] <- "missing_baseline"

  compositions <- sweep(sources$values, 2L, colSums(sources$values), "/")
  profiles <- reference$profiles[, sources$samples$episode_id, drop = FALSE]
  distances <- colSums(abs(compositions - profiles)) / colSums(compositions + profiles)
  computed_rows <- match(sources$samples$sample_id, sample_ids)
  deviation[computed_rows] <- distances
  status[computed_rows] <- "computed"

  list(deviation = deviation, status = status)
}
