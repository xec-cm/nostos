test_that("linked TSE reordering and filtering preserve registered associations and history", {
  fixture <- registration_fixture(trees = TRUE)
  row_tree <- TreeSummarizedExperiment::rowTree(fixture$tse)
  row_tree$tip.label <- c("f2", "f1")
  TreeSummarizedExperiment::rowTree(fixture$tse) <- row_tree
  col_tree <- TreeSummarizedExperiment::colTree(fixture$tse)
  col_tree$tip.label <- c("s4", "s1", "s6", "s2", "s5", "s3")
  TreeSummarizedExperiment::colTree(fixture$tse) <- col_tree
  fixture$episodes <- fixture$episodes[2:1, , drop = FALSE]
  fixture$events <- fixture$events[2:1, , drop = FALSE]

  registered <- register_fixture(fixture)
  history <- registration_record(registered)
  sample_order <- c("s5", "s2", "s6", "s1", "s4", "s3")
  reordered <- registered[c("f2", "f1"), sample_order, drop = FALSE]
  reordered_report <- validate_recovery(reordered)

  expect_identical(reordered_report$summary$structural_valid, TRUE)
  expect_identical(reordered_report$summary$validation_complete, TRUE)
  expect_identical(reordered_report$summary$dependencies, "unchanged")
  expect_identical(reordered_report$summary$sample_scope, "same")
  expect_identical(reordered_report$summary$feature_scope, "same")
  expect_identical(nrow(reordered_report$diagnostics), 0L)
  expect_identical(SummarizedExperiment::colData(reordered)$time, c(43, 10, NA, 3, 34, 17))
  expect_identical(history$episodes$episode_id, c("e2", "e1"))
  expect_identical(history$events$event_id, c("ab2", "ab1"))

  # Keep only e1 observations and an excluded sample; e2 remains historical.
  selected_samples <- c("s3", "s1", "s6")
  selected <- reordered["f2", selected_samples, drop = FALSE]
  before_validation <- serialize(selected, NULL)
  selected_report <- validate_recovery(selected)

  expect_s4_class(selected, "TreeSummarizedExperiment")
  expect_identical(selected_report$summary$structural_valid, TRUE)
  expect_identical(selected_report$summary$validation_complete, TRUE)
  expect_identical(selected_report$summary$dependencies, "unchanged")
  expect_identical(selected_report$summary$sample_scope, "subset")
  expect_identical(selected_report$summary$feature_scope, "subset")
  expect_identical(selected_report$summary$n_registered, 5L)
  expect_identical(selected_report$summary$n_retained, 2L)
  expect_setequal(
    selected_report$diagnostics$code,
    c("SAMPLE_SCOPE_REDUCED", "FEATURE_SCOPE_REDUCED")
  )
  expect_identical(registration_record(selected), history)
  expect_identical(history$scope$sample_ids, c("s1", "s2", "s3", "s4", "s5", "s6"))
  expect_identical(history$scope$feature_ids, c("f1", "f2"))

  # Tip numbers follow each tree's explicit order, not the TSE axis position.
  expect_identical(TreeSummarizedExperiment::rowLinks(selected)$nodeLab, "f2")
  expect_identical(unname(TreeSummarizedExperiment::rowLinks(selected)$nodeNum), 1L)
  expect_identical(TreeSummarizedExperiment::colLinks(selected)$nodeLab, selected_samples)
  expect_identical(unname(TreeSummarizedExperiment::colLinks(selected)$nodeNum), c(6L, 2L, 3L))
  expect_identical(serialize(selected, NULL), before_validation)

  # Compare all unrelated content with the same subset of the unregistered TSE.
  expected <- fixture$tse["f2", selected_samples, drop = FALSE]
  without_registration <- selected
  metadata <- S4Vectors::metadata(without_registration)
  metadata$recoverome <- NULL
  S4Vectors::metadata(without_registration) <- metadata
  expect_identical(without_registration, expected)
})

