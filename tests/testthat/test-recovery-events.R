test_that("same-subject events use closed overlap and not-evaluable reason precedence", {
  for (start in c(9, 18, 20)) {
    fixture <- recovery_fixture()
    fixture$events <- rbind(fixture$events, data.frame(
      event_id = "additional", episode_id = "episode_1", start_time = start,
      end_time = if (start == 9) 10 else start
    ))
    parent <- recovery_parent(fixture)
    out <- add_recovery(parent, "antibiotic", observed_rule())
    recovery <- registration_record(out)$recovery
    expect_identical(recovery$episodes$status, "not_evaluable")
    expect_identical(recovery$episodes$reason, "unresolved_events")
    expect_identical(recovery$episodes$coverage, "reaches_horizon")
    expect_true(all(is.na(unlist(as.list(recovery$episodes[5:9]), use.names = FALSE))))
    expect_identical(recovery$evidence$episode_1$blocking_events, "additional")
    expect_length(recovery$evidence$episode_1$confirmation, 0L)
    missing <- add_recovery(
      recovery_parent(fixture, reference = character()), "antibiotic", observed_rule()
    )
    expect_identical(registration_record(missing)$recovery$episodes$reason, "missing_baseline")
    blocking_events <- registration_record(missing)$recovery$evidence$episode_1$blocking_events
    expect_identical(blocking_events, "additional")
  }
})

test_that("events in other episodes block only their own subject", {
  for (subject in c("participant_1", "participant_2")) {
    fixture <- recovery_fixture()
    fixture$episodes <- rbind(fixture$episodes, data.frame(
      episode_id = "episode_2", subject_id = subject,
      origin_event_id = "other_origin", origin_boundary = "start"
    ))
    fixture$events <- rbind(fixture$events, data.frame(
      event_id = "other_origin", episode_id = "episode_2", start_time = 20, end_time = 22
    ))
    fixture$tse <- fixture$tse[, c(seq_len(ncol(fixture$tse)), 1L)]
    colnames(fixture$tse)[ncol(fixture$tse)] <- "other_sample"
    annotation <- SummarizedExperiment::colData(fixture$tse)
    annotation$subject_id[nrow(annotation)] <- subject
    annotation$episode_id[nrow(annotation)] <- "episode_2"
    annotation$day[nrow(annotation)] <- 0
    SummarizedExperiment::colData(fixture$tse) <- annotation
    out <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
    recovery <- registration_record(out)$recovery
    expect_identical(recovery$episodes$episode_id, c("episode_1", "episode_2"))
    expected <- if (subject == "participant_1") "not_evaluable" else "confirmed_return"
    expect_identical(recovery$episodes$status[[1L]], expected)
    expect_identical(recovery$episodes$reason[[2L]], "missing_baseline")
    expect_identical(recovery$episodes$coverage[[2L]], "none")
    expect_identical(recovery$episodes$n_window_visits[[2L]], 0L)
    expect_true(validate_recovery(out)$summary$structural_valid)
  }
})

test_that("finite coordinate inputs must still produce finite relative-time arithmetic", {
  fixture <- recovery_fixture(c(0, 1), c(0.75, 0.25))
  fixture$events$start_time <- fixture$events$end_time <- .Machine$double.xmax
  annotation <- SummarizedExperiment::colData(fixture$tse)
  annotation$day <- c(0, .Machine$double.xmax, .Machine$double.xmax)
  SummarizedExperiment::colData(fixture$tse) <- annotation
  rule <- observed_rule()
  rule$horizon <- .Machine$double.xmax
  expect_outcome_error(recovery_parent(fixture), rule)

  fixture <- recovery_fixture(c(0, 1), c(0.75, 0.25), origin = "end")
  fixture$events$start_time <- -.Machine$double.xmax
  fixture$events$end_time <- .Machine$double.xmax
  annotation <- SummarizedExperiment::colData(fixture$tse)
  annotation$day <- c(0, 1, 2)
  SummarizedExperiment::colData(fixture$tse) <- annotation
  expect_outcome_error(recovery_parent(fixture, reference = character()))
})
