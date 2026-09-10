test_that("selectors and unreadable identities fail at the public boundary", {
  tse <- recovery_parent()
  for (value in list(NULL, NA_character_, character(), c("sample", "episode"), 1, "sam")) {
    expect_error(recovery_results(tse, "antibiotic", level = value),
                 class = "recoverome_error_input")
  }
  for (value in list(NULL, NA_character_, c("current", "historical"), "hist")) {
    expect_error(recovery_results(tse, "antibiotic", scope = value),
                 class = "recoverome_error_input")
  }
  for (value in list(NULL, NA_character_, c("antibiotic", "other"), "bad_id", "absent")) {
    expect_error(recovery_results(tse, value), class = "recoverome_error_input")
  }
  expect_error(recovery_results(list(), "antibiotic"), class = "recoverome_error_input")
  duplicate <- tse[, c(1, 1)]
  before <- serialize(duplicate, NULL)
  error <- tryCatch(recovery_results(duplicate, "antibiotic"), error = identity)
  expect_s3_class(error, "recoverome_error_input")
  expect_identical(error$ids, c("b1", "b1"))
  expect_identical(error$call[[1L]], quote(recovery_results))
  expect_identical(serialize(duplicate, NULL), before)
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic$registration$samples <- NULL
  expect_error(recovery_results(tse, "antibiotic"), class = "recoverome_error_input")
})

test_that("formal TSE failure cannot be hidden by readable saved tables", {
  tse <- recovery_parent()
  original_validity <- methods::validObject
  local_mocked_bindings(
    validObject = function(object, ...) {
      if (methods::is(object, "TreeSummarizedExperiment")) return("container invariant failed")
      original_validity(object, ...)
    },
    .package = "methods"
  )
  error <- tryCatch(recovery_results(tse, "antibiotic"), error = identity)
  expect_s3_class(error, "recoverome_error_input")
  expect_identical(error$component, "tse")
})

test_that("saved output and parent corruption blocks either view despite unavailable inputs", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  altered <- missing <- parent <- self <- tse
  SummarizedExperiment::colData(altered)$rec_antibiotic_deviation[3] <- 0.9
  SummarizedExperiment::assay(altered, "counts")[, "s1"] <- NA_real_
  SummarizedExperiment::colData(missing)$rec_antibiotic_deviation_status <- NULL
  record <- registration_record(parent)
  record$deviation$dependencies$reference_sha256 <- strrep("0", 64)
  S4Vectors::metadata(parent)$recoverome$analyses$antibiotic <- record
  S4Vectors::metadata(self)$recoverome$analyses$antibiotic$recovery$fingerprint <- strrep("0", 64)
  for (input in list(altered, missing, parent, self)) {
    before <- serialize(input, NULL)
    for (level in c("sample", "episode")) {
      expect_error(recovery_results(input, "antibiotic", level), class = "recoverome_error_input")
    }
    expect_identical(serialize(input, NULL), before)
  }
  error <- tryCatch(recovery_results(altered, "antibiotic", "sample"), error = identity)
  expect_identical(error$ids, "s2")
  expect_match(error$component, "^deviation\\$")
})

test_that("required schemas fail while unsupported optional stages remain opaque", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  for (stage in c("reference", "deviation", "recovery")) {
    unknown <- tse
    S4Vectors::metadata(unknown)$recoverome$analyses$antibiotic[[stage]] <-
      list(schema_version = 99L, episodes = "unreadable", definition = new.env())
    expect_error(recovery_results(unknown, "antibiotic"), class = "recoverome_error_input")
    if (stage != "recovery") {
      expect_error(recovery_results(unknown, "antibiotic", "sample"),
                   class = "recoverome_error_input")
      next
    }
    view <- results_preserving_input(unknown, "sample")
    expect_identical(view$deviation[3], 0.25)
    expect_true(all(is.na(view$structural_valid)))
    expect_false(any(view$validation_complete))
    context <- S4Vectors::metadata(view)$recoverome_view
    expect_identical(context$uninterpreted_stages, "recovery")
    expect_null(context$evidence)
    expect_null(context$definitions$recovery)
    expect_null(context$scopes$recovery)
    expect_null(context$provenance$recovery)
  }
  parent <- recovery_parent()
  S4Vectors::metadata(parent)$recoverome$analyses$antibiotic$deviation <-
    list(schema_version = 99L, columns = "unreadable")
  view <- results_preserving_input(parent)
  expect_identical(view$reference_support, "single_sample")
  expect_identical(view$result_state, "not_computed")
  context <- S4Vectors::metadata(view)$recoverome_view
  expect_identical(context$uninterpreted_stages, "deviation")
  expect_null(context$definitions$deviation)
  expect_null(context$scopes$deviation)
  expect_null(context$provenance$deviation)

  extra <- tse
  S4Vectors::metadata(extra)$recoverome$analyses$antibiotic$future <- new.env()
  view <- results_preserving_input(extra)
  expect_identical(view$confirmation_time, 6)
  context <- S4Vectors::metadata(view)$recoverome_view
  expect_identical(context$uninterpreted_stages, "future")
  expect_null(context$definitions$future)
  expect_null(context$scopes$future)
  expect_null(context$provenance$future)
})

