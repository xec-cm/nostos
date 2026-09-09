#' Infrastructure for longitudinal microbiome recovery analysis
#'
#' This experimental package registers named analyses with [setup_recovery()],
#' validating explicit sample membership, episodes, events, and numeric time.
#' [validate_recovery()] diagnoses registered structure, consumed metadata, and
#' historical scope without modifying the object. [add_reference()] attaches
#' explicit personal baseline profiles with support and input provenance.
#' Deviation measurement, recovery classification, extraction, and plotting
#' remain planned; the validator still checks registration only.
#'
#' The intended workflow enriches a TreeSummarizedExperiment with sample-level
#' annotations and named analysis records. See the introductory vignette for
#' a runnable registration example and the project website for development status.
#'
#' @keywords internal
"_PACKAGE"
