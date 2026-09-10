#' Plot saved deviations and observed recovery evidence
#'
#' Display a named analysis without recalculating its reference, deviations or
#' recovery outcomes. Each episode has an observation panel and a separate time
#' evidence rail. Historical observations never become interpolated trajectories.
#'
#' @inheritParams recovery_results
#' @param episodes NULL for all episodes permitted by `scope`, or a non-empty,
#'   unique character vector of permitted episode IDs in the desired order.
#'
#' @details
#' A deviation stage is required. Before recovery, deviations are shown without
#' a threshold, detection window or invented outcome. With recovery, the declared
#' window starts at the saved origin event's start relative to its selected
#' boundary and ends at the declared horizon. Its shading is not a confidence
#' interval. The shared deviation scale is zero to one; negative panel space is
#' a separate evidence rail, not a deviation scale.
#'
#' Points are retained computed observations at registered times; baseline
#' selections have a different shape. There are no connecting lines, averaging,
#' jitter, smoothing or inferred missing values. Facets show saved reference
#' support/counts, origin context, status, reason and coverage. Shared time limits
#' include original included observations, zero and any declared horizon, even
#' after filtering. Points beyond the horizon are outside the rule window.
#'
#' First return, candidate, confirmation and rebound retain their saved times.
#' Hollow evidence marks and dashed supporting spans mean that at least one
#' required evidence ID is absent from the current TSE, not uncertain timing.
#' Confirmation requires the entire saved confirmation run, including intermediate
#' observations. Removed observation times have their own rail marks. Original
#' evaluated visit gaps greater than the declared maximum are observation gaps,
#' not proof of an outside state. Saved incomplete or missing follow-up remains
#' visible; filtering does not re-evaluate coverage or create new original gaps.
#'
#' The plot validates the analysis once and shares the extraction projections.
#' All present displayed stages must be readable. Changed sources or incomplete
#' checks appear in the caption and every facet; edited annotations never move
#' historical observations. Scope additions emit the same structured warning as
#' [recovery_results()]. The TSE is preserved. Customization does not revalidate.
#'
#' @return One ordinary, unprinted [ggplot2::ggplot] object. Customize it using
#'   `+ ggplot2::labs(...)` or `+ ggplot2::theme(...)`. Printing draws the plot.
#' @seealso [recovery_results()], [add_recovery()]
#' @export
#' @examples
#' data("recovery_examples", package = "nostos")
#' example_data <- recovery_examples$observed_recovery
#' tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
#'   assays = list(counts = example_data$counts),
#'   colData = S4Vectors::DataFrame(example_data$col_data)
#' )
#' tse <- setup_recovery(
#'   tse, "observed", example_data$episodes, example_data$events,
#'   time_col = example_data$time_col, time_unit = example_data$time_unit,
#'   time_origin = example_data$time_origin
#' )
#' tse <- add_reference(tse, "observed", "b1", assay = "counts")
#' tse <- add_deviation(tse, "observed")
#' tse <- add_recovery(tse, "observed", list(
#'   threshold = 0.25, persistence = 4, max_gap = 3, horizon = 10
#' ))
#' plot_recovery(tse, "observed")
#' filtered <- tse[, colnames(tse) != "s3"]
#' plot_recovery(filtered, "observed", scope = "historical") +
#'   ggplot2::labs(title = "Saved confirmation after removing an intermediate visit")
plot_recovery <- function(tse, analysis_id, scope = "current", episodes = NULL) {
  error_call <- environment()
  .recovery_view_selector(scope, "scope", c("current", "historical"), error_call)
  context <- .recovery_view_context(tse, analysis_id, "plot", error_call)
  if (is.null(context$stages$deviation)) {
    .recovery_abort(
      c("No deviations exist to plot for analysis {.val {analysis_id}}.",
        i = "Use {.fun recovery_results} at episode level to inspect reference support."),
      component = "deviation", call = error_call
    )
  }
  available <- .recovery_episode_view(context, scope)$table
  if (is.null(episodes)) episodes <- available$episode_id
  if (!is.character(episodes) || !is.null(dim(episodes)) || !length(episodes) || anyNA(episodes) ||
        anyDuplicated(episodes) || any(!nzchar(episodes))) {
    .recovery_abort(
      "{.arg episodes} must select a non-empty, unique character vector of episode IDs.",
      component = "episodes", call = error_call
    )
  }
  outside <- setdiff(episodes, available$episode_id)
  if (length(outside)) {
    .recovery_abort(
      "Episode IDs {.val {outside}} are unknown or outside {.val {scope}} scope.",
      component = "episodes", ids = outside, call = error_call
    )
  }
  outcomes <- as.data.frame(available[match(episodes, available$episode_id), ])
  samples <- .recovery_sample_view(context, "historical")
  samples$table$current_present <- samples$present
  samples$table$result_state <- samples$state
  samples <- as.data.frame(samples$table)
  samples <- samples[samples$included & samples$episode_id %in% episodes, ]
  context$call <- error_call
  plot_data <- .recovery_plot_data(context, samples, outcomes, analysis_id, scope)
  .recovery_view_additions(context, error_call)

  .recovery_plot_render(plot_data)
}
