test_that("the personal reference is the mean of sample compositions with explicit support", {
  tse <- register_fixture(reference_fixture())
  expect_silent(out <- add_reference(
    tse, "antibiotic", c("b3", "b1", "b2"), assay = "counts",
    preprocessing = "Explicit RFC example"
  ))
  reference <- registration_record(out)$reference

  expect_identical(class(reference), "list")
  expect_named(reference, c(
    "schema_version", "definition", "baseline_samples", "episodes", "profiles",
    "dependencies", "provenance", "fingerprint"
  ))
  expect_identical(reference$schema_version, 1L)
  expect_identical(reference$definition, list(
    sample_ids = c("b3", "b1", "b2"),
    assay = "counts",
    feature_ids = c("a", "b", "c"),
    preprocessing = "Explicit RFC example",
    normalization = "closure_v1",
    estimator = "sample_mean_v1"
  ))
  expect_s4_class(reference$baseline_samples, "DataFrame")
  expect_identical(reference$baseline_samples$sample_id, c("b1", "b2", "b3"))
  expect_identical(reference$baseline_samples$episode_id, rep("e1", 3L))
  expect_type(reference$profiles, "double")
  expect_identical(dimnames(reference$profiles), list(c("a", "b", "c"), "e1"))
  expect_equal(unname(reference$profiles[, "e1"]), c(0.7, 0.3, 0), tolerance = 1e-12)
  expect_s4_class(reference$episodes, "DataFrame")
  expect_equal(as.list(reference$episodes), list(
    episode_id = "e1", support = "multiple_times", n_samples = 3L, n_times = 3L,
    first_time = 3, last_time = 7, baseline_diameter = 0.2
  ), tolerance = 1e-12)
  expect_identical(reference$provenance$fingerprint_format, "recoverome_inputs_v1")
  expect_match(reference$fingerprint, "^[0-9a-f]{64}$")
  expect_identical(registration_record(out)$owned_columns, character())
})

test_that("empty selections describe absent baselines even after removing all current samples", {
  tse <- register_fixture(registration_fixture())

  for (input in list(tse, tse[, character(), drop = FALSE])) {
    out <- add_reference(input, "antibiotic", character(), assay = "counts")
    reference <- registration_record(out)$reference

    expect_identical(reference$definition$sample_ids, character())
    expect_identical(reference$baseline_samples$sample_id, character())
    expect_identical(reference$baseline_samples$episode_id, character())
    expect_identical(dim(reference$profiles), c(2L, 0L))
    expect_identical(rownames(reference$profiles), c("f1", "f2"))
    expect_identical(reference$episodes$episode_id, c("e1", "e2"))
    expect_identical(reference$episodes$support, rep("missing_baseline", 2L))
    expect_identical(reference$episodes$n_samples, c(0L, 0L))
    expect_identical(reference$episodes$n_times, c(0L, 0L))
    expect_identical(reference$episodes$first_time, rep(NA_real_, 2L))
    expect_identical(reference$episodes$last_time, rep(NA_real_, 2L))
    expect_identical(reference$episodes$baseline_diameter, rep(NA_real_, 2L))
    expect_identical(reference$dependencies$samples$sample_id, character())
    expect_identical(reference$dependencies$samples$input_sha256, character())
  }
})

test_that("one baseline is descriptive and is not borrowed by another episode", {
  tse <- register_fixture(registration_fixture())
  out <- add_reference(tse, "antibiotic", "s1", assay = "counts")
  reference <- registration_record(out)$reference

  expect_identical(reference$episodes$support, c("single_sample", "missing_baseline"))
  expect_identical(reference$episodes$n_samples, c(1L, 0L))
  expect_identical(reference$episodes$n_times, c(1L, 0L))
  expect_identical(reference$episodes$baseline_diameter, c(NA_real_, NA_real_))
  expect_identical(colnames(reference$profiles), "e1")
  expect_equal(unname(reference$profiles[, "e1"]), c(1 / 3, 2 / 3), tolerance = 1e-12)
})

