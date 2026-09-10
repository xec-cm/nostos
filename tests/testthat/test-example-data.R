test_that("bundled examples load through data() as ordinary R objects", {
  data_env <- new.env(parent = emptyenv())
  utils::data("recovery_examples", package = "nostos", envir = data_env)
  expect_identical(ls(data_env), "recovery_examples")

  examples <- data_env$recovery_examples
  expect_named(examples, c("single_episode", "repeated_episodes", "observed_recovery"))

  contains_s4 <- function(value) {
    if (isS4(value)) return(TRUE)
    if (!is.list(value)) return(FALSE)
    any(vapply(value, contains_s4, logical(1)))
  }
  expect_false(contains_s4(examples))

  for (example in examples) {
    expect_true(is.matrix(example$counts))
    expect_type(example$counts, "integer")
    expect_s3_class(example$col_data, "data.frame")
    expect_s3_class(example$episodes, "data.frame")
    expect_s3_class(example$events, "data.frame")
    expect_identical(rownames(example$col_data), colnames(example$counts))
  }
})

test_that("bundled examples register with the hand-worked episode-relative coordinates", {
  examples <- load_recovery_examples()
  expected_relative <- list(
    single_episode = c(-7, 0, 7),
    repeated_episodes = c(-7, 0, 7, -8, 1),
    observed_recovery = c(-2, 0, 2, 4, 6, 8, 10)
  )
  expected_samples <- list(
    single_episode = paste0("s", 1:3),
    repeated_episodes = paste0("s", 1:6),
    observed_recovery = c("b1", paste0("s", 1:6))
  )
  expected_included <- list(
    single_episode = paste0("s", 1:3),
    repeated_episodes = paste0("s", 1:5),
    observed_recovery = c("b1", paste0("s", 1:6))
  )

  for (name in names(examples)) {
    example <- examples[[name]]
    before <- serialize(example, NULL)

    tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
      assays = list(counts = example$counts),
      colData = S4Vectors::DataFrame(example$col_data)
    )

    out <- setup_recovery(
      tse,
      analysis_id = "example",
      episodes = example$episodes,
      events = example$events,
      time_col = example$time_col,
      time_unit = example$time_unit,
      time_origin = example$time_origin
    )

    record <- registration_record(out, "example")
    samples <- record$registration$samples
    origins <- vapply(
      seq_len(nrow(record$episodes)),
      function(i) {
        episode <- record$episodes[i, ]
        event <- record$events[record$events$event_id == episode$origin_event_id, ]
        event[[paste0(episode$origin_boundary, "_time")]]
      },
      numeric(1)
    )
    sample_origins <- origins[match(samples$episode_id, record$episodes$episode_id)]

    expect_true(methods::validObject(out))
    expect_identical(nrow(out), 2L)
    expect_identical(colnames(out), expected_samples[[name]])
    expect_identical(record$scope$sample_ids, expected_samples[[name]])
    expect_identical(samples$sample_id, expected_included[[name]])
    expect_identical(samples$time - sample_origins, expected_relative[[name]])
    expect_identical(SummarizedExperiment::assay(out, "counts"), example$counts)
    expect_identical(SummarizedExperiment::colData(out), SummarizedExperiment::colData(tse))
    expect_identical(serialize(example, NULL), before)

    md <- S4Vectors::metadata(out)
    md$recoverome <- NULL
    S4Vectors::metadata(out) <- md
    expect_identical(out, tse)
  }
})
