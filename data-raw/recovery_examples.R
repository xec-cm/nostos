# Run from the package root with Rscript --vanilla data-raw/recovery_examples.R.
# These synthetic values describe registration structure, not recovery outcomes.

single_counts <- matrix(
  c(80L, 20L, 75L, 25L, 40L, 60L),
  nrow = 2L,
  dimnames = list(c("feature_a", "feature_b"), c("s1", "s2", "s3"))
)

repeated_counts <- matrix(
  seq_len(12L),
  nrow = 2L,
  dimnames = list(c("f1", "f2"), paste0("s", seq_len(6L)))
)

recovery_examples <- list(
  single_episode = list(
    counts = single_counts,
    col_data = data.frame(
      subject_id = rep("participant_1", 3L),
      episode_id = rep("episode_1", 3L),
      day = c(3, 10, 17),
      phase = c("before", "during", "after"),
      row.names = colnames(single_counts)
    ),
    episodes = data.frame(
      episode_id = "episode_1",
      subject_id = "participant_1",
      origin_event_id = "exposure_1",
      origin_boundary = "start"
    ),
    events = data.frame(
      event_id = "exposure_1",
      episode_id = "episode_1",
      start_time = 10,
      end_time = 14
    ),
    time_col = "day",
    time_unit = "days",
    time_origin = "days since enrolment within each participant"
  ),
  repeated_episodes = list(
    counts = repeated_counts,
    col_data = data.frame(
      subject_id = c(rep("p1", 5L), NA_character_),
      episode_id = c(rep("e1", 3L), rep("e2", 2L), NA_character_),
      time = c(3, 10, 17, 34, 43, NA_real_),
      batch = factor(c("a", "b", "a", "b", "a", "b")),
      row.names = colnames(repeated_counts)
    ),
    episodes = data.frame(
      episode_id = c("e1", "e2"),
      subject_id = c("p1", "p1"),
      origin_event_id = c("ab1", "ab2"),
      origin_boundary = c("start", "end"),
      note = c("first exposure", "second exposure")
    ),
    events = data.frame(
      event_id = c("ab1", "ab2"),
      episode_id = c("e1", "e2"),
      start_time = c(10, 40),
      end_time = c(14, 42),
      treatment = factor(c("antibiotic-a", "antibiotic-b"))
    ),
    time_col = "time",
    time_unit = "days",
    time_origin = "days since enrolment within participant"
  )
)

dir.create("data", showWarnings = FALSE)
save(
  recovery_examples,
  file = "data/recovery_examples.rda",
  version = 3,
  compress = "xz"
)
