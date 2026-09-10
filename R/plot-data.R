.recovery_plot_data <- function(context, samples, outcomes, analysis_id, scope) {
  record <- context$record
  recovery <- context$stages$recovery
  rule <- recovery$definition
  summary <- context$report$summary
  warning <- ""
  if (!summary$validation_complete || summary$dependencies == "not_checked") {
    warning <- "Historical inputs missing or checks incomplete"
  }
  if (summary$dependencies == "changed") {
    warning <- "Saved results; sources changed"
    if (!summary$validation_complete) warning <- paste0(warning, "; checks incomplete")
  }

  # The axis uses registration history; observation values use retained outputs.
  facets <- outcomes
  episode_rows <- match(facets$episode_id, record$episodes$episode_id)
  origins <- record$episodes[episode_rows, ]
  events <- record$events[match(origins$origin_event_id, record$events$event_id), ]
  origin_time <- ifelse(origins$origin_boundary == "start", events$start_time, events$end_time)
  facets$window_start <- events$start_time - origin_time
  facets$horizon <- if (is.null(rule)) NA_real_ else rule$horizon
  facets$threshold <- if (is.null(rule)) NA_real_ else rule$threshold
  limits <- range(c(0, samples$relative_time, facets$horizon, facets$window_start), na.rm = TRUE)
  if (any(!is.finite(limits)) || !is.finite(diff(limits))) {
    .recovery_abort("Registered relative times exceed the finite plotting range.",
                    component = "time", call = context$call)
  }
  points <- samples[!is.na(samples$deviation_status) & samples$deviation_status == "computed", ]
  points$observation <- ifelse(points$is_reference, "Selected baseline", "Observed sample")
  points$window <- rep("Observed deviation", nrow(points))
  if (!is.null(rule)) {
    starts <- facets$window_start[match(points$episode_id, facets$episode_id)]
    points$window <- ifelse(points$relative_time > rule$horizon | points$relative_time < starts,
                            "Outside rule window", "In rule window")
  }
  counts <- tabulate(match(points$episode_id, facets$episode_id), nrow(facets))
  support <- paste0("Reference: ", facets$reference_support, "; n = ", facets$n_baseline_samples)
  retained_baselines <- vapply(facets$episode_id, function(id) {
    sum(samples$episode_id == id & samples$is_reference & samples$current_present)
  }, integer(1))
  support <- paste0(support, " (", retained_baselines, " retained)")
  context_label <- paste0("Origin: ", origins$origin_event_id, " / ", origins$origin_boundary,
                          " at ", origin_time, " ", record$registration$time_unit)
  status <- rep("Deviations only; recovery not computed", nrow(facets))
  if (!is.null(recovery)) {
    status <- paste0(facets$status, "; coverage: ", facets$coverage)
    reasons <- !is.na(facets$reason)
    status[reasons] <- paste0(status[reasons], "; reason: ", facets$reason[reasons])
    context_label <- paste0(context_label, "; declared window [", facets$window_start,
                            ", ", facets$horizon, "]")
    blocking <- vapply(recovery$evidence[facets$episode_id], function(evidence) {
      paste(evidence$blocking_events, collapse = ", ")
    }, character(1))
    has_blocking <- nzchar(blocking)
    context_label[has_blocking] <- paste0(context_label[has_blocking],
                                          "; blocking events: ", blocking[has_blocking])
  }
  facets$label <- paste0(facets$subject_id, " | ", facets$episode_id, "\n",
                         support, "\n", context_label, "\n", status)
  if (nzchar(warning)) facets$label <- paste(facets$label, warning, sep = "\n")
  facets$empty <- ifelse(counts == 0L, "No remaining computed deviations", "")
  facets$missing_followup <- ifelse(!is.na(facets$coverage) & facets$coverage == "none",
                                    "Missing follow-up", "")
  facets$episode_id <- factor(facets$episode_id, levels = outcomes$episode_id)
  points$episode_id <- factor(points$episode_id, levels = outcomes$episode_id)
  removed <- samples[!samples$current_present, ]
  removed$episode_id <- factor(removed$episode_id, levels = outcomes$episode_id)
  evidence <- .recovery_plot_evidence(context, samples, outcomes)
  evidence$marks$episode_id <- factor(evidence$marks$episode_id, levels = outcomes$episode_id)
  evidence$spans$episode_id <- factor(evidence$spans$episode_id, levels = outcomes$episode_id)
  evidence$gaps$episode_id <- factor(evidence$gaps$episode_id, levels = outcomes$episode_id)
  subtitle <- paste0("Scope: ", scope, " | ", record$registration$time_unit)
  if (!is.null(rule)) {
    subtitle <- paste0(subtitle, " | threshold = ", rule$threshold,
                       "; persistence = ", rule$persistence, "; maximum gap = ", rule$max_gap,
                       "; horizon = ", rule$horizon,
                       "\nShaded window is declared, not a confidence interval")
  }
  caption <- c(
    warning,
    "Points are observed; no trajectory is inferred. Reference counts describe saved support."
  )
  if (!is.null(recovery) || nrow(removed)) {
    caption <- c(
      caption,
      "Hollow marks / dashed spans = incomplete current evidence, not uncertain timing.",
      "Supporting span is observed support; gaps do not establish an outside state.",
      "x = removed observation."
    )
  }

  c(list(points = points, facets = facets, removed = removed, limits = limits,
         title = paste("Recovery observations:", analysis_id), subtitle = subtitle,
         caption = paste(caption[nzchar(caption)], collapse = "\n")), evidence)
}

