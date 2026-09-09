test_that("deviation fingerprints record consumed sources and all authoritative statuses", {
  tse <- register_fixture(registration_fixture())
  referenced <- add_reference(tse, "antibiotic", "s1", assay = "counts")
  out <- add_deviation(referenced, "antibiotic")
  deviation <- registration_record(out)$deviation

  # SHA-256 of the plain projections under RFC 002's v2/skip-auto recipe:
  # input: list(sample_id = "s2", feature_ids = c("f1", "f2"), values = c(3, 4)).
  # outputs: list(sample_id, deviation, status), with double 0 or NA_real_.
  expect_identical(deviation$dependencies$samples$sample_id, c("s1", "s2", "s3"))
  expect_identical(
    deviation$dependencies$samples$input_sha256[2L],
    "e49965a8290433710b96e3cdbf6bde586d7d883c66b0254c11da52b8f1ebef6a"
  )
  expect_identical(deviation$results$sample_id, paste0("s", 1:6))
  expect_identical(
    deviation$results$result_sha256[c(1L, 4L, 6L)],
    c(
      "1cd3ff9c1858d99e0613fd0202c8c0c30e2c0ba9a9dde56c3836d59f5c6c388f",
      "bf2284a485b578b4bbc415f9fb61badf21d5d95eb9ae5b77e5863fa161c02114",
      "fd831b25953abf50a72afc1050671d6e3086ef52969de3f7c2ed5bd55b908459"
    )
  )
})

test_that("new follow-up read totals change input evidence without changing the deviation", {
  tse <- register_fixture(reference_fixture())
  referenced <- add_reference(tse, "antibiotic", "b1", assay = "counts")
  original <- add_deviation(referenced, "antibiotic")
  scaled <- referenced
  SummarizedExperiment::assay(scaled, "counts")[, "q1"] <- c(8, 8, 4)
  scaled <- add_deviation(scaled, "antibiotic")
  original_record <- registration_record(original)$deviation
  scaled_record <- registration_record(scaled)$deviation

  expect_equal(SummarizedExperiment::colData(scaled)$rec_antibiotic_deviation[4L],
               0.4, tolerance = 1e-12)
  expect_identical(scaled_record$dependencies$reference_sha256,
                   original_record$dependencies$reference_sha256)
  expect_identical(scaled_record$dependencies$samples$input_sha256[1:3],
                   original_record$dependencies$samples$input_sha256[1:3])
  expect_false(identical(scaled_record$dependencies$samples$input_sha256[4L],
                         original_record$dependencies$samples$input_sha256[4L]))
  expect_identical(scaled_record$results, original_record$results)
})
