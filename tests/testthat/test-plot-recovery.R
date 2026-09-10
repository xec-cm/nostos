plot_layer_data <- function(plot, fields) {
  selected <- vapply(plot$layers, function(layer) {
    is.data.frame(layer$data) && all(fields %in% names(layer$data))
  }, logical(1))
  layers <- plot$layers[selected]
  populated <- vapply(layers, function(layer) nrow(layer$data) > 0L, logical(1))
  if (any(populated)) layers <- layers[populated]
  layers[[1L]]$data
}

test_that("plots preserve observed values, evidence times and normal ggplot customization", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  before <- serialize(tse, NULL)
  device <- grDevices::dev.cur()
  plot <- plot_recovery(tse[, rev(colnames(tse))], "antibiotic")
  expect_s3_class(plot, "ggplot")
  expect_identical(grDevices::dev.cur(), device)
  expect_identical(serialize(tse, NULL), before)
  expect_identical(plot$data$sample_id, c("b1", paste0("s", 1:6)))
  expect_identical(plot$data$relative_time, c(-2, 0, 2, 4, 6, 8, 10))
  expect_identical(plot$data$deviation, c(0, 0.75, 0.25, 0.125, 0.125, 0.5, 0.125))
  expect_identical(plot$data$observation, c("Selected baseline", rep("Observed sample", 6)))
  marks <- plot_layer_data(plot, c("time", "support"))
  expect_identical(marks$time, c(2, 6, 8))
  expect_identical(marks$label, c("First return / candidate", "Confirmation", "Rebound"))
  expect_identical(marks$support, rep("Retained evidence", 3))
  expect_identical(plot$scales$get_scales("y")$breaks, c(0, 0.25, 0.5, 0.75, 1))
  customized <- plot + ggplot2::labs(title = "My observed results") + ggplot2::theme_bw()
  expect_identical(customized$labels$title, "My observed results")
  expect_silent(ggplot2::ggplotGrob(customized))
  expect_match(plot$labels$subtitle, "Scope: current")
  expect_match(plot$labels$subtitle, "threshold = 0.25")
  expect_match(plot$labels$subtitle, "not a confidence interval")
  expect_false(any(vapply(plot$layers, function(layer) {
    inherits(layer$geom, c("GeomLine", "GeomSmooth", "GeomRibbon"))
  }, logical(1))))
})

test_that("filtering intermediate evidence hollows confirmation without manufacturing gaps", {
  fixture <- recovery_fixture(c(0, 2, 4, 6, 12), c(0.75, 0.25, 0.125, 0.125, 0.875))
  tse <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  filtered <- tse[, !colnames(tse) %in% c("s3", "s5")]
  plot <- plot_recovery(filtered, "antibiotic", scope = "historical")
  expect_identical(plot$data$sample_id, c("b1", "s1", "s2", "s4"))
  expect_identical(plot$data$relative_time, c(-2, 0, 2, 6))
  expect_identical(plot$data$deviation, c(0, 0.75, 0.25, 0.125))
  marks <- plot_layer_data(plot, c("time", "support"))
  expect_identical(marks$time, c(2, 6))
  expect_identical(marks$support, c("Retained evidence", "Incomplete evidence"))
  spans <- plot_layer_data(plot, c("start", "end", "support"))
  expect_identical(spans$start, 2)
  expect_identical(spans$end, 6)
  expect_identical(spans$support, "Incomplete evidence")
  removed <- plot_layer_data(plot, "result_state")
  expect_identical(removed$relative_time, c(4, 12))
  expect_true(all(is.na(removed$deviation)))
  gaps <- Filter(function(layer) {
    is.data.frame(layer$data) && identical(names(layer$data), c("episode_id", "start", "end"))
  }, plot$layers)[[1L]]$data
  expect_identical(nrow(gaps), 0L)
  expect_identical(plot$scales$get_scales("x")$limits, c(-2, 12))
  facets <- plot_layer_data(plot, "coverage")
  expect_identical(facets$coverage, "reaches_horizon")
  expect_identical(facets$confirmation_time, 6)
  expect_match(facets$label, "checks incomplete")
  expect_match(plot$labels$caption, "incomplete current evidence, not uncertain timing")
  expect_silent(ggplot2::ggplotGrob(plot))
})

