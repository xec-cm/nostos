test_that("registration stores the worked example without derived results", {
  fixture <- registration_fixture()
  out <- register_fixture(fixture)
  namespace <- S4Vectors::metadata(out)$recoverome
  record <- registration_record(out)

  expect_s4_class(out, "TreeSummarizedExperiment")
  expect_true(methods::validObject(out))
  expect_identical(namespace$schema_version, 1L)
  expect_named(namespace$analyses, "antibiotic")
  expect_identical(record$schema_version, 1L)
  expect_named(record, c("schema_version", "registration", "episodes", "events",
                         "scope", "owned_columns", "provenance"), ignore.order = TRUE)
  expect_identical(record$registration$source_columns,
                   c(subject = "subject_id", episode = "episode_id", time = "time"))
  expect_identical(record$registration$time_unit, "days")
  expect_identical(record$registration$time_origin,
                   "days since enrolment within participant")
  expect_s4_class(record$registration$samples, "DataFrame")
  expect_named(record$registration$samples,
               c("sample_id", "subject_id", "episode_id", "time"))
  expect_identical(record$registration$samples$sample_id, paste0("s", 1:5))
  expect_identical(record$registration$samples$subject_id, rep("p1", 5L))
  expect_identical(record$registration$samples$episode_id,
                   c("e1", "e1", "e1", "e2", "e2"))
  expect_identical(record$registration$samples$time, c(3, 10, 17, 34, 43))
  expect_identical(record$scope$sample_ids, paste0("s", 1:6))
  expect_identical(record$scope$feature_ids, c("f1", "f2"))
  expect_identical(record$owned_columns, character())
  expect_identical(SummarizedExperiment::colData(out),
                   SummarizedExperiment::colData(fixture$tse))
  expect_type(record$provenance$package_version, "character")
  expect_identical(record$provenance$package_version,
                   as.character(utils::packageVersion("nostos")))
  expect_length(record$provenance$registered_at, 1L)
  expect_match(record$provenance$registered_at,
               "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$")
})

test_that("only the recoverome metadata entry changes, including on a linked TSE", {
  fixture <- registration_fixture(trees = TRUE)
  before <- serialize(fixture, NULL)
  out <- register_fixture(fixture)

  expect_identical(serialize(fixture, NULL), before)
  expect_identical(SummarizedExperiment::assays(out),
                   SummarizedExperiment::assays(fixture$tse))
  expect_identical(SummarizedExperiment::rowData(out),
                   SummarizedExperiment::rowData(fixture$tse))
  expect_identical(SummarizedExperiment::colData(out),
                   SummarizedExperiment::colData(fixture$tse))
  expect_identical(TreeSummarizedExperiment::rowTree(out),
                   TreeSummarizedExperiment::rowTree(fixture$tse))
  expect_identical(TreeSummarizedExperiment::colTree(out),
                   TreeSummarizedExperiment::colTree(fixture$tse))
  expect_identical(TreeSummarizedExperiment::rowLinks(out),
                   TreeSummarizedExperiment::rowLinks(fixture$tse))
  expect_identical(TreeSummarizedExperiment::colLinks(out),
                   TreeSummarizedExperiment::colLinks(fixture$tse))
  expect_identical(S4Vectors::metadata(out)$study,
                   S4Vectors::metadata(fixture$tse)$study)
  md <- S4Vectors::metadata(out)
  md$recoverome <- NULL
  S4Vectors::metadata(out) <- md
  expect_identical(out, fixture$tse)
})

