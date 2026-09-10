test_that("nostos reads saved recoverome analyses without changing their history", {
  legacy <- readRDS(test_path("fixtures", "recoverome-0.99.0.rds"))
  for (name in names(legacy$objects)) {
    tse <- legacy$objects[[name]]
    before <- serialize(tse, NULL)
    expected <- legacy$expected[[name]]
    expect_identical(validate_recovery(tse, "observed"), expected$report)
    expect_identical(recovery_results(tse, "observed", "sample"), expected$samples)
    expect_identical(recovery_results(tse, "observed"), expected$episodes)
    expect_s3_class(plot_recovery(tse, "observed"), "ggplot")
    expect_identical(serialize(tse, NULL), before)
  }
  outcome <- legacy$expected$full$episodes
  expect_identical(outcome$candidate_time, 2)
  expect_identical(outcome$confirmation_time, 6)
  expect_identical(outcome$rebound_time, 8)
})

test_that("nostos can continue each stage of a legacy analysis", {
  legacy <- readRDS(test_path("fixtures", "recoverome-0.99.0.rds"))
  before <- serialize(legacy, NULL)
  referenced <- add_reference(legacy$registered, "observed", "b1", assay = "counts")
  reference <- S4Vectors::metadata(referenced)$recoverome$analyses$observed$reference
  original <- S4Vectors::metadata(legacy$referenced)$recoverome$analyses$observed$reference
  expect_identical(reference$profiles, original$profiles)
  expect_identical(reference$baseline_samples, original$baseline_samples)

  deviated <- add_deviation(legacy$referenced, "observed")
  expect_identical(SummarizedExperiment::colData(deviated),
                   SummarizedExperiment::colData(legacy$deviated))
  recovered <- add_recovery(legacy$deviated, "observed", legacy$rule)
  outcome <- S4Vectors::metadata(recovered)$recoverome$analyses$observed$recovery
  original <- S4Vectors::metadata(legacy$objects$full)$recoverome$analyses$observed$recovery
  expect_identical(outcome$episodes, original$episodes)
  expect_identical(outcome$evidence, original$evidence)
  expect_null(S4Vectors::metadata(recovered)$nostos)
  expect_identical(serialize(legacy, NULL), before)
})

test_that("saved sensitivity snapshots retain their format and can still be plotted", {
  legacy <- readRDS(test_path("fixtures", "recoverome-0.99.0.rds"))
  before <- serialize(legacy$sensitivity, NULL)
  plot <- plot_sensitivity(legacy$sensitivity)
  expect_s3_class(ggplot2::ggplotGrob(plot), "gtable")
  expect_identical(serialize(legacy$sensitivity, NULL), before)
})
