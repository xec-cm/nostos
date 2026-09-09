test_that("baseline selection is explicit, current, unique and included", {
  tse <- register_fixture(registration_fixture())
  for (selection in list(c("s1", "s1"), "absent", "s6", factor("s1"), 1L)) {
    expect_reference_error(tse, selection)
  }

  expect_error(
    add_reference(tse, "unregistered", "s1", assay = "counts"),
    class = "recoverome_error"
  )

  removed <- tse[, c("s2", "s3", "s4", "s5", "s6"), drop = FALSE]
  expect_reference_error(removed, "s1")
  expect_reference_error(tse, "s1", features = character())
  expect_reference_error(tse, "s1", features = c("f1", "f1"))
  expect_reference_error(tse, "s1", features = "unknown")
  expect_reference_error(tse[character(), , drop = FALSE], character())
})

test_that("baseline eligibility is strictly before event start even with an end origin", {
  fixture <- registration_fixture()
  SummarizedExperiment::colData(fixture$tse)$time[5L] <- 41
  tse <- register_fixture(fixture)
  out <- add_reference(tse, "antibiotic", "s4", assay = "counts")

  expect_equal(
    unname(registration_record(out)$reference$profiles[, "e2"]),
    c(7 / 15, 8 / 15), tolerance = 1e-12
  )
  # s2 is exactly at event start; s5 precedes event end but follows its start.
  expect_reference_error(tse, "s2")
  expect_reference_error(tse, "s5")
})

test_that("only the selected assay block needs finite nonnegative values and positive totals", {
  tse <- register_fixture(reference_fixture())
  invalid_columns <- list(
    c(NA_real_, 2, 0), c(-1, 2, 0), c(Inf, 2, 0), c(0, 0, 0),
    rep(.Machine$double.xmax, 3L)
  )
  for (invalid_values in invalid_columns) {
    invalid <- tse
    SummarizedExperiment::assay(invalid, "counts")[, "b1"] <- invalid_values
    expect_reference_error(invalid, "b1")
  }

  empty_selected_total <- tse
  SummarizedExperiment::assay(empty_selected_total, "counts")[c("a", "b"), "b1"] <- 0
  SummarizedExperiment::assay(empty_selected_total, "counts")["c", "b1"] <- 10
  expect_reference_error(empty_selected_total, "b1", features = c("a", "b"))

  for (invalid_type in list(TRUE, "1", 1 + 0i)) {
    invalid <- tse
    counts <- SummarizedExperiment::assay(invalid, "counts")
    invalid_assay <- matrix(
      invalid_type, nrow = nrow(counts), ncol = ncol(counts), dimnames = dimnames(counts)
    )
    SummarizedExperiment::assay(invalid, "counts") <- invalid_assay
    expect_reference_error(invalid, "b1")
  }
})

test_that("an assay failure retains the public call and structured offending sample", {
  tse <- register_fixture(reference_fixture())
  SummarizedExperiment::assay(tse, "counts")["a", "b1"] <- NA_real_
  before <- serialize(tse, NULL)

  condition <- tryCatch(
    add_reference(tse, "antibiotic", "b1", assay = "counts"),
    error = identity
  )

  expect_s3_class(condition, "recoverome_error_input")
  expect_identical(conditionCall(condition)[[1L]], quote(add_reference))
  expect_identical(condition$component, "assay")
  expect_identical(condition$ids, "b1")
  expect_identical(serialize(tse, NULL), before)
})

test_that("an assay name is required and must identify exactly one assay", {
  tse <- register_fixture(reference_fixture())
  expect_error(add_reference(tse, "antibiotic", "b1"))
  expect_reference_error(tse, "b1", assay = "absent")

  counts <- SummarizedExperiment::assay(tse, "counts")
  SummarizedExperiment::assays(tse) <- list(counts = counts, counts = counts)
  expect_reference_error(tse, "b1")
})

test_that("dense, sparse and delayed assays agree while ignoring unconsumed values", {
  testthat::skip_if_not_installed("Matrix")
  testthat::skip_if_not_installed("DelayedArray")
  fixture <- reference_fixture()
  counts <- SummarizedExperiment::assay(fixture$tse, "counts")
  counts["c", ] <- NA_real_
  counts[, "q1"] <- -Inf
  backends <- list(
    dense = counts,
    sparse = Matrix::Matrix(counts, sparse = TRUE),
    delayed = DelayedArray::DelayedArray(counts)
  )
  references <- list()

  for (backend in names(backends)) {
    input <- fixture
    SummarizedExperiment::assay(input$tse, "counts") <- backends[[backend]]
    tse <- register_fixture(input)
    out <- add_reference(
      tse, "antibiotic", c("b1", "b2", "b3"), assay = "counts", features = c("a", "b")
    )
    references[[backend]] <- registration_record(out)$reference
    expect_equal(
      unname(references[[backend]]$profiles[, "e1"]), c(0.7, 0.3), tolerance = 1e-12
    )
    expect_identical(SummarizedExperiment::assay(out, "counts"), backends[[backend]])
  }

  expect_identical(references$sparse$dependencies, references$dense$dependencies)
  expect_identical(references$delayed$dependencies, references$dense$dependencies)
})

test_that("reference attachment checks retained parent metadata beyond selected baselines", {
  tse <- register_fixture(registration_fixture())
  invalid_followup <- tse
  SummarizedExperiment::colData(invalid_followup)$time[3L] <- 18
  expect_reference_error(invalid_followup, "s1")

  excluded <- tse
  SummarizedExperiment::colData(excluded)$time[6L] <- Inf
  SummarizedExperiment::colData(excluded)$subject_id[6L] <- "ignored excluded subject"
  out <- add_reference(excluded, "antibiotic", "s1", assay = "counts")
  expect_equal(
    unname(registration_record(out)$reference$profiles[, "e1"]),
    c(1 / 3, 2 / 3), tolerance = 1e-12
  )

  expanded <- tse[, c(seq_len(6L), 1L), drop = FALSE]
  colnames(expanded)[7L] <- "new-sample"
  expect_reference_error(expanded, "s1")
})

test_that("unsupported or already populated stages are rejected without partial reference writes", {
  tse <- register_fixture(registration_fixture())
  for (stage in c("deviation", "recovery")) {
    downstream <- tse
    record <- registration_record(downstream)
    record[[stage]] <- list(schema_version = 1L)
    S4Vectors::metadata(downstream)$recoverome$analyses$antibiotic <- record
    expect_reference_error(downstream, "s1")
  }

  unsupported <- tse
  S4Vectors::metadata(unsupported)$recoverome$analyses$antibiotic <- list(schema_version = 99L)
  expect_reference_error(unsupported, "s1")
  expect_error(
    add_reference(unsupported, "antibiotic", "s1", assay = "counts"),
    class = "recoverome_error_namespace"
  )
  occupied <- tse
  SummarizedExperiment::colData(occupied)$rec_antibiotic_note <- "unowned"
  expect_reference_error(occupied, "s1")
})
