utils::globalVariables(c("episode", "scenario", "outcome"))

#' Display every requested recovery-rule scenario
#'
#' Show an explicit scenario-by-episode matrix of observed outcomes and times.
#' Unavailable scenarios remain visible; no setting is selected as preferable.
#'
#' @param x An unmodified DataFrame returned by [recovery_sensitivity()], retaining
#'   its `recoverome_sensitivity` metadata. Plot a fresh result after changing
#'   inputs or rules; arbitrary row/column/context edits are rejected.
#'
#' @return An ordinary, unprinted ggplot with scenarios in supplied order, one
#'   column per registered subject/episode, rule values in row labels, outcome
#'   colors, and observed return/confirmation/rebound times in cells. Customize
#'   with `+ ggplot2::labs()` or `+ ggplot2::theme()`. The plot contains a snapshot;
#'   it does not revalidate the source TSE or express inferential uncertainty.
#' @details
#' `not_evaluable` from a valid scenario (for example, missing baseline) is distinct
#' from a scenario that could not be recalculated because inputs changed or required
#' historical values are unavailable. Missing times are shown as `-`, not zero.
#' Times are formatted for display; exact numeric coordinates remain in the table.
#' Large matrices may need a larger plotting device. The result remains an
#' ordinary DataFrame: convert a separate copy when manipulating tables so the
#' original context and consistency checksum remain available for plotting.
#' @seealso [recovery_sensitivity()], [plot_recovery()]
#' @export
#' @inherit recovery_sensitivity examples
plot_sensitivity <- function(x) {
  error_call <- environment()
  context <- .recovery_sensitivity_check(x, error_call)
  values <- as.data.frame(x)
  rules <- as.data.frame(context$rules)
  episodes <- context$analysis$registration$episodes
  values$episode <- factor(values$episode_id, levels = episodes$episode_id)
  values$scenario <- factor(values$scenario_id, levels = rev(rules$scenario_id))
  values$outcome <- ifelse(values$evaluation_state == "evaluated", values$status, "not_evaluated")
  values$label <- .recovery_sensitivity_labels(values)
  scenario_labels <- paste0(
    rules$scenario_id, "\nthreshold=", rules$threshold, "; P=", rules$persistence,
    "; G=", rules$max_gap, "; H=", rules$horizon
  )
  names(scenario_labels) <- rules$scenario_id
  episode_labels <- paste(episodes$subject_id, episodes$episode_id, sep = " | ")
  names(episode_labels) <- episodes$episode_id
  colors <- c(
    confirmed_return = "#AED8CE", unconfirmed_return = "#F1D399",
    no_observed_return = "#ECC4C4", no_detected_perturbation = "#B9D2E5",
    not_evaluable = "#DBD0E5", not_evaluated = "#DFDFDF"
  )
  unit <- context$analysis$registration$time_unit
  ggplot2::ggplot(values, ggplot2::aes(x = episode, y = scenario, fill = outcome)) +
    ggplot2::geom_tile(color = "white", linewidth = 1, width = .96, height = .92) +
    ggplot2::geom_text(ggplot2::aes(label = label), size = 3.2, lineheight = 1.05) +
    ggplot2::scale_x_discrete(labels = episode_labels, drop = FALSE, position = "top") +
    ggplot2::scale_y_discrete(labels = scenario_labels, drop = FALSE) +
    ggplot2::scale_fill_manual(values = colors, labels = function(x) gsub("_", " ", x)) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
    ggplot2::labs(
      title = paste("Recovery rule sensitivity:", context$analysis$selection$analysis_id),
      subtitle = paste0("Fixed reference and deviations; times in ", unit),
      x = "Subject | episode", y = "Requested scenario", fill = "Observed status",
      caption = paste(
        "R = first observed return; C = confirmation; B = rebound; - = unavailable.",
        "P = persistence; G = maximum gap; H = horizon (registered time units).",
        "All requested settings are shown; no preferred rule or continuous recovery is inferred.",
        sep = "\n"
      )
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), legend.position = "bottom")
}

.recovery_sensitivity_check <- function(x, call) {
  if (!methods::is(x, "DataFrame")) {
    .recovery_abort(
      "{.arg x} must be the original DataFrame returned by {.fun recovery_sensitivity}.",
      component = "x", call = call
    )
  }
  context <- S4Vectors::metadata(x)$recoverome_sensitivity
  supported <- .recovery_named_list(context) && identical(context$schema_version, 1L) &&
    .recovery_named_list(context$provenance) &&
    identical(context$provenance$fingerprint_format, "recoverome_sensitivity_snapshot_v1") &&
    .recovery_valid_sha256(context$fingerprint)
  # The checksum covers the complete table/context pair, avoiding repeated schema checks.
  consistent <- supported && identical(context$fingerprint, .recovery_sensitivity_hash(x, context))
  if (!consistent) {
    .recovery_abort(
      c("Sensitivity results or their required context are missing, changed or unsupported.",
        i = "Regenerate the result with {.fun recovery_sensitivity} before plotting."),
      component = "recoverome_sensitivity", call = call
    )
  }

  context
}

.recovery_sensitivity_labels <- function(values) {
  times <- lapply(values[c("first_return_time", "confirmation_time", "rebound_time")], function(x) {
    ifelse(is.na(x), "-", format(x, trim = TRUE, digits = 4))
  })
  labels <- paste0("R ", times[[1L]], "  |  C ", times[[2L]], "  |  B ", times[[3L]])
  unavailable <- values$evaluation_state != "evaluated"
  labels[unavailable] <- gsub("_", " ", values$evaluation_reason[unavailable])
  not_evaluable <- !unavailable & values$status == "not_evaluable"
  labels[not_evaluable] <- gsub("_", " ", values$reason[not_evaluable])

  vapply(labels, function(label) paste(strwrap(label, width = 27), collapse = "\n"), character(1))
}
