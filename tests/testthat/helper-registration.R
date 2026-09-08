registration_fixture <- function(trees = FALSE) {
  feature_ids <- c("f1", "f2")
  sample_ids <- paste0("s", seq_len(6L))
  counts <- matrix(seq_len(12L), nrow = 2L,
                   dimnames = list(feature_ids, sample_ids))
  annotations <- S4Vectors::DataFrame(
    subject_id = c(rep("p1", 5L), NA_character_),
    episode_id = c(rep("e1", 3L), rep("e2", 2L), NA_character_),
    time = c(3, 10, 17, 34, 43, NA_real_),
    batch = factor(c("a", "b", "a", "b", "a", "b")),
    row.names = sample_ids
  )
  tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
    assays = list(counts = counts, another = counts / 2),
    colData = annotations,
    rowData = S4Vectors::DataFrame(
      taxonomy = c("taxon-a", "taxon-b"), row.names = feature_ids
    ),
    metadata = list(study = list(name = "registration example", version = 2L))
  )
  if (trees) {
    star_tree <- function(labels) {
      n <- length(labels)
      structure(list(
        edge = cbind(rep.int(n + 1L, n), seq_len(n)),
        tip.label = labels, Nnode = 1L, edge.length = rep(1, n)
      ), class = "phylo")
    }
    TreeSummarizedExperiment::rowTree(tse) <- star_tree(feature_ids)
    TreeSummarizedExperiment::colTree(tse) <- star_tree(sample_ids)
  }
  list(
    tse = tse,
    episodes = data.frame(
      episode_id = c("e1", "e2"), subject_id = c("p1", "p1"),
      origin_event_id = c("ab1", "ab2"), origin_boundary = c("start", "end"),
      note = c("first exposure", "second exposure")
    ),
    events = data.frame(
      event_id = c("ab1", "ab2"), episode_id = c("e1", "e2"),
      start_time = c(10, 40), end_time = c(14, 42),
      treatment = factor(c("antibiotic-a", "antibiotic-b"))
    )
  )
}

register_fixture <- function(fixture, ...) {
  args <- list(
    tse = fixture$tse, analysis_id = "antibiotic",
    episodes = fixture$episodes, events = fixture$events,
    time_unit = "days", time_origin = "days since enrolment within participant"
  )
  overrides <- list(...)
  args[names(overrides)] <- overrides
  do.call(recoverome::setup_recovery, args)
}

registration_record <- function(tse, analysis_id = "antibiotic") {
  S4Vectors::metadata(tse)$recoverome$analyses[[analysis_id]]
}

expect_setup_error <- function(fixture, ...) {
  before <- serialize(fixture, NULL)
  testthat::expect_error(register_fixture(fixture, ...))
  testthat::expect_identical(serialize(fixture, NULL), before)
}
