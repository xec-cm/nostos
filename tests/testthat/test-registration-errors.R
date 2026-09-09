capture_registration_error <- function(fixture, analysis_id = "antibiotic") {
  tryCatch(
    setup_recovery(
      fixture$tse, analysis_id, fixture$episodes, fixture$events,
      time_unit = "days", time_origin = "days since enrolment within participant"
    ),
    recoverome_error = identity
  )
}

test_that("input errors support class-based handling and field metadata", {
  fixture <- registration_fixture()
  condition <- tryCatch(
    register_fixture(fixture, analysis_id = "Invalid"),
    recoverome_error_input = identity
  )

  expect_s3_class(condition, "recoverome_error_input")
  expect_s3_class(condition, "recoverome_error")
  expect_s3_class(condition, "rlang_error")
  expect_identical(condition$component, "analysis_id")
  expect_type(condition$ids, "character")
})

test_that("namespace and collision failures have separate catchable classes", {
  malformed <- registration_fixture()
  S4Vectors::metadata(malformed$tse)$recoverome <- list(
    schema_version = 99L, analyses = list()
  )
  occupied <- registration_fixture()
  occupied$tse <- register_fixture(occupied)
  reserved <- registration_fixture()
  cd <- SummarizedExperiment::colData(reserved$tse)
  cd$rec_antibiotic_note <- "user annotation"
  SummarizedExperiment::colData(reserved$tse) <- cd
  cases <- list(malformed, occupied, reserved)
  expected_class <- c("namespace", "collision", "collision")
  expected_component <- c("recoverome", "analysis_id", "colData")

  for (i in seq_along(cases)) {
    caught <- tryCatch(
      register_fixture(cases[[i]]),
      recoverome_error_namespace = function(condition) list("namespace", condition),
      recoverome_error_collision = function(condition) list("collision", condition)
    )
    expect_identical(caught[[1]], expected_class[[i]])
    expect_s3_class(caught[[2]], "recoverome_error")
    expect_identical(caught[[2]]$component, expected_component[[i]])
  }
})

test_that("errors at different validation depths identify the public call", {
  numeric_input <- registration_fixture()
  cd <- SummarizedExperiment::colData(numeric_input$tse)
  cd$time[1] <- Inf
  SummarizedExperiment::colData(numeric_input$tse) <- cd
  relation <- registration_fixture()
  relation$episodes$origin_event_id[1] <- "ab2"
  conditions <- list(
    capture_registration_error(registration_fixture(), analysis_id = "Invalid"),
    capture_registration_error(numeric_input),
    capture_registration_error(relation)
  )

  for (condition in conditions) {
    expect_s3_class(condition, "recoverome_error_input")
    expect_identical(conditionCall(condition)[[1]], quote(setup_recovery))
  }
  expect_identical(conditions[[2]]$component, "colData time")
  expect_identical(conditions[[2]]$ids, "s1")
  expect_identical(conditions[[3]]$component, "episodes$origin_event_id")
  expect_identical(conditions[[3]]$ids, "e1")
})

test_that("namespaced calls retain their attribution through a wrapper and include a trace", {
  fixture <- registration_fixture()
  wrapped_setup <- function(input) {
    recoverome::setup_recovery(
      input$tse, "antibiotic", input$episodes, input$events,
      time_unit = "unsupported", time_origin = "days since enrolment"
    )
  }
  condition <- tryCatch(wrapped_setup(fixture), recoverome_error = identity)

  expect_identical(conditionCall(condition)[[1]], quote(recoverome::setup_recovery))
  expect_s3_class(condition$trace, "rlang_trace")
  expect_gt(length(condition$trace$call), 0L)
  trace_calls <- vapply(condition$trace$call, function(call) {
    paste(deparse(call), collapse = " ")
  }, character(1))
  expect_true(any(grepl("setup_recovery", trace_calls, fixed = TRUE)))
})

test_that("invalid table-field types retain their component in the message", {
  fixture <- registration_fixture()
  fixture$events$start_time <- c("10", "40")
  condition <- capture_registration_error(fixture)

  expect_s3_class(condition, "recoverome_error_input")
  expect_identical(condition$component, "events$start_time")
  expect_match(conditionMessage(condition), "events$start_time", fixed = TRUE)
  expect_type(condition$ids, "character")
  expect_identical(conditionCall(condition)[[1]], quote(setup_recovery))
})

test_that("row diagnostics retain every affected ID while limiting the displayed list", {
  fixture <- registration_fixture()
  fixture$tse <- fixture$tse[, rep(c(1L, 4L), length.out = 15L)]
  sample_ids <- sprintf("sample-%02d", seq_len(15L))
  colnames(fixture$tse) <- sample_ids
  cd <- SummarizedExperiment::colData(fixture$tse)
  cd$time <- rep(Inf, 15L)
  SummarizedExperiment::colData(fixture$tse) <- cd
  condition <- capture_registration_error(fixture)
  message <- conditionMessage(condition)

  expect_s3_class(condition, "recoverome_error_input")
  expect_identical(condition$component, "colData time")
  expect_identical(condition$ids, sample_ids)
  displayed <- vapply(sample_ids, function(id) grepl(id, message, fixed = TRUE), logical(1))
  expect_true(all(displayed[1:10]))
  expect_false(any(displayed[11:15]))
})

test_that("structured failures leave data, annotations and existing records untouched", {
  invalid <- registration_fixture(trees = TRUE)
  invalid$episodes$subject_id[1] <- "another-subject"
  namespace <- registration_fixture()
  S4Vectors::metadata(namespace$tse)$recoverome <- list(
    schema_version = 99L, analyses = list(foreign = list(note = "keep this"))
  )
  collision <- registration_fixture()
  collision$tse <- register_fixture(collision)

  for (fixture in list(invalid, namespace, collision)) {
    before <- serialize(fixture, NULL)
    condition <- capture_registration_error(fixture)
    expect_s3_class(condition, "recoverome_error")
    expect_identical(serialize(fixture, NULL), before)
  }
})
