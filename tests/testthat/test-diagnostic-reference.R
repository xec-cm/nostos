test_that("reference plots separate baseline samples, times and recorded variation", {
  fixture <- recovery_fixture(c(-1, -1, 0, 2), c(0.25, 0.5, 0.75, 0.125))
  referenced <- add_reference(
    register_fixture(fixture), "antibiotic", c("b1", "s1", "s2"), assay = "counts"
  )
  before <- serialize(referenced, NULL)
  plot <- plot_reference(referenced[, rev(colnames(referenced))], "antibiotic")
  expect_s3_class(plot, "ggplot")
  expect_identical(serialize(referenced, NULL), before)
  expect_identical(plot$data$sample_id, c("b1", "s1", "s2"))
  expect_identical(plot$data$relative_time, c(-2, -1, -1))
  expect_equal(plot$data$distance, c(0.25, 0, 0.25), tolerance = 1e-15)
  expect_identical(plot$data$value_source, rep("Current verified baseline distance", 3))
  support <- diagnostic_layer(plot, "n_baseline_samples")
  expect_identical(support$n_baseline_samples, 3L)
  expect_identical(support$n_baseline_times, 2L)
  expect_identical(support$baseline_diameter, 0.5)
  expect_identical(support$reference_support, "multiple_times")
  expect_match(plot$labels$subtitle, "Assay: counts")
  expect_match(plot$labels$subtitle, "Fixed features \\(2\\): feature_a, feature_b")
  expect_match(plot$labels$subtitle, "mean of sample compositions")
  expect_silent(ggplot2::ggplotGrob(plot))

  deviation <- add_deviation(referenced, "antibiotic")
  stored <- plot_reference(deviation, "antibiotic")
  expect_equal(stored$data$distance, c(0.25, 0, 0.25), tolerance = 1e-15)
  expect_identical(stored$data$value_source, rep("Stored deviation", 3))
})

test_that("reference source changes affect derivation but never replace stored deviations", {
  fixture <- recovery_fixture(c(-1, -1, 0, 2), c(0.25, 0.5, 0.75, 0.125))
  referenced <- add_reference(
    register_fixture(fixture), "antibiotic", c("b1", "s1", "s2"), assay = "counts"
  )
  deviation <- add_deviation(referenced, "antibiotic")
  SummarizedExperiment::assay(referenced, "counts")[, "b1"] <- c(6, 2)
  changed <- plot_reference(referenced, "antibiotic")
  expect_equal(changed$data$distance, c(NA, 0, 0.25), tolerance = 1e-15)
  expect_identical(changed$data$display_y[[1L]], -0.12)
  expect_match(changed$labels$caption, "sources changed")
  expect_identical(diagnostic_layer(changed, "baseline_diameter")$baseline_diameter, 0.5)

  SummarizedExperiment::assay(deviation, "counts")[, "b1"] <- c(6, 2)
  SummarizedExperiment::colData(deviation)$day[[1L]] <- 99
  stored <- plot_reference(deviation, "antibiotic")
  expect_equal(stored$data$distance, c(0.25, 0, 0.25), tolerance = 1e-15)
  expect_identical(stored$data$relative_time, c(-2, -1, -1))
  expect_identical(stored$data$value_source, rep("Stored deviation", 3))
  expect_match(stored$labels$caption, "sources changed")
})

