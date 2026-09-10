test_that("overview keeps distinct original milestones and follow-up on one common axis", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  before <- serialize(tse, NULL)
  plot <- plot_recovery_overview(tse, "antibiotic")
  expect_identical(serialize(tse, NULL), before)
  expect_identical(plot$data$time, c(0, 2, 2, 6, 8, 10))
  expect_identical(plot$data$milestone,
                   c("Perturbation", "First return", "Winning candidate", "Confirmation", "Rebound",
                     "Last observed follow-up"))
  expect_identical(plot$data$evidence_state, rep("Retained evidence", 6))
  expect_identical(plot$data$subject_id, rep("participant_1", 6))
  expect_identical(plot$data$episode_id, rep("episode_1", 6))
  expect_true(plot$data$row[[2L]] != plot$data$row[[3L]])
  labels <- plot$scales$get_scales("y")$labels
  expect_match(labels, "Status: confirmed_return")
  expect_match(labels, "Coverage: reaches_horizon")
  expect_silent(ggplot2::ggplotGrob(plot))

  fixture <- recovery_fixture(c(0, 2, 3, 5, 7, 9), c(.75, .125, .5, .125, .125, .125))
  other <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  plot <- plot_recovery_overview(other, "antibiotic")
  expect_identical(plot$data$time, c(0, 2, 5, 9, 9))
  expect_identical(plot$data$milestone,
                   c("Perturbation", "First return", "Winning candidate", "Confirmation",
                     "Last observed follow-up"))
  expect_match(plot$scales$get_scales("y")$labels, "Coverage: ends_before_horizon")
})

test_that("overview confirmation uses every run sample while follow-up uses its original time", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  filtered <- tse[, !colnames(tse) %in% c("s3", "s5", "s6")]
  plot <- plot_recovery_overview(filtered, "antibiotic")
  expect_identical(plot$data$time, c(0, 2, 2, 6, 8, 10))
  expect_identical(plot$data$evidence_state,
                   c(rep("Retained evidence", 3), "Incomplete evidence",
                     "Historical evidence", "Historical evidence"))
  episodes <- diagnostic_layer(plot, "coverage")
  expect_identical(episodes$last_observed_time, 10)
  expect_identical(episodes$coverage, "reaches_horizon")
  expect_match(plot$labels$caption, "checks incomplete")
  expect_silent(ggplot2::ggplotGrob(plot))

  absent <- plot_recovery_overview(tse[, FALSE], "antibiotic", "historical")
  expect_identical(absent$data$time, c(0, 2, 2, 6, 8, 10))
  expect_identical(absent$data$evidence_state, rep("Historical evidence", 6))
  expect_match(absent$scales$get_scales("y")$labels, "No current samples")
  expect_silent(ggplot2::ggplotGrob(absent))
})

test_that("overview includes uncomputed and non-evaluable episodes without inventing outcomes", {
  registered <- register_fixture(registration_fixture())
  plot <- plot_recovery_overview(registered, "antibiotic")
  expect_identical(nrow(plot$data), 0L)
  episodes <- diagnostic_layer(plot, "result_state")
  expect_identical(episodes$episode_id, c("e1", "e2"))
  expect_identical(episodes$subject_id, c("p1", "p1"))
  expect_identical(episodes$result_state, rep("not_computed", 2))
  expect_identical(episodes$label, rep("Recovery not computed", 2))
  expect_silent(ggplot2::ggplotGrob(plot))
  missing <- add_recovery(recovery_parent(reference = character()), "antibiotic", observed_rule())
  plot <- plot_recovery_overview(missing, "antibiotic")
  expect_identical(plot$data$milestone, "Last observed follow-up")
  expect_identical(plot$data$time, 10)
  labels <- plot$scales$get_scales("y")$labels
  expect_match(labels, "Status: not_evaluable")
  expect_match(labels, "Reason: missing_baseline")
  expect_match(labels, "Coverage: reaches_horizon")
  expect_silent(ggplot2::ggplotGrob(plot))

  none <- add_recovery(recovery_parent(recovery_fixture(-1, .5)), "antibiotic", observed_rule())
  plot <- plot_recovery_overview(none, "antibiotic")
  expect_identical(nrow(plot$data), 0L)
  expect_match(plot$scales$get_scales("y")$labels, "Coverage: none")
  expect_silent(ggplot2::ggplotGrob(plot))
})

test_that("overview uses registered coordinates after source edits and includes blocking events", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  SummarizedExperiment::colData(tse)$day[colnames(tse) == "s4"] <- 100
  plot <- plot_recovery_overview(tse, "antibiotic")
  expect_identical(plot$data$time, c(0, 2, 2, 6, 8, 10))
  expect_match(plot$labels$caption, "sources changed")
  fixture <- recovery_fixture()
  fixture$events <- rbind(fixture$events, data.frame(
    event_id = "blocking", episode_id = "episode_1", start_time = 14, end_time = 15
  ))
  blocked <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  plot <- plot_recovery_overview(blocked, "antibiotic")
  expect_match(plot$scales$get_scales("y")$labels, "Reason: unresolved_events")
  events <- diagnostic_layer(plot, "event_id")
  expect_identical(events$event_id, c("exposure_1", "blocking"))
  expect_identical(events$start, c(0, 4))
  expect_identical(events$end, c(4, 5))
})

test_that("tied milestone observations retain all supporting IDs without changing their time", {
  fixture <- recovery_fixture(c(0, 2, 2, 4, 6), c(0.75, 0.25, 0.25, 0.125, 0.125))
  recovered <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  plot <- plot_recovery_overview(recovered[, colnames(recovered) != "s3"], "antibiotic")
  expect_identical(plot$data$time, c(0, 2, 2, 6, 6))
  expect_identical(plot$data$evidence_state,
                   c("Retained evidence", rep("Incomplete evidence", 3), "Retained evidence"))
  expect_silent(ggplot2::ggplotGrob(plot))
})
