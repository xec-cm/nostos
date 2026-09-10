#' Inspect the registered observation calendar
#'
#' Show sample times, perturbation events, chosen origins, and original gaps by
#' subject and episode, before or after analytical stages have been calculated.
#'
#' @inheritParams recovery_results
#' @details
#' Current scope selects episodes with any retained originally included sample;
#' historical scope selects all registered episodes. Original samples in those
#' episodes remain visible at their registered times. Removed samples are hollow.
#' Multiple samples at the same time occupy separate vertical sample positions;
#' their time coordinates are never jittered or interpreted as temporal replication.
#'
#' Gaps join consecutive distinct registered times, including removed samples.
#' Filtering cannot manufacture a new original gap. With a stored recovery rule,
#' gaps exceeding its maximum gap are distinguished and its horizon is drawn.
#' These calendar gaps include times outside the rule window; their comparison
#' provides context and does not re-evaluate recovery. Before recovery, actual
#' gaps remain visible without an invented cutoff or horizon. Recorded interval
#' and point events, the selected origin event/boundary, and stored blocking events
#' provide context without causal attribution.
#'
#' The analysis is validated once using the existing extraction policy. Present
#' unsupported or inconsistent analytical records error; changed sources and
#' incomplete checks remain visible. Current edited annotations never replace
#' the registered calendar. Added identities are not enrolled and emit the
#' structured scope warning described in [recovery_results()].
#'
#' @return An ordinary unprinted [ggplot2::ggplot], editable with `+ labs(...)`
#'   or `+ theme(...)` from ggplot2. Empty scope returns an informative plot with
#'   preserved context. The TSE and its saved records are unchanged.
#' @seealso [plot_reference()], [plot_recovery_overview()], [plot_recovery()]
#' @export
#' @examples
#' data("recovery_examples", package = "nostos")
#' example_data <- recovery_examples$repeated_episodes
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = example_data$counts),
#'   colData = S4Vectors::DataFrame(example_data$col_data)
#' )
#' tse <- setup_recovery(
#'   tse, "observed", example_data$episodes, example_data$events,
#'   time_col = example_data$time_col, time_unit = example_data$time_unit,
#'   time_origin = example_data$time_origin
#' )
#' plot_sampling(tse, "observed")
plot_sampling <- function(tse, analysis_id, scope = "current") {
  data <- .recovery_diagnostic_context(tse, analysis_id, scope, environment())
  if (!nrow(data$episodes)) {
    return(.recovery_diagnostic_empty(data, "Registered sampling calendar",
                                      "No episodes in the selected scope"))
  }

  .recovery_sampling_display(data)
}

.recovery_sampling_gaps <- function(data) {
  gaps <- data.frame(episode_id = character(), start = double(), end = double(),
                     gap = double(), gap_class = character())
  for (row in seq_len(nrow(data$episodes))) {
    episode <- data$episodes[row, ]
    times <- sort(unique(data$samples$relative_time[
      data$samples$episode_id == episode$episode_id
    ]))
    duration <- diff(times)
    classes <- rep("Registered gap; no cutoff", length(duration))
    if (!is.na(episode$max_gap)) {
      classes <- ifelse(duration > episode$max_gap, "Gap > stored max_gap", "Gap <= stored max_gap")
    }
    gaps <- rbind(gaps, data.frame(
      episode_id = rep(episode$episode_id, length(duration)),
      start = utils::head(times, -1L), end = utils::tail(times, -1L),
      gap = duration, gap_class = classes
    ))
  }

  gaps
}

