# Assisted-by: OpenAI Codex; see inst/PROVENANCE.md.
# From the repository root: Rscript --vanilla dev/qualification/run.R
# Development-only requirements: pkgload and vegan. No network is used.
pkgload::load_all(quiet = TRUE)
stopifnot(requireNamespace("vegan", quietly = TRUE))
output_dir <- "dev/qualification/results"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
primary_rule <- list(threshold = 0.25, persistence = 4, max_gap = 3, horizon = 10)
trajectories <- list(
  return = c(.75, .25, .125, .125, .125, .125),
  rebound = c(.75, .25, .125, .125, .50, .125),
  persistent = rep(.75, 6),
  unperturbed = rep(.125, 6)
)

synthetic_input <- function(scenario, baseline = "stable", schedule = "full",
                            discordant = FALSE, depth = NULL) {
  second <- c(0, if (baseline == "stable") 0 else .4, trajectories[[scenario]])
  times <- c(-4, -2, 0, 2, 4, 6, 8, 10)
  if (schedule == "irregular") {
    times <- c(-4, -2, 0, 1, 4, 7, 9, 10)
  }
  if (discordant) {
    second <- c(second, .75)
    times <- c(times, 2)
  }
  abundance <- rbind(1 - second, second) * 1000
  if (!is.null(depth)) {
    abundance <- vapply(second, function(value) {
      as.double(stats::rmultinom(1, depth, c(1 - value, value)))
    }, numeric(2))
  }
  ids <- c("b1", "b2", paste0("s", seq_len(length(times) - 2L)))
  dimnames(abundance) <- list(c("f1", "f2"), ids)
  keep <- switch(schedule,
    alternate = !times %in% c(2, 6, 10),
    bridge = times != 4,
    rep(TRUE, length(times))
  )
  TreeSummarizedExperiment::TreeSummarizedExperiment(
    assays = list(abundance = abundance[, keep, drop = FALSE]),
    colData = S4Vectors::DataFrame(
      subject_id = "p1", episode_id = "e1", day = times[keep], row.names = ids[keep]
    )
  )
}

prepare_analysis <- function(tse, selection = "all", real = FALSE) {
  samples <- SummarizedExperiment::colData(tse)
  episodes <- data.frame(
    episode_id = "e1", subject_id = "p1", origin_event_id = "course", origin_boundary = "start"
  )
  events <- data.frame(event_id = "course", episode_id = "e1", start_time = 0, end_time = 1)
  if (real) {
    study <- S4Vectors::metadata(tse)$study
    episodes <- study$episodes
    events <- study$events
  }
  baseline_ids <- colnames(tse)[samples$day < 0]
  baseline_groups <- split(baseline_ids, samples$episode_id[match(baseline_ids, colnames(tse))])
  baseline_ids <- unlist(lapply(baseline_groups, function(ids) {
    days <- samples$day[match(ids, colnames(tse))]
    switch(selection, first = ids[which.min(days)], last = ids[which.max(days)], ids)
  }), use.names = FALSE)
  tse <- setup_recovery(
    tse, "qualification", episodes, events,
    time_col = "day", time_unit = "days", time_origin = "relative to exposure start"
  )
  tse <- add_reference(
    tse, "qualification", baseline_ids, assay = "abundance",
    preprocessing = "see the prespecified qualification protocol and data source"
  )
  add_deviation(tse, "qualification")
}

# This comparison does not use recoverome profiles or its distance helper.
compare_deviations <- function(tse) {
  abundance <- SummarizedExperiment::assay(tse, "abundance")
  composition <- sweep(abundance, 2L, colSums(abundance), "/")
  samples <- as.data.frame(recovery_results(tse, "qualification", level = "sample"))
  differences <- lapply(unique(samples$episode_id), function(episode) {
    rows <- which(samples$episode_id == episode)
    ids <- match(samples$sample_id[rows], colnames(composition))
    baseline <- ids[samples$is_reference[rows]]
    reference <- rowMeans(composition[, baseline, drop = FALSE])
    direct <- colSums(abs(composition[, ids, drop = FALSE] - reference)) / 2
    independent <- as.matrix(vegan::vegdist(
      rbind(reference, t(composition[, ids, drop = FALSE])), method = "bray"
    ))[1L, -1L]
    data.frame(
      sample_id = samples$sample_id[rows],
      direct_error = abs(samples$deviation[rows] - direct),
      vegan_error = abs(samples$deviation[rows] - independent)
    )
  })
  differences <- do.call(rbind, differences)
  stopifnot(max(differences$direct_error) < 1e-12, max(differences$vegan_error) < 1e-12)
  differences
}

