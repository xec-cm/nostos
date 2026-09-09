load_recovery_examples <- function() {
  data_env <- new.env(parent = emptyenv())
  utils::data("recovery_examples", package = "recoverome", envir = data_env)

  data_env$recovery_examples
}

registration_fixture <- function(trees = FALSE) {
  example <- load_recovery_examples()$repeated_episodes
  counts <- example$counts
  feature_ids <- rownames(counts)
  sample_ids <- colnames(counts)
  annotations <- S4Vectors::DataFrame(example$col_data)

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
    episodes = example$episodes,
    events = example$events,
    time_col = example$time_col,
    time_unit = example$time_unit,
    time_origin = example$time_origin
  )
}

register_fixture <- function(fixture, ...) {
  args <- list(
    tse = fixture$tse,
    analysis_id = "antibiotic",
    episodes = fixture$episodes,
    events = fixture$events,
    time_col = fixture$time_col,
    time_unit = fixture$time_unit,
    time_origin = fixture$time_origin
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
