# Canonicalize plain projections, never assay backing objects or S4 records.
.recovery_fingerprint <- function(value) {
  digest::digest(
    .recovery_canonical(value),
    algo = "sha256",
    serialize = TRUE,
    serializeVersion = 2,
    skip = "auto",
    ascii = FALSE
  )
}

.recovery_canonical <- function(value) {
  value_names <- names(value)
  attributes(value) <- NULL
  if (is.list(value)) {
    value <- lapply(value, .recovery_canonical)
  } else if (is.character(value)) {
    value <- enc2utf8(value)
  } else if (is.double(value)) {
    value[is.na(value)] <- NA_real_
    value[value == 0 & !is.na(value)] <- 0
  }
  if (!is.null(value_names)) {
    names(value) <- enc2utf8(value_names)
  }

  value
}

.recovery_project_table <- function(table, columns) {
  projection <- lapply(columns, function(column) as.vector(table[[column]]))

  structure(projection, names = columns)
}

.recovery_hash_source <- function(sample_id, feature_ids, values) {
  .recovery_fingerprint(list(
    sample_id = as.vector(sample_id),
    feature_ids = as.vector(feature_ids),
    values = as.double(values)
  ))
}

.recovery_hash_registration <- function(record) {
  registration <- record$registration
  source_columns <- registration$source_columns[c("subject", "episode", "time")]

  .recovery_fingerprint(list(
    registration = list(
      source_columns = source_columns,
      time_unit = as.vector(registration$time_unit),
      time_origin = as.vector(registration$time_origin),
      samples = .recovery_project_table(
        registration$samples,
        c("sample_id", "subject_id", "episode_id", "time")
      )
    ),
    episodes = .recovery_project_table(
      record$episodes,
      c("episode_id", "subject_id", "origin_event_id", "origin_boundary")
    ),
    events = .recovery_project_table(
      record$events,
      c("event_id", "episode_id", "start_time", "end_time")
    ),
    scope = list(
      sample_ids = as.vector(record$scope$sample_ids),
      feature_ids = as.vector(record$scope$feature_ids)
    )
  ))
}

.recovery_hash_reference <- function(reference) {
  definition <- reference$definition
  dependencies <- reference$dependencies
  provenance <- reference$provenance

  .recovery_fingerprint(list(
    schema_version = reference$schema_version,
    definition = list(
      sample_ids = as.vector(definition$sample_ids),
      assay = as.vector(definition$assay),
      feature_ids = as.vector(definition$feature_ids),
      preprocessing = as.vector(definition$preprocessing),
      normalization = as.vector(definition$normalization),
      estimator = as.vector(definition$estimator)
    ),
    baseline_samples = .recovery_project_table(
      reference$baseline_samples,
      c("sample_id", "episode_id")
    ),
    episodes = .recovery_project_table(
      reference$episodes,
      c("episode_id", "support", "n_samples", "n_times", "first_time",
        "last_time", "baseline_diameter")
    ),
    profiles = list(
      feature_ids = as.character(rownames(reference$profiles)),
      episode_ids = as.character(colnames(reference$profiles)),
      values = as.double(reference$profiles)
    ),
    dependencies = list(
      registration_sha256 = as.vector(dependencies$registration_sha256),
      samples = .recovery_project_table(dependencies$samples, c("sample_id", "input_sha256"))
    ),
    provenance = list(
      package_version = as.vector(provenance$package_version),
      created_at = as.vector(provenance$created_at),
      fingerprint_format = as.vector(provenance$fingerprint_format)
    )
  ))
}

.recovery_hash_result <- function(sample_id, deviation, status) {
  .recovery_fingerprint(list(
    sample_id = as.vector(sample_id),
    deviation = as.double(deviation),
    status = as.vector(status)
  ))
}

.recovery_valid_sha256 <- function(value) {
  is.character(value) && is.null(dim(value)) && !anyNA(value) &&
    all(grepl("^[0-9a-f]{64}$", value))
}

.recovery_hash_compatible <- function() {
  value <- list(
    sample_id = enc2utf8("s\u00e9"),
    feature_ids = c("f1", "f2", "f3"),
    values = c(0, 0.25, 0.75),
    missing = NA_real_,
    n = 3L
  )
  expected <- "0ebcc76956478405e0d59c09fd5ac022c6f231bd1677471c913c63132d574406"

  identical(.recovery_fingerprint(value), expected)
}
