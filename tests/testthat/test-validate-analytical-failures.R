test_that("one invalid assay column does not hide independent source and result failures", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  tse <- add_deviation(referenced, "antibiotic")
  # b3 is not a baseline: only the deviation input check can detect its raw edit.
  SummarizedExperiment::assay(tse, "counts")["a", "q1"] <- NA_real_
  SummarizedExperiment::assay(tse, "counts")[, "b3"] <- c(14, 6, 0)
  SummarizedExperiment::colData(tse)$rec_antibiotic_deviation[2L] <- 0.6
  report <- validate_preserving_input(tse)

  expect_validation_state(
    report, structural_valid = FALSE, validation_complete = FALSE,
    dependencies = "changed", n_registered = 4L, n_retained = 4L
  )
  expect_validation_diagnostic(report, "ASSAY_VALUES_INVALID", "error", "q1")
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "b3")
  expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error", "b2")
})

test_that("comparable output corruption differs from unreadable or invalid outputs", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  changed_value <- tse
  SummarizedExperiment::colData(changed_value)$rec_antibiotic_deviation[2L] <- 0.6
  report <- validate_preserving_input(changed_value)
  expect_validation_state(
    report, structural_valid = FALSE, dependencies = "changed", n_registered = 4L, n_retained = 4L
  )
  expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error", "b2")

  changed_status <- wrong_type <- missing <- duplicate <- tse
  SummarizedExperiment::colData(changed_status)$rec_antibiotic_deviation_status[4L] <- "invalid"
  values <- SummarizedExperiment::colData(wrong_type)$rec_antibiotic_deviation
  SummarizedExperiment::colData(wrong_type)$rec_antibiotic_deviation <- as.character(values)
  SummarizedExperiment::colData(missing)$rec_antibiotic_deviation <- NULL
  cd <- SummarizedExperiment::colData(duplicate)
  cd$duplicate_output <- cd$rec_antibiotic_deviation
  names(cd)[ncol(cd)] <- "rec_antibiotic_deviation"
  SummarizedExperiment::colData(duplicate) <- cd

  for (input in list(changed_status, wrong_type, missing, duplicate)) {
    report <- validate_preserving_input(input)
    expect_validation_state(
      report, structural_valid = FALSE, validation_complete = FALSE,
      dependencies = "changed", n_registered = 4L, n_retained = 4L
    )
    expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error")
  }
})

test_that("missing and ambiguous assays do not make coherent saved records structurally invalid", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  missing <- tse
  SummarizedExperiment::assayNames(missing) <- "renamed"
  ambiguous <- tse
  counts <- SummarizedExperiment::assay(ambiguous, "counts")
  SummarizedExperiment::assays(ambiguous) <- list(counts = counts, counts = counts)
  cases <- list(
    list(input = missing, code = "ASSAY_MISSING"),
    list(input = ambiguous, code = "ASSAY_AMBIGUOUS")
  )

  for (case in cases) {
    report <- validate_preserving_input(case$input)
    expect_validation_state(
      report, validation_complete = FALSE, dependencies = "changed",
      n_registered = 4L, n_retained = 4L
    )
    expect_validation_diagnostic(report, case$code, "error")
    expect_false("RESULT_INCONSISTENT" %in% report$diagnostics$code)
  }
})

test_that("unknown fingerprint formats are incomplete without inventing hash changes", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  for (stage in c("reference", "deviation")) {
    unknown <- tse
    metadata <- S4Vectors::metadata(unknown)
    metadata$recoverome$analyses$antibiotic[[stage]]$provenance$fingerprint_format <- "unsupported"
    S4Vectors::metadata(unknown) <- metadata
    report <- validate_preserving_input(unknown)

    expect_validation_state(
      report, structural_valid = NA, validation_complete = FALSE, dependencies = "not_checked",
      n_registered = 4L, n_retained = 4L
    )
    expect_validation_diagnostic(report, "FINGERPRINT_FORMAT_UNSUPPORTED", "error")
    expect_false(any(c("FINGERPRINT_CHANGED", "RESULT_INCONSISTENT") %in% report$diagnostics$code))
  }

  # The last case has an unknown deviation format, but its reference can still detect this edit.
  SummarizedExperiment::assay(unknown, "counts")[, "b1"] <- c(16, 4, 0)
  report <- validate_preserving_input(unknown)
  expect_identical(report$summary$dependencies, "changed")
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "b1")
})

