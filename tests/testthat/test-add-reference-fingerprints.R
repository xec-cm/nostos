test_that("fingerprinting implements the fixed RFC compatibility vector and canonical encoding", {
  value <- list(
    sample_id = enc2utf8("s\u00e9"),
    feature_ids = c("f1", "f2", "f3"),
    values = c(0, 0.25, 0.75),
    missing = NA_real_,
    n = 3L
  )
  expected <- "0ebcc76956478405e0d59c09fd5ac022c6f231bd1677471c913c63132d574406"
  expect_identical(nostos:::.recovery_fingerprint(value), expected)

  equivalent <- value
  equivalent$sample_id <- iconv(value$sample_id, from = "UTF-8", to = "latin1")
  equivalent$missing <- -NA_real_
  equivalent$values[1L] <- -0
  attr(equivalent$values, "annotation") <- "not a consumed field"
  expect_identical(nostos:::.recovery_fingerprint(equivalent), expected)
})

test_that("source fingerprints depend on normalized values rather than R storage details", {
  compact <- as.double(1:3)
  materialized <- c(1, 2, 3)
  named_values <- setNames(materialized, c("a", "b", "c"))
  expected <- nostos:::.recovery_hash_source("s1", c("a", "b", "c"), materialized)

  expect_identical(
    nostos:::.recovery_hash_source("s1", c("a", "b", "c"), compact), expected
  )
  expect_identical(
    nostos:::.recovery_hash_source("s1", c("a", "b", "c"), 1:3), expected
  )
  expect_identical(
    nostos:::.recovery_hash_source("s1", c("a", "b", "c"), named_values),
    expected
  )
  expect_identical(
    nostos:::.recovery_hash_source("s1", c("a", "b"), c(-0, 1)),
    nostos:::.recovery_hash_source("s1", c("a", "b"), c(0, 1))
  )
})

test_that("parent fingerprints exclude annotations while retaining declared time semantics", {
  record <- registration_record(register_fixture(registration_fixture()))
  original <- nostos:::.recovery_hash_registration(record)
  annotated <- record
  annotated$episodes$note <- c("new note", "another note")
  rownames(annotated$events) <- c("annotation-row-a", "annotation-row-b")
  annotated$provenance$registered_at <- "2000-01-01T00:00:00Z"

  expect_identical(nostos:::.recovery_hash_registration(annotated), original)

  changed <- record
  changed$registration$time_origin <- "days since a different declared origin"
  expect_false(identical(nostos:::.recovery_hash_registration(changed), original))
})

test_that("source edits and composition changes have distinct evidence", {
  tse <- register_fixture(reference_fixture())
  baseline_ids <- c("b1", "b2", "b3")
  original <- add_reference(tse, "antibiotic", baseline_ids, assay = "counts")
  original_reference <- registration_record(original)$reference
  source_projection <- list(sample_id = "b1", feature_ids = c("a", "b", "c"), values = c(8, 2, 0))
  expected_source <- digest::digest(
    source_projection,
    algo = "sha256",
    serialize = TRUE,
    serializeVersion = 2,
    skip = "auto",
    ascii = FALSE
  )
  expect_identical(original_reference$dependencies$samples$sample_id, baseline_ids)
  expect_identical(original_reference$dependencies$samples$input_sha256[1L], expected_source)
  expect_identical(original_reference$fingerprint,
                   nostos:::.recovery_hash_reference(original_reference))
  changed_result <- original_reference
  changed_result$profiles["a", "e1"] <- 0.6
  expect_false(identical(nostos:::.recovery_hash_reference(changed_result),
                         original_reference$fingerprint))

  scaled <- tse
  counts <- SummarizedExperiment::assay(scaled, "counts")
  counts[, "b1"] <- counts[, "b1"] * 2
  SummarizedExperiment::assay(scaled, "counts") <- counts
  scaled <- add_reference(scaled, "antibiotic", baseline_ids, assay = "counts")
  scaled_reference <- registration_record(scaled)$reference

  expect_identical(scaled_reference$profiles, original_reference$profiles)
  expect_identical(scaled_reference$dependencies$registration_sha256,
                   original_reference$dependencies$registration_sha256)
  expect_false(identical(scaled_reference$dependencies$samples$input_sha256[1L], expected_source))
  expect_identical(scaled_reference$dependencies$samples$input_sha256[2:3],
                   original_reference$dependencies$samples$input_sha256[2:3])

  changed <- tse
  SummarizedExperiment::assay(changed, "counts")[, "b1"] <- c(2, 8, 0)
  changed <- add_reference(changed, "antibiotic", baseline_ids, assay = "counts")
  expect_equal(
    unname(registration_record(changed)$reference$profiles[, "e1"]),
    c(0.5, 0.5, 0), tolerance = 1e-12
  )
})
