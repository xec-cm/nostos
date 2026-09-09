test_that("registration requires a nonempty TSE and unambiguous axis identities", {
  fixture <- registration_fixture()
  expect_setup_error(fixture, tse = matrix(1, 2L, 6L))
  se <- SummarizedExperiment::SummarizedExperiment(
    assays = list(counts = matrix(1, 2L, 6L))
  )
  expect_setup_error(fixture, tse = se)
  expect_setup_error(fixture, tse = fixture$tse[FALSE, ])
  expect_setup_error(fixture, tse = fixture$tse[, FALSE])

  for (axis in c("samples", "features")) {
    for (bad_id in c("", " padded", "trailing ")) {
      bad <- registration_fixture()
      if (axis == "samples") {
        colnames(bad$tse)[1] <- bad_id
      } else {
        rownames(bad$tse)[1] <- bad_id
      }
      expect_setup_error(bad)
    }
    bad <- registration_fixture()
    if (axis == "samples") {
      bad$tse <- bad$tse[, c(1L, 1:6)]
    } else {
      bad$tse <- bad$tse[c(1L, 1:2), ]
    }
    expect_true(methods::validObject(bad$tse))
    expect_setup_error(bad)
  }
  # S4Vectors rejects NA row names at assignment; NULL can reach setup.
  no_features <- registration_fixture()
  rownames(no_features$tse) <- NULL
  expect_setup_error(no_features)
  colnames(fixture$tse) <- NULL
  expect_setup_error(fixture)
})

test_that("analysis names and source selectors are explicit scalar names", {
  fixture <- registration_fixture()
  for (id in list(NULL, character(), NA_character_, "", "A", "a_b", "1a",
                  "a-b", " a", c("a", "b"), 1L, list("a"))) {
    expect_setup_error(fixture, analysis_id = id)
  }
  for (selector in list(NULL, NA_character_, "", c("time", "batch"), 3L,
                        list("time"))) {
    expect_setup_error(fixture, time_col = selector)
  }
  expect_setup_error(fixture, subject_col = "episode_id")
  expect_setup_error(fixture, episode_col = "missing")
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$second_time <- cd$time
  names(cd)[5] <- "time"
  SummarizedExperiment::colData(fixture$tse) <- cd
  expect_setup_error(fixture)
})

test_that("episode and event inputs require tables with unambiguous core columns", {
  fixture <- registration_fixture()
  for (bad_table in list(NULL, list(), matrix("e1", nrow = 1L))) {
    expect_setup_error(fixture, episodes = bad_table)
    expect_setup_error(fixture, events = bad_table)
  }
  for (component in c("episodes", "events")) {
    bad <- registration_fixture()
    bad[[component]] <- bad[[component]][FALSE, ]
    expect_setup_error(bad)
    bad <- registration_fixture()
    bad[[component]][[1]] <- NULL
    expect_setup_error(bad)
    bad <- registration_fixture()
    names(bad[[component]])[2] <- names(bad[[component]])[1]
    expect_setup_error(bad)
    bad <- registration_fixture()
    names(bad[[component]])[5] <- ""
    expect_setup_error(bad)
  }
})

test_that("core identity types and contents are validated without coercion", {
  columns <- list(episodes = c("episode_id", "subject_id", "origin_event_id"),
                  events = c("event_id", "episode_id"))
  for (component in names(columns)) {
    for (column in columns[[component]]) {
      for (bad_value in list(1:2, list("first", "second"), c(NA, "valid"),
                             c("", "valid"), c(" padded", "valid"))) {
        bad <- registration_fixture()
        bad[[component]][[column]] <- bad_value
        expect_setup_error(bad)
      }
    }
  }
  for (column in c("subject_id", "episode_id")) {
    for (bad_value in list(1:6, as.list(rep("e1", 6L)),
                           matrix(rep("e1", 6L), ncol = 1L))) {
      bad <- registration_fixture()
      cd <- SummarizedExperiment::colData(bad$tse)
      cd[[column]] <- bad_value
      SummarizedExperiment::colData(bad$tse) <- cd
      expect_setup_error(bad)
    }
  }
  for (bad_subject in c(NA_character_, "", " p1")) {
    bad <- registration_fixture()
    cd <- SummarizedExperiment::colData(bad$tse)
    cd$subject_id[1] <- bad_subject
    SummarizedExperiment::colData(bad$tse) <- cd
    expect_setup_error(bad)
  }
})

test_that("explicit membership and origin references cannot be guessed or recycled", {
  bad <- registration_fixture()
  bad$episodes$episode_id <- c("e1", "e1")
  expect_setup_error(bad)
  bad <- registration_fixture()
  bad$events$event_id <- c("ab1", "ab1")
  expect_setup_error(bad)
  bad <- registration_fixture()
  bad$events$episode_id[1] <- "unknown"
  expect_setup_error(bad)
  bad <- registration_fixture()
  bad$episodes$origin_event_id[1] <- "missing-event"
  expect_setup_error(bad)
  bad <- registration_fixture()
  bad$episodes$origin_event_id[1] <- "ab2"
  expect_setup_error(bad)
  for (boundary in c("Start", "sta", "", NA_character_)) {
    bad <- registration_fixture()
    bad$episodes$origin_boundary[1] <- boundary
    expect_setup_error(bad)
  }
  bad <- registration_fixture()
  bad$episodes$subject_id[1] <- "different-participant"
  expect_setup_error(bad)
  for (episode in c("unknown", "", " e1")) {
    bad <- registration_fixture()
    cd <- SummarizedExperiment::colData(bad$tse)
    cd$episode_id[1] <- episode
    SummarizedExperiment::colData(bad$tse) <- cd
    expect_setup_error(bad)
  }
  bad <- registration_fixture()
  cd <- SummarizedExperiment::colData(bad$tse)
  cd$episode_id <- rep(NA_character_, 6L)
  SummarizedExperiment::colData(bad$tse) <- cd
  expect_setup_error(bad)
  bad <- registration_fixture()
  cd <- SummarizedExperiment::colData(bad$tse)
  cd$episode_id[4:5] <- "e1"
  SummarizedExperiment::colData(bad$tse) <- cd
  expect_setup_error(bad)
})