test_that("repeated times change support without changing equal sample weights", {
  cases <- list(
    list(times = c(3, 3, 7, 17), support = "multiple_times", n_times = 2L, last = 7),
    list(times = c(3, 3, 3, 17), support = "single_time", n_times = 1L, last = 3)
  )

  for (case in cases) {
    fixture <- reference_fixture()
    SummarizedExperiment::colData(fixture$tse)$time <- case$times
    tse <- register_fixture(fixture)
    out <- add_reference(tse, "antibiotic", c("b1", "b2", "b3"), assay = "counts")
    reference <- registration_record(out)$reference

    expect_equal(unname(reference$profiles[, "e1"]), c(0.7, 0.3, 0), tolerance = 1e-12)
    expect_identical(reference$episodes$support, case$support)
    expect_identical(reference$episodes$n_samples, 3L)
    expect_identical(reference$episodes$n_times, case$n_times)
    expect_identical(reference$episodes$first_time, 3)
    expect_identical(reference$episodes$last_time, case$last)
    expect_equal(reference$episodes$baseline_diameter, 0.2, tolerance = 1e-12)
  }
})

test_that("feature selection closes each sample anew and permits one selected feature", {
  fixture <- reference_fixture()
  SummarizedExperiment::assay(fixture$tse, "counts")["c", "b1"] <- 90
  tse <- register_fixture(fixture)
  baseline_ids <- c("b1", "b2", "b3")
  full <- add_reference(tse, "antibiotic", baseline_ids, assay = "counts")
  subset <- add_reference(tse, "antibiotic", baseline_ids, assay = "counts", features = c("a", "b"))
  single <- add_reference(tse, "antibiotic", baseline_ids, assay = "counts", features = "a")

  expect_equal(
    unname(registration_record(full)$reference$profiles[, "e1"]),
    c(0.46, 0.24, 0.3), tolerance = 1e-12
  )
  expect_equal(
    unname(registration_record(subset)$reference$profiles[, "e1"]),
    c(0.7, 0.3), tolerance = 1e-12
  )
  expect_identical(registration_record(subset)$scope$feature_ids, c("a", "b", "c"))
  expect_identical(registration_record(single)$reference$profiles[1L, "e1"], 1)
  expect_identical(registration_record(single)$reference$episodes$baseline_diameter, 0)
})

test_that("matching by identity preserves profiles and source hashes after axis reordering", {
  tse <- register_fixture(reference_fixture())
  baseline_ids <- c("b1", "b2", "b3")
  expected <- add_reference(tse, "antibiotic", baseline_ids, assay = "counts")
  reordered <- tse[c("c", "a", "b"), c("q1", "b3", "b1", "b2"), drop = FALSE]
  actual <- add_reference(
    reordered, "antibiotic", baseline_ids, assay = "counts", features = c("a", "b", "c")
  )

  expect_identical(registration_record(actual)$reference$profiles,
                   registration_record(expected)$reference$profiles)
  expect_identical(registration_record(actual)$reference$baseline_samples,
                   registration_record(expected)$reference$baseline_samples)
  expect_identical(registration_record(actual)$reference$dependencies,
                   registration_record(expected)$reference$dependencies)
  expect_identical(colnames(actual), c("q1", "b3", "b1", "b2"))
  expect_identical(rownames(actual), c("c", "a", "b"))
})

test_that("reference attachment preserves linked TSE content, other analyses and history", {
  fixture <- registration_fixture(trees = TRUE)
  fixture$tse <- register_fixture(fixture, analysis_id = "other")
  tse <- register_fixture(fixture)
  before <- serialize(tse, NULL)
  out <- add_reference(tse, "antibiotic", c("s4", "s1"), assay = "counts")
  reference <- registration_record(out)$reference

  expect_identical(serialize(tse, NULL), before)
  expect_identical(registration_record(out, "other"), registration_record(tse, "other"))
  without_reference <- out
  metadata <- S4Vectors::metadata(without_reference)
  metadata$recoverome$analyses$antibiotic$reference <- NULL
  S4Vectors::metadata(without_reference) <- metadata
  expect_identical(without_reference, tse)

  filtered <- out["f1", "s4", drop = FALSE]
  expect_identical(registration_record(filtered)$reference, reference)
  expect_identical(dim(reference$profiles), c(2L, 2L))
  expect_identical(reference$baseline_samples$sample_id, c("s1", "s4"))
  expect_reference_error(out, c("s4", "s1"))
})
