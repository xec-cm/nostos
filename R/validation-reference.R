.recovery_parse_reference <- function(value, registration, compatible) {
  header <- .recovery_stage_header(value, "reference")
  result <- list(
    check = header, readable = header$readable, value = value,
    assay = NULL, features = NULL, baseline_ids = NULL, profile_ids = NULL,
    input_ids = NULL, inputs = NULL, parent_hash = NULL, fingerprint = NULL,
    format_ready = FALSE, hash_ready = FALSE
  )
  if (!header$readable) {
    return(result)
  }

  fields <- c("schema_version", "definition", "baseline_samples", "episodes", "profiles",
              "dependencies", "provenance", "fingerprint")
  valid <- c(fields = setequal(names(value), fields))
  definition <- value$definition
  definition_readable <- .recovery_named_list(definition)
  if (definition_readable && .recovery_valid_text(definition$assay)) {
    result$assay <- as.vector(definition$assay)
  }
  if (definition_readable && .recovery_valid_ids(definition$feature_ids, unique = TRUE) &&
        length(definition$feature_ids) > 0L) {
    result$features <- as.vector(definition$feature_ids)
  }
  selection_ready <- definition_readable &&
    .recovery_valid_ids(definition$sample_ids, unique = TRUE)
  valid[["definition"]] <- definition_readable &&
    setequal(names(definition), c("sample_ids", "assay", "feature_ids", "preprocessing",
                                  "normalization", "estimator")) &&
    selection_ready && !is.null(result$assay) && !is.null(result$features) &&
    .recovery_valid_text(definition$preprocessing) &&
    identical(definition$normalization, "closure_v1") &&
    identical(definition$estimator, "sample_mean_v1")

  baseline <- value$baseline_samples
  valid[["baseline_samples"]] <- .recovery_stage_table(baseline, c("sample_id", "episode_id")) &&
    .recovery_valid_ids(baseline$sample_id, unique = TRUE) &&
    .recovery_valid_ids(baseline$episode_id)
  if (valid[["baseline_samples"]]) {
    result$baseline_ids <- as.vector(baseline$sample_id)
  }
  if (!is.null(result$baseline_ids) && !is.null(registration$samples) &&
        .recovery_fields_ready(registration$samples, "sample_id")) {
    result$input_ids <- intersect(result$baseline_ids, registration$samples$value$sample_id)
  }
  episodes <- .recovery_reference_episodes(value$episodes)
  valid[["episodes"]] <- episodes$valid
  profile_ids_ready <- is.matrix(value$profiles) &&
    length(colnames(value$profiles)) == ncol(value$profiles) &&
    .recovery_valid_ids(as.character(colnames(value$profiles)), unique = TRUE)
  if (profile_ids_ready) {
    result$profile_ids <- as.character(colnames(value$profiles))
  }
  valid[["profiles"]] <- profile_ids_ready && is.double(value$profiles) &&
    .recovery_valid_ids(rownames(value$profiles), unique = TRUE) &&
    all(is.finite(value$profiles)) && all(value$profiles >= 0)

  dependencies <- value$dependencies
  dependencies_readable <- .recovery_named_list(dependencies)
  valid[["dependencies"]] <- dependencies_readable &&
    setequal(names(dependencies), c("registration_sha256", "samples"))
  if (dependencies_readable && .recovery_valid_sha256(dependencies$registration_sha256) &&
        length(dependencies$registration_sha256) == 1L) {
    result$parent_hash <- as.vector(dependencies$registration_sha256)
  } else {
    valid[["dependencies"]] <- FALSE
  }
  result$inputs <- .recovery_hash_rows(
    if (dependencies_readable) dependencies$samples else NULL,
    "input_sha256", "reference", "reference$dependencies$samples"
  )
  valid[["fingerprint"]] <- .recovery_valid_sha256(value$fingerprint) &&
    length(value$fingerprint) == 1L
  if (valid[["fingerprint"]]) {
    result$fingerprint <- as.vector(value$fingerprint)
  }

  structure <- .recovery_check_part()
  for (field in names(valid)[!valid]) {
    structure$findings <- c(structure$findings, .recovery_stage_problem(
      "reference", if (field == "fields") "reference" else paste0("reference$", field)
    ))
  }
  structure$structural_valid <- all(valid)
  structure$complete <- all(valid)
  if (!all(valid)) {
    structure$dependencies <- "not_checked"
  }
  provenance <- .recovery_stage_provenance(value$provenance, "reference", compatible)
  result$format_ready <- provenance$format_ready
  result$hash_ready <- all(valid) && result$inputs$complete && isTRUE(provenance$structural_valid)
  relations <- .recovery_reference_links(value, result, registration, episodes)
  result$check <- .recovery_merge_checks(list(
    header, structure, result$inputs, provenance, relations
  ))

  result
}

