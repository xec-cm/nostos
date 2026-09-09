.recovery_check_string <- function(value, label, call = rlang::caller_env()) {
  if (!is.character(value) || !is.null(dim(value)) || length(value) != 1L ||
        is.na(value) || !nzchar(trimws(value, whitespace = "[\\h\\v]"))) {
    .recovery_abort(
      paste0("`", label, "` must be one non-empty character string."),
      component = label,
      call = call
    )
  }
}

.recovery_bad_rows <- function(bad,
                               label,
                               message,
                               ids = seq_along(bad),
                               call = rlang::caller_env()) {
  if (!any(bad)) {
    return(invisible(NULL))
  }

  affected_ids <- as.character(ids[bad])
  displayed_ids <- utils::head(affected_ids, 10L)
  details <- paste0("IDs/rows: ", paste(displayed_ids, collapse = ", "), ".")
  if (length(affected_ids) > length(displayed_ids)) {
    details <- paste0(details, " And ", length(affected_ids) - length(displayed_ids), " more.")
  }

  .recovery_abort(
    c(paste0("`", label, "` ", message, "."), i = details),
    component = label,
    ids = affected_ids,
    call = call
  )
}

.recovery_id_vector <- function(value, label, call = rlang::caller_env()) {
  if (!(is.character(value) || is.factor(value)) || !is.null(dim(value))) {
    .recovery_abort(
      paste0("`", label, "` must be a character or factor vector of IDs."),
      component = label,
      call = call
    )
  }

  if (is.factor(value)) {
    value <- as.character(value)
  }

  value
}

.recovery_ids <- function(value,
                          label,
                          unique = FALSE,
                          allow_na = FALSE,
                          ids = seq_along(value),
                          call = rlang::caller_env()) {
  value <- .recovery_id_vector(value, label, call = call)
  missing <- is.na(value)
  trimmed <- trimws(value, whitespace = "[\\h\\v]")
  bad <- (!allow_na & missing) | (!missing & (!nzchar(value) | trimmed != value))

  .recovery_bad_rows(
    bad,
    label,
    "contains missing, empty or whitespace-padded IDs",
    ids = ids,
    call = call
  )
  if (unique) {
    .recovery_bad_rows(duplicated(value), label, "must contain unique IDs", value, call = call)
  }

  value
}

.recovery_numeric <- function(value,
                              label,
                              finite = TRUE,
                              ids = seq_along(value),
                              call = rlang::caller_env()) {
  if (!typeof(value) %in% c("integer", "double") || is.object(value) ||
        !is.null(dim(value))) {
    .recovery_abort(
      paste0("`", label, "` must be a plain integer or double time vector."),
      component = label,
      call = call
    )
  }

  if (finite) {
    .recovery_bad_rows(!is.finite(value), label, "must be finite", ids, call = call)
  }

  as.double(value)
}

.recovery_check_container <- function(tse, call = rlang::caller_env()) {
  if (!methods::is(tse, "TreeSummarizedExperiment")) {
    .recovery_abort("`tse` must be a TreeSummarizedExperiment.", component = "tse", call = call)
  }

  validity <- methods::validObject(tse, test = TRUE)
  if (!identical(validity, TRUE)) {
    .recovery_abort(
      c("`tse` fails formal S4 validity.", x = paste(validity, collapse = "; ")),
      component = "tse",
      call = call
    )
  }
  if (!nrow(tse) || !ncol(tse)) {
    .recovery_abort(
      "`tse` must contain at least one feature and one sample.",
      component = "tse",
      call = call
    )
  }

  .recovery_ids(rownames(tse), "feature IDs (rownames(tse))", unique = TRUE, call = call)
  .recovery_ids(colnames(tse), "sample IDs (colnames(tse))", unique = TRUE, call = call)

  invisible(NULL)
}