test_that("removed baselines retain identities and historical support without invented values", {
  fixture <- recovery_fixture(c(-1, -1, 0, 2), c(0.25, 0.5, 0.75, 0.125))
  referenced <- add_reference(
    register_fixture(fixture), "antibiotic", c("b1", "s1", "s2"), assay = "counts"
  )
  filtered <- referenced[, colnames(referenced) != "s1"]
  plot <- plot_reference(filtered, "antibiotic")
  expect_identical(plot$data$sample_id, c("b1", "s1", "s2"))
  expect_equal(plot$data$distance, c(0.25, NA, 0.25), tolerance = 1e-15)
  expect_identical(plot$data$availability,
                   c("Retained sample", "Removed sample", "Retained sample"))
  support <- diagnostic_layer(plot, "n_baseline_samples")
  expect_identical(support$n_baseline_samples, 3L)
  expect_identical(support$n_baseline_times, 2L)
  expect_identical(support$baseline_diameter, 0.5)
  expect_match(plot$labels$caption, "checks incomplete")
  expect_silent(ggplot2::ggplotGrob(plot))

  SummarizedExperiment::assay(filtered, "counts")[, "s2"] <- c(6, 2)
  changed <- plot_reference(filtered, "antibiotic")
  annotation <- diagnostic_layer(changed, c("sample_id", "label"))
  expect_identical(annotation$label, c("b1", "s1 (removed), s2 (retained)"))
  expect_identical(changed$data$relative_time, c(-2, -1, -1))
  expect_equal(changed$data$distance, c(0.25, NA, NA), tolerance = 1e-15)
  expect_silent(ggplot2::ggplotGrob(changed))

  stored <- add_deviation(referenced, "antibiotic")
  plot <- plot_reference(stored[, FALSE], "antibiotic", "historical")
  expect_identical(plot$data$relative_time, c(-2, -1, -1))
  expect_true(all(is.na(plot$data$distance)))
  expect_identical(plot$data$availability, rep("Removed sample", 3))
  expect_silent(ggplot2::ggplotGrob(plot))
})

test_that("unverifiable features, fingerprints and assay inputs never yield derived distances", {
  fixture <- recovery_fixture(c(-1, -1, 0, 2), c(0.25, 0.5, 0.75, 0.125))
  referenced <- add_reference(
    register_fixture(fixture), "antibiotic", c("b1", "s1", "s2"), assay = "counts"
  )
  missing_feature <- referenced[1, ]
  unknown <- missing_assay <- invalid <- referenced
  record <- registration_record(unknown)
  record$reference$provenance$fingerprint_format <- "future"
  S4Vectors::metadata(unknown)$recoverome$analyses$antibiotic <- record
  SummarizedExperiment::assayNames(missing_assay) <- "renamed"
  SummarizedExperiment::assay(invalid, "counts")[, "s1"] <- NA_real_
  for (input in list(missing_feature, unknown, missing_assay)) {
    plot <- plot_reference(input, "antibiotic")
    expect_true(all(is.na(plot$data$distance)))
    expect_match(plot$labels$caption, "checks incomplete")
  }
  expect_equal(plot_reference(invalid, "antibiotic")$data$distance,
               c(0.25, NA, 0.25), tolerance = 1e-15)
  testthat::local_mocked_bindings(
    assay = function(...) stop("backend unavailable"), .package = "SummarizedExperiment"
  )
  plot <- plot_reference(referenced, "antibiotic")
  expect_true(all(is.na(plot$data$distance)))
  expect_silent(ggplot2::ggplotGrob(plot))
})

test_that("single, tied and absent baselines have truthful support labels", {
  single <- plot_reference(recovery_parent(), "antibiotic")
  labels <- single$facet$params$labeller(data.frame(episode_id = "episode_1"))
  expect_match(labels[[1L]], "One sample cannot estimate pairwise variation")
  expect_identical(diagnostic_layer(single, "baseline_diameter")$baseline_diameter, NA_real_)
  fixture <- recovery_fixture(c(-1, -1, 2), c(0.25, 0.25, 0.75))
  tied <- add_reference(register_fixture(fixture), "antibiotic", c("s1", "s2"), assay = "counts")
  plot <- plot_reference(tied, "antibiotic")
  expect_identical(plot$data$relative_time, c(-1, -1))
  expect_equal(plot$data$distance, c(0, 0), tolerance = 1e-15)
  annotation <- diagnostic_layer(plot, c("sample_id", "label"))
  expect_identical(annotation$label, "s1, s2")
  expect_identical(diagnostic_layer(plot, "reference_support")$reference_support, "single_time")
  expect_silent(ggplot2::ggplotGrob(plot))
  missing <- plot_reference(recovery_parent(reference = character()), "antibiotic")
  expect_identical(nrow(missing$data), 0L)
  expect_identical(diagnostic_layer(missing, "n_baseline_samples")$n_baseline_samples, 0L)
  expect_identical(diagnostic_layer(missing, "label")$label, "No recorded baseline samples")
  expect_silent(ggplot2::ggplotGrob(missing))
})
