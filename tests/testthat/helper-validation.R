expect_validation_state <- function(report,
                                    structural_valid = TRUE,
                                    validation_complete = TRUE,
                                    dependencies = "unchanged",
                                    sample_scope = "same",
                                    feature_scope = "same",
                                    n_registered = 5L,
                                    n_retained = 5L) {
  expected <- list(
    structural_valid = structural_valid,
    validation_complete = validation_complete,
    dependencies = dependencies,
    sample_scope = sample_scope,
    feature_scope = feature_scope,
    n_registered = n_registered,
    n_retained = n_retained
  )

  testthat::expect_identical(nrow(report$summary), 1L)
  for (field in names(expected)) {
    testthat::expect_identical(report$summary[[field]], expected[[field]], info = field)
  }
}

expect_validation_diagnostic <- function(report, code, severity, ids = NULL) {
  findings <- report$diagnostics[report$diagnostics$code == code, , drop = FALSE]
  testthat::expect_gt(nrow(findings), 0L)
  testthat::expect_true(all(findings$severity == severity), info = code)

  if (!is.null(ids)) {
    affected <- as.character(unlist(as.list(findings$ids), use.names = FALSE))
    testthat::expect_setequal(affected, ids)
  }

  invisible(findings)
}

analytical_fixture <- function(registered) {
  referenced <- nostos::add_reference(
    registered, "antibiotic", c("b1", "b2", "b3"), assay = "counts"
  )

  nostos::add_deviation(referenced, "antibiotic")
}

validate_preserving_input <- function(tse, analysis_id = NULL) {
  before <- serialize(tse, NULL)
  report <- nostos::validate_recovery(tse, analysis_id = analysis_id)
  testthat::expect_identical(serialize(tse, NULL), before)

  report
}

results_preserving_input <- function(tse, level = "episode", scope = "current",
                                     analysis_id = "antibiotic") {
  before <- serialize(tse, NULL)
  result <- nostos::recovery_results(tse, analysis_id, level, scope)
  testthat::expect_identical(serialize(tse, NULL), before)

  result
}
