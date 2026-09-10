#' Synthetic inputs for registration and observed recovery
#'
#' Small deterministic examples for registering analyses with
#' [setup_recovery()]. They contain plain matrices, data frames, and character
#' scalars; no TreeSummarizedExperiment object or analysis is stored.
#'
#' @format A named list of three examples:
#' \describe{
#'   \item{single_episode}{Two features and three samples from one participant,
#'     with one episode and an exposure interval starting on day 10. The
#'     episode origin is the start of that interval.}
#'   \item{repeated_episodes}{Two features and six samples. Five samples from
#'     participant `p1` belong to two episodes; sample `s6` is explicitly
#'     excluded by its missing episode membership. The episodes use the start
#'     and end of their respective exposure intervals as origins.}
#'   \item{observed_recovery}{Two features and seven samples, with baseline b1
#'     at day 8 and follow-up at days 10, 12, 14, 16, 18 and 20. Relative to
#'     baseline (1, 0), follow-up deviations are 0.75, 0.25, 0.125, 0.125,
#'     0.5 and 0.125. These illustrate an observed return and later rebound.}
#' }
#'
#' Each example contains these seven components:
#' \describe{
#'   \item{counts}{An integer matrix with named feature rows and sample columns.}
#'   \item{col_data}{A data frame whose row names match the count matrix sample
#'     IDs. Columns include `subject_id`, `episode_id`, and the numeric time
#'     column identified by `time_col`. The single-episode example also has
#'     character `phase`; the repeated-episode example has factor `batch`.}
#'   \item{episodes}{A data frame with `episode_id`, `subject_id`,
#'     `origin_event_id`, and `origin_boundary`. The repeated-episode example
#'     also has a character `note` annotation.}
#'   \item{events}{A data frame with `event_id`, `episode_id`, `start_time`, and
#'     `end_time`. The repeated-episode example also has a factor `treatment`
#'     annotation.}
#'   \item{time_col}{The name of the sample time column: `day` or `time`.}
#'   \item{time_unit}{The character scalar `"days"`.}
#'   \item{time_origin}{A description of the numeric coordinate system: days
#'     since enrolment within each participant.}
#' }
#'
#' @details
#' All values are synthetic. These examples illustrate identities, time
#' coordinates, explicit membership, and preservation of registration history.
#' They provide no evidence of recovery, health, treatment effects, or
#' statistical performance.
#'
#' Missing membership in `repeated_episodes` is intentional: the excluded
#' sample has missing subject and time values, which registration does not
#' consume. Its identity remains part of the original container scope.
#'
#' The examples can be regenerated from the package repository with
#' `Rscript --vanilla data-raw/recovery_examples.R`. The generator uses only
#' base R, no random draws, and saves version-3 serialization with xz
#' compression.
#'
#' @source Created for recoverome; no participant or external study data.
#' @keywords datasets
#' @seealso [setup_recovery()], [add_recovery()]
#' @examples
#' data("recovery_examples", package = "nostos")
#' names(recovery_examples)
#'
#' example_input <- recovery_examples$single_episode
#' example_input$episodes
#' example_input$events
"recovery_examples"