.recovery_named_list <- function(value) {
  if (!is.list(value) || is.object(value)) {
    return(FALSE)
  }
  if (!length(value)) {
    return(TRUE)
  }

  !is.null(names(value)) && !anyNA(names(value)) &&
    all(nzchar(names(value))) && !anyDuplicated(names(value))
}

.recovery_namespace <- function(root,
                                analysis_id,
                                column_names,
                                call = rlang::caller_env()) {
  present <- which(names(root) == "recoverome")
  if (length(present) > 1L) {
    .recovery_abort(
      "The recoverome namespace is ambiguous: duplicate root metadata names.",
      class = "recoverome_error_namespace",
      component = "recoverome",
      call = call
    )
  }

  namespace <- if (!length(present)) {
    list(schema_version = 1L, analyses = list())
  } else {
    root[[present]]
  }
  if (!.recovery_named_list(namespace) ||
        !all(c("schema_version", "analyses") %in% names(namespace))) {
    .recovery_abort(
      "The recoverome namespace must be a uniquely named list with schema_version and analyses.",
      class = "recoverome_error_namespace",
      component = "recoverome",
      call = call
    )
  }
  if (!identical(namespace$schema_version, 1L)) {
    .recovery_abort(
      "The recoverome namespace has an unsupported schema_version; expected 1L.",
      class = "recoverome_error_namespace",
      component = "recoverome",
      call = call
    )
  }

  analyses <- namespace$analyses
  if (!.recovery_named_list(analyses) ||
        any(!grepl("^[a-z][a-z0-9]*$", names(analyses)))) {
    .recovery_abort(
      "The recoverome namespace analyses must be a uniquely named list of valid analysis IDs.",
      class = "recoverome_error_namespace",
      component = "recoverome$analyses",
      call = call
    )
  }
  if (analysis_id %in% names(analyses)) {
    .recovery_abort(
      c(
        paste0("Analysis `", analysis_id, "` already exists."),
        i = "Register a new analysis name."
      ),
      class = "recoverome_error_collision",
      component = "analysis_id",
      ids = analysis_id,
      call = call
    )
  }

  prefix <- paste0("rec_", analysis_id, "_")
  collisions <- column_names[!is.na(column_names) & startsWith(column_names, prefix)]
  if (length(collisions)) {
    .recovery_abort(
      c(
        paste0("Reserved colData prefix `", prefix, "` is already used."),
        i = paste0("Columns: ", paste(collisions, collapse = ", "), ".")
      ),
      class = "recoverome_error_collision",
      component = "colData",
      ids = collisions,
      call = call
    )
  }

  namespace
}

.recovery_sample_inputs <- function(annotation,
                                    columns,
                                    sample_ids,
                                    call = rlang::caller_env()) {
  for (column in columns) {
    if (sum(names(annotation) == column, na.rm = TRUE) != 1L) {
      .recovery_abort(
        paste0("Selected colData column `", column, "` must occur exactly once."),
        component = "colData",
        ids = column,
        call = call
      )
    }
  }

  episode <- .recovery_ids(
    annotation[[columns[["episode"]]]],
    "colData episode",
    allow_na = TRUE,
    ids = sample_ids,
    call = call
  )
  included <- !is.na(episode)
  if (!any(included)) {
    .recovery_abort(
      "At least one sample must be included in an episode.",
      component = "colData episode",
      call = call
    )
  }

  # Enforce source types even when excluded cells are not consumed.
  subject <- .recovery_id_vector(annotation[[columns[["subject"]]]], "colData subject", call = call)
  subject <- .recovery_ids(
    subject[included],
    "colData subject",
    ids = sample_ids[included],
    call = call
  )
  time <- .recovery_numeric(
    annotation[[columns[["time"]]]],
    "colData time",
    finite = FALSE,
    call = call
  )
  time <- .recovery_numeric(time[included], "colData time", ids = sample_ids[included], call = call)

  S4Vectors::DataFrame(
    sample_id = sample_ids[included],
    subject_id = subject,
    episode_id = episode[included],
    time = time,
    row.names = NULL
  )
}