outcome <- function(tse, rule, case_id) {
  recovered <- add_recovery(tse, "qualification", rule)
  result <- as.data.frame(recovery_results(recovered, "qualification"))
  cbind(case_id = case_id, as.data.frame(rule), result)
}

# Independent small visit classifier: base aggregation and runs, no package helpers.
classify_visits <- function(times, deviations, rule) {
  eligible <- times >= 0 & times <= rule$horizon
  visits <- tapply(deviations[eligible] <= rule$threshold, times[eligible], all)
  times <- as.double(names(visits))
  order <- order(times)
  times <- times[order]
  within <- as.logical(visits[order])
  outside <- which(!within)
  if (!length(outside)) return("no_detected_perturbation")
  candidates <- which(within & seq_along(within) > outside[1L])
  if (!length(candidates)) return("no_observed_return")
  breaks <- c(TRUE, diff(times) > rule$max_gap | !head(within, -1L) | !tail(within, -1L))
  runs <- split(seq_along(times), cumsum(breaks))
  confirmed <- vapply(runs, function(index) {
    all(within[index]) && min(index) > outside[1L] &&
      diff(range(times[index])) >= rule$persistence
  }, logical(1))
  if (any(confirmed)) "confirmed_return" else "unconfirmed_return"
}

# Schedule/baseline perturbations, including independently known compositions.
cases <- expand.grid(
  scenario = names(trajectories), baseline = c("stable", "unstable"),
  selection = c("all", "first", "last"), schedule = c("full", "alternate", "bridge", "irregular"),
  stringsAsFactors = FALSE
)
synthetic <- comparisons <- vector("list", nrow(cases))
for (i in seq_len(nrow(cases))) {
  case <- cases[i, ]
  raw <- synthetic_input(case$scenario, case$baseline, case$schedule)
  tse <- prepare_analysis(raw, case$selection)
  synthetic[[i]] <- cbind(case, outcome(tse, primary_rule, paste0("synthetic-", i)))
  comparisons[[i]] <- cbind(case_id = paste0("synthetic-", i), compare_deviations(tse))
  sample_results <- recovery_results(tse, "qualification", level = "sample")
  reference <- switch(case$selection, all = .2, first = 0, last = .4)
  if (case$baseline == "stable") reference <- 0
  expected <- abs(SummarizedExperiment::assay(raw)[2L, ] / 1000 - reference)
  stopifnot(max(abs(sample_results$deviation - expected)) < 1e-12)
  independent <- classify_visits(sample_results$relative_time, expected, primary_rule)
  stopifnot(identical(synthetic[[i]]$status, independent))
}
synthetic <- do.call(rbind, synthetic)
primary <- subset(synthetic, baseline == "stable" & selection == "all" & schedule == "full")
stopifnot(
  identical(primary$status, c("confirmed_return", "confirmed_return", "no_observed_return",
                              "no_detected_perturbation")),
  identical(primary$confirmation_time[1:2], c(6, 6)), primary$rebound_time[2L] == 8
)

rule_grid <- expand.grid(threshold = c(.10, .25, .40), persistence = c(2, 4),
                         max_gap = c(2, 3), horizon = c(6, 10))
synthetic_grid <- list()
for (scenario in names(trajectories)) {
  tse <- prepare_analysis(synthetic_input(scenario))
  for (i in seq_len(nrow(rule_grid))) {
    synthetic_grid[[length(synthetic_grid) + 1L]] <- cbind(
      scenario = scenario, outcome(tse, as.list(rule_grid[i, ]), paste0(scenario, "-rule-", i))
    )
  }
}

