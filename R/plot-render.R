# ggplot2 evaluates these column names in the layer data.
utils::globalVariables(c(
  "relative_time", "deviation", "observation", "window", "window_start", "horizon",
  "threshold", "last_observed_time", "episode_id", "time", "y", "label", "support",
  "start", "end", "empty", "missing_followup"
))

.recovery_plot_render <- function(data) {
  facets <- data$facets
  declared <- facets[!is.na(facets$horizon), ]
  followup <- facets[!is.na(facets$coverage) & facets$coverage == "ends_before_horizon", ]
  labels <- stats::setNames(facets$label, as.character(facets$episode_id))
  center <- data$limits[[1L]] / 2 + data$limits[[2L]] / 2
  rail <- nrow(declared) > 0L || nrow(data$removed) > 0L
  plot <- ggplot2::ggplot(data$points) +
    (if (rail) ggplot2::geom_rect(
      data = facets, xmin = -Inf, xmax = Inf, ymin = -0.68, ymax = -0.07,
      fill = "#f3f4f6", inherit.aes = FALSE
    )) +
    ggplot2::geom_rect(
      data = declared, ggplot2::aes(xmin = window_start, xmax = horizon, ymin = 0, ymax = 1),
      fill = "#e8eef4", inherit.aes = FALSE
    ) +
    ggplot2::geom_rect(
      data = followup,
      ggplot2::aes(xmin = last_observed_time, xmax = horizon, ymin = 0, ymax = 1),
      fill = "#f5dfad", alpha = 0.7, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = facets, x = 0, xend = 0, y = 0, yend = 1,
      colour = "#64748b", linewidth = 0.4, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = declared, ggplot2::aes(x = horizon, xend = horizon, y = 0, yend = 1),
      colour = "#64748b", linetype = "dashed", linewidth = 0.4, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = declared,
      ggplot2::aes(x = window_start, xend = horizon, y = threshold, yend = threshold),
      colour = "#6b7280", linetype = "dotted", linewidth = 0.5, inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(x = relative_time, y = deviation, shape = observation, colour = window),
      size = 2.8, stroke = 0.8
    ) +
    ggplot2::geom_segment(
      data = data$spans,
      ggplot2::aes(x = start, xend = end, y = -0.35, yend = -0.35, linetype = support),
      colour = "#174f64", linewidth = 0.6, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = data$spans,
      ggplot2::aes(x = start, xend = start, y = -0.38, yend = -0.32, linetype = support),
      colour = "#174f64", linewidth = 0.6, inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = data$spans,
      ggplot2::aes(x = end, xend = end, y = -0.38, yend = -0.32, linetype = support),
      colour = "#174f64", linewidth = 0.6, inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      data = data$marks, ggplot2::aes(x = time, y = y, fill = support),
      shape = 21, size = 2.8, colour = "#174f64", stroke = 0.8, inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = data$marks, ggplot2::aes(x = time, y = y, label = label),
      vjust = -1.1, size = 2.8, colour = "#174f64", inherit.aes = FALSE
    ) +
    ggplot2::geom_point(
      data = data$removed, ggplot2::aes(x = relative_time, y = -0.56),
      shape = 4, size = 2, colour = "#7c4650", inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      data = data$gaps, ggplot2::aes(x = start, xend = end, y = -0.65, yend = -0.65),
      colour = "#966526", linetype = "dotted", linewidth = 0.8, inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = data$gaps,
      ggplot2::aes(x = start / 2 + end / 2, y = -0.65, label = "Observation gap > G"),
      vjust = -0.5, size = 2.7, colour = "#805519", inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = followup,
      ggplot2::aes(x = last_observed_time / 2 + horizon / 2, y = 0.9),
      label = "Beyond recorded\nfollow-up", size = 2.7, colour = "#805519",
      inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = facets, ggplot2::aes(label = empty), x = center, y = 0.6,
      size = 3.4, inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = facets, ggplot2::aes(label = missing_followup), x = center, y = 0.45,
      size = 3.4, colour = "#805519", inherit.aes = FALSE
    ) +
    ggplot2::facet_wrap(
      ggplot2::vars(episode_id), ncol = 1, drop = FALSE,
      labeller = ggplot2::labeller(episode_id = labels)
    ) +
    ggplot2::scale_x_continuous(limits = data$limits, expand = ggplot2::expansion(mult = 0.09)) +
    ggplot2::scale_y_continuous(
      breaks = seq(0, 1, 0.25), limits = c(if (rail) -0.72 else -0.05, 1.05)
    ) +
    ggplot2::scale_shape_manual(
      values = c("Observed sample" = 16, "Selected baseline" = 17),
      limits = c("Observed sample", "Selected baseline"),
      guide = if (nrow(data$points)) "legend" else "none"
    ) +
    ggplot2::scale_colour_manual(values = c(
      "Observed deviation" = "#174f64", "In rule window" = "#174f64",
      "Outside rule window" = "#8b6b38"
    ), limits = if (nrow(declared)) c("In rule window", "Outside rule window") else
      "Observed deviation", guide = if (nrow(data$points)) "legend" else "none") +
    ggplot2::scale_fill_manual(values = c(
      "Retained evidence" = "#174f64", "Incomplete evidence" = "white"
    ), guide = "none") +
    ggplot2::scale_linetype_manual(values = c(
      "Retained evidence" = "solid", "Incomplete evidence" = "dashed"
    ), guide = "none") +
    ggplot2::labs(
      title = data$title, subtitle = data$subtitle, caption = data$caption,
      x = "Registered relative time",
      y = if (rail) "Deviation (0-1) / evidence rail" else "Deviation",
      shape = NULL, colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(hjust = 0, size = 9, lineheight = 1.1),
      strip.background = ggplot2::element_rect(fill = "#f3f4f6", colour = NA),
      plot.caption = ggplot2::element_text(hjust = 0, size = 8),
      plot.subtitle = ggplot2::element_text(size = 10),
      legend.position = "bottom"
    )

  plot
}
