.recovery_check_string <- function(value, label) {
  if (!is.character(value) || !is.null(dim(value)) || length(value) != 1L ||
        is.na(value) || !nzchar(trimws(value, whitespace = "[\\h\\v]"))) {
    stop(label, " must be one non-empty character string.", call. = FALSE)
  }
}

.recovery_bad_rows <- function(bad, label, message, ids = seq_along(bad)) {
  if (any(bad)) {
    stop(label, " ", message, " (IDs/rows: ",
         paste(utils::head(ids[bad], 10L), collapse = ", "), ").", call. = FALSE)
  }
}

.recovery_id_vector <- function(value, label) {
  if (!(is.character(value) || is.factor(value)) || !is.null(dim(value))) {
    stop(label, " must be a character or factor vector of IDs.", call. = FALSE)
  }
  if (is.factor(value)) value <- as.character(value)
  value
}

.recovery_ids <- function(value, label, unique = FALSE, allow_na = FALSE,
                          ids = seq_along(value)) {
  value <- .recovery_id_vector(value, label)
  missing <- is.na(value)
  trimmed <- trimws(value, whitespace = "[\\h\\v]")
  bad <- (!allow_na & missing) | (!missing & (!nzchar(value) | trimmed != value))
  .recovery_bad_rows(bad, label, "contains missing, empty or whitespace-padded IDs", ids)
  if (unique) {
    .recovery_bad_rows(duplicated(value), label, "must contain unique IDs", value)
  }
  value
}

.recovery_numeric <- function(value, label, finite = TRUE, ids = seq_along(value)) {
  if (!typeof(value) %in% c("integer", "double") || is.object(value) ||
        !is.null(dim(value))) {
    stop(label, " must be a plain integer or double time vector.", call. = FALSE)
  }
  if (finite) .recovery_bad_rows(!is.finite(value), label, "must be finite", ids)
  as.double(value)
}

.recovery_check_container <- function(tse) {
  if (!methods::is(tse, "TreeSummarizedExperiment")) {
    stop("tse must be a TreeSummarizedExperiment.", call. = FALSE)
  }
  validity <- methods::validObject(tse, test = TRUE)
  if (!identical(validity, TRUE)) {
    stop("tse fails formal S4 validity: ", paste(validity, collapse = "; "), call. = FALSE)
  }
  if (!nrow(tse) || !ncol(tse)) {
    stop("tse must contain at least one feature and one sample.", call. = FALSE)
  }
  .recovery_ids(rownames(tse), "feature IDs (rownames(tse))", unique = TRUE)
  .recovery_ids(colnames(tse), "sample IDs (colnames(tse))", unique = TRUE)
  invisible(NULL)
}

.recovery_named_list <- function(value) {
  if (!is.list(value) || is.object(value)) return(FALSE)
  if (!length(value)) return(TRUE)
  !is.null(names(value)) && !anyNA(names(value)) &&
    all(nzchar(names(value))) && !anyDuplicated(names(value))
}

.recovery_namespace <- function(root, analysis_id, column_names) {
  present <- which(names(root) == "recoverome")
  if (length(present) > 1L) {
    stop("recoverome namespace is ambiguous: duplicate root metadata names.", call. = FALSE)
  }
  namespace <- if (!length(present)) {
    list(schema_version = 1L, analyses = list())
  } else {
    root[[present]]
  }
  if (!.recovery_named_list(namespace) ||
        !all(c("schema_version", "analyses") %in% names(namespace))) {
    stop("recoverome namespace must be a uniquely named list with schema_version and analyses.",
         call. = FALSE)
  }
  if (!identical(namespace$schema_version, 1L)) {
    stop("recoverome namespace has an unsupported schema_version; expected 1L.", call. = FALSE)
  }
  analyses <- namespace$analyses
  if (!.recovery_named_list(analyses) ||
        any(!grepl("^[a-z][a-z0-9]*$", names(analyses)))) {
    stop("recoverome namespace analyses must be a uniquely named list of valid analysis IDs.",
         call. = FALSE)
  }
  if (analysis_id %in% names(analyses)) {
    stop("analysis_id '", analysis_id, "' already exists; register a new name.", call. = FALSE)
  }
  prefix <- paste0("rec_", analysis_id, "_")
  collisions <- column_names[!is.na(column_names) & startsWith(column_names, prefix)]
  if (length(collisions)) {
    stop("Reserved colData prefix '", prefix, "' is already used by: ",
         paste(collisions, collapse = ", "), ".", call. = FALSE)
  }
  namespace
}

