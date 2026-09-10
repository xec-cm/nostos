# These opt-in tests reuse the bundled fixture and base integration helpers.
# Loading the adapter registers methods on TSE's existing SCE superclass.
fixture_helpers <- new.env()
sys.source("../../tests/testthat/helper-registration.R", envir = fixture_helpers)

tidy_fixture <- function() {
  fixture <- fixture_helpers$registration_fixture(trees = TRUE)
  row_tree <- TreeSummarizedExperiment::rowTree(fixture$tse)
  row_tree$tip.label <- c("f2", "f1")
  TreeSummarizedExperiment::rowTree(fixture$tse) <- row_tree
  col_tree <- TreeSummarizedExperiment::colTree(fixture$tse)
  col_tree$tip.label <- c("s4", "s1", "s6", "s2", "s5", "s3")
  TreeSummarizedExperiment::colTree(fixture$tse) <- col_tree
  registered <- fixture_helpers$register_fixture(fixture)
  referenced <- nostos::add_reference(
    registered, "antibiotic", c("s1", "s4"), assay = "counts"
  )
  deviated <- nostos::add_deviation(referenced, "antibiotic")
  fixture$tse <- nostos::add_recovery(deviated, "antibiotic", fixture_helpers$observed_rule())

  fixture_helpers$register_fixture(fixture, analysis_id = "control")
}

expect_tidy_preservation <- function(actual, expected, original) {
  testthat::expect_s4_class(actual, "TreeSummarizedExperiment")
  testthat::expect_true(methods::validObject(actual))
  testthat::expect_identical(rownames(actual), rownames(expected))
  testthat::expect_identical(colnames(actual), colnames(expected))
  testthat::expect_identical(
    SummarizedExperiment::assays(actual), SummarizedExperiment::assays(expected)
  )
  testthat::expect_identical(
    SummarizedExperiment::rowData(actual), SummarizedExperiment::rowData(expected)
  )
  testthat::expect_identical(
    SummarizedExperiment::colData(actual), SummarizedExperiment::colData(expected)
  )
  testthat::expect_identical(
    TreeSummarizedExperiment::rowTree(actual), TreeSummarizedExperiment::rowTree(expected)
  )
  testthat::expect_identical(
    TreeSummarizedExperiment::colTree(actual), TreeSummarizedExperiment::colTree(expected)
  )
  testthat::expect_identical(
    TreeSummarizedExperiment::rowLinks(actual), TreeSummarizedExperiment::rowLinks(expected)
  )
  testthat::expect_identical(
    TreeSummarizedExperiment::colLinks(actual), TreeSummarizedExperiment::colLinks(expected)
  )
  testthat::expect_identical(S4Vectors::metadata(actual), S4Vectors::metadata(original))
  testthat::expect_identical(
    names(S4Vectors::metadata(actual)$recoverome$analyses), c("antibiotic", "control")
  )
  testthat::expect_identical(
    nostos::validate_recovery(actual), nostos::validate_recovery(expected)
  )
}

expect_tidy_views <- function(actual, expected) {
  for (level in c("sample", "episode")) {
    for (scope in c("current", "historical")) {
      testthat::expect_identical(
        nostos::recovery_results(actual, "antibiotic", level, scope),
        nostos::recovery_results(expected, "antibiotic", level, scope)
      )
    }
  }
}

testthat::test_that("sample filtering retains trees, annotations and two named histories", {
  original <- tidy_fixture()
  before <- serialize(original, NULL)
  actual <- dplyr::filter(original, .cell %in% c("s1", "s3", "s6"))
  expected <- original[, c("s1", "s3", "s6"), drop = FALSE]
  expect_tidy_preservation(actual, expected, original)
  expect_tidy_views(actual, expected)
  testthat::expect_identical(colnames(actual), c("s1", "s3", "s6"))
  testthat::expect_identical(
    unname(TreeSummarizedExperiment::colLinks(actual)$nodeNum), c(2L, 6L, 3L)
  )
  report <- nostos::validate_recovery(actual, "antibiotic")
  testthat::expect_identical(report$summary$sample_scope, "subset")
  testthat::expect_identical(report$summary$dependencies, "not_checked")
  testthat::expect_false(report$summary$validation_complete)
  testthat::expect_true(all(c(
    "SAMPLE_SCOPE_REDUCED", "REFERENCE_INPUT_MISSING", "DEVIATION_SAMPLE_MISSING",
    "RECOVERY_INPUT_MISSING"
  ) %in% report$diagnostics$code))
  testthat::expect_identical(serialize(original, NULL), before)
})

testthat::test_that("annotation filters and empty or excluded-only selections match base", {
  original <- tidy_fixture()
  by_annotation <- dplyr::filter(original, episode_id == "e1")
  expected <- original[, c("s1", "s2", "s3"), drop = FALSE]
  expect_tidy_preservation(by_annotation, expected, original)
  expect_tidy_views(by_annotation, expected)

  for (ids in list("s6", character())) {
    actual <- dplyr::filter(original, .cell %in% ids)
    expected <- original[, ids, drop = FALSE]
    expect_tidy_preservation(actual, expected, original)
    expect_tidy_views(actual, expected)
    current <- nostos::recovery_results(actual, "antibiotic")
    historical <- nostos::recovery_results(actual, "antibiotic", scope = "historical")
    testthat::expect_identical(nrow(current), 0L)
    testthat::expect_identical(historical$episode_id, c("e1", "e2"))
    testthat::expect_identical(historical$result_state, c("available", "available"))
  }
})

