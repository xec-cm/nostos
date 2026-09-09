.recovery_parse_deviation <- function(value, analysis_id, registration, reference, compatible) {
  header <- .recovery_stage_header(value, "deviation")
  result <- list(
    check = header, readable = header$readable, value = value,
    sample_ids = NULL, input_ids = NULL, columns = NULL, inputs = NULL, outputs = NULL,
    parent_hash = NULL, format_ready = FALSE
  )
  if (!header$readable) {
    return(result)
  }

  fields <- c("schema_version", "method", "columns", "sample_ids", "dependencies",
              "results", "provenance")
  valid <- c(fields = setequal(names(value), fields))
  valid[["method"]] <- identical(value$method, "bray_relative_v1")
  expected_columns <- c(
    deviation = paste0("rec_", analysis_id, "_deviation"),
    status = paste0("rec_", analysis_id, "_deviation_status")
  )
  result$columns <- expected_columns
  valid[["columns"]] <- identical(value$columns, expected_columns)
  valid[["sample_ids"]] <- .recovery_valid_ids(value$sample_ids, unique = TRUE)
  if (valid[["sample_ids"]]) {
    result$sample_ids <- as.vector(value$sample_ids)
  }

  dependencies <- value$dependencies
  dependencies_readable <- .recovery_named_list(dependencies)
  valid[["dependencies"]] <- dependencies_readable &&
    setequal(names(dependencies), c("reference_sha256", "samples"))
  if (dependencies_readable && .recovery_valid_sha256(dependencies$reference_sha256) &&
        length(dependencies$reference_sha256) == 1L) {
    result$parent_hash <- as.vector(dependencies$reference_sha256)
  } else {
    valid[["dependencies"]] <- FALSE
  }
  result$inputs <- .recovery_hash_rows(
    if (dependencies_readable) dependencies$samples else NULL,
    "input_sha256", "deviation", "deviation$dependencies$samples"
  )
  result$outputs <- .recovery_hash_rows(
    value$results, "result_sha256", "deviation", "deviation$results"
  )

  structure <- .recovery_check_part()
  for (field in names(valid)[!valid]) {
    structure$findings <- c(structure$findings, .recovery_stage_problem(
      "deviation", if (field == "fields") "deviation" else paste0("deviation$", field)
    ))
  }
  structure$structural_valid <- all(valid)
  structure$complete <- all(valid)
  if (!all(valid)) {
    structure$dependencies <- "not_checked"
  }
  provenance <- .recovery_stage_provenance(value$provenance, "deviation", compatible)
  result$format_ready <- provenance$format_ready
  relations <- .recovery_deviation_links(result, registration, reference)
  result$input_ids <- relations$input_ids
  result$check <- .recovery_merge_checks(list(
    header, structure, result$inputs, result$outputs, provenance, relations
  ))

  result
}

.recovery_deviation_links <- function(parsed, registration, reference) {
  result <- .recovery_check_part()
  coverage <- .recovery_input_coverage(parsed, registration, reference)
  result$input_ids <- coverage$input_ids
  result$complete <- coverage$complete
  result$dependencies <- coverage$dependencies
  result$findings <- coverage$findings
  scope <- registration$scope$sample_ids
  if (!is.null(parsed$sample_ids) && !is.null(scope)) {
    outside <- setdiff(parsed$sample_ids, scope)
    if (length(outside)) {
      result$findings <- c(
        result$findings, .recovery_stage_problem("deviation", "deviation$sample_ids", outside)
      )
    }
  }
  if (!is.null(parsed$sample_ids) && !is.null(parsed$outputs$ids) &&
        !identical(parsed$sample_ids, parsed$outputs$ids)) {
    result$findings <- c(result$findings, .recovery_stage_problem("deviation", "deviation$results"))
  }
  if (!is.null(parsed$sample_ids) && !is.null(parsed$inputs$ids)) {
    outside <- setdiff(parsed$inputs$ids, parsed$sample_ids)
    if (length(outside)) {
      result$findings <- c(result$findings, .recovery_stage_problem(
        "deviation", "deviation$dependencies$samples", outside
      ))
    }
  }
  expected <- unname(parsed$columns)
  if (!is.null(registration$owned_columns) &&
        !identical(registration$owned_columns, expected)) {
    result$findings <- c(result$findings, .recovery_finding(
      "RESERVED_COLUMNS_INVALID", "owned_columns",
      "The deviation ownership manifest must declare its exact output columns.",
      ids = unique(c(registration$owned_columns, expected))
    ))
  }
  result$structural_valid <- !length(result$findings)

  result
}

.recovery_input_coverage <- function(parsed, registration, reference) {
  result <- .recovery_check_part()
  result$input_ids <- NULL
  samples <- registration$samples
  ready <- !is.null(parsed$sample_ids) && !is.null(samples) &&
    .recovery_fields_ready(samples, c("sample_id", "episode_id")) &&
    !is.null(reference) && reference$readable && !is.null(reference$profile_ids)
  if (!ready) {
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    return(result)
  }

  rows <- match(parsed$sample_ids, samples$value$sample_id)
  computed <- !is.na(rows) & samples$value$episode_id[rows] %in% reference$profile_ids
  expected <- parsed$sample_ids[computed]
  result$input_ids <- expected
  if (is.null(parsed$inputs$ids)) {
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    return(result)
  }
  if (!identical(parsed$inputs$ids, expected)) {
    affected <- union(setdiff(expected, parsed$inputs$ids), setdiff(parsed$inputs$ids, expected))
    if (!length(affected)) {
      affected <- expected
    }
    result$findings <- .recovery_stage_problem(
      "deviation", "deviation$dependencies$samples", affected
    )
    result$structural_valid <- FALSE
    result$complete <- FALSE
    result$dependencies <- "not_checked"
  }

  result
}