test_that("factor IDs and integer coordinates normalize only in the stored copy", {
  fixture <- registration_fixture()
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$subject_id <- factor(cd$subject_id)
  cd$episode_id <- factor(cd$episode_id, levels = c("e2", "unused", "e1"))
  cd$time <- as.integer(cd$time)
  SummarizedExperiment::colData(fixture$tse) <- cd
  for (column in c("episode_id", "subject_id", "origin_event_id")) {
    fixture$episodes[[column]] <- factor(fixture$episodes[[column]])
  }
  for (column in c("event_id", "episode_id")) {
    fixture$events[[column]] <- factor(fixture$events[[column]])
  }
  fixture$events$start_time <- as.integer(fixture$events$start_time)
  fixture$events$end_time <- as.integer(fixture$events$end_time)
  before <- serialize(fixture, NULL)
  out <- register_fixture(fixture)
  record <- registration_record(out)

  expect_identical(serialize(fixture, NULL), before)
  expect_identical(record$registration$samples$episode_id,
                   c("e1", "e1", "e1", "e2", "e2"))
  expect_type(record$registration$samples$time, "double")
  expect_s4_class(record$episodes, "DataFrame")
  expect_s4_class(record$events, "DataFrame")
  expect_identical(record$episodes$episode_id, c("e1", "e2"))
  expect_identical(record$episodes$subject_id, c("p1", "p1"))
  expect_identical(record$episodes$origin_event_id, c("ab1", "ab2"))
  expect_identical(record$events$event_id, c("ab1", "ab2"))
  expect_identical(record$events$episode_id, c("e1", "e2"))
  expect_identical(record$events$start_time, c(10, 40))
  expect_identical(record$events$end_time, c(14, 42))
  expect_identical(record$events$treatment, fixture$events$treatment)
  expect_identical(record$episodes$note, fixture$episodes$note)
})

test_that("identities determine associations after independent row permutations", {
  fixture <- registration_fixture()
  fixture$tse <- fixture$tse[c("f2", "f1"), c("s5", "s2", "s6", "s1", "s4", "s3")]
  fixture$episodes <- fixture$episodes[2:1, ]
  fixture$events <- fixture$events[2:1, ]
  rownames(fixture$episodes) <- c("ignored-a", "ignored-b")
  rownames(fixture$events) <- c("not-sample-a", "not-sample-b")
  record <- registration_record(register_fixture(fixture))

  expect_identical(record$scope$sample_ids, c("s5", "s2", "s6", "s1", "s4", "s3"))
  expect_identical(record$scope$feature_ids, c("f2", "f1"))
  expect_identical(record$registration$samples$sample_id, c("s5", "s2", "s1", "s4", "s3"))
  expect_identical(record$registration$samples$episode_id, c("e2", "e1", "e1", "e2", "e1"))
  expect_identical(record$registration$samples$time, c(43, 10, 3, 34, 17))
  expect_identical(record$episodes$episode_id, c("e2", "e1"))
  expect_identical(record$events$event_id, c("ab2", "ab1"))
  # Hand-worked origins from RFC 001 are 42 for e2 and 10 for e1.
  expect_identical(record$registration$samples$time - c(42, 10, 10, 42, 10),
                   c(1, 0, -7, -8, 7))
})

test_that("excluded cells, repeated times, point events and extra events are supported", {
  fixture <- registration_fixture()
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$subject_id[6] <- " invalid excluded subject "
  cd$time[6] <- Inf
  cd$time[2] <- cd$time[1]
  SummarizedExperiment::colData(fixture$tse) <- cd
  fixture$events$end_time[1] <- fixture$events$start_time[1]
  extra <- fixture$events[1, ]
  extra$event_id <- "another-event"
  extra$start_time <- 2.25
  extra$end_time <- 12.5
  fixture$events <- rbind(fixture$events, extra)
  record <- registration_record(register_fixture(fixture))

  expect_identical(record$registration$samples$time, c(3, 3, 17, 34, 43))
  expect_identical(record$registration$samples$sample_id, paste0("s", 1:5))
  expect_identical(record$events$start_time, c(10, 40, 2.25))
  expect_identical(record$events$end_time, c(10, 42, 12.5))
})