testthat::test_that("sample reordering preserves ID links and original extraction order", {
  original <- tidy_fixture()
  actual <- dplyr::arrange(original, dplyr::desc(.cell))
  expected <- original[, c("s6", "s5", "s4", "s3", "s2", "s1"), drop = FALSE]
  expect_tidy_preservation(actual, expected, original)
  expect_tidy_views(actual, expected)
  testthat::expect_identical(
    unname(TreeSummarizedExperiment::colLinks(actual)$nodeNum), c(3L, 5L, 1L, 6L, 4L, 2L)
  )
  view <- nostos::recovery_results(actual, "antibiotic", "sample")
  testthat::expect_identical(view$sample_id, paste0("s", 1:6))
  testthat::expect_true(all(view$dependencies == "unchanged"))
})

testthat::test_that("ordinary annotation mutation preserves the complete TSE", {
  original <- tidy_fixture()
  actual <- dplyr::mutate(original, note = paste0("batch-", batch))
  expected <- original
  annotations <- SummarizedExperiment::colData(expected)
  annotations$note <- c("batch-a", "batch-b", "batch-a", "batch-b", "batch-a", "batch-b")
  SummarizedExperiment::colData(expected) <- annotations
  expect_tidy_preservation(actual, expected, original)
  expect_tidy_views(actual, expected)
})

testthat::test_that("source mutation is diagnosed without rewriting saved coordinates", {
  original <- tidy_fixture()
  actual <- dplyr::mutate(original, time = time + 1)
  expected <- original
  annotations <- SummarizedExperiment::colData(expected)
  annotations$time <- c(4, 11, 18, 35, 44, NA_real_)
  SummarizedExperiment::colData(expected) <- annotations
  expect_tidy_preservation(actual, expected, original)
  expect_tidy_views(actual, expected)
  report <- nostos::validate_recovery(actual)
  testthat::expect_identical(report$summary$dependencies, c("changed", "changed"))
  testthat::expect_true("DEPENDENCY_VALUE_CHANGED" %in% report$diagnostics$code)
  view <- nostos::recovery_results(actual, "antibiotic", "sample")
  testthat::expect_identical(view$time, c(3, 10, 17, 34, 43, NA_real_))
})

testthat::test_that("owned deviation mutation remains an error, isolated to its analysis", {
  original <- tidy_fixture()
  actual <- dplyr::mutate(original, rec_antibiotic_deviation = 0)
  expected <- original
  annotations <- SummarizedExperiment::colData(expected)
  annotations$rec_antibiotic_deviation <- rep(0, 6L)
  SummarizedExperiment::colData(expected) <- annotations
  expect_tidy_preservation(actual, expected, original)
  report <- nostos::validate_recovery(actual)
  testthat::expect_identical(report$summary$structural_valid, c(FALSE, TRUE))
  testthat::expect_identical(report$summary$dependencies, c("changed", "unchanged"))
  testthat::expect_true("RESULT_INCONSISTENT" %in% report$diagnostics$code)
  for (level in c("sample", "episode")) {
    testthat::expect_error(
      nostos::recovery_results(actual, "antibiotic", level), class = "recoverome_error"
    )
    testthat::expect_error(
      nostos::recovery_results(expected, "antibiotic", level), class = "recoverome_error"
    )
  }
})

testthat::test_that("feature filtering and sample renaming are outside this adapter view", {
  original <- tidy_fixture()
  before <- serialize(original, NULL)
  testthat::expect_error(dplyr::filter(original, taxonomy == "taxon-a"), "taxonomy")
  testthat::expect_error(dplyr::mutate(original, .cell = paste0("new-", .cell)), "view only")
  testthat::expect_identical(serialize(original, NULL), before)
})

testthat::test_that("mutation loses colData metadata and is unsupported for that case", {
  original <- tidy_fixture()
  annotations <- SummarizedExperiment::colData(original)
  S4Vectors::metadata(annotations) <- list(annotation_note = "retain me")
  SummarizedExperiment::colData(original) <- annotations
  actual <- dplyr::mutate(original, note = "ok")
  testthat::expect_identical(S4Vectors::metadata(SummarizedExperiment::colData(actual)), list())
  testthat::expect_identical(
    S4Vectors::metadata(SummarizedExperiment::colData(original)),
    list(annotation_note = "retain me")
  )
  # Column descriptors are lost too, even with empty DataFrame-level metadata.
  annotations <- SummarizedExperiment::colData(original)
  S4Vectors::metadata(annotations) <- list()
  S4Vectors::mcols(annotations) <- S4Vectors::DataFrame(description = names(annotations))
  SummarizedExperiment::colData(original) <- annotations
  actual <- dplyr::mutate(original, note = "ok")
  testthat::expect_null(S4Vectors::mcols(SummarizedExperiment::colData(actual)))
  testthat::expect_identical(
    S4Vectors::mcols(SummarizedExperiment::colData(original))$description,
    names(annotations)
  )
  testthat::expect_identical(S4Vectors::metadata(annotations), list())
  # The limitation concerns annotation metadata, not the named TSE records.
  testthat::expect_identical(S4Vectors::metadata(actual), S4Vectors::metadata(original))
})
