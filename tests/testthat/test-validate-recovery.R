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

test_that("registration validation returns versioned, typed tables quietly", {
  tse <- register_fixture(registration_fixture(trees = TRUE))
  before <- serialize(tse, NULL)
  expect_silent(report <- validate_recovery(tse))

  expect_identical(class(report), "list")
  expect_named(report, c("report_schema_version", "summary", "diagnostics"))
  expect_identical(report$report_schema_version, 1L)
  expect_s4_class(report$summary, "DataFrame")
  expect_s4_class(report$diagnostics, "DataFrame")
  expect_named(report$summary, c(
    "analysis_id", "structural_valid", "validation_complete", "dependencies",
    "sample_scope", "feature_scope", "n_registered", "n_retained"
  ))
  expect_named(report$diagnostics, c(
    "analysis_id", "code", "severity", "component", "message", "ids"
  ))
  expect_identical(report$summary$analysis_id, "antibiotic")
  expect_validation_state(report)
  expect_identical(nrow(report$diagnostics), 0L)

  for (field in c("analysis_id", "code", "severity", "component", "message")) {
    expect_identical(report$diagnostics[[field]], character(), info = field)
  }
  expect_length(report$diagnostics$ids, 0L)
  expect_true(is.list(report$diagnostics$ids) || methods::is(report$diagnostics$ids, "List"))
  expect_identical(validate_recovery(tse), report)
  expect_identical(serialize(tse, NULL), before)
})

test_that("absent analyses and an absent requested name are report findings", {
  tse <- registration_fixture()$tse
  empty_namespace <- tse
  S4Vectors::metadata(empty_namespace)$recoverome <- list(
    schema_version = 1L, analyses = list()
  )

  for (input in list(tse, empty_namespace)) {
    report <- validate_recovery(input)
    expect_identical(nrow(report$summary), 0L)
    expect_identical(report$summary$analysis_id, character())
    expect_identical(report$summary$structural_valid, logical())
    expect_identical(report$summary$validation_complete, logical())
    expect_identical(report$summary$dependencies, character())
    expect_identical(report$summary$sample_scope, character())
    expect_identical(report$summary$feature_scope, character())
    expect_identical(report$summary$n_registered, integer())
    expect_identical(report$summary$n_retained, integer())
    findings <- expect_validation_diagnostic(report, "NO_ANALYSES", "info")
    expect_true(all(is.na(findings$analysis_id)))

    missing <- validate_recovery(input, analysis_id = "absent")
    expect_identical(missing$summary$analysis_id, "absent")
    expect_validation_state(
      missing,
      structural_valid = FALSE,
      validation_complete = FALSE,
      dependencies = "not_checked",
      sample_scope = "not_checked",
      feature_scope = "not_checked",
      n_registered = NA_integer_,
      n_retained = NA_integer_
    )
    expect_validation_diagnostic(missing, "ANALYSIS_NOT_FOUND", "error")
  }
})

test_that("invalid public arguments raise errors instead of malformed reports", {
  expect_error(validate_recovery(list()), class = "recoverome_error_input")
  tse <- registration_fixture()$tse
  for (analysis_id in list(character(), c("first", "second"), NA_character_, 1, "Bad_id")) {
    expect_error(validate_recovery(tse, analysis_id), class = "recoverome_error_input")
  }
})

test_that("reordering and equivalent source types preserve identity-based comparisons", {
  fixture <- registration_fixture()
  fixture$episodes <- fixture$episodes[2:1, , drop = FALSE]
  fixture$events <- fixture$events[2:1, , drop = FALSE]
  tse <- register_fixture(fixture)
  tse <- tse[2:1, c(6, 3, 1, 5, 2, 4), drop = FALSE]
  cd <- SummarizedExperiment::colData(tse)
  cd$subject_id <- factor(cd$subject_id)
  cd$episode_id <- factor(cd$episode_id, levels = c("e2", "e1"))
  cd$time <- as.integer(cd$time)
  SummarizedExperiment::colData(tse) <- cd

  report <- validate_recovery(tse)

  expect_validation_state(report)
  expect_identical(nrow(report$diagnostics), 0L)
})

