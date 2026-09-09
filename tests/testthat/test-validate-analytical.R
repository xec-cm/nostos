test_that("supported analytical stages retain the version-one registration report", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(
    registered, "antibiotic", c("b1", "b2", "b3"), assay = "counts"
  )
  measured <- add_deviation(referenced, "antibiotic")
  registration_report <- validate_preserving_input(registered)

  for (tse in list(referenced, measured)) {
    report <- validate_preserving_input(tse)
    expect_identical(report$report_schema_version, 1L)
    expect_identical(names(report$summary), names(registration_report$summary))
    expect_identical(names(report$diagnostics), names(registration_report$diagnostics))
    expect_validation_state(report, n_registered = 4L, n_retained = 4L)
    expect_identical(nrow(report$diagnostics), 0L)
  }
})

test_that("identity reordering and unrelated annotations or assays do not invalidate results", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  current <- tse[c("c", "a", "b"), c("q1", "b2", "b1", "b3"), drop = FALSE]
  SummarizedExperiment::colData(current)$batch <- letters[1:4]
  SummarizedExperiment::rowData(current)$description <- c("third", "first", "second")
  S4Vectors::metadata(current)$study <- list(note = "new unrelated description")
  SummarizedExperiment::assays(current) <- list(
    counts = SummarizedExperiment::assay(current, "counts"),
    unrelated = matrix(Inf, nrow = 3L, ncol = 4L, dimnames = dimnames(current))
  )
  report <- validate_preserving_input(current)

  expect_validation_state(report, n_registered = 4L, n_retained = 4L)
  expect_identical(nrow(report$diagnostics), 0L)
})

test_that("raw source edits and registered time edits are visible without changing saved outputs", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  for (sample_id in c("b1", "q1")) {
    changed <- tse
    counts <- SummarizedExperiment::assay(changed, "counts")
    counts[, sample_id] <- counts[, sample_id] * 2
    SummarizedExperiment::assay(changed, "counts") <- counts
    report <- validate_preserving_input(changed)

    expect_validation_state(report, dependencies = "changed", n_registered = 4L, n_retained = 4L)
    expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", sample_id)
    expect_false(any(c("FINGERPRINT_CHANGED", "RESULT_INCONSISTENT") %in% report$diagnostics$code))
  }

  changed_time <- tse
  SummarizedExperiment::colData(changed_time)$time[4L] <- 18
  report <- validate_preserving_input(changed_time)
  expect_validation_state(report, dependencies = "changed", n_registered = 4L, n_retained = 4L)
  expect_validation_diagnostic(report, "DEPENDENCY_VALUE_CHANGED", "warning", "q1")
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "q1")
})

test_that("missing analytical inputs preserve history while making comparisons incomplete", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  cases <- list(
    list(
      input = tse[, c("b2", "b3", "q1"), drop = FALSE],
      code = "REFERENCE_INPUT_MISSING", ids = "b1", component = "reference$baseline_samples",
      sample_scope = "subset", feature_scope = "same", retained = 3L
    ),
    list(
      input = tse[, c("b1", "b2", "b3"), drop = FALSE],
      code = "DEVIATION_SAMPLE_MISSING", ids = "q1", component = "deviation$sample_ids",
      sample_scope = "subset", feature_scope = "same", retained = 3L
    ),
    list(
      input = tse[c("a", "b"), , drop = FALSE],
      code = "REFERENCE_INPUT_MISSING", ids = "c", component = "reference$definition$feature_ids",
      sample_scope = "same", feature_scope = "subset", retained = 4L
    )
  )

  for (case in cases) {
    report <- validate_preserving_input(case$input)
    expect_validation_state(
      report, validation_complete = FALSE, dependencies = "not_checked",
      sample_scope = case$sample_scope, feature_scope = case$feature_scope,
      n_registered = 4L, n_retained = case$retained
    )
    findings <- expect_validation_diagnostic(report, case$code, "info", case$ids)
    expect_true(case$component %in% findings$component)
    expect_false(any(report$diagnostics$severity == "error"))
    expect_identical(registration_record(case$input), registration_record(tse))
  }
})