test_that("sparse original visits and saved follow-up remain distinct after filtering", {
  fixture <- recovery_fixture(c(0, 2, 7, 9), c(0.75, 0.125, 0.125, 0.125))
  tse <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  plot <- plot_recovery(tse[, colnames(tse) != "s3"], "antibiotic")
  gaps <- Filter(function(layer) {
    is.data.frame(layer$data) && identical(names(layer$data), c("episode_id", "start", "end"))
  }, plot$layers)[[1L]]$data
  expect_identical(gaps$start, 2)
  expect_identical(gaps$end, 7)
  facets <- plot_layer_data(plot, "coverage")
  expect_identical(facets$last_observed_time, 9)
  expect_identical(facets$horizon, 10)
  expect_identical(facets$status, "unconfirmed_return")
  expect_identical(facets$coverage, "ends_before_horizon")
  expect_silent(ggplot2::ggplotGrob(plot))

  none <- add_recovery(recovery_parent(recovery_fixture(-1, 0.5)), "antibiotic", observed_rule())
  plot <- plot_recovery(none, "antibiotic")
  expect_identical(plot_layer_data(plot, "missing_followup")$missing_followup, "Missing follow-up")
  expect_identical(plot_layer_data(plot, "coverage")$coverage, "none")
})

test_that("neutral deviations, missing baselines and all-removed episodes are readable", {
  parent <- recovery_parent()
  neutral <- plot_recovery(parent, "antibiotic")
  expect_true(all(is.na(plot_layer_data(neutral, "threshold")$threshold)))
  expect_identical(unique(neutral$data$window), "Observed deviation")
  expect_match(plot_layer_data(neutral, "label")$label, "recovery not computed")
  expect_false(grepl("horizon|threshold|coverage", neutral$labels$subtitle))

  missing <- add_recovery(recovery_parent(reference = character()), "antibiotic", observed_rule())
  plot <- plot_recovery(missing, "antibiotic")
  expect_identical(nrow(plot$data), 0L)
  expect_match(plot_layer_data(plot, "label")$label, "missing_baseline")
  expect_match(plot_layer_data(plot, "label")$label, "n = 0")
  expect_identical(plot_layer_data(plot, "empty")$empty, "No remaining computed deviations")
  expect_silent(ggplot2::ggplotGrob(plot))

  recovered <- add_recovery(parent, "antibiotic", observed_rule())
  empty <- recovered[, FALSE]
  expect_error(plot_recovery(empty, "antibiotic"), class = "recoverome_error")
  historical <- plot_recovery(empty, "antibiotic", "historical")
  expect_identical(nrow(historical$data), 0L)
  expect_identical(plot_layer_data(historical, c("time", "support"))$time, c(2, 6, 8))
  marks <- plot_layer_data(historical, c("time", "support"))
  expect_identical(marks$support, rep("Incomplete evidence", 3))
  expect_match(plot_layer_data(historical, "label")$label, "0 retained")
  expect_silent(ggplot2::ggplotGrob(historical))
})

test_that("source changes retain saved coordinates and absent observations keep separate marks", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  SummarizedExperiment::colData(tse)$day[[5L]] <- 20
  plot <- plot_recovery(tse, "antibiotic")
  expect_identical(plot$data$relative_time[[5L]], 6)
  expect_match(plot$labels$caption, "Saved results; sources changed")
  expect_match(plot_layer_data(plot, "label")$label, "Saved results; sources changed")

  plot <- plot_recovery(tse[, !colnames(tse) %in% c("s2", "s5")], "antibiotic")
  marks <- plot_layer_data(plot, c("time", "support"))
  expect_identical(marks$time, c(2, 6, 8))
  expect_identical(marks$support, rep("Incomplete evidence", 3))
  expect_identical(plot_layer_data(plot, "result_state")$relative_time, c(2, 8))
})

test_that("end origins, simultaneous points and beyond-horizon values preserve the rule window", {
  fixture <- recovery_fixture(c(-2, 0, 2, 2, 4, 12), c(0.75, 0.25, 0.125, 0.25, 0.125, 0.75), "end")
  plot <- plot_recovery(add_recovery(recovery_parent(fixture), "antibiotic", observed_rule()),
                        "antibiotic")
  facets <- plot_layer_data(plot, "window_start")
  expect_identical(facets$window_start, -4)
  expect_match(facets$label, "exposure_1 / end at 14 days")
  expect_identical(sum(plot$data$relative_time == 2), 2L)
  expect_identical(plot$data$window[plot$data$relative_time == 12], "Outside rule window")
  expect_identical(plot_layer_data(plot, c("time", "support"))$time, c(0, 4))
  expect_identical(plot$scales$get_scales("x")$limits, c(-6, 12))
})

