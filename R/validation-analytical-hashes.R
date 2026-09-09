.recovery_stored_hashes <- function(reference, deviation, stored, registration) {
  parts <- list()
  if (!is.null(reference) && reference$readable) {
    parts$reference <- .recovery_reference_hashes(reference, stored, registration)
  }
  if (!is.null(deviation) && deviation$readable) {
    available <- !is.null(reference) && reference$readable &&
      reference$format_ready && deviation$format_ready &&
      !is.null(reference$fingerprint) && !is.null(deviation$parent_hash)
    parts$deviation <- .recovery_compare_hash(
      if (available) reference$fingerprint else NULL,
      deviation$parent_hash,
      "deviation$dependencies$reference_sha256"
    )
  }

  .recovery_merge_checks(parts)
}

.recovery_reference_hashes <- function(reference, stored, registration) {
  self <- if (reference$format_ready && reference$hash_ready) {
    .recovery_hash_reference(reference$value)
  } else {
    NULL
  }
  # Registration validity is independent of analytical stages and owned outputs.
  parent_ready <- reference$format_ready && !is.null(reference$parent_hash) &&
    isTRUE(registration$hash_ready)
  parent <- if (parent_ready) .recovery_hash_registration(stored) else NULL

  .recovery_merge_checks(list(
    .recovery_compare_hash(self, reference$fingerprint, "reference$fingerprint"),
    .recovery_compare_hash(
      parent, reference$parent_hash, "reference$dependencies$registration_sha256"
    )
  ))
}

.recovery_compare_hash <- function(actual, expected, component) {
  result <- .recovery_check_part()
  if (is.null(actual) || is.null(expected)) {
    result$complete <- FALSE
    result$dependencies <- "not_checked"
    return(result)
  }
  if (!identical(actual, expected)) {
    result$structural_valid <- FALSE
    result$dependencies <- "changed"
    result$findings <- .recovery_finding(
      "FINGERPRINT_CHANGED", component,
      "The stored fingerprint no longer agrees with {.field {component}}."
    )
  }

  result
}
