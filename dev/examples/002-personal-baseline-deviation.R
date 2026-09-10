# Arithmetic evidence for proposed RFC 002, not a package implementation.
# From the repository, run with the development package loaded:
# Rscript --vanilla -e 'pkgload::load_all();
#   source("dev/examples/002-personal-baseline-deviation.R")'
# Expected values are independent of the calculations they check. No proposed
# add_reference/add_deviation function is called.

# Equal sample weights: close each baseline before averaging.
baseline_counts <- matrix(
  c(8, 2, 0, 60, 40, 0, 7, 3, 0),
  nrow = 3L,
  dimnames = list(c("a", "b", "c"), c("b1", "b2", "b3"))
)
baseline_compositions <- sweep(baseline_counts, 2L, colSums(baseline_counts), "/")
reference <- rowMeans(baseline_compositions)
baseline_diameter <- max(stats::dist(t(baseline_compositions), method = "manhattan")) / 2

stopifnot(
  max(abs(reference - c(0.7, 0.3, 0))) < 1e-12,
  abs(baseline_diameter - 0.2) < 1e-12
)

# Pooling reads would give a different reference because sample totals differ.
pooled_composition <- rowSums(baseline_counts) / sum(baseline_counts)
stopifnot(max(abs(pooled_composition - reference)) > 0.07)

# Compare a sample with the fixed three-baseline reference.
query_composition <- c(a = 4, b = 4, c = 2) / 10
full_deviation <- sum(abs(query_composition - reference)) / 2
stopifnot(abs(full_deviation - 0.3) < 1e-12)

# Changing the explicit baseline selection changes the reference.
single_deviation <- sum(abs(query_composition - baseline_compositions[, "b1"])) / 2
stopifnot(abs(single_deviation - 0.4) < 1e-12)

alternative_reference <- rowMeans(baseline_compositions[, c("b1", "b3"), drop = FALSE])
alternative_deviation <- sum(abs(query_composition - alternative_reference)) / 2
stopifnot(
  max(abs(alternative_reference - c(0.75, 0.25, 0))) < 1e-12,
  abs(alternative_deviation - 0.35) < 1e-12
)

# Changing features requires a new closure for each sample and a new reference.
subset_query <- query_composition[c("a", "b")] / sum(query_composition[c("a", "b")])
subset_baseline_counts <- baseline_counts[c("a", "b"), , drop = FALSE]
subset_baseline <- sweep(
  subset_baseline_counts,
  2L,
  colSums(subset_baseline_counts),
  "/"
)
subset_reference <- rowMeans(subset_baseline)
subset_deviation <- sum(abs(subset_query - subset_reference)) / 2
stopifnot(abs(subset_deviation - 0.2) < 1e-12)

# A nonzero removed feature exposes the error of closing an old mean profile.
counterexample_counts <- matrix(
  c(8, 2, 90, 60, 40, 0),
  nrow = 3L,
  dimnames = list(c("a", "b", "c"), c("b1", "b2"))
)
full_counterexample <- sweep(
  counterexample_counts,
  2L,
  colSums(counterexample_counts),
  "/"
)
new_counts <- counterexample_counts[c("a", "b"), , drop = FALSE]
new_compositions <- sweep(new_counts, 2L, colSums(new_counts), "/")
new_reference <- rowMeans(new_compositions)
old_reference_subset <- rowMeans(full_counterexample)[c("a", "b")]
reclosed_old_reference <- old_reference_subset / sum(old_reference_subset)
stopifnot(
  max(abs(new_reference - c(0.7, 0.3))) < 1e-12,
  max(abs(reclosed_old_reference - c(34 / 55, 21 / 55))) < 1e-12,
  max(abs(new_reference - reclosed_old_reference)) > 0.08
)

# Repeated episodes use separate references in the bundled registration case.
utils::data("recovery_examples", package = "nostos")
example_data <- recovery_examples$repeated_episodes
episode_1_samples <- c("s1", "s2", "s3")
episode_2_samples <- c("s4", "s5")
repeated_counts <- example_data$counts[, c(episode_1_samples, episode_2_samples), drop = FALSE]
repeated_compositions <- sweep(repeated_counts, 2L, colSums(repeated_counts), "/")
reference_e1 <- repeated_compositions[, "s1"]
reference_e2 <- repeated_compositions[, "s4"]
repeated_deviation <- c(
  colSums(abs(repeated_compositions[, episode_1_samples, drop = FALSE] - reference_e1)) / 2,
  colSums(abs(repeated_compositions[, episode_2_samples, drop = FALSE] - reference_e2)) / 2
)
stopifnot(
  max(abs(unname(repeated_deviation) - c(0, 2 / 21, 4 / 33, 0, 2 / 285))) < 1e-12,
  is.na(example_data$col_data["s6", "episode_id"])
)

# Being before the end boundary is insufficient: the baseline must precede start.
second_event <- example_data$events[example_data$events$event_id == "ab2", , drop = FALSE]
during_event_time <- 41
stopifnot(
  identical(second_event$start_time, 40),
  identical(second_event$end_time, 42),
  example_data$col_data["s4", "time"] < second_event$start_time,
  during_event_time - second_event$end_time < 0,
  !(during_event_time < second_event$start_time)
)

print(c(
  full = full_deviation,
  single_baseline = single_deviation,
  alternative_selection = alternative_deviation,
  changed_feature_scope = subset_deviation
))
print(repeated_deviation)