.recovery_sampling_display <- function(data) {
  samples <- data$samples
  episodes <- data$episodes
  events <- data$events
  gaps <- .recovery_sampling_gaps(data)
  gaps$label <- format(signif(gaps$gap, 3), trim = TRUE)
  samples$availability <- ifelse(samples$current_present, "Retained sample", "Removed sample")
  samples$sample_rank <- stats::ave(
    seq_len(nrow(samples)), samples$episode_id, samples$relative_time, FUN = seq_along
  )
  max_ties <- max(c(1, samples$sample_rank))
  samples$episode_id <- factor(samples$episode_id, levels = episodes$episode_id)
  events$episode_id <- factor(events$episode_id, levels = episodes$episode_id)
  gaps$episode_id <- factor(gaps$episode_id, levels = episodes$episode_id)
  episodes$episode_id <- factor(episodes$episode_id, levels = episodes$episode_id)
  events$event_kind <- ifelse(events$selected_origin, "Origin event", "Other recorded event")
  labels <- stats::setNames(episodes$facet, as.character(episodes$episode_id))
  horizon <- episodes[!is.na(episodes$horizon), ]
  subtitle <- data$subtitle
  if (nrow(horizon)) {
    subtitle <- paste0(subtitle, "\nStored horizon = ", horizon$horizon[[1L]],
                       "; max_gap = ", horizon$max_gap[[1L]])
  }
  caption <- paste(
    data$caption,
    "Gap labels give elapsed time between original visits, including removed samples.",
    "Stacked samples share an unchanged time coordinate; they are not separate visits.",
    "Solid vertical line: chosen origin. Dashed vertical line: stored horizon, when present.",
    sep = "\n"
  )

  ggplot2::ggplot(samples) +
    ggplot2::geom_segment(data = episodes, x = 0, xend = 0, y = -0.75, yend = max_ties + 0.35,
                          colour = "#64748b", linewidth = 0.4, inherit.aes = FALSE) +
    ggplot2::geom_segment(
      data = horizon, ggplot2::aes(x = horizon, xend = horizon), y = -0.75, yend = max_ties + 0.35,
      linetype = "dashed", colour = "#64748b", inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = events, ggplot2::aes(x = start, xend = end, colour = event_kind), y = 0, yend = 0,
      linewidth = 2, inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      data = events[events$start == events$end, ], ggplot2::aes(x = start, colour = event_kind),
      y = 0, shape = 18, size = 3.5, inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = events, ggplot2::aes(x = start / 2 + end / 2, label = event_id),
      y = 0, vjust = -1, size = 2.7, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = gaps, ggplot2::aes(x = start, xend = end, colour = gap_class), y = -0.5, yend = -0.5,
      linewidth = 0.8, inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = gaps, ggplot2::aes(x = start / 2 + end / 2, label = label),
      y = -0.5, vjust = -0.8, size = 2.8, inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(x = relative_time, y = sample_rank, shape = availability),
      size = 3, stroke = 1, colour = "#174f64"
    ) +
    ggplot2::facet_wrap(ggplot2::vars(episode_id), ncol = 1, drop = FALSE,
                        labeller = ggplot2::labeller(episode_id = labels)) +
    ggplot2::scale_x_continuous(limits = data$limits, expand = ggplot2::expansion(mult = 0.08)) +
    ggplot2::scale_y_continuous(breaks = c(-0.5, 0, seq_len(max_ties)),
                                labels = c("Gaps", "Events", paste("Sample", seq_len(max_ties))),
                                limits = c(-0.85, max_ties + 0.4)) +
    ggplot2::scale_shape_manual(values = c("Retained sample" = 16, "Removed sample" = 1),
                                limits = unique(samples$availability)) +
    ggplot2::scale_colour_manual(values = c(
      "Registered gap; no cutoff" = "#94a3b8", "Gap <= stored max_gap" = "#94a3b8",
      "Gap > stored max_gap" = "#b7791f", "Origin event" = "#174f64",
      "Other recorded event" = "#775c99"
    ), limits = unique(c(events$event_kind, gaps$gap_class))) +
    ggplot2::labs(title = "Registered sampling calendar", subtitle = subtitle, caption = caption,
                  x = paste0("Registered relative time (", data$unit, ")"), y = NULL,
                  colour = NULL, shape = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(strip.text = ggplot2::element_text(hjust = 0, size = 9),
                   legend.position = "bottom", plot.caption = ggplot2::element_text(hjust = 0))
}
