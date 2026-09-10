.recovery_view_metadata <- function(context, analysis_id, level, scope) {
  record <- context$record
  stages <- context$stages
  stage_names <- unique(c(names(stages), context$uninterpreted))
  definitions <- provenance <- scopes <- structure(vector("list", length(stage_names)),
                                                   names = stage_names)
  for (stage in names(stages)) {
    value <- stages[[stage]]
    if (is.null(value)) next
    definitions[[stage]] <- switch(stage,
      reference = value$definition,
      deviation = list(method = value$method, columns = value$columns),
      recovery = value$definition
    )
    provenance[[stage]] <- list(
      provenance = value$provenance, fingerprint = value$fingerprint,
      dependencies = value$dependencies
    )
    if (stage == "deviation") provenance[[stage]]$results <- value$results
    scopes[[stage]] <- switch(stage,
      reference = list(sample_ids = value$baseline_samples$sample_id,
                       feature_ids = value$definition$feature_ids),
      deviation = list(sample_ids = value$sample_ids,
                       feature_ids = stages$reference$definition$feature_ids),
      recovery = value$dependencies[c("sample_ids", "feature_ids")]
    )
  }
  list(
    schema_version = 1L,
    selection = list(analysis_id = analysis_id, level = level, scope = scope),
    validation = context$report,
    registration = c(
      record$registration[c("source_columns", "time_unit", "time_origin")],
      record[c("episodes", "events")]
    ),
    scopes = c(list(registration = record$scope), scopes),
    definitions = definitions,
    provenance = c(list(registration = list(provenance = record$provenance)), provenance),
    evidence = stages$recovery$evidence,
    uninterpreted_stages = context$uninterpreted
  )
}
