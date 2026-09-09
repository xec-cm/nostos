#' Infrastructure for longitudinal microbiome recovery analysis
#'
#' This experimental package registers named analyses with [setup_recovery()],
#' validating explicit sample membership, episodes, events, and numeric time.
#' [validate_recovery()] diagnoses registered structure, consumed inputs, stored
#' reference/deviation dependencies and historical scope without modifying the
#' object. [add_reference()] attaches
#' explicit personal baseline profiles with support and input provenance.
#' [add_deviation()] records sample deviations against those fixed profiles.
#' Recovery classification, extraction, and plotting remain planned. Validation
#' never refits references or recalculates historical results.
#'
#' The intended workflow enriches a TreeSummarizedExperiment with sample-level
#' annotations and named analysis records. See the introductory vignette for
#' runnable registration, reference and deviation examples, and the project
#' website for development status.
#'
#' @keywords internal
"_PACKAGE"
