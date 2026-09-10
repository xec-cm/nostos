test_that("shared support types preserve operation and diagnostic failure policies", {
  tse <- add_reference(register_fixture(reference_fixture()), "antibiotic", "b1", assay = "counts")
  record <- registration_record(tse)
  record$reference$episodes$first_time <- Inf
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic <- record
  before <- serialize(tse, NULL)

  condition <- expect_error(add_deviation(tse, "antibiotic"), class = "recoverome_error_namespace")
  expect_identical(condition$component, "reference$fingerprint")
  report <- validate_preserving_input(tse)
  invalid <- report$diagnostics[report$diagnostics$code == "REFERENCE_RECORD_INVALID", ]
  expect_true("reference$episodes" %in% invalid$component)
  expect_identical(serialize(tse, NULL), before)
})

test_that("a malformed definition still exposes independent readable source changes", {
  tse <- add_reference(register_fixture(reference_fixture()), "antibiotic", "b1", assay = "counts")
  record <- registration_record(tse)
  record$reference$definition$estimator <- "unknown"
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic <- record
  SummarizedExperiment::assay(tse, "counts")[, "b1"] <- c(16, 4, 0)
  before <- serialize(tse, NULL)

  condition <- expect_error(add_deviation(tse, "antibiotic"), class = "recoverome_error_namespace")
  expect_identical(condition$component, "reference$definition")
  report <- validate_preserving_input(tse)
  invalid <- report$diagnostics[report$diagnostics$code == "REFERENCE_RECORD_INVALID", ]
  expect_true("reference$definition" %in% invalid$component)
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "b1")
  expect_identical(serialize(tse, NULL), before)
})
