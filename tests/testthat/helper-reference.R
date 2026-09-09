reference_fixture <- function() {
  # Counts and the equal-sample reference come from RFC 002's worked example.
  counts <- matrix(
    c(8, 2, 0, 60, 40, 0, 7, 3, 0, 4, 4, 2),
    nrow = 3L,
    dimnames = list(c("a", "b", "c"), c("b1", "b2", "b3", "q1"))
  )
  annotations <- S4Vectors::DataFrame(
    subject_id = rep("p1", 4L),
    episode_id = rep("e1", 4L),
    time = c(3, 5, 7, 17),
    row.names = colnames(counts)
  )

  list(
    tse = TreeSummarizedExperiment::TreeSummarizedExperiment(
      assays = list(counts = counts),
      colData = annotations,
      metadata = list(study = list(note = "RFC 002 arithmetic example"))
    ),
    episodes = data.frame(
      episode_id = "e1", subject_id = "p1",
      origin_event_id = "ab1", origin_boundary = "start"
    ),
    events = data.frame(
      event_id = "ab1", episode_id = "e1", start_time = 10, end_time = 14
    ),
    time_col = "time",
    time_unit = "days",
    time_origin = "days since enrolment within participant"
  )
}

expect_reference_error <- function(tse, reference, assay = "counts", ...) {
  before <- serialize(tse, NULL)
  testthat::expect_error(
    recoverome::add_reference(tse, "antibiotic", reference, assay = assay, ...),
    class = "recoverome_error"
  )
  testthat::expect_identical(serialize(tse, NULL), before)
}