test_that("a subset retains valid episode history and reports the original scope", {
  tse <- register_fixture(registration_fixture())
  subset <- tse["f1", c("s1", "s3"), drop = FALSE]
  before <- serialize(subset, NULL)

  report <- validate_recovery(subset)

  expect_validation_state(
    report,
    sample_scope = "subset",
    feature_scope = "subset",
    n_retained = 2L
  )
  expect_validation_diagnostic(report, "SAMPLE_SCOPE_REDUCED", "info", c("s2", "s4", "s5", "s6"))
  expect_validation_diagnostic(report, "FEATURE_SCOPE_REDUCED", "info", "f2")
  expect_false("REGISTRATION_RECORD_INVALID" %in% report$diagnostics$code)
  expect_identical(registration_record(subset)$episodes$episode_id, c("e1", "e2"))
  expect_identical(serialize(subset, NULL), before)
})

test_that("empty axes and loss of all included samples are distinct historical states", {
  tse <- register_fixture(registration_fixture())
  empty_samples <- validate_recovery(tse[, character(), drop = FALSE])
  empty_features <- validate_recovery(tse[character(), , drop = FALSE])
  excluded_only <- validate_recovery(tse[, "s6", drop = FALSE])

  expect_validation_state(
    empty_samples, dependencies = "not_checked", sample_scope = "empty", n_retained = 0L
  )
  expect_validation_diagnostic(empty_samples, "SCOPE_EMPTY", "info")
  expect_validation_diagnostic(empty_samples, "REGISTERED_SAMPLES_ABSENT", "info")
  expect_validation_state(empty_features, feature_scope = "empty")
  expect_validation_diagnostic(empty_features, "SCOPE_EMPTY", "info")
  expect_validation_state(
    excluded_only, dependencies = "not_checked", sample_scope = "subset", n_retained = 0L
  )
  expect_validation_diagnostic(excluded_only, "REGISTERED_SAMPLES_ABSENT", "info")
  expect_false("SCOPE_EMPTY" %in% excluded_only$diagnostics$code)

  for (report in list(empty_samples, empty_features, excluded_only)) {
    expect_false("REGISTRATION_RECORD_INVALID" %in% report$diagnostics$code)
  }
})

test_that("added IDs are outside registration and renamed IDs have mixed scope", {
  tse <- register_fixture(registration_fixture())
  expanded <- tse[c(1, 2, 1), c(seq_len(6L), 1), drop = FALSE]
  rownames(expanded) <- c("f1", "f2", "new-feature")
  colnames(expanded) <- c(paste0("s", seq_len(6L)), "new-sample")
  expansion <- validate_recovery(expanded)

  expect_validation_state(expansion, sample_scope = "expanded", feature_scope = "expanded")
  expect_validation_diagnostic(
    expansion,
    "SCOPE_EXPANDED",
    "warning",
    c("new-feature", "new-sample")
  )
  expect_false("DEPENDENCY_VALUE_CHANGED" %in% expansion$diagnostics$code)

  renamed <- tse
  colnames(renamed)[1] <- "renamed-sample"
  rownames(renamed)[2] <- "renamed-feature"
  mixed <- validate_recovery(renamed)

  expect_validation_state(mixed, sample_scope = "mixed", feature_scope = "mixed", n_retained = 4L)
  expect_validation_diagnostic(mixed, "SAMPLE_SCOPE_REDUCED", "info", "s1")
  expect_validation_diagnostic(mixed, "FEATURE_SCOPE_REDUCED", "info", "f2")
  expect_validation_diagnostic(
    mixed,
    "SCOPE_EXPANDED",
    "warning",
    c("renamed-sample", "renamed-feature")
  )
})

test_that("changed retained metadata is separate from a valid historical subset", {
  tse <- register_fixture(registration_fixture())
  tse <- tse[, c("s3", "s1"), drop = FALSE]
  cd <- SummarizedExperiment::colData(tse)
  cd$time[2] <- 4
  SummarizedExperiment::colData(tse) <- cd

  report <- validate_recovery(tse)

  expect_validation_state(
    report,
    dependencies = "changed",
    sample_scope = "subset",
    n_retained = 2L
  )
  findings <- expect_validation_diagnostic(report, "DEPENDENCY_VALUE_CHANGED", "warning", "s1")
  expect_identical(findings$analysis_id, rep("antibiotic", nrow(findings)))
  expect_true(all(vapply(as.list(findings$ids), is.character, logical(1))))
  expect_validation_diagnostic(report, "SAMPLE_SCOPE_REDUCED", "info", c("s2", "s4", "s5", "s6"))
  expect_false("REGISTRATION_RECORD_INVALID" %in% report$diagnostics$code)
})