test_that("literal selectors, DataFrames and supported units retain caller coordinates", {
  fixture <- registration_fixture()
  cd <- SummarizedExperiment::colData(fixture$tse)
  names(cd)[1:3] <- c("participant ID", "assigned episode", "elapsed time")
  cd[["extra"]] <- 1L
  names(cd)[4:5] <- c("unrelated", "unrelated")
  SummarizedExperiment::colData(fixture$tse) <- cd
  fixture$episodes <- S4Vectors::DataFrame(fixture$episodes)
  fixture$events <- S4Vectors::DataFrame(fixture$events)

  for (unit in c("seconds", "minutes", "hours", "days")) {
    out <- register_fixture(fixture, subject_col = "participant ID",
                            episode_col = "assigned episode", time_col = "elapsed time",
                            time_unit = unit)
    record <- registration_record(out)
    expect_identical(record$registration$source_columns,
                     c(subject = "participant ID", episode = "assigned episode",
                       time = "elapsed time"))
    expect_identical(record$registration$samples$time, c(3, 10, 17, 34, 43))
    expect_identical(record$registration$time_unit, unit)
    expect_identical(SummarizedExperiment::colData(out), cd)
  }
})

test_that("new registrations preserve historical and unsupported older analysis contents", {
  fixture <- registration_fixture()
  fixture$tse <- register_fixture(fixture)
  original <- registration_record(fixture$tse)
  fixture$tse <- fixture$tse[, c("s1", "s4", "s6")]
  md <- S4Vectors::metadata(fixture$tse)
  future <- list(schema_version = 999L, unknown_stage = list(values = 1:3))
  md$recoverome$analyses$future <- future
  S4Vectors::metadata(fixture$tse) <- md
  before <- serialize(fixture, NULL)
  out <- register_fixture(fixture, analysis_id = "antibiotic2")

  expect_identical(serialize(fixture, NULL), before)
  expect_identical(registration_record(out), original)
  expect_identical(registration_record(out, "future"), future)
  expect_identical(registration_record(out, "antibiotic2")$scope$sample_ids,
                   c("s1", "s4", "s6"))
  expect_identical(registration_record(out, "antibiotic2")$registration$samples$sample_id,
                   c("s1", "s4"))
  expect_setup_error(fixture, "analysis_id", analysis_id = "future",
                     class = "recoverome_error_collision")
})

test_that("each registration may assign a sample to its own explicit episode", {
  fixture <- registration_fixture()
  fixture$tse <- register_fixture(fixture)
  original <- registration_record(fixture$tse)
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$episode_alt <- c(rep("e2", 3L), rep("e1", 2L), NA_character_)
  SummarizedExperiment::colData(fixture$tse) <- cd
  out <- register_fixture(fixture, analysis_id = "alternate", episode_col = "episode_alt")

  expect_identical(registration_record(out), original)
  expect_identical(registration_record(out, "alternate")$registration$samples$episode_id,
                   c("e2", "e2", "e2", "e1", "e1"))
  expect_identical(SummarizedExperiment::colData(out), cd)
})

test_that("named scalar selectors do not change the stored selector names", {
  fixture <- registration_fixture()
  out <- register_fixture(
    fixture, subject_col = c(chosen = "subject_id"),
    episode_col = c(chosen = "episode_id"), time_col = c(chosen = "time")
  )
  expect_identical(registration_record(out)$registration$source_columns,
                   c(subject = "subject_id", episode = "episode_id", time = "time"))
})

test_that("unrelated names and opaque old records remain outside registration ownership", {
  fixture <- registration_fixture()
  old_namespace <- list(
    schema_version = 1L, analyses = list(older = 42L, empty = NULL),
    annotation = list(note = "keep this extension")
  )
  S4Vectors::metadata(fixture$tse) <- list(
    note = "first unrelated value", note = "second unrelated value",
    recoverome = old_namespace
  )
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$rec_antibiotic2_note <- "belongs to another prefix"
  SummarizedExperiment::colData(fixture$tse) <- cd
  out <- register_fixture(fixture)
  md <- S4Vectors::metadata(out)
  expect_identical(md[1:2], S4Vectors::metadata(fixture$tse)[1:2])
  expect_identical(md$recoverome$analyses$older, 42L)
  expect_true("empty" %in% names(md$recoverome$analyses))
  expect_null(md$recoverome$analyses$empty)
  expect_identical(md$recoverome$annotation, old_namespace$annotation)
  expect_identical(SummarizedExperiment::colData(out), cd)
})
