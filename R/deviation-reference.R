.recovery_deviation_reference <- function(record, call) {
  reference <- record[["reference"]]
  if (!.recovery_named_list(reference) || !"schema_version" %in% names(reference)) {
    .recovery_abort(
      "The analysis must contain a reference record with a schema_version.",
      class = "recoverome_error_namespace",
      component = "reference",
      call = call
    )
  }
  if (!identical(reference$schema_version, 1L)) {
    .recovery_abort(
      "The reference schema is unsupported; its contents were not interpreted.",
      class = "recoverome_error_namespace",
      component = "reference$schema_version",
      call = call
    )
  }
  fields <- c(
    "schema_version", "definition", "baseline_samples", "episodes", "profiles",
    "dependencies", "provenance", "fingerprint"
  )
  if (!setequal(names(reference), fields)) {
    .recovery_abort(
      "The reference record has missing or unsupported fields.",
      class = "recoverome_error_namespace",
      component = "reference",
      call = call
    )
  }

  definition <- reference$definition
  fields <- c("sample_ids", "assay", "feature_ids", "preprocessing", "normalization", "estimator")
  valid_definition <- .recovery_named_list(definition) && setequal(names(definition), fields) &&
    .recovery_valid_ids(definition$sample_ids, unique = TRUE) &&
    .recovery_valid_ids(definition$feature_ids, unique = TRUE) &&
    length(definition$feature_ids) > 0L &&
    .recovery_valid_text(definition$assay) && .recovery_valid_text(definition$preprocessing) &&
    identical(definition$normalization, "closure_v1") &&
    identical(definition$estimator, "sample_mean_v1")
  if (!valid_definition) {
    .recovery_abort(
      "Reference definitions require explicit IDs, assay, preprocessing and supported methods.",
      class = "recoverome_error_namespace",
      component = "reference$definition",
      call = call
    )
  }

  .recovery_reference_provenance(reference$provenance, call)
  .recovery_reference_evidence(reference, record, call)
  if (!.recovery_valid_sha256(reference$fingerprint) || length(reference$fingerprint) != 1L ||
        !identical(.recovery_hash_reference(reference), as.vector(reference$fingerprint))) {
    .recovery_abort(
      "The stored reference fingerprint does not match its record.",
      class = "recoverome_error_namespace",
      component = "reference$fingerprint",
      call = call
    )
  }
  if (!identical(.recovery_hash_registration(record),
                 as.vector(reference$dependencies$registration_sha256))) {
    .recovery_abort(
      "The registration differs from the reference's recorded parent dependency.",
      class = "recoverome_error_namespace",
      component = "reference$dependencies$registration_sha256",
      call = call
    )
  }

  reference
}

.recovery_reference_provenance <- function(provenance, call) {
  fields <- c("package_version", "created_at", "fingerprint_format")
  valid <- .recovery_named_list(provenance) && setequal(names(provenance), fields) &&
    .recovery_valid_text(provenance$package_version) &&
    .recovery_valid_text(provenance$created_at) &&
    .recovery_valid_text(provenance$fingerprint_format)
  if (!valid) {
    .recovery_abort(
      "Reference provenance requires a package version, UTC time and fingerprint format.",
      class = "recoverome_error_namespace",
      component = "reference$provenance",
      call = call
    )
  }
  if (!identical(provenance$fingerprint_format, "recoverome_inputs_v1") ||
        !.recovery_hash_compatible()) {
    .recovery_abort(
      "The reference fingerprint format cannot be verified in this environment.",
      class = "recoverome_error_namespace",
      component = "reference$provenance$fingerprint_format",
      call = call
    )
  }

  stamp <- provenance$created_at
  timestamp_format <- "%Y-%m-%dT%H:%M:%SZ"
  parsed <- strptime(stamp, format = timestamp_format, tz = "UTC")
  if (is.na(parsed) || format(parsed, format = timestamp_format, tz = "UTC") != stamp) {
    .recovery_abort(
      "Reference provenance must contain a valid ISO-8601 UTC creation timestamp.",
      class = "recoverome_error_namespace",
      component = "reference$provenance$created_at",
      call = call
    )
  }
}

.recovery_reference_table <- function(value, columns, component, call) {
  valid <- methods::is(value, "DataFrame") &&
    identical(methods::validObject(value, test = TRUE), TRUE) &&
    !is.null(names(value)) && !anyNA(names(value)) &&
    all(nzchar(names(value))) && !anyDuplicated(names(value)) &&
    all(columns %in% names(value))
  if (!valid) {
    .recovery_abort(
      "Stored {.field {component}} must be a valid DataFrame with its required unique columns.",
      class = "recoverome_error_namespace",
      component = component,
      call = call
    )
  }
}
