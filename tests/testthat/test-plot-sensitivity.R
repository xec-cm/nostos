test_that("plots preserve scenario order, states and observed times", {
  result <- recovery_sensitivity(recovery_parent(), "antibiotic", sensitivity_rules())
  before <- serialize(result, NULL)
  plot <- plot_sensitivity(result)
  expect_s3_class(plot, "ggplot")
  expect_identical(serialize(result, NULL), before)
  expect_identical(levels(plot$data$scenario), rev(sensitivity_rules()$scenario_id))
  expect_identical(plot$data$outcome, result$status)
  expect_match(plot$data$label[1], "R 2.*C 6.*B 8")
  expect_identical(nrow(ggplot2::ggplot_build(plot)$data[[1]]), 4L)
  expect_s3_class(plot + ggplot2::labs(title = "Edited title"), "ggplot")
})

test_that("plots distinguish evaluated missing baselines from unavailable histories", {
  result <- recovery_sensitivity(recovery_parent(reference = character()), "antibiotic",
                                 sensitivity_rules()[1, ])
  plot <- plot_sensitivity(result)
  expect_identical(plot$data$outcome, "not_evaluable")
  expect_identical(plot$data$label, "missing baseline")
  tse <- recovery_parent()
  result <- recovery_sensitivity(tse[, FALSE], "antibiotic", sensitivity_rules())
  plot <- plot_sensitivity(result)
  expect_identical(plot$data$outcome, rep("not_evaluated", 4))
  expect_identical(plot$data$label, rep("historical inputs\nunavailable", 4))
  expect_identical(nrow(ggplot2::ggplot_build(plot)$data[[1]]), 4L)
})

test_that("edited tables and missing or changed context cannot be plotted as original results", {
  result <- recovery_sensitivity(recovery_parent(), "antibiotic", sensitivity_rules())
  changed <- result
  changed$threshold[1] <- .9
  expect_error(plot_sensitivity(changed), class = "recoverome_error_input")
  expect_error(plot_sensitivity(result[1:2, ]), class = "recoverome_error_input")
  expect_error(plot_sensitivity(as.data.frame(result)), class = "recoverome_error_input")
  changed <- result
  S4Vectors::metadata(changed)$recoverome_sensitivity$rules$horizon[1] <- 100
  expect_error(plot_sensitivity(changed), class = "recoverome_error_input")
  S4Vectors::metadata(changed) <- list()
  expect_error(plot_sensitivity(changed), class = "recoverome_error_input")
  restored <- unserialize(serialize(result, NULL))
  expect_s3_class(plot_sensitivity(restored), "ggplot")
})