.recovery_sample_inputs <- function(annotation, columns, sample_ids) {
  for (column in columns) {
    if (sum(names(annotation) == column, na.rm = TRUE) != 1L) {
      stop("Selected colData column '", column, "' must occur exactly once.", call. = FALSE)
    }
  }
  episode <- .recovery_ids(annotation[[columns[["episode"]]]], "colData episode", allow_na = TRUE,
                           ids = sample_ids)
  included <- !is.na(episode)
  if (!any(included)) stop("At least one sample must be included in an episode.", call. = FALSE)
  # Enforce source types even when excluded cells are not consumed.
  subject <- .recovery_id_vector(annotation[[columns[["subject"]]]], "colData subject")
  subject <- .recovery_ids(subject[included], "colData subject", ids = sample_ids[included])
  time <- .recovery_numeric(annotation[[columns[["time"]]]], "colData time", finite = FALSE)
  time <- .recovery_numeric(time[included], "colData time", ids = sample_ids[included])
  S4Vectors::DataFrame(sample_id = sample_ids[included], subject_id = subject,
                       episode_id = episode[included], time = time, row.names = NULL)
}

.recovery_input_table <- function(value, label, id_columns, time_columns = character()) {
  if (!(is.data.frame(value) || methods::is(value, "DataFrame"))) {
    stop(label, " must be a data.frame or S4Vectors::DataFrame.", call. = FALSE)
  }
  column_names <- names(value)
  if (is.null(column_names) || anyNA(column_names) || any(!nzchar(column_names)) ||
        anyDuplicated(column_names)) {
    stop(label, " must have unique, non-empty column names.", call. = FALSE)
  }
  required <- c(id_columns, time_columns)
  absent <- setdiff(required, column_names)
  if (length(absent)) {
    stop(label, " is missing required columns: ", paste(absent, collapse = ", "), ".",
         call. = FALSE)
  }
  # Normalize core vectors before conversion, preserving all annotation columns.
  for (column in id_columns) {
    value[[column]] <- .recovery_ids(value[[column]], paste0(label, "$", column))
  }
  for (column in time_columns) {
    value[[column]] <- .recovery_numeric(value[[column]], paste0(label, "$", column))
  }
  value <- S4Vectors::DataFrame(value, check.names = FALSE)
  rownames(value) <- NULL
  value
}

.recovery_check_relations <- function(samples, episodes, events) {
  .recovery_ids(episodes$episode_id, "episodes$episode_id", unique = TRUE)
  .recovery_ids(events$event_id, "events$event_id", unique = TRUE)
  .recovery_bad_rows(!episodes$origin_boundary %in% c("start", "end"),
                     "episodes$origin_boundary", "must be start or end", episodes$episode_id)
  .recovery_bad_rows(events$start_time > events$end_time, "events",
                     "requires start_time <= end_time", events$event_id)
  sample_episode <- match(samples$episode_id, episodes$episode_id)
  .recovery_bad_rows(is.na(sample_episode), "samples", "refer to an unknown episode",
                     samples$sample_id)
  .recovery_bad_rows(samples$subject_id != episodes$subject_id[sample_episode], "samples",
                     "have a subject different from their episode subject", samples$sample_id)
  .recovery_bad_rows(!episodes$episode_id %in% samples$episode_id, "episodes",
                     "must each have at least one included sample", episodes$episode_id)
  .recovery_bad_rows(!events$episode_id %in% episodes$episode_id, "events",
                     "refer to an unknown episode", events$event_id)
  origin <- match(episodes$origin_event_id, events$event_id)
  .recovery_bad_rows(is.na(origin), "episodes$origin_event_id", "refers to an unknown event",
                     episodes$episode_id)
  .recovery_bad_rows(events$episode_id[origin] != episodes$episode_id,
                     "episodes$origin_event_id", "must belong to the same episode",
                     episodes$episode_id)
  origin_time <- ifelse(episodes$origin_boundary == "start", events$start_time[origin],
                        events$end_time[origin])
  .recovery_bad_rows(!is.finite(samples$time - origin_time[sample_episode]), "samples",
                     "have non-finite relative time (arithmetic overflow)", samples$sample_id)
  invisible(NULL)
}