test_that("new analyses keep their own scope and dependencies after a historical subset", {
  fixture <- registration_fixture()
  annotations <- SummarizedExperiment::colData(fixture$tse)
  annotations$review_time <- annotations$time
  SummarizedExperiment::colData(fixture$tse) <- annotations
  fixture$tse <- register_fixture(fixture)
  original_history <- registration_record(fixture$tse)

  fixture$tse <- fixture$tse["f1", c("s4", "s1", "s6"), drop = FALSE]
  registered <- register_fixture(fixture, analysis_id = "selected", time_col = "review_time")
  selected_history <- registration_record(registered, "selected")
  analysis_ids <- c("antibiotic", "selected")
  report <- validate_recovery(registered)
  summary <- report$summary[match(analysis_ids, report$summary$analysis_id), , drop = FALSE]

  expect_identical(as.list(summary), list(
    analysis_id = analysis_ids,
    structural_valid = c(TRUE, TRUE),
    validation_complete = c(TRUE, TRUE),
    dependencies = c("unchanged", "unchanged"),
    sample_scope = c("subset", "same"),
    feature_scope = c("subset", "same"),
    n_registered = c(5L, 2L),
    n_retained = c(2L, 2L)
  ))
  expect_identical(registration_record(registered), original_history)
  expect_identical(selected_history$scope$sample_ids, c("s4", "s1", "s6"))
  expect_identical(selected_history$scope$feature_ids, "f1")
  expect_identical(selected_history$registration$samples$sample_id, c("s4", "s1"))
  expect_identical(selected_history$registration$samples$time, c(34, 3))
  expect_true(all(report$diagnostics$analysis_id == "antibiotic"))

  # Only the newer analysis consumes review_time, so the edit stays local to it.
  changed <- registered
  annotations <- SummarizedExperiment::colData(changed)
  annotations["s4", "review_time"] <- 35
  SummarizedExperiment::colData(changed) <- annotations
  time_report <- validate_recovery(changed)
  time_summary <- time_report$summary[
    match(analysis_ids, time_report$summary$analysis_id), , drop = FALSE
  ]
  time_findings <- time_report$diagnostics[
    time_report$diagnostics$code == "DEPENDENCY_VALUE_CHANGED", , drop = FALSE
  ]

  expect_identical(time_summary$dependencies, c("unchanged", "changed"))
  expect_identical(time_findings$analysis_id, "selected")
  expect_identical(as.character(unlist(time_findings$ids)), "s4")

  selected_report <- validate_recovery(changed, analysis_id = "selected")
  selected_summary <- time_report$summary[
    time_report$summary$analysis_id == "selected", , drop = FALSE
  ]
  expect_identical(selected_report$summary, selected_summary)
  expect_identical(selected_report$diagnostics, time_findings)

  # Renaming is removal plus addition for both histories, never re-enrollment.
  colnames(changed)[colnames(changed) == "s1"] <- "renamed-sample"
  before_validation <- serialize(changed, NULL)
  renamed_report <- validate_recovery(changed)
  renamed_summary <- renamed_report$summary[
    match(analysis_ids, renamed_report$summary$analysis_id), , drop = FALSE
  ]
  additions <- renamed_report$diagnostics[
    renamed_report$diagnostics$code == "SCOPE_EXPANDED", , drop = FALSE
  ]

  expect_identical(renamed_summary$structural_valid, c(TRUE, TRUE))
  expect_identical(renamed_summary$validation_complete, c(TRUE, TRUE))
  expect_identical(renamed_summary$sample_scope, c("mixed", "mixed"))
  expect_identical(renamed_summary$n_registered, c(5L, 2L))
  expect_identical(renamed_summary$n_retained, c(1L, 1L))
  expect_identical(renamed_summary$dependencies, c("unchanged", "changed"))
  expect_setequal(additions$analysis_id, analysis_ids)
  expect_identical(as.character(unlist(additions$ids)), rep("renamed-sample", 2L))
  expect_identical(registration_record(changed), original_history)
  expect_identical(registration_record(changed, "selected"), selected_history)
  expect_identical(S4Vectors::metadata(changed)$study, S4Vectors::metadata(fixture$tse)$study)
  expect_identical(serialize(changed, NULL), before_validation)
})