test_that("only consumed cells of originally excluded samples are dependencies", {
  tse <- register_fixture(registration_fixture())
  cd <- SummarizedExperiment::colData(tse)
  cd$subject_id[6] <- "unused-subject"
  cd$time[6] <- Inf
  SummarizedExperiment::colData(tse) <- cd
  expect_validation_state(validate_recovery(tse))

  cd$episode_id[6] <- "e1"
  SummarizedExperiment::colData(tse) <- cd
  enrolled <- validate_recovery(tse)
  expect_validation_state(enrolled, dependencies = "changed")
  expect_validation_diagnostic(enrolled, "DEPENDENCY_VALUE_CHANGED", "warning", "s6")

  excluded_only <- validate_recovery(tse[, "s6", drop = FALSE])
  expect_validation_state(
    excluded_only, dependencies = "changed", sample_scope = "subset", n_retained = 0L
  )
  expect_validation_diagnostic(excluded_only, "DEPENDENCY_VALUE_CHANGED", "warning", "s6")
})

test_that("source column failures skip unsafe comparisons and retain independent findings", {
  tse <- register_fixture(registration_fixture())
  missing <- tse
  cd <- SummarizedExperiment::colData(missing)
  cd$time <- NULL
  cd$subject_id[1] <- "another-subject"
  SummarizedExperiment::colData(missing) <- cd
  report <- validate_recovery(missing)

  expect_validation_state(report, dependencies = "changed", validation_complete = FALSE)
  expect_validation_diagnostic(report, "DEPENDENCY_COLUMN_MISSING", "warning")
  expect_validation_diagnostic(report, "DEPENDENCY_VALUE_CHANGED", "warning", "s1")

  ambiguous <- tse
  cd <- SummarizedExperiment::colData(ambiguous)
  cd$duplicate_time <- cd$time
  names(cd)[ncol(cd)] <- "time"
  SummarizedExperiment::colData(ambiguous) <- cd
  report <- validate_recovery(ambiguous)

  expect_validation_state(report, dependencies = "changed", validation_complete = FALSE)
  expect_validation_diagnostic(report, "DEPENDENCY_COLUMN_AMBIGUOUS", "warning")
  expect_false("DEPENDENCY_VALUE_CHANGED" %in% report$diagnostics$code)

  invalid_type <- tse
  cd <- SummarizedExperiment::colData(invalid_type)
  cd$time <- as.character(cd$time)
  SummarizedExperiment::colData(invalid_type) <- cd
  report <- validate_recovery(invalid_type)

  expect_validation_state(report, dependencies = "changed", validation_complete = FALSE)
  expect_validation_diagnostic(report, "DEPENDENCY_VALUE_CHANGED", "warning")
})

test_that("assay and unrelated annotation changes are not registration dependencies", {
  tse <- register_fixture(registration_fixture())
  SummarizedExperiment::assay(tse, "counts") <- SummarizedExperiment::assay(tse, "counts") * 7
  cd <- SummarizedExperiment::colData(tse)
  cd$batch <- "new-batch"
  cd$unrelated <- "kept"
  cd$duplicate_annotation <- "another"
  names(cd)[ncol(cd)] <- "unrelated"
  SummarizedExperiment::colData(tse) <- cd
  S4Vectors::metadata(tse)$study$version <- 3L
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic$episodes$note <- c("edited", "annotation")

  report <- validate_recovery(tse)

  expect_validation_state(report)
  expect_identical(nrow(report$diagnostics), 0L)
})

test_that("duplicate current IDs are invalid despite formal container validity", {
  tse <- register_fixture(registration_fixture())
  duplicate_samples <- tse[, c(1, 1, 3, 4, 5, 6), drop = FALSE]
  duplicate_features <- tse[c(1, 1), , drop = FALSE]
  expect_true(methods::validObject(duplicate_samples))
  expect_true(methods::validObject(duplicate_features))

  samples <- validate_recovery(duplicate_samples)
  expect_identical(samples$summary$structural_valid, FALSE)
  expect_identical(samples$summary$validation_complete, FALSE)
  expect_identical(samples$summary$sample_scope, "not_checked")
  expect_identical(samples$summary$feature_scope, "same")
  expect_identical(samples$summary$dependencies, "not_checked")
  expect_identical(samples$summary$n_retained, NA_integer_)
  expect_validation_diagnostic(samples, "SAMPLE_IDS_INVALID", "error")

  features <- validate_recovery(duplicate_features)
  expect_identical(features$summary$structural_valid, FALSE)
  expect_identical(features$summary$validation_complete, FALSE)
  expect_identical(features$summary$feature_scope, "not_checked")
  expect_identical(features$summary$sample_scope, "same")
  expect_identical(features$summary$dependencies, "unchanged")
  expect_validation_diagnostic(features, "FEATURE_IDS_INVALID", "error")
})

