test_that("recovery validation preserves historical outcomes and independent findings", {
  original <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  saved <- registration_record(original)$recovery
  filtered <- original[, !colnames(original) %in% "s3"]
  report <- validate_preserving_input(filtered)
  expect_identical(registration_record(filtered)$recovery, saved)
  expect_identical(report$summary$structural_valid, TRUE)
  expect_identical(report$summary$validation_complete, FALSE)
  expect_identical(report$summary$dependencies, "not_checked")
  expect_validation_diagnostic(report, "RECOVERY_INPUT_MISSING", "info", "s3")

  altered <- filtered
  record <- registration_record(altered)
  record$recovery$episodes$confirmation_time <- 7
  S4Vectors::metadata(altered)$recoverome$analyses$antibiotic <- record
  report <- validate_preserving_input(altered)
  expect_identical(report$summary$structural_valid, FALSE)
  expect_identical(report$summary$validation_complete, FALSE)
  expect_identical(report$summary$dependencies, "changed")
  expect_validation_diagnostic(report, "FINGERPRINT_CHANGED", "error")
  expect_validation_diagnostic(report, "RECOVERY_INPUT_MISSING", "info", "s3")

  source <- original
  SummarizedExperiment::assay(source, "counts")[, "s2"] <- c(12, 4)
  report <- validate_preserving_input(source)
  expect_identical(report$summary$structural_valid, TRUE)
  expect_identical(report$summary$validation_complete, TRUE)
  expect_identical(report$summary$dependencies, "changed")
  expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "s2")
  expect_identical(registration_record(source)$recovery, saved)
})

test_that("recovery fingerprints cover rule, outcome, evidence and complete parent records", {
  original <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  mutations <- list(
    function(record) {
      record$recovery$definition$threshold <- 0.3
      record
    },
    function(record) {
      record$recovery$episodes$rebound_time <- 9
      record
    },
    function(record) {
      record$recovery$evidence$episode_1$confirmation <- "s3"
      record
    },
    function(record) {
      record$deviation$provenance$created_at <- "2020-01-01T00:00:00Z"
      record
    },
    function(record) {
      record$reference$provenance$created_at <- "2020-01-01T00:00:00Z"
      record
    }
  )
  for (mutate in mutations) {
    altered <- original
    record <- mutate(registration_record(altered))
    S4Vectors::metadata(altered)$recoverome$analyses$antibiotic <- record
    report <- validate_preserving_input(altered)
    expect_identical(report$summary$structural_valid, FALSE)
    expect_identical(report$summary$dependencies, "changed")
    expect_validation_diagnostic(report, "FINGERPRINT_CHANGED", "error")
  }
})

test_that("unknown and malformed recovery stages retain independent parent checks", {
  original <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  future <- original
  S4Vectors::metadata(future)$recoverome$analyses$antibiotic$recovery <- list(schema_version = 99L)
  report <- validate_preserving_input(future)
  expect_identical(report$summary$structural_valid, NA)
  expect_identical(report$summary$validation_complete, FALSE)
  expect_identical(report$summary$dependencies, "not_checked")
  expect_validation_diagnostic(report, "SCHEMA_UNSUPPORTED", "error")
  expect_false("RECOVERY_RECORD_INVALID" %in% report$diagnostics$code)

  replacements <- list(NULL, list(schema_version = 1L), list(schema_version = 1L, episodes = 1))
  for (replacement in replacements) {
    malformed <- original
    metadata <- S4Vectors::metadata(malformed)
    metadata$recoverome$analyses$antibiotic["recovery"] <- list(replacement)
    S4Vectors::metadata(malformed) <- metadata
    SummarizedExperiment::assay(malformed, "counts")[, "s2"] <- c(12, 4)
    report <- validate_preserving_input(malformed)
    expect_identical(report$summary$structural_valid, FALSE)
    expect_identical(report$summary$validation_complete, FALSE)
    expect_identical(report$summary$dependencies, "changed")
    expect_validation_diagnostic(report, "RECOVERY_RECORD_INVALID", "error")
    expect_validation_diagnostic(report, "ANALYTICAL_INPUT_CHANGED", "error", "s2")
  }
})

test_that("an unknown recovery fingerprint format is not mistaken for a changed hash", {
  original <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  record <- registration_record(original)
  record$recovery$provenance$fingerprint_format <- "future"
  S4Vectors::metadata(original)$recoverome$analyses$antibiotic <- record
  report <- validate_preserving_input(original)
  expect_identical(report$summary$structural_valid, NA)
  expect_identical(report$summary$validation_complete, FALSE)
  expect_identical(report$summary$dependencies, "not_checked")
  expect_validation_diagnostic(report, "FINGERPRINT_FORMAT_UNSUPPORTED", "error")
  expect_false("FINGERPRINT_CHANGED" %in% report$diagnostics$code)

  SummarizedExperiment::colData(original)$rec_antibiotic_deviation[3] <- 0.9
  report <- validate_preserving_input(original)
  expect_identical(report$summary$structural_valid, FALSE)
  expect_identical(report$summary$dependencies, "changed")
  expect_validation_diagnostic(report, "RESULT_INCONSISTENT", "error", "s2")
})


test_that("outcome invariants and links are diagnosed independently of self hashes", {
  original <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  cases <- list(
    times = list(
      mutate = function(record) {
        record$recovery$episodes$confirmation_time <- 12
        record
      },
      component = "recovery$episodes"
    ),
    evidence = list(
      mutate = function(record) {
        record$recovery$evidence$episode_1$confirmation <- "unknown_sample"
        record
      },
      component = "recovery$evidence"
    ),
    scope = list(
      mutate = function(record) {
        record$recovery$dependencies$sample_ids <- c("b1", "s1")
        record
      },
      component = "recovery$dependencies$sample_ids"
    ),
    parent = list(
      mutate = function(record) {
        record$deviation <- NULL
        record
      },
      component = "recovery$dependencies"
    )
  )
  for (case in cases) {
    altered <- original
    record <- case$mutate(registration_record(altered))
    S4Vectors::metadata(altered)$recoverome$analyses$antibiotic <- record
    report <- validate_preserving_input(altered)
    findings <- report$diagnostics
    expect_true(any(findings$code == "RECOVERY_RECORD_INVALID" &
                      findings$component == case$component))
    expect_identical(report$summary$structural_valid, FALSE)
  }
})