test_that("loss outside realized analytical inputs does not require new calculations", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(
    registered, "antibiotic", c("b1", "b2", "b3"), assay = "counts", features = c("a", "b")
  )
  measured <- add_deviation(referenced, "antibiotic")
  report <- validate_preserving_input(measured[c("a", "b"), , drop = FALSE])
  expect_validation_state(report, feature_scope = "subset", n_registered = 4L, n_retained = 4L)
  expect_validation_diagnostic(report, "FEATURE_SCOPE_REDUCED", "info", "c")

  # q1 was removed before deviation existed, so its result comparison was never required.
  measured_subset <- add_deviation(referenced[, c("b1", "b2", "b3"), drop = FALSE], "antibiotic")
  report <- validate_preserving_input(measured_subset)
  expect_validation_state(report, sample_scope = "subset", n_registered = 4L, n_retained = 3L)
  expect_false("DEVIATION_SAMPLE_MISSING" %in% report$diagnostics$code)
})

test_that("limited support and deliberately missing results remain valid descriptive records", {
  registered <- register_fixture(registration_fixture(trees = TRUE))
  referenced <- add_reference(registered, "antibiotic", "s1", assay = "counts")
  measured <- add_deviation(referenced, "antibiotic")
  SummarizedExperiment::assay(measured, "counts")[, c("s4", "s5", "s6")] <- NA_real_
  SummarizedExperiment::colData(measured)$rec_antibiotic_deviation[1L] <- -0
  SummarizedExperiment::colData(measured)$rec_antibiotic_deviation[6L] <- -NA_real_
  report <- validate_preserving_input(measured)

  expect_validation_state(report)
  expect_validation_diagnostic(report, "BASELINE_SUPPORT_LIMITED", "info", c("e1", "e2"))
  expect_false(any(report$diagnostics$severity == "error"))
})

test_that("empty calculations differ from later removal of all previously computed results", {
  registered <- register_fixture(registration_fixture())
  referenced <- add_reference(registered, "antibiotic", character(), assay = "counts")
  empty_calculation <- add_deviation(referenced[, character(), drop = FALSE], "antibiotic")
  report <- validate_preserving_input(empty_calculation)
  expect_validation_state(
    report, dependencies = "not_checked", sample_scope = "empty", n_retained = 0L
  )
  expect_false("DEVIATION_SAMPLE_MISSING" %in% report$diagnostics$code)

  measured <- add_deviation(referenced, "antibiotic")
  removed <- measured[, character(), drop = FALSE]
  report <- validate_preserving_input(removed)
  expect_validation_state(
    report, validation_complete = FALSE, dependencies = "not_checked",
    sample_scope = "empty", n_retained = 0L
  )
  expect_validation_diagnostic(report, "DEVIATION_SAMPLE_MISSING", "info", paste0("s", 1:6))
})

test_that("analytical comparisons use canonical values and only selected assay features", {
  skip_if_not_installed("Matrix")
  skip_if_not_installed("DelayedArray")
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(
    registered, "antibiotic", "b1", assay = "counts", features = c("a", "b")
  )
  measured <- add_deviation(referenced, "antibiotic")
  counts <- SummarizedExperiment::assay(measured, "counts")
  counts["c", ] <- NA_real_
  backends <- list(
    integer = matrix(as.integer(counts), nrow = 3L, dimnames = dimnames(counts)),
    double = counts,
    sparse = Matrix::Matrix(counts, sparse = TRUE),
    delayed = DelayedArray::DelayedArray(counts)
  )

  for (backend in backends) {
    input <- measured
    SummarizedExperiment::assay(input, "counts") <- backend
    report <- validate_preserving_input(input)
    expect_validation_state(report, n_registered = 4L, n_retained = 4L)
    expect_false(any(report$diagnostics$severity == "error"))
  }
})
