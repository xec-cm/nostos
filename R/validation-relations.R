.recovery_relation_finding <- function(bad, component, message, ids) {
  if (!any(bad)) { return(list()) }
  .recovery_finding(
    "REGISTRATION_RECORD_INVALID",
    component,
    message,
    ids = ids[bad],
    .envir = parent.frame()
  )
}

.recovery_validation_relations <- function(samples, episodes, events) {
  findings <- list()
  complete <- FALSE
  sample_table <- samples$value
  episode_table <- episodes$value
  event_table <- events$value

  if (.recovery_fields_ready(episodes, "origin_boundary")) {
    findings <- c(findings, .recovery_relation_finding(
      !episode_table$origin_boundary %in% c("start", "end"),
      "episodes$origin_boundary",
      "Stored origins must select start or end explicitly.",
      ids = episodes$ids
    ))
  }

  if (.recovery_fields_ready(events, c("start_time", "end_time"))) {
    findings <- c(findings, .recovery_relation_finding(
      event_table$start_time > event_table$end_time,
      "events",
      "Stored events require start_time <= end_time.",
      ids = events$ids
    ))
  }

  samples_linked <- .recovery_fields_ready(samples, "episode_id") && .recovery_fields_ready(episodes, "episode_id")
  if (samples_linked) {
    sample_episode <- match(sample_table$episode_id, episode_table$episode_id)
    findings <- c(findings, .recovery_relation_finding(
      is.na(sample_episode),
      "registration$samples$episode_id",
      "Stored samples refer to unknown episodes.",
      ids = samples$ids
    ))
    findings <- c(findings, .recovery_relation_finding(
      !episode_table$episode_id %in% sample_table$episode_id,
      "episodes",
      "Each original episode must have at least one registered sample.",
      ids = episodes$ids
    ))
    if (.recovery_fields_ready(samples, "subject_id") &&
          .recovery_fields_ready(episodes, "subject_id")) {
      known <- !is.na(sample_episode)
      findings <- c(findings, .recovery_relation_finding(
        sample_table$subject_id[known] != episode_table$subject_id[sample_episode[known]],
        "registration$samples$subject_id",
        "Stored sample subjects differ from their episode subjects.",
        ids = samples$ids[known]
      ))
    }
  }

  if (.recovery_fields_ready(events, "episode_id") &&
        .recovery_fields_ready(episodes, "episode_id")) {
    findings <- c(findings, .recovery_relation_finding(
      !event_table$episode_id %in% episode_table$episode_id,
      "events$episode_id",
      "Stored events refer to unknown episodes.",
      ids = events$ids
    ))
  }

  origins_linked <- .recovery_fields_ready(episodes, "origin_event_id") && .recovery_fields_ready(events, "event_id")
  if (origins_linked) {
    origin <- match(episode_table$origin_event_id, event_table$event_id)
    findings <- c(findings, .recovery_relation_finding(
      is.na(origin),
      "episodes$origin_event_id",
      "Stored episode origins refer to unknown events.",
      ids = episodes$ids
    ))
    if (.recovery_fields_ready(episodes, "episode_id") &&
          .recovery_fields_ready(events, "episode_id")) {
      known <- !is.na(origin)
      findings <- c(findings, .recovery_relation_finding(
        episode_table$episode_id[known] != event_table$episode_id[origin[known]],
        "episodes$origin_event_id",
        "Origin events must belong to their own episode.",
        ids = episodes$ids[known]
      ))
    }
  }

  if (samples_linked && origins_linked && .recovery_fields_ready(samples, "time") &&
        .recovery_fields_ready(episodes, "origin_boundary") &&
        .recovery_fields_ready(events, c("start_time", "end_time"))) {
    usable_episode <- !is.na(origin) & episode_table$origin_boundary %in% c("start", "end")
    origin_time <- rep(NA_real_, nrow(episode_table))
    start <- usable_episode & episode_table$origin_boundary == "start"
    end <- usable_episode & episode_table$origin_boundary == "end"
    origin_time[start] <- event_table$start_time[origin[start]]
    origin_time[end] <- event_table$end_time[origin[end]]
    usable_sample <- !is.na(sample_episode) & !is.na(origin_time[sample_episode])
    complete <- all(usable_episode) && all(usable_sample)
    findings <- c(findings, .recovery_relation_finding(
      !is.finite(sample_table$time[usable_sample] - origin_time[sample_episode[usable_sample]]),
      "registration$samples$time",
      "Stored sample times overflow when expressed relative to their event origin.",
      ids = samples$ids[usable_sample]
    ))
  }

  list(findings = findings, complete = complete)
}
