sensitivity_rules <- function() {
  data.frame(
    scenario_id = c("primary", "short_gap", "tight_band", "short_horizon"),
    threshold = c(.25, .25, .1, .25), persistence = 4,
    max_gap = c(3, 1, 3, 3), horizon = c(10, 10, 10, 4)
  )
}
