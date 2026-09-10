# Shared field predicates; each caller retains its own failure/diagnostic policy.
.recovery_reference_definition <- function(value) {
  fields <- c("sample_ids", "assay", "feature_ids", "preprocessing", "normalization", "estimator")
  if (!.recovery_named_list(value)) {
    return(stats::setNames(rep(FALSE, length(fields) + 1L), c("fields", fields)))
  }

  c(
    fields = setequal(names(value), fields),
    sample_ids = .recovery_valid_ids(value$sample_ids, unique = TRUE),
    assay = .recovery_valid_text(value$assay),
    feature_ids = .recovery_valid_ids(value$feature_ids, unique = TRUE) &&
      length(value$feature_ids) > 0L,
    preprocessing = .recovery_valid_text(value$preprocessing),
    normalization = identical(value$normalization, "closure_v1"),
    estimator = identical(value$estimator, "sample_mean_v1")
  )
}

# value is already a valid DataFrame with the required support columns.
.recovery_reference_support <- function(value) {
  counts <- vapply(c("n_samples", "n_times"), function(column) {
    x <- value[[column]]
    is.integer(x) && !is.object(x) && is.null(dim(x)) && !anyNA(x) && all(x >= 0L)
  }, logical(1))
  times <- vapply(c("first_time", "last_time", "baseline_diameter"), function(column) {
    x <- value[[column]]
    is.double(x) && !is.object(x) && is.null(dim(x))
  }, logical(1))

  c(
    episode_id = .recovery_valid_ids(value$episode_id, unique = TRUE),
    support = .recovery_valid_ids(value$support) &&
      all(value$support %in% c("missing_baseline", "single_sample",
                               "single_time", "multiple_times")),
    counts = all(counts), times = all(times)
  )
}