test_that("saved self and parent mismatches are reported without refitting reference profiles", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  altered_profile <- altered_registration <- altered_parent <- tse
  metadata <- S4Vectors::metadata(altered_profile)
  metadata$recoverome$analyses$antibiotic$reference$profiles[, "e1"] <- c(0.65, 0.35, 0)
  S4Vectors::metadata(altered_profile) <- metadata
  metadata <- S4Vectors::metadata(altered_registration)
  metadata$recoverome$analyses$antibiotic$registration$time_origin <- "another origin"
  S4Vectors::metadata(altered_registration) <- metadata
  record <- registration_record(altered_parent)
  record$deviation$dependencies$reference_sha256 <- strrep("0", 64L)
  S4Vectors::metadata(altered_parent)$recoverome$analyses$antibiotic <- record

  for (input in list(altered_profile, altered_registration, altered_parent)) {
    report <- validate_preserving_input(input)
    expect_validation_state(
      report, structural_valid = FALSE, dependencies = "changed", n_registered = 4L, n_retained = 4L
    )
    expect_validation_diagnostic(report, "FINGERPRINT_CHANGED", "error")
    expect_false("ANALYTICAL_INPUT_CHANGED" %in% report$diagnostics$code)
    expect_false("RESULT_INCONSISTENT" %in% report$diagnostics$code)
  }
})

test_that("an opaque reference still permits independent result and other-analysis checks", {
  fixture <- reference_fixture()
  fixture$tse <- analytical_fixture(register_fixture(reference_fixture()))
  tse <- register_fixture(fixture, analysis_id = "other")
  metadata <- S4Vectors::metadata(tse)
  metadata$recoverome$analyses$antibiotic$reference <- list(schema_version = 99L, payload = TRUE)
  S4Vectors::metadata(tse) <- metadata
  SummarizedExperiment::colData(tse)$rec_antibiotic_deviation[2L] <- 0.6
  report <- validate_preserving_input(tse)
  selected <- report$summary[report$summary$analysis_id == "antibiotic", , drop = FALSE]
  other <- report$summary[report$summary$analysis_id == "other", , drop = FALSE]

  expect_identical(selected$structural_valid, FALSE)
  expect_identical(selected$validation_complete, FALSE)
  expect_identical(selected$dependencies, "changed")
  expect_identical(other$structural_valid, TRUE)
  expect_identical(other$validation_complete, TRUE)
  expect_identical(other$dependencies, "unchanged")
  findings <- expect_validation_diagnostic(report, "SCHEMA_UNSUPPORTED", "error")
  expect_true(all(findings$analysis_id == "antibiotic"))
  expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error", "b2")
  expect_false("REFERENCE_RECORD_INVALID" %in% report$diagnostics$code)

  future_deviation <- analytical_fixture(register_fixture(reference_fixture()))
  metadata <- S4Vectors::metadata(future_deviation)
  metadata$recoverome$analyses$antibiotic$deviation <- list(schema_version = 99L, payload = TRUE)
  S4Vectors::metadata(future_deviation) <- metadata
  SummarizedExperiment::assay(future_deviation, "counts")[, "b1"] <- c(16, 4, 0)
  report <- validate_preserving_input(future_deviation)
  expect_validation_state(
    report, structural_valid = NA, validation_complete = FALSE, dependencies = "changed",
    n_registered = 4L, n_retained = 4L
  )
  expect_validation_diagnostic(report, "SCHEMA_UNSUPPORTED", "error")
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "b1")
  expect_false("DEVIATION_RECORD_INVALID" %in% report$diagnostics$code)
})

