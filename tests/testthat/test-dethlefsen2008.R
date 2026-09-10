test_that("the curated real example preserves source dimensions and calendar", {
  data("dethlefsen2008", package = "recoverome")
  expect_s4_class(dethlefsen2008, "TreeSummarizedExperiment")
  expect_identical(dim(dethlefsen2008), c(5670L, 18L))
  abundance <- SummarizedExperiment::assay(dethlefsen2008, "abundance")
  expect_equal(unname(colSums(abundance)), rep(43405, 18), tolerance = 1e-8)
  expect_equal(abundance["V3_Gp3_refOTU_1", "A1"], 1.603139427516159, tolerance = 1e-14)
  samples <- SummarizedExperiment::colData(dethlefsen2008)
  expect_identical(samples$sample_id, colnames(dethlefsen2008))
  expect_equal(samples$day, c(-60, -6, -2, -1, 3, 5, 33, 180,
                              -60, -1, 5, 33, 180, -60, -1, 5, 33, 180))
  study <- S4Vectors::metadata(dethlefsen2008)$study
  expect_identical(study$source_sha256,
                   "4fbe0c8ffb0c121851ca791bdce5ee7da8977920315908e70e6014d3990273cc")
  expect_identical(study$episodes$subject_id, c("A", "B", "C"))
  expect_equal(study$events$end_time, rep(5, 3))
  expect_null(S4Vectors::metadata(dethlefsen2008)$recoverome)
})
