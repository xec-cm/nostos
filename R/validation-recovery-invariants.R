.recovery_outcome_invariants <- function(episodes, rule) {
  statuses <- c("not_evaluable", "no_detected_perturbation", "no_observed_return",
                "unconfirmed_return", "confirmed_return")
  reasons <- c("missing_baseline", "unresolved_events", "no_observations_in_window")
  not_evaluable <- episodes$status == "not_evaluable"
  detected <- episodes$status %in% c("no_observed_return", "unconfirmed_return", "confirmed_return")
  returned <- episodes$status %in% c("unconfirmed_return", "confirmed_return")
  confirmed <- episodes$status == "confirmed_return"
  valid <- !is.na(episodes$status) & episodes$status %in% statuses &
    ((not_evaluable & episodes$reason %in% reasons) | (!not_evaluable & is.na(episodes$reason))) &
    episodes$n_window_visits >= 0L & (not_evaluable | episodes$n_window_visits > 0L)
  valid <- valid & (detected == !is.na(episodes$first_perturbation_time)) &
    (returned == !is.na(episodes$first_return_time)) &
    (returned == !is.na(episodes$candidate_time)) &
    (confirmed == !is.na(episodes$confirmation_time)) &
    (confirmed | is.na(episodes$rebound_time))
  for (field in c("first_return_time", "candidate_time", "confirmation_time", "rebound_time")) {
    time <- episodes[[field]]
    valid <- valid & (is.na(time) | (time >= 0 & time <= rule$horizon))
  }
  valid <- valid & (is.na(episodes$first_perturbation_time) |
                      episodes$first_perturbation_time <= rule$horizon)
  rows <- which(returned)
  valid[rows] <- valid[rows] &
    episodes$first_return_time[rows] > episodes$first_perturbation_time[rows] &
    episodes$candidate_time[rows] >= episodes$first_return_time[rows]
  rows <- which(episodes$status == "unconfirmed_return")
  valid[rows] <- valid[rows] & episodes$candidate_time[rows] == episodes$first_return_time[rows]
  rows <- which(confirmed)
  valid[rows] <- valid[rows] &
    episodes$confirmation_time[rows] - episodes$candidate_time[rows] >= rule$persistence &
    (is.na(episodes$rebound_time[rows]) |
       episodes$rebound_time[rows] > episodes$confirmation_time[rows])
  last <- episodes$last_observed_time
  coverage <- episodes$coverage
  valid <- valid & !is.na(coverage) & (
    (coverage == "none" & is.na(last) & episodes$n_window_visits == 0L) |
      (coverage == "ends_before_horizon" & !is.na(last) & last >= 0 & last < rule$horizon) |
      (coverage == "reaches_horizon" & !is.na(last) & last >= rule$horizon)
  )
  valid[is.na(valid)] <- FALSE
  if (all(valid)) {
    return(.recovery_check_part())
  }

  .recovery_outcome_problem("recovery$episodes", episodes$episode_id[!valid], complete = TRUE)
}

.recovery_evidence_links <- function(parsed, registration) {
  result <- .recovery_check_part()
  episodes <- parsed$value$episodes
  fields <- c("perturbation", "first_return", "candidate", "confirmation", "rebound")
  time_fields <- c("first_perturbation_time", "first_return_time", "candidate_time",
                   "confirmation_time", "rebound_time")
  for (row in seq_len(nrow(episodes))) {
    id <- episodes$episode_id[[row]]
    if (is.na(id) || !id %in% names(parsed$value$evidence)) {
      next
    }
    evidence <- parsed$value$evidence[[id]]
    selected <- evidence[fields]
    present <- lengths(selected) > 0L
    timed <- vapply(time_fields, function(field) !is.na(episodes[[field]][[row]]), logical(1))
    valid <- identical(unname(present), unname(timed))
    valid <- valid && (length(evidence$confirmation_run) > 0L) ==
      (episodes$status[[row]] == "confirmed_return")
    valid <- valid && all(unlist(evidence[c(fields, "confirmation_run")], use.names = FALSE) %in%
                            evidence$evaluated)
    if (!is.null(parsed$sample_ids)) {
      valid <- valid && all(c(evidence$evaluated, evidence$coverage) %in% parsed$sample_ids)
    }
    sample_table <- registration$samples
    if (!is.null(sample_table) &&
          .recovery_fields_ready(sample_table, c("sample_id", "episode_id"))) {
      samples <- unique(c(evidence$evaluated, evidence$coverage))
      rows <- match(samples, sample_table$value$sample_id)
      valid <- valid && !anyNA(rows) && all(sample_table$value$episode_id[rows] == id)
    }
    if (!is.null(registration$events) && .recovery_fields_ready(registration$events, "event_id")) {
      valid <- valid && all(evidence$blocking_events %in% registration$events$value$event_id)
    }
    if (!isTRUE(valid)) {
      result$findings <- c(
        result$findings, .recovery_stage_problem("recovery", "recovery$evidence", id)
      )
    }
  }
  result$structural_valid <- !length(result$findings)

  result
}