test_that("malformed supported stage records produce findings instead of exceptions", {
  tse <- analytical_fixture(register_fixture(reference_fixture()))
  cases <- list(reference = "REFERENCE_RECORD_INVALID", deviation = "DEVIATION_RECORD_INVALID")
  for (stage in names(cases)) {
    malformed <- tse
    metadata <- S4Vectors::metadata(malformed)
    metadata$recoverome$analyses$antibiotic[[stage]] <- list(schema_version = 1L)
    S4Vectors::metadata(malformed) <- metadata
    report <- validate_preserving_input(malformed)

    expect_identical(report$summary$structural_valid, FALSE)
    expect_identical(report$summary$validation_complete, FALSE)
    expect_validation_diagnostic(report, cases[[stage]], "error")
    expect_false("SCHEMA_UNSUPPORTED" %in% report$diagnostics$code)
  }
})

test_that("every computed sample requires its recorded input fingerprint", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  measured <- add_deviation(referenced, "antibiotic")
  record <- registration_record(measured)
  inputs <- record$deviation$dependencies$samples
  record$deviation$dependencies$samples <- inputs[inputs$sample_id != "q1", , drop = FALSE]
  S4Vectors::metadata(measured)$recoverome$analyses$antibiotic <- record
  scaled <- measured
  SummarizedExperiment::assay(scaled, "counts")[, "q1"] <- c(8, 8, 4)

  for (input in list(measured, scaled)) {
    report <- validate_preserving_input(input)
    expect_validation_state(
      report, structural_valid = FALSE, validation_complete = FALSE,
      dependencies = "not_checked", n_registered = 4L, n_retained = 4L
    )
    findings <- expect_validation_diagnostic(report, "DEVIATION_RECORD_INVALID", "error", "q1")
    expect_true("deviation$dependencies$samples" %in% findings$component)
    # Without q1's original hash, its input change cannot be established.
    expect_false("ANALYTICAL_INPUT_CHANGED" %in% report$diagnostics$code)
  }
})

test_that("invalid profile values do not hide comparable deviation source changes", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  measured <- add_deviation(referenced, "antibiotic")
  record <- registration_record(measured)
  record$reference$profiles[1L, 1L] <- NA_real_
  S4Vectors::metadata(measured)$recoverome$analyses$antibiotic <- record
  SummarizedExperiment::assay(measured, "counts")[, "q1"] <- c(8, 8, 4)
  report <- validate_preserving_input(measured)

  expect_validation_state(
    report, structural_valid = FALSE, validation_complete = FALSE,
    dependencies = "changed", n_registered = 4L, n_retained = 4L
  )
  expect_validation_diagnostic(report, "REFERENCE_RECORD_INVALID", "error")
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "q1")
})

test_that("missing realized scope does not hide comparable authoritative output changes", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  measured <- add_deviation(referenced, "antibiotic")
  record <- registration_record(measured)
  record$deviation$sample_ids <- NULL
  S4Vectors::metadata(measured)$recoverome$analyses$antibiotic <- record
  SummarizedExperiment::colData(measured)$rec_antibiotic_deviation[4L] <- 0.5
  report <- validate_preserving_input(measured)

  expect_validation_state(
    report, structural_valid = FALSE, validation_complete = FALSE,
    dependencies = "changed", n_registered = 4L, n_retained = 4L
  )
  expect_validation_diagnostic(report, "DEVIATION_RECORD_INVALID", "error")
  expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error", "q1")
})

test_that("an unreadable assay does not suppress an independently changed output", {
  registered <- register_fixture(reference_fixture())
  referenced <- add_reference(registered, "antibiotic", "b1", assay = "counts")
  measured <- add_deviation(referenced, "antibiotic")
  SummarizedExperiment::colData(measured)$rec_antibiotic_deviation[4L] <- 0.5
  local_mocked_bindings(
    assay = function(...) stop("assay backend is temporarily unavailable"),
    .package = "SummarizedExperiment"
  )
  report <- validate_preserving_input(measured)

  expect_validation_state(
    report, structural_valid = FALSE, validation_complete = FALSE,
    dependencies = "changed", n_registered = 4L, n_retained = 4L
  )
  expect_validation_diagnostic(report, "ASSAY_READ_FAILED", "error")
  expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error", "q1")
})
