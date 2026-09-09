test_that("a supported and internally coherent reference is required before calculation", {
  tse <- register_fixture(reference_fixture())
  expect_deviation_error(tse)
  expect_error(add_deviation(tse, "unknown"), class = "recoverome_error_input")
  referenced <- add_reference(tse, "antibiotic", "b1", assay = "counts")

  unsupported <- referenced
  metadata <- S4Vectors::metadata(unsupported)
  metadata$recoverome$analyses$antibiotic$reference <- list(schema_version = 99L)
  S4Vectors::metadata(unsupported) <- metadata
  expect_deviation_error(unsupported, "recoverome_error_namespace")

  unknown_format <- referenced
  metadata <- S4Vectors::metadata(unknown_format)
  metadata$recoverome$analyses$antibiotic$reference$provenance$fingerprint_format <- "future_format"
  S4Vectors::metadata(unknown_format) <- metadata
  expect_deviation_error(unknown_format, "recoverome_error_namespace")

  altered_profile <- referenced
  metadata <- S4Vectors::metadata(altered_profile)
  metadata$recoverome$analyses$antibiotic$reference$profiles[, "e1"] <- c(0.7, 0.3, 0)
  S4Vectors::metadata(altered_profile) <- metadata
  expect_deviation_error(altered_profile, "recoverome_error_namespace")
})

test_that("changed raw baseline values block reuse even when the composition is unchanged", {
  tse <- register_fixture(reference_fixture())
  referenced <- add_reference(tse, "antibiotic", "b1", assay = "counts")
  scaled <- referenced
  SummarizedExperiment::assay(scaled, "counts")[, "b1"] <- c(16, 4, 0)
  expect_deviation_error(scaled, "recoverome_error_input")

  changed_time <- referenced
  SummarizedExperiment::colData(changed_time)$time[4L] <- 18
  expect_deviation_error(changed_time, "recoverome_error_input")

  changed_parent <- referenced
  metadata <- S4Vectors::metadata(changed_parent)
  metadata$recoverome$analyses$antibiotic$registration$time_origin <- "another origin"
  S4Vectors::metadata(changed_parent) <- metadata
  expect_deviation_error(changed_parent, "recoverome_error_namespace")
})

test_that("required baselines and selected features cannot be dropped before calculation", {
  tse <- register_fixture(reference_fixture())
  referenced <- add_reference(tse, "antibiotic", "b1", assay = "counts")
  expect_deviation_error(referenced[, c("b2", "b3", "q1"), drop = FALSE])
  # Feature c is required even though the baseline has zero abundance there.
  expect_deviation_error(referenced[c("a", "b"), , drop = FALSE])

  expanded <- referenced[, c(1:4, 4L), drop = FALSE]
  colnames(expanded)[5L] <- "new_sample"
  expect_deviation_error(expanded, "recoverome_error_input")
})

test_that("invalid follow-up values fail atomically with public call and sample context", {
  tse <- register_fixture(reference_fixture())
  referenced <- add_reference(tse, "antibiotic", "b1", assay = "counts")
  invalid <- referenced
  SummarizedExperiment::assay(invalid, "counts")["a", "q1"] <- NA_real_
  before <- serialize(invalid, NULL)
  condition <- tryCatch(add_deviation(invalid, "antibiotic"), error = identity)

  expect_s3_class(condition, "recoverome_error_input")
  expect_identical(conditionCall(condition)[[1L]], quote(add_deviation))
  expect_identical(condition$component, "assay")
  expect_identical(condition$ids, "q1")
  expect_identical(serialize(invalid, NULL), before)

  for (values in list(c(0, 0, 0), c(-1, 4, 2), c(Inf, 4, 2))) {
    invalid <- referenced
    SummarizedExperiment::assay(invalid, "counts")[, "q1"] <- values
    expect_deviation_error(invalid, "recoverome_error_input")
  }
  invalid_type <- referenced
  SummarizedExperiment::assay(invalid_type, "counts") <- matrix(
    TRUE, nrow = 3L, ncol = 4L, dimnames = dimnames(referenced)
  )
  expect_deviation_error(invalid_type, "recoverome_error_input")

  missing_assay <- referenced
  SummarizedExperiment::assayNames(missing_assay) <- "renamed"
  expect_deviation_error(missing_assay, "recoverome_error_input")
})

test_that("existing columns and downstream records are never overwritten", {
  tse <- register_fixture(reference_fixture())
  referenced <- add_reference(tse, "antibiotic", "b1", assay = "counts")
  for (column in c("rec_antibiotic_deviation", "rec_antibiotic_deviation_status")) {
    occupied <- referenced
    SummarizedExperiment::colData(occupied)[[column]] <- rep(NA_real_, 4L)
    expect_deviation_error(occupied, "recoverome_error_collision")
  }

  downstream <- referenced
  metadata <- S4Vectors::metadata(downstream)
  metadata$recoverome$analyses$antibiotic$recovery <- list(schema_version = 1L)
  S4Vectors::metadata(downstream) <- metadata
  expect_deviation_error(downstream, "recoverome_error_collision")
})