tied <- prepare_analysis(synthetic_input("return", discordant = TRUE))
tied_result <- outcome(tied, primary_rule, "discordant-tie")
stopifnot(tied_result$candidate_time == 4, tied_result$confirmation_time == 8)
comparisons[[length(comparisons) + 1L]] <- cbind(
  case_id = "discordant-tie", compare_deviations(tied)
)
full <- add_recovery(prepare_analysis(synthetic_input("return")), "qualification", primary_rule)
filtered <- full[, colnames(full) != "s3"]
historical <- as.data.frame(recovery_results(filtered, "qualification"))
stopifnot(historical$confirmation_time == 6, !historical$validation_complete)

scaled <- synthetic_input("return")
SummarizedExperiment::assay(scaled) <- SummarizedExperiment::assay(scaled) * 100
scaled <- prepare_analysis(scaled)
scaled_deviations <- recovery_results(scaled, "qualification", level = "sample")$deviation
stopifnot(max(abs(scaled_deviations - c(0, 0, trajectories$return))) < 1e-12)
comparisons[[length(comparisons) + 1L]] <- cbind(case_id = "scaled", compare_deviations(scaled))

set.seed(20260910, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
draws <- expand.grid(
  scenario = c("return", "rebound"), depth = c(100, 1000, 10000), replicate = 1:20,
  stringsAsFactors = FALSE
)
depth_results <- vector("list", nrow(draws))
for (i in seq_len(nrow(draws))) {
  draw <- draws[i, ]
  tse <- prepare_analysis(synthetic_input(draw$scenario, "unstable", depth = draw$depth))
  result <- outcome(tse, primary_rule, paste0("depth-", i))
  target <- abs(c(0, .4, trajectories[[draw$scenario]]) - .2)
  observed <- recovery_results(tse, "qualification", level = "sample")$deviation
  depth_results[[i]] <- cbind(draw, max_target_departure = max(abs(observed - target)), result)
  comparisons[[length(comparisons) + 1L]] <- cbind(
    case_id = paste0("depth-", i), compare_deviations(tse)
  )
}

# Real cohort: every rule, baseline selection and episode is retained.
data("dethlefsen2008", package = "recoverome")
real_grid <- expand.grid(threshold = c(.10, .25, .40), persistence = c(7, 28),
                         max_gap = c(14, 35), horizon = c(33, 180))
real_results <- real_samples <- list()
for (selection in c("all", "first", "last")) {
  tse <- prepare_analysis(dethlefsen2008, selection, real = TRUE)
  real_samples[[selection]] <- cbind(
    selection = selection,
    as.data.frame(recovery_results(tse, "qualification", level = "sample"))
  )
  comparisons[[length(comparisons) + 1L]] <- cbind(
    case_id = paste0("real-", selection), compare_deviations(tse)
  )
  for (i in seq_len(nrow(real_grid))) {
    real_results[[length(real_results) + 1L]] <- cbind(
      selection = selection,
      outcome(tse, as.list(real_grid[i, ]), paste0(selection, "-rule-", i))
    )
  }
}

outputs <- list(
  synthetic = synthetic, synthetic_rules = do.call(rbind, synthetic_grid),
  depth = do.call(rbind, depth_results), real_rules = do.call(rbind, real_results),
  real_samples = do.call(rbind, real_samples), comparisons = do.call(rbind, comparisons),
  tied = tied_result, historical = historical
)
for (name in names(outputs)) {
  utils::write.csv(outputs[[name]], file.path(output_dir, paste0(name, ".csv")), row.names = FALSE)
}
writeLines(
  c("Protocol registration commit: 42797a5", "Seed: 20260910",
    paste("RNG kinds:", paste(RNGkind(), collapse = "/")), capture.output(utils::sessionInfo())),
  file.path(output_dir, "session-info.txt")
)
cat("Assessment reproduced; all independent arithmetic and rule assertions passed.\n")
