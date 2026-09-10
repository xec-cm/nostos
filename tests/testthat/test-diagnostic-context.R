test_that("all diagnostics validate once, preserve the TSE and return editable unprinted ggplots", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  validate <- nostos:::.recovery_validate_input
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  testthat::local_mocked_bindings(.recovery_validate_input = function(...) {
    calls$n <- calls$n + 1L
    validate(...)
  })
  before <- serialize(tse, NULL)
  device <- grDevices::dev.cur()
  for (draw in list(plot_reference, plot_sampling, plot_recovery_overview)) {
    calls$n <- 0L
    plot <- draw(tse, "antibiotic")
    expect_identical(calls$n, 1L)
    expect_identical(serialize(tse, NULL), before)
    expect_identical(grDevices::dev.cur(), device)
    expect_s3_class(plot, "ggplot")
    expect_identical((plot + ggplot2::labs(title = "Custom"))$labels$title, "Custom")
    expect_match(plot$labels$subtitle, "Scope: current")
    expect_match(plot$labels$subtitle, "Time unit: days")
    expect_match(plot$labels$caption, "Validation: unchanged; checks complete")
  }
})

test_that("empty scope returns informative plots while historical scope retains episode identity", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  empty <- tse[, FALSE]
  for (draw in list(plot_reference, plot_sampling, plot_recovery_overview)) {
    plot <- draw(empty, "antibiotic")
    expect_identical(nrow(plot$data), 0L)
    expect_identical(ggplot2::ggplot_build(plot)$data[[1L]]$label,
                     "No episodes in the selected scope")
    expect_match(plot$labels$subtitle, "Scope: current")
    expect_match(plot$labels$caption, "checks incomplete")
    expect_silent(ggplot2::ggplotGrob(plot))
    plot <- draw(empty, "antibiotic", "historical")
    expect_true("episode_1" %in% as.character(plot$data$episode_id))
    expect_match(plot$labels$subtitle, "Scope: historical")
    expect_silent(ggplot2::ggplotGrob(plot))
  }
  registered <- register_fixture(registration_fixture())
  plot <- plot_reference(registered, "antibiotic")
  expect_identical(ggplot2::ggplot_build(plot)$data[[1L]]$label, "Reference not computed")
  for (draw in list(plot_reference, plot_sampling, plot_recovery_overview)) {
    plot <- draw(registered[, "s6", drop = FALSE], "antibiotic")
    expect_identical(nrow(plot$data), 0L)
    expect_silent(ggplot2::ggplotGrob(plot))
  }
})

test_that("diagnostics reject incoherent required records and exact invalid selectors", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  corrupted <- unsupported <- tse
  SummarizedExperiment::colData(corrupted)$rec_antibiotic_deviation[[3L]] <- 0.9
  S4Vectors::metadata(unsupported)$recoverome$analyses$antibiotic$deviation$schema_version <- 999L
  for (draw in list(plot_reference, plot_sampling, plot_recovery_overview)) {
    expect_error(draw(corrupted, "antibiotic"), class = "recoverome_error_input")
    expect_error(draw(unsupported, "antibiotic"), class = "recoverome_error_input")
    expect_error(draw(tse, "antibiotic", "cur"), class = "recoverome_error_input")
    expect_error(draw(tse, "absent"), class = "recoverome_error_input")
    expect_error(draw(tse, NULL), class = "recoverome_error_input")
  }
})

test_that("diagnostics warn once about additions without including their identities", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  expanded <- tse[c(1, 2, 1), c(seq_len(7), 1)]
  rownames(expanded) <- c(rownames(tse), "new feature")
  colnames(expanded) <- c(colnames(tse), "new sample")
  for (draw in list(plot_reference, plot_sampling, plot_recovery_overview)) {
    warnings <- new.env(parent = emptyenv())
    warnings$values <- list()
    plot <- withCallingHandlers(draw(expanded, "antibiotic"), warning = function(condition) {
      warnings$values <- c(warnings$values, list(condition))
      invokeRestart("muffleWarning")
    })
    expect_length(warnings$values, 1L)
    expect_s3_class(warnings$values[[1L]], "recoverome_warning_scope")
    expect_identical(warnings$values[[1L]]$sample_ids, "new sample")
    expect_identical(warnings$values[[1L]]$feature_ids, "new feature")
    expect_false("new sample" %in% plot$data$sample_id)
  }
})
