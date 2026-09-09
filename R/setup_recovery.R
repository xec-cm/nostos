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
#' @section Errors:
#' Checks performed by recoverome signal errors with [cli::cli_abort()]. They
#' inherit from `recoverome_error` and one of `recoverome_error_input` (invalid
#' inputs), `recoverome_error_namespace` (malformed or unsupported metadata), or
#' `recoverome_error_collision` (an occupied analysis name or column prefix).
#' Conditions identify the public call, carry a backtrace, and include `component`
#' and `ids` fields. `ids` contains affected IDs or row positions as character
#' values when available, otherwise `character()`. Row-check messages display up
#' to ten IDs; the condition retains the full vector. Handle conditions by class
#' and fields rather than parsing their prose. Errors raised by R or dependencies
#' retain their own classes.
#'
#' @return A TSE of the input class, with one named registration added to its
#'   metadata. Assays, trees, links, row/column identities, and `colData()` are
#'   unchanged. The original input object is not modified.
#' @importClassesFrom TreeSummarizedExperiment TreeSummarizedExperiment
#' @export
#' @examples
#' data("recovery_examples", package = "recoverome")
#' example_data <- recovery_examples$single_episode
#'
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = example_data$counts),
#'   colData = S4Vectors::DataFrame(example_data$col_data)
#' )
#'
#' registered <- setup_recovery(
#'   tse,
#'   analysis_id = "antibiotic",
#'   episodes = example_data$episodes,
#'   events = example_data$events,
#'   time_col = example_data$time_col,
#'   time_unit = example_data$time_unit,
#'   time_origin = example_data$time_origin
#' )
#'
#' record <- S4Vectors::metadata(registered)$recoverome$analyses$antibiotic
#' record$registration$samples
#' record$scope
setup_recovery <- function(tse,
                           analysis_id,
                           episodes,
                           events,
                           subject_col = "subject_id",
                           episode_col = "episode_id",
                           time_col = "time",
                           time_unit,
                           time_origin) {
  error_call <- environment()

  .recovery_check_container(tse, call = error_call)
  .recovery_check_string(analysis_id, "analysis_id", call = error_call)
  if (!grepl("^[a-z][a-z0-9]*$", analysis_id)) {
    .recovery_abort(
      "{.arg analysis_id} must match ^[a-z][a-z0-9]*$.",
      component = "analysis_id",
      call = error_call
    )
  }

  columns <- list(subject = subject_col, episode = episode_col, time = time_col)
  for (name in names(columns)) {
    .recovery_check_string(columns[[name]], paste0(name, "_col"), call = error_call)
  }
  columns <- vapply(columns, unname, character(1))
  if (anyDuplicated(columns)) {
    .recovery_abort(
      "{.arg subject_col}, {.arg episode_col} and {.arg time_col} must be distinct.",
      component = "source_columns",
      call = error_call
    )
  }

  .recovery_check_string(time_unit, "time_unit", call = error_call)
  if (!time_unit %in% c("seconds", "minutes", "hours", "days")) {
    .recovery_abort(
      "{.arg time_unit} must be seconds, minutes, hours or days.",
      component = "time_unit",
      call = error_call
    )
  }
  .recovery_check_string(time_origin, "time_origin", call = error_call)

  annotation <- SummarizedExperiment::colData(tse)
  root <- S4Vectors::metadata(tse)
  namespace <- .recovery_namespace(root, analysis_id, names(annotation), call = error_call)
  samples <- .recovery_sample_inputs(annotation, columns, colnames(tse), call = error_call)
  episodes <- .recovery_input_table(
    episodes,
    "episodes",
    id_columns = c("episode_id", "subject_id", "origin_event_id", "origin_boundary"),
    call = error_call
  )
  events <- .recovery_input_table(
    events,
    "events",
    id_columns = c("event_id", "episode_id"),
    time_columns = c("start_time", "end_time"),
    call = error_call
  )
  .recovery_check_relations(samples, episodes, events, call = error_call)

  namespace$analyses[[analysis_id]] <- list(
    schema_version = 1L,
    registration = list(
      source_columns = columns,
      time_unit = time_unit,
      time_origin = time_origin,
      samples = samples
    ),
    episodes = episodes,
    events = events,
    scope = list(
      sample_ids = colnames(tse),
      feature_ids = rownames(tse)
    ),
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