test_that("episode selectors preserve requested order and reject out-of-scope identities", {
  fixture <- registration_fixture()
  parent <- recovery_parent(fixture, reference = c("s1", "s4"))
  plot <- plot_recovery(parent, "antibiotic", episodes = c("e2", "e1"))
  expect_identical(levels(plot$data$episode_id), c("e2", "e1"))
  expect_identical(as.character(plot_layer_data(plot, "label")$episode_id), c("e2", "e1"))
  expect_silent(ggplot2::ggplotGrob(plot))
  for (selection in list(character(), c("e1", "e1"), NA_character_, 1, matrix("e1"), "")) {
    expect_error(plot_recovery(parent, "antibiotic", episodes = selection),
                 class = "recoverome_error")
  }
  filtered <- parent[, c("s1", "s2", "s3")]
  condition <- tryCatch(plot_recovery(filtered, "antibiotic", episodes = c("e2", "unknown")),
                        recoverome_error = identity)
  expect_identical(condition$ids, c("e2", "unknown"))
  expect_identical(as.character(plot_layer_data(plot_recovery(filtered, "antibiotic", "historical"),
                                                "label")$episode_id), c("e1", "e2"))
  expect_error(plot_recovery(parent, "antibiotic", scope = "cur"), class = "recoverome_error")
  expect_error(plot_recovery(parent, NULL), class = "recoverome_error")
})

test_that("plotting validates once and rejects every unsupported displayed stage", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  validate <- nostos:::.recovery_validate_input
  calls <- new.env(parent = emptyenv())
  calls$count <- 0L
  testthat::local_mocked_bindings(.recovery_validate_input = function(...) {
    calls$count <- calls$count + 1L
    validate(...)
  })
  plot_recovery(tse, "antibiotic")
  expect_identical(calls$count, 1L)
  for (stage in c("reference", "deviation", "recovery")) {
    changed <- tse
    S4Vectors::metadata(changed)$recoverome$analyses$antibiotic[[stage]]$schema_version <- 999L
    expect_error(plot_recovery(changed, "antibiotic"), class = "recoverome_error")
  }
  registered <- register_fixture(recovery_fixture())
  reference <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  expect_error(plot_recovery(reference, "antibiotic"), "No deviations exist")
  changed <- tse
  SummarizedExperiment::colData(changed)$rec_antibiotic_deviation[[2L]] <- 0.8
  expect_error(plot_recovery(changed, "antibiotic"), class = "recoverome_error")
})

test_that("uncomputed and excluded samples cannot supply deviations or episode membership", {
  fixture <- recovery_fixture(c(0, 2, 4, 6, 12), c(0.75, 0.25, 0.125, 0.125, 0.875))
  registered <- register_fixture(fixture)
  reference <- add_reference(registered[, colnames(registered) != "s5"],
                             "antibiotic", "b1", assay = "counts")
  parent <- add_deviation(reference, "antibiotic")
  plot <- plot_recovery(parent, "antibiotic")
  removed <- plot_layer_data(plot, "result_state")
  expect_identical(removed$sample_id, "s5")
  expect_identical(removed$result_state, "not_computed")
  expect_identical(removed$relative_time, 12)
  expect_identical(removed$deviation, NA_real_)
  expect_identical(plot$scales$get_scales("x")$limits, c(-2, 12))

  parent <- recovery_parent(registration_fixture(), reference = c("s1", "s4"))
  expect_false("s6" %in% plot_recovery(parent, "antibiotic")$data$sample_id)
  expect_error(plot_recovery(parent[, "s6", drop = FALSE], "antibiotic"),
               class = "recoverome_error")
})

test_that("unknown fingerprint formats stay visible and added identities warn exactly once", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  unknown <- tse
  record <- registration_record(unknown)
  record$recovery$provenance$fingerprint_format <- "future"
  S4Vectors::metadata(unknown)$recoverome$analyses$antibiotic <- record
  plot <- plot_recovery(unknown, "antibiotic")
  expect_match(plot$labels$caption, "checks incomplete")
  expect_identical(plot_layer_data(plot, c("time", "support"))$time, c(2, 6, 8))
  expanded <- tse[c(1, 2, 1), c(seq_len(7), 1)]
  colnames(expanded) <- c("b1", paste0("s", 1:6), "new{sample}")
  rownames(expanded) <- c(rownames(tse), "new{feature}")
  conditions <- new.env(parent = emptyenv())
  conditions$warnings <- list()
  plot <- withCallingHandlers(plot_recovery(expanded, "antibiotic"), warning = function(condition) {
    conditions$warnings <- c(conditions$warnings, list(condition))
    invokeRestart("muffleWarning")
  })
  expect_length(conditions$warnings, 1L)
  expect_s3_class(conditions$warnings[[1L]], "recoverome_warning_scope")
  expect_identical(conditions$warnings[[1L]]$sample_ids, "new{sample}")
  expect_identical(conditions$warnings[[1L]]$feature_ids, "new{feature}")
  expect_identical(plot$data$sample_id, c("b1", paste0("s", 1:6)))
})