.recovery_plot_evidence <- function(context, samples, outcomes) {
  marks <- data.frame(episode_id = character(), time = double(), y = double(),
                      label = character(), support = character())
  spans <- data.frame(episode_id = character(), start = double(), end = double(),
                      support = character())
  gaps <- data.frame(episode_id = character(), start = double(), end = double())
  recovery <- context$stages$recovery
  if (is.null(recovery)) return(list(marks = marks, spans = spans, gaps = gaps))

  for (row in seq_len(nrow(outcomes))) {
    outcome <- outcomes[row, ]
    id <- outcome$episode_id
    evidence <- recovery$evidence[[id]]
    milestone <- data.frame(
      episode_id = id,
      time = c(outcome$first_return_time, outcome$candidate_time,
               outcome$confirmation_time, outcome$rebound_time),
      y = c(-0.13, -0.24, -0.35, -0.46),
      label = c("First return", "Candidate", "Confirmation", "Rebound"),
      support = vapply(evidence[c("first_return", "candidate", "confirmation_run", "rebound")],
                       function(ids) {
                         retained <- all(ids %in% context$sample_ids)
                         if (retained) "Retained evidence" else "Incomplete evidence"
                       }, character(1))
    )
    if (!is.na(outcome$first_return_time) &&
          identical(outcome$first_return_time, outcome$candidate_time)) {
      milestone$label[[2L]] <- "First return / candidate"
      milestone$time[[1L]] <- NA_real_
    }
    marks <- rbind(marks, milestone[!is.na(milestone$time), ])
    if (!is.na(outcome$confirmation_time)) {
      spans <- rbind(spans, data.frame(episode_id = id, start = outcome$candidate_time,
                                       end = outcome$confirmation_time,
                                       support = milestone$support[[3L]]))
    }
    # The evaluated IDs encode the original visits, including removed samples.
    times <- sort(unique(samples$relative_time[match(evidence$evaluated, samples$sample_id)]))
    starts <- utils::head(times, -1L)
    ends <- utils::tail(times, -1L)
    separated <- ends - starts > recovery$definition$max_gap
    gaps <- rbind(gaps, data.frame(episode_id = rep(id, sum(separated)),
                                   start = starts[separated], end = ends[separated]))
  }

  list(marks = marks, spans = spans, gaps = gaps)
}
