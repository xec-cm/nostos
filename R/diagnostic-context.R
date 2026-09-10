# Prepare one historical context for the diagnostic views, without revalidation.
.recovery_diagnostic_context <- function(tse, analysis_id, scope, call) {
  .recovery_view_selector(scope, "scope", c("current", "historical"), call)
  context <- .recovery_view_context(tse, analysis_id, "plot", call)
  episodes <- .recovery_episode_view(context, scope)
  episodes$table$current_present <- episodes$present
  episodes$table$result_state <- episodes$state
  episodes <- as.data.frame(episodes$table)
  samples <- .recovery_sample_view(context, "historical")
  samples$table$current_present <- samples$present
  samples$table$result_state <- samples$state
  samples <- as.data.frame(samples$table)
  samples <- samples[samples$included & samples$episode_id %in% episodes$episode_id, ]

  record <- context$record
  registration <- record$episodes[match(episodes$episode_id, record$episodes$episode_id), ]
  origin_events <- record$events[match(registration$origin_event_id, record$events$event_id), ]
  episodes$origin_event_id <- registration$origin_event_id
  episodes$origin_boundary <- registration$origin_boundary
  episodes$origin_time <- ifelse(registration$origin_boundary == "start",
                                 origin_events$start_time, origin_events$end_time)
  rule <- context$stages$recovery$definition
  episodes$horizon <- rep(if (is.null(rule)) NA_real_ else rule$horizon, nrow(episodes))
  episodes$max_gap <- rep(if (is.null(rule)) NA_real_ else rule$max_gap, nrow(episodes))
  episodes$row <- rev(seq_len(nrow(episodes)))
  episodes$identity <- paste(episodes$subject_id, episodes$episode_id, sep = " | ")

  events <- data.frame(episode_id = character(), event_id = character(),
                       start = double(), end = double(), selected_origin = logical())
  for (row in seq_len(nrow(episodes))) {
    episode <- episodes[row, ]
    blocking <- context$stages$recovery$evidence[[episode$episode_id]]$blocking_events
    selected <- record$events$episode_id == episode$episode_id |
      record$events$event_id %in% blocking
    event <- as.data.frame(record$events[selected, ])
    events <- rbind(events, data.frame(
      episode_id = rep(episode$episode_id, nrow(event)), event_id = event$event_id,
      start = event$start_time - episode$origin_time,
      end = event$end_time - episode$origin_time,
      selected_origin = event$event_id == episode$origin_event_id
    ))
  }
  limits <- range(c(0, samples$relative_time, events$start, events$end, episodes$horizon),
                  na.rm = TRUE)
  if (any(!is.finite(limits)) || !is.finite(diff(limits))) {
    .recovery_abort("Registered relative times exceed the finite plotting range.",
                    component = "time", call = call)
  }
  unit <- record$registration$time_unit
  summary <- context$report$summary
  checks <- if (summary$validation_complete) "checks complete" else "checks incomplete"
  validation <- paste0("Validation: ", summary$dependencies, "; ", checks)
  if (summary$dependencies == "changed") {
    validation <- paste("Saved context; sources changed.", validation)
  }
  episodes$facet <- paste0(episodes$identity, "\nOrigin: ", episodes$origin_event_id,
                           " / ", episodes$origin_boundary, recycle0 = TRUE)
  if (!summary$validation_complete || summary$dependencies == "changed") {
    episodes$facet <- paste(episodes$facet, validation, sep = "\n", recycle0 = TRUE)
  }
  .recovery_view_additions(context, call)

  list(
    context = context, samples = samples, episodes = episodes, events = events,
    limits = limits, analysis_id = analysis_id, scope = scope, unit = unit,
    subtitle = paste0("Analysis: ", analysis_id, " | Scope: ", scope, " | Time unit: ", unit),
    caption = paste(validation,
                    "Recorded coordinates are preserved; gaps do not establish unobserved states.",
                    sep = "\n")
  )
}

.recovery_diagnostic_empty <- function(data, title, message) {
  ggplot2::ggplot(data$episodes) +
    ggplot2::annotate("text", x = 0, y = 0, label = message, size = 4) +
    ggplot2::labs(title = title, subtitle = data$subtitle, caption = data$caption) +
    ggplot2::theme_void() +
    ggplot2::theme(plot.caption = ggplot2::element_text(hjust = 0))
}
