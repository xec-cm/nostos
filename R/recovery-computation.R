.recovery_episode_outcome <- function(episode, record, samples, rule, call) {
  origin_row <- match(episode$origin_event_id, record$events$event_id)
  origin_event <- record$events[origin_row, , drop = FALSE]
  origin <- switch(episode$origin_boundary,
    start = origin_event$start_time,
    end = origin_event$end_time
  )
  detection_start <- origin_event$start_time - origin
  window_end <- origin + rule$horizon
  samples <- samples[samples$episode_id == episode$episode_id, , drop = FALSE]
  samples$time <- samples$time - origin
  if (any(!is.finite(c(detection_start, window_end, samples$time)))) {
    .recovery_abort(
      "Relative times or the horizon overflow for episode {.val {episode$episode_id}}.",
      component = "time", ids = episode$episode_id, call = call
    )
  }
  samples <- samples[order(samples$time, seq_len(nrow(samples))), , drop = FALSE]
  evaluated <- samples$time >= detection_start & samples$time <= rule$horizon
  coverage <- samples$time >= 0
  window <- samples$time >= 0 & samples$time <= rule$horizon
  last_time <- if (any(coverage)) max(samples$time[coverage]) else NA_real_
  coverage_state <- if (!any(coverage)) {
    "none"
  } else {
    if (last_time < rule$horizon) "ends_before_horizon" else "reaches_horizon"
  }
  event_episodes <- match(record$events$episode_id, record$episodes$episode_id)
  subjects <- record$episodes$subject_id[event_episodes]
  blocking <- record$events$event_id != episode$origin_event_id &
    subjects == episode$subject_id & record$events$start_time <= window_end &
    record$events$end_time >= origin_event$start_time
  evidence <- list(
    evaluated = as.vector(samples$sample_id[evaluated]),
    coverage = as.vector(samples$sample_id[coverage]),
    perturbation = character(), first_return = character(), candidate = character(),
    confirmation = character(), confirmation_run = character(), rebound = character(),
    blocking_events = as.vector(record$events$event_id[blocking])
  )
  outcome <- list(
    episode_id = episode$episode_id,
    status = "not_evaluable", reason = NA_character_, coverage = coverage_state,
    first_perturbation_time = NA_real_, first_return_time = NA_real_,
    candidate_time = NA_real_, confirmation_time = NA_real_, rebound_time = NA_real_,
    last_observed_time = last_time,
    n_window_visits = as.integer(length(unique(samples$time[window])))
  )
  reasons <- c(
    missing_baseline = !episode$episode_id %in% colnames(record$reference$profiles),
    unresolved_events = any(blocking),
    no_observations_in_window = !any(window)
  )
  if (any(reasons)) {
    outcome$reason <- names(reasons)[which(reasons)[[1L]]]
    return(list(outcome = outcome, evidence = evidence))
  }

  visits <- .recovery_observed_visits(samples[evaluated, , drop = FALSE], rule$threshold)
  .recovery_observed_return(visits, outcome, evidence, rule)
}

.recovery_observed_visits <- function(samples, threshold) {
  groups <- unname(split(seq_len(nrow(samples)), match(samples$time, unique(samples$time))))
  list(
    time = vapply(groups, function(rows) samples$time[[rows[[1L]]]], double(1)),
    within = vapply(groups, function(rows) all(samples$deviation[rows] <= threshold), logical(1)),
    ids = lapply(groups, function(rows) as.vector(samples$sample_id[rows]))
  )
}

.recovery_observed_return <- function(visits, outcome, evidence, rule) {
  outside <- which(!visits$within)
  if (!length(outside)) {
    outcome$status <- "no_detected_perturbation"
    return(list(outcome = outcome, evidence = evidence))
  }
  perturbation <- outside[[1L]]
  outcome$first_perturbation_time <- visits$time[[perturbation]]
  evidence$perturbation <- visits$ids[[perturbation]]
  eligible <- which(visits$within & visits$time >= 0 &
                      visits$time > outcome$first_perturbation_time)
  if (!length(eligible)) {
    outcome$status <- "no_observed_return"
    return(list(outcome = outcome, evidence = evidence))
  }
  first <- eligible[[1L]]
  outcome$first_return_time <- outcome$candidate_time <- visits$time[[first]]
  evidence$first_return <- evidence$candidate <- visits$ids[[first]]
  outcome$status <- "unconfirmed_return"

  breaks <- c(TRUE, diff(eligible) > 1L | diff(visits$time[eligible]) > rule$max_gap)
  runs <- cumsum(breaks)
  starts <- match(runs, runs)
  spans <- visits$time[eligible] - visits$time[eligible[starts]]
  confirmations <- which(spans >= rule$persistence)
  if (!length(confirmations)) {
    return(list(outcome = outcome, evidence = evidence))
  }

  confirmed <- confirmations[[1L]]
  candidate <- eligible[[starts[[confirmed]]]]
  confirmation <- eligible[[confirmed]]
  run <- eligible[seq.int(starts[[confirmed]], confirmed)]
  outcome$status <- "confirmed_return"
  outcome$candidate_time <- visits$time[[candidate]]
  outcome$confirmation_time <- visits$time[[confirmation]]
  evidence$candidate <- visits$ids[[candidate]]
  evidence$confirmation <- visits$ids[[confirmation]]
  evidence$confirmation_run <- unlist(visits$ids[run], use.names = FALSE)
  rebounds <- outside[visits$time[outside] > outcome$confirmation_time]
  if (length(rebounds)) {
    rebound <- rebounds[[1L]]
    outcome$rebound_time <- visits$time[[rebound]]
    evidence$rebound <- visits$ids[[rebound]]
  }

  list(outcome = outcome, evidence = evidence)
}
