#' Inspect saved observed outcomes across episodes
#'
#' Summarize original milestone times and recorded follow-up on a common relative
#' time axis, with a separate status and coverage label for each subject/episode.
#'
#' @inheritParams recovery_results
#' @details
#' Current scope selects episodes with any retained originally included sample;
#' historical scope selects every registered episode. Outcomes and milestone times
#' always come from the original saved recovery record. No rule is rerun after
#' filtering or source changes. Uncomputed and not-evaluable outcomes remain
#' explicit, including the original reason and coverage where available.
#'
#' Perturbation, first return, winning candidate, confirmation, rebound and last
#' observed follow-up have distinct positions within each episode row. These small
#' vertical offsets separate coincident milestones without moving their times.
#' First return may differ from the winning candidate; confirmation and rebound
#' may both occur. The confirmation marker uses the complete confirmation run,
#' including intermediate visits. Each milestone distinguishes fully retained,
#' wholly historical and partially retained evidence IDs. Evidence availability
#' describes identity presence, not source validity or uncertainty in the saved
#' time. Follow-up uses the saved last observed time and its supporting sample IDs.
#'
#' Recorded events, the chosen origin at zero and the stored horizon provide
#' context. No milestone trajectory or continuous recovery interval is drawn.
#' A common axis does not estimate comparable biological recovery across different
#' reference definitions. Status and coverage are distinct recorded categories.
#'
#' Validate the analysis once using the existing extraction policy. Present
#' unsupported or incoherent records error. Scope additions emit the structured
#' warning described in [recovery_results()] and are never enrolled. Captions
#' retain the scope, time unit, validation findings and observation limitations.
#'
#' @return An ordinary unprinted [ggplot2::ggplot], editable with ggplot2 layers
#'   and themes. Empty scope returns an informative plot with preserved context.
#'   The TSE and all saved outcomes, fingerprints and provenance are unchanged.
#' @seealso [recovery_results()], [plot_recovery()], [plot_reference()], [plot_sampling()]
#' @export
#' @examples
#' data("recovery_examples", package = "recoverome")
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
#' plot_recovery_overview(tse[, colnames(tse) != "s3"], "observed", scope = "historical")
plot_recovery_overview <- function(tse, analysis_id, scope = "current") {
  data <- .recovery_diagnostic_context(tse, analysis_id, scope, environment())
  if (!nrow(data$episodes)) {
    return(.recovery_diagnostic_empty(data, "Saved episode outcomes",
                                      "No episodes in the selected scope"))
  }
  milestones <- .recovery_overview_milestones(data)

  .recovery_overview_display(data, milestones)
}

.recovery_overview_milestones <- function(data) {
  milestones <- data.frame(episode_id = character(), subject_id = character(), time = double(),
                           milestone = character(), evidence_state = character(), row = double())
  recovery <- data$context$stages$recovery
  if (is.null(recovery)) return(milestones)

  for (row in seq_len(nrow(data$episodes))) {
    episode <- data$episodes[row, ]
    evidence <- recovery$evidence[[episode$episode_id]]
    ids <- evidence[c("perturbation", "first_return", "candidate", "confirmation_run", "rebound")]
    coverage <- data$samples[match(evidence$coverage, data$samples$sample_id), ]
    ids$followup <- coverage$sample_id[coverage$relative_time == episode$last_observed_time]
    states <- vapply(ids, function(value) {
      present <- value %in% data$context$sample_ids
      if (all(present)) return("Retained evidence")
      if (!any(present)) return("Historical evidence")
      "Incomplete evidence"
    }, character(1))
    observed <- data.frame(
      episode_id = episode$episode_id, subject_id = episode$subject_id,
      time = c(episode$first_perturbation_time, episode$first_return_time, episode$candidate_time,
               episode$confirmation_time, episode$rebound_time, episode$last_observed_time),
      milestone = c("Perturbation", "First return", "Winning candidate", "Confirmation", "Rebound",
                    "Last observed follow-up"),
      evidence_state = unname(states), row = episode$row + c(-0.22, -0.11, 0, 0.11, 0.22, 0.32)
    )
    milestones <- rbind(milestones, observed[!is.na(observed$time), ])
  }

  milestones
}