.recovery_reference_episodes <- function(value) {
  columns <- c("episode_id", "support", "n_samples", "n_times",
               "first_time", "last_time", "baseline_diameter")
  if (!.recovery_stage_table(value, columns)) {
    return(list(valid = FALSE, ids = NULL, support = NULL))
  }
  ids_ready <- .recovery_valid_ids(value$episode_id, unique = TRUE)
  support_ready <- .recovery_valid_ids(value$support) &&
    all(value$support %in% c("missing_baseline", "single_sample", "single_time", "multiple_times"))
  counts <- vapply(c("n_samples", "n_times"), function(field) {
    x <- value[[field]]
    is.integer(x) && !is.object(x) && is.null(dim(x)) && !anyNA(x) && all(x >= 0L)
  }, logical(1))
  times <- vapply(c("first_time", "last_time", "baseline_diameter"), function(field) {
    x <- value[[field]]
    is.double(x) && !is.object(x) && is.null(dim(x)) && all(is.na(x) | is.finite(x))
  }, logical(1))

  list(
    valid = ids_ready && support_ready && all(counts) && all(times),
    ids = if (ids_ready) as.vector(value$episode_id) else NULL,
    support = if (support_ready) as.vector(value$support) else NULL
  )
}

.recovery_reference_links <- function(value, parsed, registration, episodes) {
  result <- .recovery_check_part()
  samples <- registration$samples
  baseline_ready <- !is.null(parsed$baseline_ids)
  selection_ready <- .recovery_named_list(value$definition) &&
    .recovery_valid_ids(value$definition$sample_ids, unique = TRUE)
  if (baseline_ready && selection_ready &&
        !setequal(parsed$baseline_ids, value$definition$sample_ids)) {
    result$findings <- .recovery_stage_problem("reference", "reference$baseline_samples")
  }
  if (baseline_ready && !is.null(samples) &&
        .recovery_fields_ready(samples, c("sample_id", "episode_id"))) {
    rows <- match(parsed$baseline_ids, samples$value$sample_id)
    bad <- is.na(rows) | value$baseline_samples$episode_id != samples$value$episode_id[rows]
    if (any(bad)) {
      result$findings <- c(result$findings, .recovery_stage_problem(
        "reference", "reference$baseline_samples", parsed$baseline_ids[bad]
      ))
    }
  }
  if (baseline_ready && !is.null(parsed$inputs$ids) &&
        !identical(parsed$baseline_ids, parsed$inputs$ids)) {
    result$findings <- c(
      result$findings,
      .recovery_stage_problem("reference", "reference$dependencies$samples")
    )
  }
  if (is.matrix(value$profiles) && !is.null(parsed$features) &&
        !identical(as.character(rownames(value$profiles)), parsed$features)) {
    result$findings <- c(
      result$findings, .recovery_stage_problem("reference", "reference$profiles")
    )
  }
  if (!is.null(episodes$ids) && !is.null(episodes$support)) {
    limited <- episodes$support %in% c("missing_baseline", "single_sample", "single_time")
    if (any(limited)) {
      result$findings <- c(result$findings, .recovery_finding(
        "BASELINE_SUPPORT_LIMITED", "reference$episodes",
        "These episodes have missing, single-sample or single-time baseline support.",
        ids = episodes$ids[limited], severity = "info"
      ))
    }
  }
  errors <- vapply(result$findings, function(x) x$severity == "error", logical(1))
  result$structural_valid <- !any(errors)

  result
}