.recovery_input_table <- function(value,
                                  label,
                                  id_columns,
                                  time_columns = character(),
                                  call = rlang::caller_env()) {
  if (!(is.data.frame(value) || methods::is(value, "DataFrame"))) {
    .recovery_abort(
      paste0("`", label, "` must be a data.frame or S4Vectors::DataFrame."),
      component = label,
      call = call
    )
  }

  column_names <- names(value)
  if (is.null(column_names) || anyNA(column_names) || any(!nzchar(column_names)) ||
        anyDuplicated(column_names)) {
    .recovery_abort(
      paste0("`", label, "` must have unique, non-empty column names."),
      component = label,
      call = call
    )
  }
  required <- c(id_columns, time_columns)
  absent <- setdiff(required, column_names)
  if (length(absent)) {
    .recovery_abort(
      c(paste0("`", label, "` is missing required columns."), i = paste(absent, collapse = ", ")),
      component = label,
      ids = absent,
      call = call
    )
  }

  # Normalize core vectors before conversion, preserving all annotation columns.
  for (column in id_columns) {
    value[[column]] <- .recovery_ids(value[[column]], paste0(label, "$", column), call = call)
  }
  for (column in time_columns) {
    value[[column]] <- .recovery_numeric(value[[column]], paste0(label, "$", column), call = call)
  }
  value <- S4Vectors::DataFrame(value, check.names = FALSE)
  rownames(value) <- NULL

  value
}

.recovery_check_relations <- function(samples, episodes, events, call = rlang::caller_env()) {
  .recovery_ids(episodes$episode_id, "episodes$episode_id", unique = TRUE, call = call)
  .recovery_ids(events$event_id, "events$event_id", unique = TRUE, call = call)

  .recovery_bad_rows(
    !episodes$origin_boundary %in% c("start", "end"),
    "episodes$origin_boundary",
    "must be start or end",
    ids = episodes$episode_id,
    call = call
  )
  .recovery_bad_rows(
    events$start_time > events$end_time,
    "events",
    "requires start_time <= end_time",
    ids = events$event_id,
    call = call
  )

  sample_episode <- match(samples$episode_id, episodes$episode_id)
  .recovery_bad_rows(
    is.na(sample_episode),
    "samples",
    "refer to an unknown episode",
    ids = samples$sample_id,
    call = call
  )
  .recovery_bad_rows(
    samples$subject_id != episodes$subject_id[sample_episode],
    "samples",
    "have a subject different from their episode subject",
    ids = samples$sample_id,
    call = call
  )
  .recovery_bad_rows(
    !episodes$episode_id %in% samples$episode_id,
    "episodes",
    "must each have at least one included sample",
    ids = episodes$episode_id,
    call = call
  )
  .recovery_bad_rows(
    !events$episode_id %in% episodes$episode_id,
    "events",
    "refer to an unknown episode",
    ids = events$event_id,
    call = call
  )

  origin <- match(episodes$origin_event_id, events$event_id)
  .recovery_bad_rows(
    is.na(origin),
    "episodes$origin_event_id",
    "refers to an unknown event",
    ids = episodes$episode_id,
    call = call
  )
  .recovery_bad_rows(
    events$episode_id[origin] != episodes$episode_id,
    "episodes$origin_event_id",
    "must belong to the same episode",
    ids = episodes$episode_id,
    call = call
  )
  origin_time <- ifelse(
    episodes$origin_boundary == "start",
    events$start_time[origin],
    events$end_time[origin]
  )
  .recovery_bad_rows(
    !is.finite(samples$time - origin_time[sample_episode]),
    "samples",
    "have non-finite relative time (arithmetic overflow)",
    ids = samples$sample_id,
    call = call
  )

  invisible(NULL)
}