test_that("broken snapshot relationships are structural findings", {
  tse <- register_fixture(registration_fixture())
  foreign_origin <- tse
  record <- registration_record(foreign_origin)
  record$episodes$origin_event_id[1] <- "ab2"
  S4Vectors::metadata(foreign_origin)$recoverome$analyses$antibiotic <- record

  absent_snapshot_id <- tse
  record <- registration_record(absent_snapshot_id)
  record$registration$samples$sample_id[1] <- "outside-original-scope"
  S4Vectors::metadata(absent_snapshot_id)$recoverome$analyses$antibiotic <- record

  for (input in list(foreign_origin, absent_snapshot_id)) {
    before <- serialize(input, NULL)
    report <- validate_recovery(input)
    expect_identical(report$summary$structural_valid, FALSE)
    expect_validation_diagnostic(report, "REGISTRATION_RECORD_INVALID", "error")
    expect_identical(serialize(input, NULL), before)
  }
})

test_that("registration provenance requires a real UTC date and time", {
  tse <- register_fixture(registration_fixture())
  invalid_timestamps <- c(
    "2026-02-30T25:99:99Z",
    "2026-02-29T12:34:56Z",
    "2026-09-09T24:00:00Z"
  )

  for (timestamp in invalid_timestamps) {
    invalid <- tse
    record <- registration_record(invalid)
    record$provenance$registered_at <- timestamp
    S4Vectors::metadata(invalid)$recoverome$analyses$antibiotic <- record
    before <- serialize(invalid, NULL)

    report <- validate_recovery(invalid)

    expect_identical(report$summary$structural_valid, FALSE, info = timestamp)
    findings <- expect_validation_diagnostic(report, "REGISTRATION_RECORD_INVALID", "error")
    expect_identical(findings$component, "provenance")
    expect_identical(serialize(invalid, NULL), before)
  }

  record <- registration_record(tse)
  record$provenance$registered_at <- "2024-02-29T23:59:59Z"
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic <- record

  report <- validate_recovery(tse)

  expect_validation_state(report)
  expect_identical(nrow(report$diagnostics), 0L)

  record$provenance$registered_at <- I("2026-09-09T12:00:00Z")
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic <- record
  before <- serialize(tse, NULL)

  expect_silent(as_is_report <- validate_recovery(tse))

  expect_identical(as_is_report, report)
  expect_identical(serialize(tse, NULL), before)
})

test_that("unreadable namespaces produce global findings without guessed analyses", {
  tse <- register_fixture(registration_fixture())
  duplicate_namespace <- tse
  metadata <- S4Vectors::metadata(duplicate_namespace)
  metadata <- c(metadata, list(recoverome = metadata$recoverome))
  S4Vectors::metadata(duplicate_namespace) <- metadata
  report <- validate_recovery(duplicate_namespace)
  expect_identical(nrow(report$summary), 0L)
  findings <- expect_validation_diagnostic(report, "NAMESPACE_INVALID", "error")
  expect_true(all(is.na(findings$analysis_id)))

  duplicate_names <- tse
  namespace <- S4Vectors::metadata(duplicate_names)$recoverome
  namespace$analyses <- list(
    antibiotic = namespace$analyses$antibiotic,
    antibiotic = namespace$analyses$antibiotic
  )
  S4Vectors::metadata(duplicate_names)$recoverome <- namespace
  report <- validate_recovery(duplicate_names)
  expect_identical(nrow(report$summary), 0L)
  expect_validation_diagnostic(report, "ANALYSIS_IDS_INVALID", "error")

  future_namespace <- tse
  S4Vectors::metadata(future_namespace)$recoverome <- list(schema_version = 99L, opaque = TRUE)
  report <- validate_recovery(future_namespace)
  expect_identical(nrow(report$summary), 0L)
  expect_validation_diagnostic(report, "SCHEMA_UNSUPPORTED", "error")
  expect_setequal(report$diagnostics$code, "SCHEMA_UNSUPPORTED")
})

