test_that("removed and never-computed samples remain distinguishable", {
  registered <- register_fixture(recovery_fixture())
  reference <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  deviation <- add_deviation(reference[, colnames(reference) != "s6"], "antibiotic")
  filtered <- deviation[, colnames(deviation) != "s3"]
  view <- results_preserving_input(filtered, "sample", "historical")
  expect_identical(view$sample_id, c("b1", paste0("s", 1:6)))
  expect_identical(view$current_present, c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE))
  expect_identical(view$result_state, c(rep("available", 3), "removed", "available", "available",
                                        "not_computed"))
  expect_identical(view$deviation, c(0, 0.75, 0.25, NA_real_, 0.125, 0.5, NA_real_))
  expect_identical(view$deviation_status[c(4, 7)], rep(NA_character_, 2))
  expect_identical(view$relative_time, c(-2, 0, 2, 4, 6, 8, 10))
  current <- results_preserving_input(filtered, "sample")
  expect_identical(current$sample_id, c("b1", "s1", "s2", "s4", "s5"))
})

test_that("zero-row current views and historical outcomes retain typed columns and context", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  empty <- tse[, FALSE]
  for (level in c("sample", "episode")) {
    current <- results_preserving_input(empty, level)
    full <- results_preserving_input(tse, level)
    expect_identical(nrow(current), 0L)
    expect_identical(names(current), names(full))
    expect_identical(vapply(as.list(current), typeof, character(1)),
                     vapply(as.list(full), typeof, character(1)))
    expect_identical(S4Vectors::metadata(current)$recoverome_view$evidence$episode_1$confirmation,
                     "s4")
  }
  historical <- results_preserving_input(empty, "episode", "historical")
  expect_identical(historical$current_present, FALSE)
  expect_identical(historical$result_state, "available")
  expect_identical(historical$confirmation_time, 6)
  expect_identical(historical$rebound_time, 8)
  expect_identical(historical$coverage, "reaches_horizon")
  expect_false(historical$validation_complete)
  samples <- results_preserving_input(empty, "sample", "historical")
  expect_identical(samples$result_state, rep("removed", 7))
  expect_true(all(is.na(samples$deviation) & is.na(samples$deviation_status)))
})

test_that("excluded samples establish no current episode and supply no registered annotation", {
  fixture <- registration_fixture()
  SummarizedExperiment::colData(fixture$tse)$subject_id[6] <- "not_snapshotted"
  SummarizedExperiment::colData(fixture$tse)$time[6] <- 100
  registered <- register_fixture(fixture)
  only_excluded <- registered[, "s6", drop = FALSE]
  expect_identical(nrow(results_preserving_input(only_excluded)), 0L)
  sample <- results_preserving_input(only_excluded, "sample")
  expect_identical(sample$sample_id, "s6")
  expect_identical(sample$subject_id, NA_character_)
  expect_identical(sample$episode_id, NA_character_)
  expect_identical(sample$time, NA_real_)
  expect_identical(sample$relative_time, NA_real_)
  historical <- results_preserving_input(only_excluded, scope = "historical")
  expect_identical(historical$episode_id, c("e1", "e2"))
  expect_identical(historical$current_present, c(FALSE, FALSE))
})

test_that("changed current sources keep the saved values and registered coordinates", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  SummarizedExperiment::colData(tse)$day[colnames(tse) == "s4"] <- 30
  SummarizedExperiment::colData(tse)$subject_id[colnames(tse) == "s4"] <- "edited"
  SummarizedExperiment::assay(tse, "counts")[, "s2"] <- c(12, 4)
  view <- results_preserving_input(tse, "sample")
  expect_identical(view$relative_time[view$sample_id == "s4"], 6)
  expect_identical(view$subject_id[view$sample_id == "s4"], "participant_1")
  expect_identical(view$deviation[view$sample_id == "s2"], 0.25)
  expect_identical(view$dependencies, rep("changed", 7))
  report <- S4Vectors::metadata(view)$recoverome_view$validation
  expect_true(all(c("DEPENDENCY_VALUE_CHANGED", "ANALYTICAL_INPUT_CHANGED") %in%
                    report$diagnostics$code))
  SummarizedExperiment::colData(tse)$day <- NULL
  SummarizedExperiment::assay(tse, "counts")[, "s2"] <- NA_real_
  view <- results_preserving_input(tse)
  expect_identical(view$confirmation_time, 6)
  expect_identical(view$dependencies, "changed")
  expect_false(view$validation_complete)
})


test_that("additions produce one structured warning without enrolling their identities", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  expanded <- tse[c(1, 2, 1, 2), c(seq_len(7), 1, 2)]
  added_samples <- c("new{sample}", "another sample")
  added_features <- c("new{feature}", "another feature")
  colnames(expanded) <- c("b1", paste0("s", 1:6), added_samples)
  rownames(expanded) <- c(rownames(tse), added_features)
  conditions <- new.env(parent = emptyenv())
  conditions$warnings <- list()
  view <- withCallingHandlers(
    results_preserving_input(expanded, "sample", "historical"),
    warning = function(condition) {
      conditions$warnings <- c(conditions$warnings, list(condition))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(conditions$warnings, 1L)
  warning <- conditions$warnings[[1L]]
  expect_s3_class(warning, "recoverome_warning_scope")
  expect_identical(warning$sample_ids, added_samples)
  expect_identical(warning$feature_ids, added_features)
  expect_identical(warning$ids, c(added_samples, added_features))
  expect_identical(warning$call[[1L]], quote(nostos::recovery_results))
  expect_identical(view$sample_id, c("b1", paste0("s", 1:6)))
  expect_identical(view$deviation[3], 0.25)
  report <- S4Vectors::metadata(view)$recoverome_view$validation
  expect_identical(report$summary$sample_scope, "expanded")
  expect_identical(report$summary$feature_scope, "expanded")
  expect_validation_diagnostic(report, "SCOPE_EXPANDED", "warning",
                               c(added_samples, added_features))
})
