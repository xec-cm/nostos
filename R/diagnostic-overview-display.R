.recovery_overview_display <- function(data, milestones) {
  episodes <- data$episodes
  status <- ifelse(is.na(episodes$status), "not_computed", episodes$status)
  reasons <- !is.na(episodes$reason)
  status[reasons] <- paste0(status[reasons], "\nReason: ", episodes$reason[reasons])
  coverage <- ifelse(is.na(episodes$coverage), "not_computed", episodes$coverage)
  labels <- paste0(episodes$identity, "\nStatus: ", status, "\nCoverage: ", coverage)
  absent <- !episodes$current_present
  labels[absent] <- paste0(labels[absent], "\nNo current samples")
  episodes$label <- ifelse(episodes$result_state == "not_computed", "Recovery not computed", "")
  events <- data$events
  events$row <- episodes$row[match(events$episode_id, episodes$episode_id)] - 0.31
  horizon <- episodes[!is.na(episodes$horizon), ]
  midpoint <- data$limits[[1L]] / 2 + data$limits[[2L]] / 2
  caption <- paste(
    data$caption,
    "Evidence availability refers to retained IDs, not source validity or uncertain timing.",
    "Grey bars/diamonds: recorded events. Solid origin at 0; dashed stored horizon.",
    "Milestone offsets separate coincident times; no continuous recovery is inferred.",
    "A common axis does not establish biological comparability across reference definitions.",
    sep = "\n"
  )

  ggplot2::ggplot(milestones) +
    ggplot2::geom_rect(
      data = episodes, ggplot2::aes(ymin = row - 0.38, ymax = row + 0.4),
      xmin = -Inf, xmax = Inf, fill = "#f3f4f6", inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = episodes, ggplot2::aes(y = row - 0.38, yend = row + 0.4), x = 0, xend = 0,
      colour = "#94a3b8", linewidth = 0.4, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = horizon, ggplot2::aes(x = horizon, xend = horizon, y = row - 0.38, yend = row + 0.4),
      colour = "#94a3b8", linewidth = 0.4, linetype = "dashed", inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = events, ggplot2::aes(x = start, xend = end, y = row, yend = row),
      colour = "#a3a3a3", linewidth = 1.5, inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      data = events[events$start == events$end, ], ggplot2::aes(x = start, y = row),
      shape = 18, colour = "#a3a3a3", size = 2.5, inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(
        x = time, y = row, shape = milestone, colour = evidence_state, fill = evidence_state
      ),
      size = 3, stroke = 0.9
    ) +
    ggplot2::geom_text(
      data = episodes, ggplot2::aes(y = row, label = label),
      x = midpoint, size = 3.3, inherit.aes = FALSE
    ) +
    ggplot2::scale_x_continuous(limits = data$limits, expand = ggplot2::expansion(mult = 0.08)) +
    ggplot2::scale_y_continuous(breaks = episodes$row, labels = labels,
                                limits = c(0.45, nrow(episodes) + 0.55)) +
    ggplot2::scale_shape_manual(values = c(
      "Perturbation" = 21, "First return" = 22, "Winning candidate" = 23,
      "Confirmation" = 24, "Rebound" = 25, "Last observed follow-up" = 8
    ), limits = unique(milestones$milestone), guide = if (nrow(milestones)) "legend" else "none") +
    ggplot2::scale_colour_manual(values = c(
      "Retained evidence" = "#174f64", "Historical evidence" = "#737373",
      "Incomplete evidence" = "#ab6816"
    ), limits = unique(milestones$evidence_state),
    guide = if (nrow(milestones)) "legend" else "none") +
    ggplot2::scale_fill_manual(values = c(
      "Retained evidence" = "#174f64", "Historical evidence" = "white",
      "Incomplete evidence" = "#ffedd5"
    ), limits = unique(milestones$evidence_state),
    guide = if (nrow(milestones)) "legend" else "none") +
    ggplot2::labs(title = "Saved episode outcomes", subtitle = data$subtitle, caption = caption,
                  x = paste0("Registered relative time (", data$unit, ")"), y = NULL,
                  shape = NULL, colour = NULL, fill = NULL) +
    ggplot2::guides(
      shape = ggplot2::guide_legend(nrow = 2),
      colour = ggplot2::guide_legend(nrow = 1), fill = ggplot2::guide_legend(nrow = 1)
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", legend.box = "vertical",
                   panel.grid.major.y = ggplot2::element_blank(),
                   axis.text.y = ggplot2::element_text(size = 9),
                   plot.caption = ggplot2::element_text(hjust = 0))
}
