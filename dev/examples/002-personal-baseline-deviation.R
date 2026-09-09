# Arithmetic evidence for proposed RFC 002, not a package implementation.
# From the repository, run with the development package loaded:
# Rscript --vanilla -e 'pkgload::load_all();
#   source("dev/examples/002-personal-baseline-deviation.R")'

# Reuse the shipped registration example. Expected values below are stated
# independently; there are no calls to proposed add_reference/add_deviation.
utils::data("recovery_examples", package = "recoverome")
example_data <- recovery_examples$repeated_episodes
counts <- example_data$counts[, 1:5, drop = FALSE]
composition <- sweep(counts, 2L, colSums(counts), "/")
reference_e1 <- composition[, "s1"]
reference_e2 <- composition[, "s4"]
repeated_deviation <- c(
  colSums(abs(composition[, 1:3, drop = FALSE] - reference_e1)) / 2,
  colSums(abs(composition[, 4:5, drop = FALSE] - reference_e2)) / 2
)

stopifnot(
  max(abs(unname(repeated_deviation) - c(0, 2 / 21, 4 / 33, 0, 2 / 285))) < 1e-12,
  is.na(example_data$col_data$episode_id[6L]),
  identical(example_data$events$start_time, c(10, 40)),
  identical(example_data$events$end_time, c(14, 42)),
  example_data$col_data$time[4L] < 40,
  41 - 42 < 0,
  !(41 < 40)
)

# A separate hand-worked composition shows how read totals, explicit selection
# and feature removal affect the proposed descriptive quantity.
baseline_counts <- matrix(
  c(8, 2, 0, 60, 40, 0, 7, 3, 0),
  nrow = 3L,
  dimnames = list(c("a", "b", "c"), c("b1", "b2", "b3"))
)
baseline <- sweep(baseline_counts, 2L, colSums(baseline_counts), "/")
reference <- rowMeans(baseline)
query <- c(4, 4, 2) / 10
full_deviation <- sum(abs(query - reference)) / 2
single_deviation <- sum(abs(query - baseline[, "b1"])) / 2
alternative_reference <- rowMeans(baseline[, c("b1", "b3"), drop = FALSE])
alternative_deviation <- sum(abs(query - alternative_reference)) / 2
baseline_diameter <- max(stats::dist(t(baseline), method = "manhattan")) / 2

# Equal sample weighting differs from pooling read counts.
pooled <- rowSums(baseline_counts) / sum(baseline_counts)
subset_query <- query[1:2] / sum(query[1:2])
subset_baseline_counts <- baseline_counts[1:2, , drop = FALSE]
subset_baseline <- sweep(
  subset_baseline_counts, 2L, colSums(subset_baseline_counts), "/"
)
subset_reference <- rowMeans(subset_baseline)
subset_deviation <- sum(abs(subset_query - subset_reference)) / 2

stopifnot(
  max(abs(reference - c(0.7, 0.3, 0))) < 1e-12,
  abs(full_deviation - 0.3) < 1e-12,
  abs(single_deviation - 0.4) < 1e-12,
  max(abs(alternative_reference - c(0.75, 0.25, 0))) < 1e-12,
  abs(alternative_deviation - 0.35) < 1e-12,
  abs(baseline_diameter - 0.2) < 1e-12,
  abs(subset_deviation - 0.2) < 1e-12,
  max(abs(pooled - reference)) > 0.07
)

print(repeated_deviation)
print(c(
  full = full_deviation,
  single_baseline = single_deviation,
  alternative_selection = alternative_deviation,
  changed_feature_scope = subset_deviation
))

# A nonzero removed feature distinguishes the required operation from
# incorrectly closing an already averaged reference.
counterexample_counts <- matrix(c(8, 2, 90, 60, 40, 0), nrow = 3L)
full_counterexample <- sweep(
  counterexample_counts, 2L, colSums(counterexample_counts), "/"
)
new_counts <- counterexample_counts[1:2, , drop = FALSE]
new_compositions <- sweep(new_counts, 2L, colSums(new_counts), "/")
new_reference <- rowMeans(new_compositions)
old_reference_subset <- rowMeans(full_counterexample)[1:2]
reclosed_old_reference <- old_reference_subset / sum(old_reference_subset)
stopifnot(
  max(abs(new_reference - c(0.7, 0.3))) < 1e-12,
  max(abs(reclosed_old_reference - c(34 / 55, 21 / 55))) < 1e-12,
  max(abs(new_reference - reclosed_old_reference)) > 0.08
)
