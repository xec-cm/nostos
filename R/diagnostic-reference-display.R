# ggplot2 evaluates these names in each layer's data.
utils::globalVariables(c(
  "distance", "display_y", "value_source", "availability", "sample_id", "identity",
  "event_id", "row", "sample_rank", "gap_class", "event_kind", "milestone", "evidence_state"
))

.recovery_reference_display <- function(data, baseline, reference, title) {
  episodes <- data$episodes
  support <- paste0("Recorded samples = ", episodes$n_baseline_samples, "; distinct times = ",
                    episodes$n_baseline_times, "; ", episodes$reference_support)
  diameter <- ifelse(is.na(episodes$baseline_diameter), "not estimable",
                     format(signif(episodes$baseline_diameter, 3), trim = TRUE))
  support <- paste0(support, "\nRecorded baseline diameter: ", diameter)
  single <- episodes$n_baseline_samples == 1L
  support[single] <- paste0(support[single], "\nOne sample cannot estimate pairwise variation")
  tied <- episodes$n_baseline_samples > episodes$n_baseline_times
  support[tied] <- paste0(support[tied], "\nTied samples are not temporal replication")
  labels <- stats::setNames(paste(episodes$facet, support, sep = "\n"), episodes$episode_id)
  baseline$episode_id <- factor(baseline$episode_id, levels = episodes$episode_id)
  episodes$episode_id <- factor(episodes$episode_id, levels = episodes$episode_id)
  episodes$label <- ifelse(episodes$n_baseline_samples == 0L, "No recorded baseline samples", "")
  baseline$display_y <- ifelse(is.na(baseline$distance), -0.12, baseline$distance)
  groups <- interaction(
    baseline$episode_id, baseline$relative_time, baseline$display_y, drop = TRUE
  )
  annotation <- baseline[!duplicated(groups), ]
  text <- vapply(split(seq_len(nrow(baseline)), groups), function(index) {
    ids <- baseline$sample_id[index]
    availability <- baseline$availability[index]
    if (length(unique(availability)) > 1L) {
      ids <- paste0(ids, " (", tolower(sub(" sample$", "", availability)), ")")
    }
    paste(ids, collapse = ", ")
  }, character(1))
  annotation$label <- unname(text[as.character(groups[!duplicated(groups)])])
  limits <- range(c(0, baseline$relative_time))
  definition <- reference$definition
  features <- paste(utils::head(definition$feature_ids, 6L), collapse = ", ")
  if (length(definition$feature_ids) > 6L) features <- paste0(features, ", ...")
  subtitle <- paste0(data$subtitle, "\nAssay: ", definition$assay,
                     " | Fixed features (", length(definition$feature_ids), "): ", features,
                     "\nReference: mean of sample compositions | Preprocessing: ",
                     definition$preprocessing)
  caption <- paste(
    data$caption,
    "Recorded support is not a stability claim. Samples at one time are not temporal replicates.",
    "Unavailable distances stay on an identity/time rail below zero; no profile is refitted.",
    sep = "\n"
  )
  has_missing <- anyNA(baseline$distance)

  ggplot2::ggplot(baseline) +
    ggplot2::geom_vline(xintercept = 0, colour = "#94a3b8", linewidth = 0.4) +
    (if (has_missing) ggplot2::geom_rect(
      data = episodes, xmin = -Inf, xmax = Inf, ymin = -0.2, ymax = -0.055,
      fill = "#f3f4f6", inherit.aes = FALSE
    )) +
    ggplot2::geom_point(
      ggplot2::aes(x = relative_time, y = display_y, colour = value_source, shape = availability),
      size = 3, stroke = 1
    ) +
    ggplot2::geom_text(
      data = annotation, ggplot2::aes(x = relative_time, y = display_y, label = label),
      vjust = -1.1, size = 3, inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = episodes, ggplot2::aes(label = label), x = mean(limits), y = 0.5,
      size = 4, inherit.aes = FALSE
    ) +
    ggplot2::facet_wrap(ggplot2::vars(episode_id), ncol = 1, drop = FALSE,
                        labeller = ggplot2::labeller(episode_id = labels)) +
    ggplot2::scale_x_continuous(limits = limits, expand = ggplot2::expansion(mult = 0.15)) +
    ggplot2::scale_y_continuous(breaks = seq(0, 1, 0.25),
                                limits = c(if (has_missing) -0.22 else -0.03, 1.08)) +
    ggplot2::scale_colour_manual(
      values = c("Stored deviation" = "#174f64", "Current verified baseline distance" = "#775c99",
                 "Distance unavailable" = "#8b5d50"),
      limits = unique(baseline$value_source), guide = if (nrow(baseline)) "legend" else "none"
    ) +
    ggplot2::scale_shape_manual(
      values = c("Retained sample" = 16, "Removed sample" = 4),
      limits = unique(baseline$availability),
      guide = if (nrow(baseline)) "legend" else "none"
    ) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = paste0("Registered relative time (", data$unit, ")"),
                  y = "Distance to fixed reference", colour = NULL, shape = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(strip.text = ggplot2::element_text(hjust = 0, size = 9),
                   legend.position = "bottom", plot.caption = ggplot2::element_text(hjust = 0))
}