test_that("unknown analysis schemas do not prevent checking independent analyses", {
  fixture <- registration_fixture()
  fixture$tse <- register_fixture(fixture)
  tse <- register_fixture(fixture, analysis_id = "other")
  S4Vectors::metadata(tse)$recoverome$analyses$other <- list(
    schema_version = 99L, opaque_future_payload = "not a registration"
  )
  report <- validate_recovery(tse)
  expect_setequal(report$summary$analysis_id, c("antibiotic", "other"))
  current <- report$summary[report$summary$analysis_id == "antibiotic", , drop = FALSE]
  future <- report$summary[report$summary$analysis_id == "other", , drop = FALSE]
  expect_identical(current$structural_valid, TRUE)
  expect_identical(current$validation_complete, TRUE)
  expect_identical(current$dependencies, "unchanged")
  expect_identical(future$structural_valid, NA)
  expect_identical(future$validation_complete, FALSE)
  findings <- expect_validation_diagnostic(report, "SCHEMA_UNSUPPORTED", "error")
  expect_true(all(findings$analysis_id == "other"))
  expect_setequal(report$diagnostics$code, "SCHEMA_UNSUPPORTED")

  selected <- validate_recovery(tse, analysis_id = "antibiotic")
  expect_identical(selected$summary$analysis_id, "antibiotic")
  expect_validation_state(selected)
  expect_identical(nrow(selected$diagnostics), 0L)
})

test_that("unknown stages are incomplete while independent dependency checks still run", {
  tse <- register_fixture(registration_fixture())
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic$reference <- list(method = "future")
  cd <- SummarizedExperiment::colData(tse)
  cd$time[1] <- 4
  SummarizedExperiment::colData(tse) <- cd

  report <- validate_recovery(tse)

  expect_validation_state(
    report, structural_valid = NA, validation_complete = FALSE, dependencies = "changed"
  )
  expect_validation_diagnostic(report, "STAGE_UNSUPPORTED", "error")
  expect_validation_diagnostic(report, "DEPENDENCY_VALUE_CHANGED", "warning", "s1")
  expect_false("REGISTRATION_RECORD_INVALID" %in% report$diagnostics$code)
})

test_that("reserved columns distinguish ownership violations from unsupported stages", {
  tse <- register_fixture(registration_fixture())
  foreign <- tse
  cd <- SummarizedExperiment::colData(foreign)
  cd$rec_antibiotic_note <- "foreign annotation"
  SummarizedExperiment::colData(foreign) <- cd
  report <- validate_recovery(foreign)
  expect_identical(report$summary$structural_valid, FALSE)
  expect_validation_diagnostic(report, "RESERVED_COLUMNS_INVALID", "error")

  declared <- foreign
  record <- registration_record(declared)
  record$owned_columns <- "rec_antibiotic_note"
  S4Vectors::metadata(declared)$recoverome$analyses$antibiotic <- record
  report <- validate_recovery(declared)
  expect_validation_state(report, structural_valid = NA, validation_complete = FALSE)
  expect_validation_diagnostic(report, "STAGE_UNSUPPORTED", "error")
  expect_false("RESERVED_COLUMNS_INVALID" %in% report$diagnostics$code)

  missing <- tse
  S4Vectors::metadata(missing)$recoverome$analyses$antibiotic$owned_columns <- "rec_antibiotic_note"
  report <- validate_recovery(missing)
  expect_identical(report$summary$structural_valid, FALSE)
  expect_identical(report$summary$validation_complete, FALSE)
  expect_validation_diagnostic(report, "STAGE_UNSUPPORTED", "error")
  expect_validation_diagnostic(report, "RESERVED_COLUMNS_INVALID", "error")
})

test_that("formal invalidity becomes a report finding rather than an exception", {
  tse <- register_fixture(registration_fixture())
  original_validity <- methods::validObject
  testthat::local_mocked_bindings(
    validObject = function(object, test = FALSE, ...) {
      if (!methods::is(object, "TreeSummarizedExperiment")) {
        return(original_validity(object, test = test, ...))
      }
      if (isTRUE(test)) {
        return("container invariant failed")
      }
      stop("container invariant failed")
    },
    .package = "methods"
  )

  report <- validate_recovery(tse)

  expect_identical(report$summary$structural_valid, FALSE)
  expect_identical(report$summary$validation_complete, FALSE)
  expect_validation_diagnostic(report, "OBJECT_S4_INVALID", "error")
})

test_that("validation needs no assay accessor and never changes the container", {
  tse <- register_fixture(registration_fixture(trees = TRUE))
  tse <- tse["f1", c("s1", "s3"), drop = FALSE]
  before <- serialize(tse, NULL)
  testthat::local_mocked_bindings(
    assay = function(...) stop("validation accessed assay values"),
    assays = function(...) stop("validation accessed assay values"),
    .package = "SummarizedExperiment"
  )
  # Formal validity can inspect dimensions without retrieving an assay.
  expect_true(methods::validObject(tse))

  report <- validate_recovery(tse)

  expect_validation_state(
    report,
    sample_scope = "subset",
    feature_scope = "subset",
    n_retained = 2L
  )
  expect_identical(serialize(tse, NULL), before)
})
