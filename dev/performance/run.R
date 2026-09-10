# Optional, explicit profiling; never sourced by the package check suite.
# Usage: Rscript --vanilla dev/performance/run.R tests SOURCE LABEL OUTPUT.csv
#        Rscript --vanilla dev/performance/run.R workflow BACKEND FEATURES SAMPLES OUTPUT.csv
args <- commandArgs(trailingOnly = TRUE)

measure_tests <- function(source, label, output) {
  rows <- lapply(1:2, function(iteration) {
    gc()
    timing <- system.time(result <- testthat::test_local(source, reporter = "silent"))
    result <- as.data.frame(result)
    row <- data.frame(
      revision = label, iteration = iteration, elapsed_seconds = unname(timing[["elapsed"]]),
      passed = sum(result$passed), failed = sum(result$failed),
      warnings = sum(result$warning), skipped = sum(result$skipped)
    )
    print(row)
    stopifnot(row$failed == 0, row$warnings == 0)
    row
  })
  utils::write.csv(do.call(rbind, rows), output, row.names = FALSE)
}

profile_fixture <- function(backend, features, samples, directory) {
  stopifnot(samples %% 10L == 0L, features > 1L)
  set.seed(42)
  counts <- matrix(0, features, samples,
                   dimnames = list(paste0("f", seq_len(features)), paste0("s", seq_len(samples))))
  selected <- sample.int(length(counts), ceiling(length(counts) * .05))
  counts[selected] <- sample.int(20L, length(selected), replace = TRUE)
  counts[1L, ] <- 1 # Every sample has a positive library size.
  checksum <- digest::digest(counts, algo = "sha256")
  density <- mean(counts != 0)
  if (backend == "sparse") counts <- methods::as(counts, "dgCMatrix")
  if (backend == "hdf5") {
    counts <- HDF5Array::writeHDF5Array(
      counts, filepath = file.path(directory, "assay.h5"), name = "counts",
      chunkdim = c(features, 10L), level = 6L, with.dimnames = TRUE
    )
    stopifnot(methods::is(counts, "HDF5Matrix"))
  }
  episode_ids <- paste0("e", seq_len(samples / 10L))
  subject_ids <- paste0("p", seq_along(episode_ids))
  tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
    assays = list(counts = counts),
    colData = S4Vectors::DataFrame(
      subject_id = rep(subject_ids, each = 10L), episode_id = rep(episode_ids, each = 10L),
      day = rep(-2:7, length(episode_ids)), row.names = colnames(counts)
    )
  )
  list(
    tse = tse, checksum = checksum, density = density,
    episodes = data.frame(episode_id = episode_ids, subject_id = subject_ids,
                          origin_event_id = episode_ids, origin_boundary = "start"),
    events = data.frame(event_id = episode_ids, episode_id = episode_ids,
                        start_time = 0, end_time = 0),
    baseline = colnames(tse)[SummarizedExperiment::colData(tse)$day < 0]
  )
}

profile_workflow <- function(fixture) {
  tse <- nostos::setup_recovery(
    fixture$tse, "profile", fixture$episodes, fixture$events,
    time_col = "day", time_unit = "days", time_origin = "days since synthetic exposure"
  )
  tse <- nostos::add_reference(tse, "profile", fixture$baseline, assay = "counts")
  tse <- nostos::add_deviation(tse, "profile")
  nostos::add_recovery(tse, "profile", list(
    threshold = .25, persistence = 2, max_gap = 1, horizon = 7
  ))
}

# Timing runs are uninstrumented; allocation/heap observations use a separate run.
# These are R allocations and heap high-water marks, not process RSS or HDF5 caches.
measure_operation <- function(operation) {
  elapsed <- vapply(1:3, function(iteration) {
    gc()
    unname(system.time(invisible(operation()))[["elapsed"]])
  }, numeric(1))
  memory_log <- tempfile()
  on.exit(unlink(memory_log), add = TRUE)
  before <- gc(reset = TRUE)
  Rprofmem(memory_log)
  on.exit(Rprofmem(NULL), add = TRUE)
  invisible(operation())
  Rprofmem(NULL)
  after <- gc()
  allocations <- readLines(memory_log, warn = FALSE)
  allocations <- as.double(sub(" .*", "", allocations[grepl("^[0-9]+ ", allocations)]))

  data.frame(
    access = c("first_measured", "repeat_1", "repeat_2"), elapsed_seconds = elapsed,
    allocated_mib = sum(allocations) / 1024^2,
    largest_allocation_mib = max(c(0, allocations)) / 1024^2,
    heap_before_mib = sum(before[, 2L]), heap_high_water_mib = sum(after[, ncol(after)])
  )
}

measure_workflow <- function(backend, features, samples, output) {
  stopifnot(backend %in% c("dense", "sparse", "hdf5"), capabilities("profmem"))
  if (backend == "hdf5" && !requireNamespace("HDF5Array", quietly = TRUE)) {
    stop("Install optional profiling dependency HDF5Array; it is not a runtime dependency.")
  }
  pkgload::load_all(quiet = TRUE)
  directory <- tempfile("recoverome-profile-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  fixture <- profile_fixture(backend, features, samples, directory)
  raw_path <- file.path(directory, "input.rds")
  saveRDS(fixture$tse, raw_path, compress = FALSE)
  # Backend conversion/file writing and analytical preparation are outside these
  # operations. The workflow measurement separately includes all analytical stages.
  prepared <- profile_workflow(fixture)
  render <- function(fun) ggplot2::ggplotGrob(fun(prepared, "profile"))
  operations <- list(
    load = function() readRDS(raw_path),
    materialize = function() as.matrix(SummarizedExperiment::assay(fixture$tse, "counts")),
    workflow = function() profile_workflow(fixture),
    validate = function() nostos::validate_recovery(prepared, "profile"),
    extract_samples = function() {
      nostos::recovery_results(prepared, "profile", level = "sample")
    },
    extract_episodes = function() nostos::recovery_results(prepared, "profile"),
    plot_recovery = function() render(nostos::plot_recovery),
    plot_reference = function() render(nostos::plot_reference),
    plot_sampling = function() render(nostos::plot_sampling),
    plot_overview = function() render(nostos::plot_recovery_overview)
  )
  rows <- lapply(names(operations), function(name) {
    cat(backend, features, samples, name, "\n")
    measured <- measure_operation(operations[[name]])
    cbind(data.frame(backend = backend, features = features, samples = samples,
                     operation = name, density = fixture$density,
                     input_sha256 = fixture$checksum), measured)
  })
  utils::write.csv(do.call(rbind, rows), output, row.names = FALSE)
  writeLines(c(paste("Command:", paste(commandArgs(), collapse = " ")),
               capture.output(utils::sessionInfo())), paste0(output, ".session.txt"))
  # Cross-backend comparison concerns values and diagnostics, not new timestamps.
  saveRDS(list(
    validation = nostos::validate_recovery(prepared, "profile"),
    samples = as.data.frame(nostos::recovery_results(prepared, "profile", level = "sample")),
    episodes = as.data.frame(nostos::recovery_results(prepared, "profile"))
  ), paste0(output, ".results.rds"))
}

if (length(args) == 4L && args[[1L]] == "tests") {
  measure_tests(normalizePath(args[[2L]]), args[[3L]], args[[4L]])
} else if (length(args) == 5L && args[[1L]] == "workflow") {
  measure_workflow(args[[2L]], as.integer(args[[3L]]), as.integer(args[[4L]]), args[[5L]])
} else {
  stop("See usage at the start of dev/performance/run.R; run from the package checkout.")
}