test_that("time declarations require complete supported values", {
  fixture <- registration_fixture()
  for (unit in list(NULL, character(), NA_character_, "", "day", "Days", "d",
                    "weeks", c("days", "hours"), 1L)) {
    expect_setup_error(fixture, time_unit = unit)
  }
  for (origin in list(NULL, character(), NA_character_, "", "   ",
                      c("origin1", "origin2"), 1L, list("enrolment"))) {
    expect_setup_error(fixture, time_origin = origin)
  }
})

test_that("time inputs are plain numeric vectors, never implicit calendar conversions", {
  invalid_times <- list(
    as.character(1:6), rep(TRUE, 6L), factor(1:6),
    as.Date("2020-01-01") + 1:6,
    as.POSIXct("2020-01-01", tz = "UTC") + 1:6,
    as.difftime(1:6, units = "days"),
    as.list(1:6), matrix(1:6, ncol = 1L), as.complex(1:6),
    structure(as.double(1:6), class = "custom_numeric_time")
  )
  for (times in invalid_times) {
    bad <- registration_fixture()
    cd <- SummarizedExperiment::colData(bad$tse)
    cd$time <- times
    SummarizedExperiment::colData(bad$tse) <- cd
    expect_setup_error(bad)
    for (column in c("start_time", "end_time")) {
      bad <- registration_fixture()
      if (is.matrix(times)) {
        bad$events[[column]] <- times[1:2, , drop = FALSE]
      } else if (inherits(times, "custom_numeric_time")) {
        bad$events[[column]] <- structure(times[1:2], class = "custom_numeric_time")
      } else {
        bad$events[[column]] <- times[1:2]
      }
      expect_setup_error(bad)
    }
  }
})

test_that("included samples and event endpoints must have finite ordered times", {
  for (time in c(NA_real_, NaN, Inf, -Inf)) {
    bad <- registration_fixture()
    cd <- SummarizedExperiment::colData(bad$tse)
    cd$time[1] <- time
    SummarizedExperiment::colData(bad$tse) <- cd
    expect_setup_error(bad)
    for (column in c("start_time", "end_time")) {
      bad <- registration_fixture()
      bad$events[[column]][1] <- time
      expect_setup_error(bad)
    }
  }
  bad <- registration_fixture()
  bad$events$start_time[1] <- 15
  expect_setup_error(bad)
})

test_that("overflow is checked against the explicitly selected origin boundary", {
  for (episode in c("e1", "e2")) {
    bad <- registration_fixture()
    cd <- SummarizedExperiment::colData(bad$tse)
    cd$time[cd$episode_id %in% episode] <- .Machine$double.xmax
    SummarizedExperiment::colData(bad$tse) <- cd
    event <- which(bad$events$episode_id == episode)
    bad$events$start_time[event] <- -.Machine$double.xmax
    bad$events$end_time[event] <- -.Machine$double.xmax
    expect_setup_error(bad)
  }
  fixture <- registration_fixture()
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$time[1:3] <- -.Machine$double.xmax
  SummarizedExperiment::colData(fixture$tse) <- cd
  fixture$events$start_time[1] <- -.Machine$double.xmax
  fixture$events$end_time[1] <- .Machine$double.xmax
  record <- registration_record(register_fixture(fixture))
  expect_identical(record$registration$samples$time[1:3], rep(-.Machine$double.xmax, 3L))
})

test_that("occupied names and reserved column prefixes reject repeated registration", {
  fixture <- registration_fixture()
  fixture$tse <- register_fixture(fixture)
  expect_setup_error(fixture)
  fixture <- registration_fixture()
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$rec_antibiotic_note <- "owned by the user"
  SummarizedExperiment::colData(fixture$tse) <- cd
  expect_setup_error(fixture)
})

test_that("malformed or unsupported namespace containers are not overwritten", {
  malformed <- list(
    NULL, 1L, list(), list(schema_version = 2L, analyses = list()),
    list(schema_version = 1L, analyses = "foreign data"),
    list(schema_version = 1L, analyses = list(list())),
    list(schema_version = 1L, analyses = setNames(list(1, 2), c("same", "same"))),
    list(schema_version = 1L, analyses = setNames(list(1), "invalid_id")),
    setNames(list(1L, 1L, list()), c("schema_version", "schema_version", "analyses"))
  )
  for (namespace in malformed) {
    bad <- registration_fixture()
    S4Vectors::metadata(bad$tse) <- list(recoverome = namespace, user_note = "keep")
    expect_setup_error(bad)
  }
  bad <- registration_fixture()
  S4Vectors::metadata(bad$tse) <- setNames(list(NULL, list()), c("recoverome", "recoverome"))
  expect_setup_error(bad)
})
