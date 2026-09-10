# Freeze compatibility evidence with recoverome at 7485c28, before the rename.
# Run with that checkout and an output path; do not regenerate using nostos.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
pkgload::load_all(args[[1L]], quiet = TRUE, helpers = FALSE)
stopifnot(read.dcf(file.path(args[[1L]], "DESCRIPTION"))[1L, "Package"] == "recoverome")
data("recovery_examples", package = "recoverome")
example <- recovery_examples$observed_recovery
raw <- TreeSummarizedExperiment::TreeSummarizedExperiment(
  assays = list(counts = example$counts, other = example$counts / 2),
  colData = S4Vectors::DataFrame(example$col_data),
  metadata = list(study = "legacy compatibility fixture")
)
star_tree <- function(ids) {
  n <- length(ids)
  structure(list(edge = cbind(rep(n + 1L, n), seq_len(n)),
                 tip.label = ids, Nnode = 1L, edge.length = rep(1, n)), class = "phylo")
}
TreeSummarizedExperiment::rowTree(raw) <- star_tree(rownames(raw))
TreeSummarizedExperiment::colTree(raw) <- star_tree(colnames(raw))
registered <- recoverome::setup_recovery(
  raw, "observed", example$episodes, example$events,
  time_col = example$time_col, time_unit = example$time_unit, time_origin = example$time_origin
)
referenced <- recoverome::add_reference(registered, "observed", "b1", assay = "counts")
deviated <- recoverome::add_deviation(referenced, "observed")
rule <- list(threshold = .25, persistence = 4, max_gap = 3, horizon = 10)
full <- recoverome::add_recovery(deviated, "observed", rule)
filtered <- full[, !colnames(full) %in% c("b1", "s2")]
rules <- data.frame(scenario_id = c("primary", "short_gap"), threshold = .25,
                    persistence = 4, max_gap = c(3, 1), horizon = 10)
objects <- list(full = full, filtered = filtered)
expected <- lapply(objects, function(tse) {
  list(
    report = recoverome::validate_recovery(tse, "observed"),
    samples = suppressWarnings(recoverome::recovery_results(tse, "observed", "sample")),
    episodes = suppressWarnings(recoverome::recovery_results(tse, "observed"))
  )
})
saveRDS(list(
  source_revision = "7485c28", raw = raw, registered = registered,
  referenced = referenced, deviated = deviated, rule = rule,
  objects = objects, expected = expected,
  sensitivity = recoverome::recovery_sensitivity(full, "observed", rules)
), args[[2L]], compress = "xz", version = 3)
