.recovery_sample_view <- function(context, scope) {
  record <- context$record
  reference <- context$stages$reference
  deviation <- context$stages$deviation
  ids <- record$scope$sample_ids
  present <- ids %in% context$sample_ids
  if (scope == "current") ids <- ids[present]
  present <- ids %in% context$sample_ids
  samples <- record$registration$samples
  rows <- match(ids, samples$sample_id)
  episodes <- match(samples$episode_id[rows], record$episodes$episode_id)
  origins <- match(record$episodes$origin_event_id[episodes], record$events$event_id)
  origin <- ifelse(
    record$episodes$origin_boundary[episodes] == "start",
    record$events$start_time[origins],
    record$events$end_time[origins]
  )
  table <- S4Vectors::DataFrame(
    sample_id = ids,
    subject_id = samples$subject_id[rows],
    episode_id = samples$episode_id[rows],
    time = samples$time[rows],
    relative_time = as.double(samples$time[rows] - origin),
    included = !is.na(rows),
    is_reference = if (is.null(reference)) rep(NA, length(ids)) else
      ids %in% reference$baseline_samples$sample_id,
    deviation = rep(NA_real_, length(ids)),
    deviation_status = rep(NA_character_, length(ids))
  )
  state <- rep("not_computed", length(ids))
  if (!is.null(deviation)) {
    computed <- ids %in% deviation$sample_ids
    state[computed & !present] <- "removed"
    available <- computed & present
    state[available] <- "available"
    current_rows <- match(ids[available], context$sample_ids)
    columns <- deviation$columns
    table$deviation[available] <- context$annotation[[columns[["deviation"]]]][current_rows]
    table$deviation_status[available] <- context$annotation[[columns[["status"]]]][current_rows]
  }

  list(table = table, present = present, state = state)
}

.recovery_episode_view <- function(context, scope) {
  record <- context$record
  samples <- record$registration$samples
  retained_episodes <- samples$episode_id[samples$sample_id %in% context$sample_ids]
  rows <- seq_len(nrow(record$episodes))
  if (scope == "current") rows <- rows[record$episodes$episode_id %in% retained_episodes]
  ids <- record$episodes$episode_id[rows]
  count <- length(ids)
  table <- S4Vectors::DataFrame(
    episode_id = ids,
    subject_id = record$episodes$subject_id[rows],
    reference_support = rep(NA_character_, count),
    n_baseline_samples = rep(NA_integer_, count),
    n_baseline_times = rep(NA_integer_, count),
    baseline_diameter = rep(NA_real_, count),
    status = rep(NA_character_, count),
    reason = rep(NA_character_, count),
    coverage = rep(NA_character_, count),
    first_perturbation_time = rep(NA_real_, count),
    first_return_time = rep(NA_real_, count),
    candidate_time = rep(NA_real_, count),
    confirmation_time = rep(NA_real_, count),
    rebound_time = rep(NA_real_, count),
    last_observed_time = rep(NA_real_, count),
    n_window_visits = rep(NA_integer_, count)
  )
  reference <- context$stages$reference
  if (!is.null(reference)) {
    support <- reference$episodes[match(ids, reference$episodes$episode_id), , drop = FALSE]
    table$reference_support <- support$support
    table$n_baseline_samples <- support$n_samples
    table$n_baseline_times <- support$n_times
    table$baseline_diameter <- support$baseline_diameter
  }
  recovery <- context$stages$recovery
  if (!is.null(recovery)) {
    fields <- c("status", "reason", "coverage", "first_perturbation_time", "first_return_time",
                "candidate_time", "confirmation_time", "rebound_time", "last_observed_time",
                "n_window_visits")
    outcome <- recovery$episodes[match(ids, recovery$episodes$episode_id), fields, drop = FALSE]
    table[fields] <- outcome
  }
  state <- rep(if (is.null(recovery)) "not_computed" else "available", count)

  list(table = table, present = ids %in% retained_episodes, state = state)
}
