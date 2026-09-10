# Arithmetic evidence for proposed RFC 003, not a recovery implementation.
# From the repository, run with the development package loaded:
# Rscript --vanilla -e 'pkgload::load_all();
#   source("dev/examples/003-observed-recovery.R")'
# These blocks check the stated visit evidence and independently expected times.
# They do not call add_recovery(), fit a model, or encode an outcome as a stub.

threshold <- 0.25
persistence <- 4
max_gap <- 3
horizon <- 10

# The illustrative deviations can arise from RFC 002's actual Bray--Curtis rule.
reference <- c(a = 1, b = 0)
counts <- rbind(a = c(2, 6, 7, 7, 1), b = c(6, 2, 1, 1, 7))
colnames(counts) <- c("v0", "v2", "v4", "v6", "v12")
composition <- sweep(counts, 2L, colSums(counts), "/")
deviation <- colSums(abs(composition - reference)) / 2
time <- c(v0 = 0, v2 = 2, v4 = 4, v6 = 6, v12 = 12)
stopifnot(max(abs(deviation - c(0.75, 0.25, 0.125, 0.125, 0.875))) < 1e-12)

# Straightforward return: candidate 2, confirmation 6, all gaps no larger than 3.
in_window <- time >= 0 & time <= horizon
outside <- in_window & deviation > threshold
first_perturbation <- min(time[outside])
return_ids <- names(time)[in_window & time > first_perturbation & deviation <= threshold]
return_times <- time[return_ids]
confirmation_index <- which(return_times - return_times[1L] >= persistence)[1L]
stopifnot(
  first_perturbation == 0,
  identical(return_ids, c("v2", "v4", "v6")),
  return_times[1L] == 2,
  return_times[confirmation_index] == 6,
  all(diff(return_times) <= max_gap),
  max(time) == 12,
  max(time) >= horizon,
  !any(outside & time > return_times[confirmation_index])
)

# Truncated follow-up: an observed return is not enough to confirm persistence.
truncated_times <- time[c("v0", "v2", "v4")]
truncated_deviation <- deviation[names(truncated_times)]
truncated_return <- truncated_times[truncated_deviation <= threshold]
stopifnot(
  min(truncated_return) == 2,
  diff(range(truncated_return)) == 2,
  diff(range(truncated_return)) < persistence,
  max(truncated_times) < horizon
)

# A failed first return does not become the candidate of a later confirmed run.
retry_times <- c(v0 = 0, v2 = 2, v3 = 3, v5 = 5, v7 = 7, v9 = 9)
retry_deviation <- c(v0 = 0.75, v2 = 0.125, v3 = 0.5, v5 = 0.125, v7 = 0.125, v9 = 0.125)
first_return <- min(retry_times[retry_times > 0 & retry_deviation <= threshold])
confirmed_ids <- c("v5", "v7", "v9")
confirmed_times <- retry_times[confirmed_ids]
confirmation_index <- which(confirmed_times - confirmed_times[1L] >= persistence)[1L]
stopifnot(
  first_return == 2,
  retry_deviation["v3"] > threshold,
  retry_times["v3"] - first_return < persistence,
  all(retry_deviation[confirmed_ids] <= threshold),
  all(diff(confirmed_times) <= max_gap),
  confirmed_times[1L] == 5,
  confirmed_times[confirmation_index] == 9
)

# Rebound after confirmation is separate evidence and does not erase that result.
rebound_times <- c(v0 = 0, v2 = 2, v4 = 4, v6 = 6, v8 = 8, v10 = 10)
rebound_deviation <- c(v0 = 0.75, v2 = 0.125, v4 = 0.125, v6 = 0.125, v8 = 0.5, v10 = 0.125)
confirmed_times <- rebound_times[c("v2", "v4", "v6")]
confirmation_index <- which(confirmed_times - confirmed_times[1L] >= persistence)[1L]
confirmation_time <- confirmed_times[confirmation_index]
rebound <- rebound_times > confirmation_time & rebound_times <= horizon &
  rebound_deviation > threshold
stopifnot(
  confirmation_time == 6,
  all(diff(confirmed_times) <= max_gap),
  all(rebound_deviation[names(confirmed_times)] <= threshold),
  min(rebound_times[rebound]) == 8
)

# A five-day gap splits support: neither resulting run spans four days.
gap_times <- c(v0 = 0, v2 = 2, v7 = 7, v9 = 9)
gap_deviation <- c(v0 = 0.75, v2 = 0.125, v7 = 0.125, v9 = 0.125)
inside_times <- gap_times[gap_deviation <= threshold]
run_number <- cumsum(c(TRUE, diff(inside_times) > max_gap))
run_spans <- vapply(split(inside_times, run_number), function(x) diff(range(x)), numeric(1))
stopifnot(
  identical(unname(diff(inside_times)), c(5, 2)),
  identical(unname(run_spans), c(0, 2)),
  all(run_spans < persistence)
)