test_that("optional does not excuse supported corruption or a missing parent", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  malformed <- orphan <- tse
  S4Vectors::metadata(malformed)$recoverome$analyses$antibiotic$recovery <-
    list(schema_version = 1L)
  expect_error(recovery_results(malformed, "antibiotic", "sample"),
               class = "recoverome_error_input")
  S4Vectors::metadata(orphan)$recoverome$analyses$antibiotic$recovery <- list(schema_version = 99L)
  S4Vectors::metadata(orphan)$recoverome$analyses$antibiotic$deviation <- NULL
  expect_error(recovery_results(orphan, "antibiotic", "sample"),
               class = "recoverome_error_input")
  orphan <- recovery_parent()
  S4Vectors::metadata(orphan)$recoverome$analyses$antibiotic$reference <- NULL
  expect_error(recovery_results(orphan, "antibiotic"), class = "recoverome_error_input")
})

test_that("unknown formats permit readable results without concealing independent failures", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  for (stage in c("reference", "deviation", "recovery")) {
    unknown <- tse
    record <- registration_record(unknown)
    record[[stage]]$provenance$fingerprint_format <- "future"
    S4Vectors::metadata(unknown)$recoverome$analyses$antibiotic <- record
    view <- results_preserving_input(unknown)
    expect_identical(view$confirmation_time, 6)
    expect_identical(view$dependencies, "not_checked")
    expect_false(view$validation_complete)
  }
  SummarizedExperiment::colData(unknown)$rec_antibiotic_deviation[3] <- 0.9
  expect_error(recovery_results(unknown, "antibiotic"), class = "recoverome_error_input")
  unknown <- tse
  record <- registration_record(unknown)
  record$deviation$provenance$fingerprint_format <- "future"
  S4Vectors::metadata(unknown)$recoverome$analyses$antibiotic <- record
  SummarizedExperiment::assay(unknown, "counts")[, "b1"] <- c(6, 2)
  expect_identical(results_preserving_input(unknown)$dependencies, "changed")
  SummarizedExperiment::colData(unknown)$rec_antibiotic_deviation[3] <- 2
  expect_error(recovery_results(unknown, "antibiotic"), class = "recoverome_error_input")
})

test_that("missing or ambiguous current sources preserve saved output and diagnostics", {
  tse <- recovery_parent()
  missing <- ambiguous <- tse
  SummarizedExperiment::assayNames(missing) <- "renamed"
  counts <- SummarizedExperiment::assay(ambiguous, "counts")
  SummarizedExperiment::assays(ambiguous) <- list(counts = counts, counts = counts)
  for (input in list(missing, ambiguous)) {
    view <- results_preserving_input(input, "sample")
    expect_identical(view$deviation[3], 0.25)
    expect_identical(view$dependencies, rep("changed", 7))
    expect_false(any(view$validation_complete))
  }
  annotation <- SummarizedExperiment::colData(tse)
  annotation$duplicate_day <- annotation$day
  names(annotation)[ncol(annotation)] <- "day"
  SummarizedExperiment::colData(tse) <- annotation
  view <- results_preserving_input(tse, "sample")
  expect_identical(view$relative_time[3], 2)
  report <- S4Vectors::metadata(view)$recoverome_view$validation
  expect_true("DEPENDENCY_COLUMN_AMBIGUOUS" %in% report$diagnostics$code)
})

test_that("each extraction validates only its selected analysis exactly once", {
  tse <- recovery_parent()
  S4Vectors::metadata(tse)$recoverome$analyses$other <- "unreadable"
  calls <- new.env(parent = emptyenv())
  calls$count <- 0L
  original <- recoverome:::.recovery_validate_input
  local_mocked_bindings(
    .recovery_validate_input = function(tse, analysis_id, error_call, allow_all = TRUE) {
      calls$count <- calls$count + 1L
      original(tse, analysis_id, error_call, allow_all)
    },
    .package = "recoverome"
  )
  first <- results_preserving_input(tse, "sample")
  expect_identical(calls$count, 1L)
  expect_true(all(first$validation_complete))
  report <- S4Vectors::metadata(first)$recoverome_view$validation
  expect_identical(report$summary$analysis_id, "antibiotic")
  SummarizedExperiment::assay(tse, "counts")[, "s2"] <- c(4, 4)
  second <- results_preserving_input(tse, "sample")
  expect_identical(calls$count, 2L)
  expect_identical(second$dependencies, rep("changed", 7))
  expect_identical(first$dependencies, rep("unchanged", 7))
})
