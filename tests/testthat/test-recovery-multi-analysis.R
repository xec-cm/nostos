test_that("named analyses retain distinct outcome scopes on the same filtered TSE", {
  fixture <- recovery_fixture()
  complete <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  full_history <- registration_record(complete)
  fixture$tse <- complete[, c("s3", "b1", "s1", "s2")]
  shortened <- register_fixture(fixture, analysis_id = "short")
  shortened <- add_reference(shortened, "short", "b1", assay = "counts")
  shortened <- add_deviation(shortened, "short")
  combined <- add_recovery(shortened, "short", observed_rule())
  short_history <- registration_record(combined, "short")

  expect_identical(registration_record(combined), full_history)
  expect_identical(full_history$recovery$episodes$status, "confirmed_return")
  expect_identical(full_history$recovery$episodes$confirmation_time, 6)
  expect_identical(full_history$recovery$episodes$rebound_time, 8)
  expect_identical(short_history$recovery$episodes$status, "unconfirmed_return")
  expect_identical(short_history$recovery$episodes$candidate_time, 2)
  expect_identical(short_history$recovery$episodes$confirmation_time, NA_real_)
  expect_identical(short_history$recovery$episodes$last_observed_time, 4)
  expect_identical(short_history$recovery$evidence$episode_1$evaluated, c("s1", "s2", "s3"))
  expect_identical(full_history$scope$sample_ids, c("b1", paste0("s", 1:6)))
  expect_identical(short_history$scope$sample_ids, c("s3", "b1", "s1", "s2"))

  report <- validate_preserving_input(combined)
  summary <- report$summary
  rows <- match(c("antibiotic", "short"), summary$analysis_id)
  expect_identical(summary$sample_scope[rows], c("subset", "same"))
  expect_identical(summary$n_registered[rows], c(7L, 4L))
  expect_identical(summary$n_retained[rows], c(4L, 4L))
  expect_identical(summary$structural_valid[rows], c(TRUE, TRUE))
  expect_identical(summary$validation_complete[rows], c(FALSE, TRUE))
  expect_identical(summary$dependencies[rows], c("not_checked", "unchanged"))

  altered <- combined
  SummarizedExperiment::colData(altered)$rec_short_deviation[colnames(altered) == "s2"] <- 0.5
  report <- validate_preserving_input(altered)
  rows <- match(c("antibiotic", "short"), report$summary$analysis_id)
  expect_identical(report$summary$dependencies[rows], c("not_checked", "changed"))
  expect_identical(report$summary$structural_valid[rows], c(TRUE, FALSE))
  inconsistent <- report$diagnostics[report$diagnostics$code == "RESULT_INCONSISTENT", ]
  expect_identical(unique(inconsistent$analysis_id), "short")
  expect_identical(registration_record(altered), full_history)
  expect_identical(registration_record(altered, "short"), short_history)

  # An edited parent record must also invalidate its recovery link independently.
  altered <- combined
  record <- short_history
  record$deviation$provenance$created_at <- "2000-01-01T00:00:00Z"
  S4Vectors::metadata(altered)$recoverome$analyses$short <- record
  report <- validate_preserving_input(altered)
  rows <- match(c("antibiotic", "short"), report$summary$analysis_id)
  expect_identical(report$summary$dependencies[rows], c("not_checked", "changed"))
  findings <- report$diagnostics
  parent_link <- findings[findings$code == "FINGERPRINT_CHANGED" &
                            findings$component == "recovery$dependencies$deviation_sha256", ]
  expect_identical(parent_link$analysis_id, "short")
  expect_identical(registration_record(altered)$recovery, full_history$recovery)
  expect_identical(registration_record(altered, "short")$recovery, short_history$recovery)

  filtered <- combined[, c("s2", "b1")]
  report <- validate_preserving_input(filtered)
  rows <- match(c("antibiotic", "short"), report$summary$analysis_id)
  expect_identical(report$summary$sample_scope[rows], c("subset", "subset"))
  expect_identical(report$summary$n_registered[rows], c(7L, 4L))
  expect_identical(report$summary$n_retained[rows], c(2L, 2L))
  expect_identical(report$summary$structural_valid[rows], c(TRUE, TRUE))
  expect_identical(report$summary$validation_complete[rows], c(FALSE, FALSE))
  expect_identical(report$summary$dependencies[rows], c("not_checked", "not_checked"))
  expect_identical(registration_record(filtered), full_history)
  expect_identical(registration_record(filtered, "short"), short_history)
})
