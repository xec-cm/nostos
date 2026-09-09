test_that("deviations reproduce the independent RFC reference selections", {
  tse <- register_fixture(reference_fixture())
  cases <- list(
    list(baseline = c("b1", "b2", "b3"), features = NULL, expected = 0.3),
    list(baseline = "b1", features = NULL, expected = 0.4),
    list(baseline = c("b1", "b3"), features = NULL, expected = 0.35),
    list(baseline = c("b1", "b2", "b3"), features = c("a", "b"), expected = 0.2)
  )

  for (case in cases) {
    referenced <- add_reference(
      tse, "antibiotic", case$baseline, assay = "counts", features = case$features
    )
    out <- add_deviation(referenced, "antibiotic")
    values <- SummarizedExperiment::colData(out)$rec_antibiotic_deviation

    expect_equal(values[4L], case$expected, tolerance = 1e-12)
    expect_identical(
      SummarizedExperiment::colData(out)$rec_antibiotic_deviation_status,
      rep("computed", 4L)
    )
    expect_identical(registration_record(out)$reference, registration_record(referenced)$reference)
  }
})

test_that("repeated episodes use their own references and record actual result ownership", {
  tse <- register_fixture(registration_fixture())
  referenced <- add_reference(tse, "antibiotic", c("s1", "s4"), assay = "counts")
  out <- add_deviation(referenced, "antibiotic")
  record <- registration_record(out)
  deviation <- record$deviation

  expect_type(SummarizedExperiment::colData(out)$rec_antibiotic_deviation, "double")
  expect_equal(
    SummarizedExperiment::colData(out)$rec_antibiotic_deviation,
    c(0, 2 / 21, 4 / 33, 0, 2 / 285, NA_real_), tolerance = 1e-12
  )
  expect_identical(
    SummarizedExperiment::colData(out)$rec_antibiotic_deviation_status,
    c(rep("computed", 5L), "excluded")
  )
  expect_identical(deviation$schema_version, 1L)
  expect_identical(deviation$method, "bray_relative_v1")
  expect_identical(deviation$columns, c(
    deviation = "rec_antibiotic_deviation", status = "rec_antibiotic_deviation_status"
  ))
  expect_identical(record$owned_columns, unname(deviation$columns))
  expect_identical(deviation$sample_ids, paste0("s", 1:6))
  expect_identical(deviation$dependencies$reference_sha256, record$reference$fingerprint)
  expect_s4_class(deviation$dependencies$samples, "DataFrame")
  expect_identical(deviation$dependencies$samples$sample_id, paste0("s", 1:5))
  expect_s4_class(deviation$results, "DataFrame")
  expect_identical(deviation$results$sample_id, paste0("s", 1:6))
  expect_identical(deviation$provenance$fingerprint_format, "recoverome_inputs_v1")
  expect_identical(
    deviation$provenance$package_version, as.character(utils::packageVersion("recoverome"))
  )
  expect_match(deviation$provenance$created_at, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")
})

test_that("missing baselines and exclusions do not consume invalid sample abundances", {
  tse <- register_fixture(registration_fixture())
  referenced <- add_reference(tse, "antibiotic", "s1", assay = "counts")
  SummarizedExperiment::assay(referenced, "counts")[, "s4"] <- NA_real_
  SummarizedExperiment::assay(referenced, "counts")[, "s5"] <- -Inf
  SummarizedExperiment::assay(referenced, "counts")[, "s6"] <- 0
  SummarizedExperiment::colData(referenced)$time[6L] <- Inf
  SummarizedExperiment::colData(referenced)$subject_id[6L] <- "ignored excluded subject"
  out <- add_deviation(referenced, "antibiotic")

  expect_equal(
    SummarizedExperiment::colData(out)$rec_antibiotic_deviation,
    c(0, 2 / 21, 4 / 33, NA_real_, NA_real_, NA_real_), tolerance = 1e-12
  )
  expect_identical(
    SummarizedExperiment::colData(out)$rec_antibiotic_deviation_status,
    c(rep("computed", 3L), "missing_baseline", "missing_baseline", "excluded")
  )
  expect_identical(registration_record(out)$deviation$dependencies$samples$sample_id,
                   c("s1", "s2", "s3"))
  expect_identical(SummarizedExperiment::assay(out, "counts"),
                   SummarizedExperiment::assay(referenced, "counts"))
})

test_that("an empty reference supports missing results and a typed empty current scope", {
  tse <- register_fixture(registration_fixture())
  referenced <- add_reference(tse, "antibiotic", character(), assay = "counts")
  SummarizedExperiment::assay(referenced, "counts")[, ] <- NA_real_
  out <- add_deviation(referenced, "antibiotic")

  expect_identical(SummarizedExperiment::colData(out)$rec_antibiotic_deviation,
                   rep(NA_real_, 6L))
  expect_identical(
    SummarizedExperiment::colData(out)$rec_antibiotic_deviation_status,
    c(rep("missing_baseline", 5L), "excluded")
  )
  expect_identical(registration_record(out)$deviation$dependencies$samples$sample_id, character())

  empty <- add_deviation(referenced[, character(), drop = FALSE], "antibiotic")
  expect_identical(SummarizedExperiment::colData(empty)$rec_antibiotic_deviation, numeric())
  expect_identical(
    SummarizedExperiment::colData(empty)$rec_antibiotic_deviation_status, character()
  )
  expect_identical(registration_record(empty)$deviation$sample_ids, character())
  expect_identical(registration_record(empty)$deviation$results$sample_id, character())
  expect_identical(registration_record(empty)$deviation$results$result_sha256, character())
})

test_that("reordered identities and allowed filtering retain the defined feature calculation", {
  tse <- register_fixture(reference_fixture())
  referenced <- add_reference(
    tse, "antibiotic", c("b1", "b2", "b3"), assay = "counts", features = c("a", "b")
  )
  # The unselected feature can be invalid or absent; the selected block is unchanged.
  SummarizedExperiment::assay(referenced, "counts")["c", ] <- NA_real_
  reordered <- referenced[c("c", "b", "a"), c("q1", "b3", "b1", "b2"), drop = FALSE]
  out <- add_deviation(reordered, "antibiotic")

  expect_identical(colnames(out), c("q1", "b3", "b1", "b2"))
  expect_identical(rownames(out), c("c", "b", "a"))
  expect_equal(SummarizedExperiment::colData(out)$rec_antibiotic_deviation,
               c(0.2, 0, 0.1, 0.1), tolerance = 1e-12)
  expect_identical(registration_record(out)$deviation$sample_ids, colnames(reordered))
  expect_identical(registration_record(out)$scope$sample_ids, c("b1", "b2", "b3", "q1"))

  retained <- referenced[c("a", "b"), c("b1", "b2", "b3"), drop = FALSE]
  baseline_only <- add_deviation(retained, "antibiotic")
  expect_equal(SummarizedExperiment::colData(baseline_only)$rec_antibiotic_deviation,
               c(0.1, 0.1, 0), tolerance = 1e-12)
  expect_identical(registration_record(baseline_only)$deviation$sample_ids, c("b1", "b2", "b3"))
})

test_that("integer, double, sparse and delayed storage preserve the same measured deviations", {
  skip_if_not_installed("Matrix")
  skip_if_not_installed("DelayedArray")
  tse <- register_fixture(registration_fixture())
  referenced <- add_reference(tse, "antibiotic", c("s1", "s4"), assay = "counts")
  counts <- SummarizedExperiment::assay(referenced, "counts")
  counts[, "s6"] <- NA_integer_
  doubles <- matrix(as.double(counts), nrow = 2L, dimnames = dimnames(counts))
  backends <- list(
    integer = counts, double = doubles,
    sparse = Matrix::Matrix(doubles, sparse = TRUE),
    delayed = DelayedArray::DelayedArray(doubles)
  )
  records <- list()

  for (backend in names(backends)) {
    input <- referenced
    SummarizedExperiment::assay(input, "counts") <- backends[[backend]]
    out <- add_deviation(input, "antibiotic")
    records[[backend]] <- registration_record(out)$deviation

    expect_equal(SummarizedExperiment::colData(out)$rec_antibiotic_deviation,
                 c(0, 2 / 21, 4 / 33, 0, 2 / 285, NA_real_), tolerance = 1e-12)
    expect_identical(SummarizedExperiment::assay(out, "counts"), backends[[backend]])
  }

  for (record in records[-1L]) {
    expect_identical(record$dependencies, records$integer$dependencies)
    expect_identical(record$results, records$integer$results)
  }
})

test_that("deviation attachment preserves linked content and independent analysis histories", {
  fixture <- registration_fixture(trees = TRUE)
  fixture$tse <- register_fixture(fixture, analysis_id = "other")
  fixture$tse <- add_reference(fixture$tse, "other", "s1", assay = "counts")
  fixture$tse <- add_deviation(fixture$tse, "other")
  tse <- register_fixture(fixture)
  referenced <- add_reference(tse, "antibiotic", c("s1", "s4"), assay = "counts")
  before <- serialize(referenced, NULL)
  out <- add_deviation(referenced, "antibiotic")
  record <- registration_record(out)

  expect_identical(serialize(referenced, NULL), before)
  expect_identical(registration_record(out, "other"), registration_record(referenced, "other"))
  stripped <- out
  original_columns <- names(SummarizedExperiment::colData(referenced))
  SummarizedExperiment::colData(stripped) <- SummarizedExperiment::colData(stripped)[
    , original_columns, drop = FALSE
  ]
  S4Vectors::metadata(stripped)$recoverome$analyses$antibiotic <- registration_record(referenced)
  expect_identical(stripped, referenced)

  historical <- out["f1", c("s2", "s5", "s6"), drop = FALSE]
  expect_identical(registration_record(historical), record)
  expect_equal(SummarizedExperiment::colData(historical)$rec_antibiotic_deviation,
               c(2 / 21, 2 / 285, NA_real_), tolerance = 1e-12)
  expect_deviation_error(out, "recoverome_error_collision")
})
