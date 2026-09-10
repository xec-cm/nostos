diagnostic_layer <- function(plot, fields) {
  selected <- vapply(plot$layers, function(layer) {
    is.data.frame(layer$data) && all(fields %in% names(layer$data))
  }, logical(1))
  layers <- plot$layers[selected]
  populated <- vapply(layers, function(layer) nrow(layer$data) > 0L, logical(1))
  if (any(populated)) layers <- layers[populated]

  layers[[1L]]$data
}
