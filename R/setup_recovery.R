#' Register a named recovery analysis
#'
#' Attach explicit sample membership, episodes, events, and original scope to a
#' TreeSummarizedExperiment (TSE). Registration records the inputs needed by later
#' analysis stages; it does not estimate a reference, deviation, or recovery.
#'
#' @param tse A formally valid `TreeSummarizedExperiment` with at least one feature
#'   and sample. Row and column names must be unique, non-missing, non-empty
#'   character IDs without surrounding whitespace.
#' @param analysis_id One character ID matching `^[a-z][a-z0-9]*$`. Both this name
#'   and the `rec_<analysis_id>_` prefix in `colData(tse)` must be unused.
#' @param episodes A data.frame (including subclasses) or
#'   [S4Vectors::DataFrame] with `episode_id`, `subject_id`, `origin_event_id`, and
#'   `origin_boundary` columns. Episode IDs must be unique. The boundary is
#'   `"start"` or `"end"`, selecting a time from an event in that same episode.
#' @param events A data.frame (including subclasses) or [S4Vectors::DataFrame]
#'   with `event_id`, `episode_id`, `start_time`, and `end_time` columns. Event IDs
#'   must be unique. Every event belongs to a declared episode and has finite
#'   numeric times with `start_time <= end_time`; equality denotes a point event.
#' @param subject_col,episode_col,time_col Distinct, literal column names in
#'   `colData(tse)`. Each selected name must occur exactly once. Subject and
#'   episode columns are character or factor vectors; time is plain integer or
#'   double. An `NA` episode excludes that sample, whose subject/time cells are
#'   then ignored. Every included sample needs a valid subject and finite time.
#' @param time_unit One of `"seconds"`, `"minutes"`, `"hours"`, or `"days"`.
#'   Partial matching and automatic conversion are not supported.
#' @param time_origin One non-empty character description of the coordinate
#'   system shared by sample and event times within each subject, across episodes.
#'
#' @details
#' Membership and event origins are matched by ID, never by row position or time
#' proximity. Every episode must have at least one included sample whose subject
#' matches the episode subject. Multiple episodes per subject, multiple events per
#' episode, unordered inputs, and distinct samples at the same time are allowed.
#' No baseline or follow-up eligibility is inferred.
#'
#' Core IDs must be character or factors with non-missing, non-empty labels and
#' no surrounding whitespace. Factors are stored as character; integer times are
#' stored as double. Required table columns must be atomic vectors. Table column
#' names must be unique and non-empty; row names are ignored. Extra annotation
#' columns and table row order are preserved.
#'
#' Calendar times (`Date`, `POSIXct`, `difftime`), classed numeric time vectors,
#' logical times, and open-ended events are unsupported. Convert calendar times
#' explicitly before registration and describe that conversion in `time_origin`.
#' Relative time is sample time minus the selected event boundary. This subtraction
#' must remain finite; relative time is not stored as a separate result column.
#'
#' The only change is a named record in `S4Vectors::metadata(tse)$recoverome`.
#' Schema 1 records normalized inputs, source-column bindings, the full original
#' sample/feature scope (including excluded samples), an empty `owned_columns`
#' manifest, and package-version/UTC-time provenance. Existing records and other
#' metadata are preserved. A malformed or unsupported root namespace is rejected;
#' existing analysis contents are not revalidated when adding an independent name.
#' Reusing a name or reserved prefix is an error, with no overwrite or partial
#' registration. No assay values are read, hashed, or copied into the record.
#'
#' Standard TSE subsetting retains this historical registration. It does not
#' enroll new samples or recompute the analysis from a subset. Stored snapshots
#' are not intended for manual editing.
#'
#' @return A TSE of the input class, with one named registration added to its
#'   metadata. Assays, trees, links, row/column identities, and `colData()` are
#'   unchanged. The original input object is not modified.
#' @importClassesFrom TreeSummarizedExperiment TreeSummarizedExperiment
#' @export
#' @examples
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = matrix(
#'     c(4L, 6L, 7L, 3L, 5L, 5L), nrow = 2,
#'     dimnames = list(c("f1", "f2"), c("s1", "s2", "s3"))
#'   )),
#'   colData = S4Vectors::DataFrame(
#'     subject_id = rep("p1", 3), episode_id = rep("e1", 3),
#'     time = c(-7, 0, 7)
#'   )
#' )
#' episodes <- data.frame(
#'   episode_id = "e1", subject_id = "p1",
#'   origin_event_id = "ab1", origin_boundary = "start"
#' )
#' events <- data.frame(
#'   event_id = "ab1", episode_id = "e1", start_time = 0, end_time = 4
#' )
#' registered <- setup_recovery(
#'   tse, "antibiotic", episodes, events,
#'   time_unit = "days", time_origin = "days since antibiotic start within subject"
#' )
#' record <- S4Vectors::metadata(registered)$recoverome$analyses$antibiotic
#' record$registration$samples
#' record$scope
setup_recovery <- function(tse, analysis_id, episodes, events,
                           subject_col = "subject_id", episode_col = "episode_id",
                           time_col = "time", time_unit, time_origin) {
  .recovery_check_container(tse)
  .recovery_check_string(analysis_id, "analysis_id")
  if (!grepl("^[a-z][a-z0-9]*$", analysis_id)) {
    stop("analysis_id must match ^[a-z][a-z0-9]*$.", call. = FALSE)
  }
  columns <- list(subject = subject_col, episode = episode_col, time = time_col)
  for (name in names(columns)) {
    .recovery_check_string(columns[[name]], paste0(name, "_col"))
  }
  columns <- vapply(columns, unname, character(1))
  if (anyDuplicated(columns)) {
    stop("subject_col, episode_col and time_col must be distinct.", call. = FALSE)
  }
  .recovery_check_string(time_unit, "time_unit")
  if (!time_unit %in% c("seconds", "minutes", "hours", "days")) {
    stop("time_unit must be seconds, minutes, hours or days.", call. = FALSE)
  }
  .recovery_check_string(time_origin, "time_origin")

  annotation <- SummarizedExperiment::colData(tse)
  root <- S4Vectors::metadata(tse)
  namespace <- .recovery_namespace(root, analysis_id, names(annotation))
  samples <- .recovery_sample_inputs(annotation, columns, colnames(tse))
  episodes <- .recovery_input_table(
    episodes, "episodes",
    c("episode_id", "subject_id", "origin_event_id", "origin_boundary")
  )
  events <- .recovery_input_table(
    events, "events", c("event_id", "episode_id"), c("start_time", "end_time")
  )
  .recovery_check_relations(samples, episodes, events)

  namespace$analyses[[analysis_id]] <- list(
    schema_version = 1L,
    registration = list(
      source_columns = columns, time_unit = time_unit, time_origin = time_origin,
      samples = samples
    ),
    episodes = episodes, events = events,
    scope = list(sample_ids = colnames(tse), feature_ids = rownames(tse)),
    owned_columns = character(),
    provenance = list(
      package_version = as.character(utils::packageVersion("recoverome")),
      registered_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
  )
  root[["recoverome"]] <- namespace
  S4Vectors::metadata(tse) <- root
  tse
}
