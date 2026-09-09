.recovery_finding <- function(code,
                              component,
                              message,
                              ids = character(),
                              severity = "error",
                              .envir = parent.frame()) {
  list(list(
    analysis_id = NA_character_,
    code = code,
    severity = severity,
    component = component,
    message = cli::ansi_strip(cli::format_inline(message, .envir = .envir)),
    ids = as.character(ids)
  ))
}

.recovery_validation_report <- function(summaries = list(), findings = list()) {
  summary <- S4Vectors::DataFrame(
    analysis_id = vapply(summaries, `[[`, character(1), "analysis_id"),
    structural_valid = vapply(summaries, `[[`, logical(1), "structural_valid"),
    validation_complete = vapply(summaries, `[[`, logical(1), "validation_complete"),
    dependencies = vapply(summaries, `[[`, character(1), "dependencies"),
    sample_scope = vapply(summaries, `[[`, character(1), "sample_scope"),
    feature_scope = vapply(summaries, `[[`, character(1), "feature_scope"),
    n_registered = vapply(summaries, `[[`, integer(1), "n_registered"),
    n_retained = vapply(summaries, `[[`, integer(1), "n_retained")
  )
  diagnostics <- S4Vectors::DataFrame(
    analysis_id = vapply(findings, `[[`, character(1), "analysis_id"),
    code = vapply(findings, `[[`, character(1), "code"),
    severity = vapply(findings, `[[`, character(1), "severity"),
    component = vapply(findings, `[[`, character(1), "component"),
    message = vapply(findings, `[[`, character(1), "message"),
    ids = I(lapply(findings, `[[`, "ids"))
  )

  list(
    report_schema_version = 1L,
    summary = summary,
    diagnostics = diagnostics
  )
}

.recovery_validation_summary <- function(analysis_id) {
  list(
    analysis_id = analysis_id,
    structural_valid = TRUE,
    validation_complete = TRUE,
    dependencies = "not_checked",
    sample_scope = "not_checked",
    feature_scope = "not_checked",
    n_registered = NA_integer_,
    n_retained = NA_integer_
  )
}

.recovery_valid_text <- function(value) {
  is.character(value) && is.null(dim(value)) && length(value) == 1L &&
    !is.na(value) && nzchar(trimws(value, whitespace = "[\\h\\v]"))
}

.recovery_valid_ids <- function(value, unique = FALSE) {
  if (!is.character(value) || !is.null(dim(value)) || anyNA(value)) {
    return(FALSE)
  }

  all(nzchar(value)) &&
    all(trimws(value, whitespace = "[\\h\\v]") == value) &&
    (!unique || !anyDuplicated(value))
}

.recovery_validation_namespace <- function(root) {
  findings <- list()
  present <- which(names(root) == "recoverome")
  if (!length(present)) {
    return(list(analyses = list(), findings = findings, readable = TRUE))
  }
  if (length(present) != 1L) {
    findings <- .recovery_finding(
      "NAMESPACE_INVALID",
      "recoverome",
      "Root metadata contains more than one {.field recoverome} entry."
    )
    return(list(analyses = NULL, findings = findings, readable = FALSE))
  }

  namespace <- root[[present]]
  required <- "schema_version"
  if (!.recovery_named_list(namespace) || !all(required %in% names(namespace))) {
    findings <- .recovery_finding(
      "NAMESPACE_INVALID",
      "recoverome",
      "The namespace must be a uniquely named list with a schema_version."
    )
    return(list(analyses = NULL, findings = findings, readable = FALSE))
  }
  if (!identical(namespace$schema_version, 1L)) {
    findings <- .recovery_finding(
      "SCHEMA_UNSUPPORTED",
      "recoverome$schema_version",
      "The root namespace schema is unsupported; its analyses were not interpreted."
    )
    return(list(analyses = NULL, findings = findings, readable = FALSE))
  }

  analyses <- namespace[["analyses"]]
  if (!"analyses" %in% names(namespace) || !is.list(analyses) || is.object(analyses)) {
    findings <- .recovery_finding(
      "NAMESPACE_INVALID",
      "recoverome$analyses",
      "Analyses must be a named list."
    )
  } else if (!.recovery_named_list(analyses) ||
               any(!grepl("^[a-z][a-z0-9]*$", names(analyses)))) {
    findings <- .recovery_finding(
      "ANALYSIS_IDS_INVALID",
      "recoverome$analyses",
      "Analysis names must be unique and match ^[a-z][a-z0-9]*$.",
      ids = names(analyses)
    )
  }

  list(analyses = analyses, findings = findings, readable = !length(findings))
}

.recovery_validation_axis <- function(ids, size, axis) {
  if (!size && is.null(ids)) {
    ids <- character()
  }
  valid <- .recovery_valid_ids(ids, unique = TRUE) && length(ids) == size
  findings <- if (valid) {
    list()
  } else {
    .recovery_finding(
      if (axis == "sample") "SAMPLE_IDS_INVALID" else "FEATURE_IDS_INVALID",
      paste0(axis, "_ids"),
      "Current {.val {axis}} IDs must be explicit, unique, non-empty and unpadded.",
      ids = if (is.character(ids)) ids else character()
    )
  }

  list(ids = ids, valid = valid, findings = findings)
}