# No observed return is distinct from missing observations or no detected deviation.
no_return_times <- c(0, 4, 8)
no_return_deviation <- c(0.75, 0.5, 0.375)
stopifnot(
  all(no_return_deviation > threshold),
  max(no_return_times) == 8,
  max(no_return_times) < horizon
)
no_detection_times <- c(2, 6, 12)
no_detection_deviation <- c(0.25, 0.125, 0.75)
in_window <- no_detection_times <= horizon
stopifnot(
  sum(in_window) == 2L,
  all(no_detection_deviation[in_window] <= threshold),
  max(no_detection_times) > horizon
)
late_only_times <- no_detection_times[!in_window]
stopifnot(!any(late_only_times >= 0 & late_only_times <= horizon), max(late_only_times) > horizon)

# Simultaneous samples form one visit; the high value cannot be averaged away.
duplicate_times <- c(v0 = 0, v2a = 2, v2b = 2, v4 = 4, v6 = 6, v8 = 8)
duplicate_deviation <- c(v0 = 0.75, v2a = 0.125, v2b = 0.375, v4 = 0.125, v6 = 0.125, v8 = 0.125)
visit_deviation <- tapply(duplicate_deviation, duplicate_times, max)
visit_times <- as.double(names(visit_deviation))
return_times <- visit_times[visit_times > 0 & visit_deviation <= threshold]
stopifnot(
  visit_deviation["2"] == 0.375,
  visit_deviation["2"] > threshold,
  mean(duplicate_deviation[c("v2a", "v2b")]) == threshold,
  return_times[1L] == 4,
  return_times[which(return_times - return_times[1L] >= persistence)[1L]] == 8
)
# Many samples at one time still contribute no observed persistence duration.
simultaneous_times <- c(2, 2, 2, 4)
stopifnot(length(unique(simultaneous_times)) == 2L, diff(range(simultaneous_times)) < persistence)
# Ignoring a missing simultaneous value would create unsupported inside evidence.
missing_visit <- c(0.125, NA_real_)
stopifnot(anyNA(missing_visit), all(missing_visit <= threshold, na.rm = TRUE))

# Equality is included at the band, gap, duration and horizon boundaries.
boundary_times <- c(v0 = 0, v6 = 6, v9 = 9, v10 = 10)
boundary_deviation <- c(v0 = 0.75, v6 = 0.25, v9 = 0.125, v10 = 0.125)
boundary_return <- boundary_times[boundary_times <= horizon & boundary_deviation <= threshold]
stopifnot(
  boundary_deviation["v6"] == threshold,
  max(diff(boundary_return)) == max_gap,
  diff(range(boundary_return)) == persistence,
  max(boundary_return) == horizon
)
# Moving the only confirming observation beyond H does not backdate confirmation.
late_confirmation_times <- c(0, 6, 9, 12)
late_confirmation_deviation <- c(0.75, 0.25, 0.125, 0.125)
within_return <- late_confirmation_times <= horizon & late_confirmation_deviation <= threshold
stopifnot(
  diff(range(late_confirmation_times[within_return])) < persistence,
  max(late_confirmation_times) > horizon
)

# An end origin retains evidence of deviation during the original exposure.
event_start <- 10
event_end <- 14
absolute_time <- c(12, 14, 16, 18)
end_origin_deviation <- c(0.75, 0.25, 0.125, 0.125)
relative_time <- absolute_time - event_end
detection_start <- event_start - event_end
during_detection <- relative_time >= detection_start & end_origin_deviation > threshold
first_perturbation <- min(relative_time[during_detection])
return_times <- relative_time[relative_time >= 0 & end_origin_deviation <= threshold]
stopifnot(
  detection_start == -4,
  first_perturbation == -2,
  return_times[1L] == 0,
  return_times[which(return_times - return_times[1L] >= persistence)[1L]] == 4
)

# Same-subject events overlap the whole declared window, including its endpoints.
events <- data.frame(
  event_id = c("origin", "later", "other_subject", "before", "touches_horizon", "after"),
  subject_id = c("p1", "p1", "p2", "p1", "p1", "p1"),
  start = c(10, 22, 22, 8, 24, 25),
  end = c(14, 23, 23, 9, 24, 26)
)
blocking <- events$event_id != "origin" & events$subject_id == "p1" &
  events$end >= event_start & events$start <= event_end + horizon
stopifnot(identical(events$event_id[blocking], c("later", "touches_horizon")))

# The bundled episodes retain their own baselines and never borrow one another's.
utils::data("recovery_examples", package = "nostos")
example_data <- recovery_examples$repeated_episodes
selected_baselines <- "s1"
baseline_episode <- example_data$col_data[selected_baselines, "episode_id"]
stopifnot(
  identical(baseline_episode, "e1"),
  !any(baseline_episode == "e2")
)
episode_1_ids <- c("s1", "s2", "s3")
example_counts <- example_data$counts[, episode_1_ids, drop = FALSE]
example_composition <- sweep(example_counts, 2L, colSums(example_counts), "/")
example_deviation <- colSums(abs(example_composition - example_composition[, "s1"])) / 2
example_event <- example_data$events[example_data$events$event_id == "ab1", , drop = FALSE]
example_times <- example_data$col_data[episode_1_ids, "time"] - example_event$start_time
stopifnot(
  max(abs(example_deviation - c(0, 2 / 21, 4 / 33))) < 1e-12,
  identical(example_times, c(-7, 0, 7)),
  all(example_deviation[example_times >= 0 & example_times <= horizon] <= threshold)
)

cat("All RFC 003 arithmetic examples passed; no recovery API was implemented.\n")
