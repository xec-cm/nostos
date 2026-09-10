# RFC 004 proposal: explicitly constructed views and scientific schematics.
# This script implements neither recovery_results() nor plot_recovery().
# Run from the repository root with Rscript --vanilla.

# Atomic columns preserve IDs and diagnostic flags during ordinary conversion.
# Values are hand-declared from the RFC 003 examples, not package calculations.
sample_view <- S4Vectors::DataFrame(
  analysis_id = rep("example", 8L),
  view_scope = rep("historical", 8L),
  current_present = c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE),
  result_state = c(rep("available", 3L), "removed", rep("available", 3L), "not_computed"),
  structural_valid = rep(TRUE, 8L),
  validation_complete = rep(FALSE, 8L),
  dependencies = rep("not_checked", 8L),
  sample_id = c("b1", "o0", "o2", "o4", "o6", "o12", "excluded", "never_computed"),
  subject_id = c(rep("p1", 6L), NA_character_, "p1"),
  episode_id = c(rep("e1", 6L), NA_character_, "e1"),
  time = c(-3, 0, 2, 4, 6, 12, NA_real_, -1),
  relative_time = c(-3, 0, 2, 4, 6, 12, NA_real_, -1),
  included = c(rep(TRUE, 6L), FALSE, TRUE),
  is_reference = c(TRUE, rep(FALSE, 7L)),
  deviation = c(0, 0.75, 0.25, NA_real_, 0.125, 0.875, NA_real_, NA_real_),
  deviation_status = c(rep("computed", 3L), NA_character_, rep("computed", 2L),
                       "excluded", NA_character_)
)
S4Vectors::metadata(sample_view)$recoverome_view <- list(
  schema_version = 1L,
  selection = list(analysis_id = "example", level = "sample", scope = "historical"),
  evidence = list(e1 = list(confirmation_run = c("o2", "o4", "o6")))
)
# Context is deliberately abbreviated in this example, not a full validator report.
plain_view <- as.data.frame(sample_view)
stopifnot(
  identical(plain_view$sample_id, c("b1", "o0", "o2", "o4", "o6", "o12",
                                    "excluded", "never_computed")),
  identical(plain_view$result_state[c(4L, 7L, 8L)],
            c("removed", "available", "not_computed")),
  identical(plain_view$deviation_status[7L], "excluded"),
  is.na(plain_view$subject_id[7L]),
  all(is.na(plain_view$deviation[c(4L, 7L, 8L)])),
  identical(plain_view$validation_complete, rep(FALSE, 8L))
)
empty_view <- sample_view[FALSE, , drop = FALSE]
stopifnot(nrow(empty_view) == 0L, identical(names(empty_view), names(sample_view)))
if (requireNamespace("tibble", quietly = TRUE)) {
  tidy_view <- tibble::as_tibble(plain_view)
  stopifnot(identical(as.list(tidy_view), as.list(plain_view)))
}

# Independent evidence check: losing o4 leaves the q=6 value present, but the
# original confirmation run is only partially available. Do not reclassify it.
original_run <- c("o2", "o4", "o6")
retained <- c("b1", "o0", "o2", "o6", "o12", "excluded")
stopifnot("o6" %in% retained, !all(original_run %in% retained))
original_visit_times <- c(0, 2, 4, 6)
stopifnot(identical(diff(original_visit_times), c(2, 2, 2)))
# In the separate gap example, the actual registered gap is five days.
stopifnot(identical(diff(c(0, 2, 7, 9)), c(2, 5, 2)))

# Saved observations and outcomes below are explicit illustrative records.
# No helper estimates references, discovers runs or classifies recovery.
observations <- data.frame(
  time = c(-3, 0, 2, 4, 6, 12),
  deviation = c(0, 0.75, 0.25, 0.125, 0.125, 0.875)
)
panels <- list(
  list(
    title = "A  Complete observed evidence", scope = "current",
    note = "confirmed_return | coverage reaches horizon",
    checks = "Dependencies unchanged; checks complete", warning = FALSE,
    observations = observations, keep = rep(TRUE, 6L), recovery = TRUE,
    candidate = 2, confirmation = 6, partial = FALSE, gap = numeric(), last = 12
  ),
  list(
    title = "B  Recovery stage not computed", scope = "current",
    note = "Deviation values available | no recovery outcome",
    checks = "No threshold or horizon has been selected", warning = FALSE,
    observations = observations, keep = rep(TRUE, 6L), recovery = FALSE,
    candidate = NA_real_, confirmation = NA_real_, partial = FALSE,
    gap = numeric(), last = NA_real_
  ),
  list(
    title = "C  Intermediate support removed", scope = "historical",
    note = "Saved confirmed_return | coverage still reaches horizon",
    checks = "Historical inputs missing; checks incomplete", warning = TRUE,
    observations = observations, keep = c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE),
    recovery = TRUE, candidate = 2, confirmation = 6, partial = TRUE,
    gap = numeric(), last = 12
  ),
  list(
    title = "D  Current source time changed", scope = "current",
    note = "Saved confirmed_return | original time 6 is displayed",
    checks = "Saved results; sources changed (current time 6 -> 20)", warning = TRUE,
    observations = observations, keep = rep(TRUE, 6L), recovery = TRUE,
    candidate = 2, confirmation = 6, partial = FALSE, gap = numeric(), last = 12
  ),
  list(
    title = "E  Original gap and incomplete follow-up", scope = "current",
    note = "unconfirmed_return | coverage ends before horizon",
    checks = "Gap and unobserved region do not prove non-recovery", warning = FALSE,
    observations = data.frame(time = c(-3, 0, 2, 7, 9),
                              deviation = c(0, 0.75, 0.125, 0.125, 0.125)),
    keep = rep(TRUE, 5L), recovery = TRUE, candidate = 2,
    confirmation = NA_real_, partial = FALSE, gap = c(2, 7), last = 9
  ),
  list(
    title = "F  All samples removed", scope = "historical",
    note = "Saved confirmed_return | no remaining deviation values",
    checks = "Historical inputs missing; checks incomplete", warning = TRUE,
    observations = observations, keep = rep(FALSE, 6L), recovery = TRUE,
    candidate = 2, confirmation = 6, partial = TRUE, gap = numeric(), last = 12
  )
)

# Drawing is intentionally separate from the proposed plotting implementation.
draw_panel <- function(panel) {
  point_colour <- "#255B70"
  rail_colour <- "#673C73"
  graphics::plot(
    NA, xlim = c(-4, 13), ylim = c(-0.42, 1.08), axes = FALSE,
    xlab = "", ylab = "Bray-Curtis deviation"
  )
  if (panel$recovery) {
    graphics::rect(0, 0, 10, 0.25, col = "#E5F2E9", border = NA)
    graphics::segments(0, 0.25, 10, 0.25, col = "#4D8660", lty = 2)
    graphics::segments(10, 0, 10, 1, col = "#777777", lty = 3)
    graphics::text(7.6, 0.055, "Declared band", col = "#3C6C4B", cex = 0.68)
    graphics::text(10, 1.035, "H", col = "#666666", cex = 0.8)
  }
  if (panel$recovery && panel$last < 10) {
    graphics::rect(panel$last, 0, 10, 1, density = 13, angle = 45,
                   col = "#CD9F4B", border = NA)
    graphics::text(9.5, 0.78, "Beyond
follow-up", srt = 90, cex = 0.63)
  }
  graphics::segments(0, 0, 0, 1, col = "#BBBBBB", lty = 3)
  graphics::axis(1, at = c(-3, 0, 2, 4, 6, 8, 10, 12), pos = 0, cex.axis = 0.75)
  graphics::axis(2, at = c(0, 0.25, 0.5, 0.75, 1), las = 1, cex.axis = 0.75)
  graphics::box(bty = "l")
  graphics::mtext("Registered relative time (days)", side = 1, line = 1.3, cex = 0.73)

  shown <- panel$observations[panel$keep, , drop = FALSE]
  colours <- rep(point_colour, nrow(shown))
  if (panel$recovery) {
    colours[shown$time > 10] <- "#8B8B8B"
  }
  graphics::points(shown$time, shown$deviation,
                   pch = ifelse(shown$time < 0, 17, 19), col = colours, cex = 1.2)
  removed <- panel$observations$time[!panel$keep]
  graphics::points(removed, rep(-0.33, length(removed)), pch = 1,
                   col = "#8B8B8B", cex = 0.8)
  if (length(removed)) {
    graphics::text(12.9, -0.405, "removed", adj = 1, cex = 0.64, col = "#777777")
  }

  if (!is.na(panel$confirmation)) {
    graphics::segments(panel$candidate, -0.18, panel$confirmation, -0.18,
                       col = rail_colour, lty = if (panel$partial) 2 else 1, lwd = 1.4)
    graphics::points(panel$confirmation, -0.18, pch = if (panel$partial) 5 else 18,
                     col = rail_colour, cex = 1.25)
    graphics::text(panel$confirmation, -0.265, "Q", col = rail_colour, cex = 0.8)
  }
  if (!is.na(panel$candidate)) {
    candidate_present <- panel$candidate %in% shown$time
    graphics::points(panel$candidate, -0.18, pch = if (candidate_present) 16 else 1,
                     col = rail_colour, cex = 1)
    graphics::text(panel$candidate, -0.265, "F/C", col = rail_colour, cex = 0.72)
  }
  if (length(panel$gap)) {
    graphics::segments(panel$gap[1L], 0.46, panel$gap[2L], 0.46,
                       col = "#A87524", lty = 3, lwd = 1.5)
    graphics::text(mean(panel$gap), 0.54, "Original visit gap: 5 > G", cex = 0.7,
                   col = "#91651D")
  }
  graphics::title(main = panel$title, adj = 0, cex.main = 0.96, line = 3.8)
  graphics::mtext(panel$note, side = 3, adj = 0, line = 2.3, cex = 0.69)
  graphics::mtext(panel$checks, side = 3, adj = 0, line = 1.15, cex = 0.67,
                  col = if (panel$warning) "#A13B33" else "#555555")
  graphics::mtext(paste0("Scope: ", panel$scope, " | p1 / e1 | single_sample, n = 1"),
                  side = 3, adj = 0, line = 0.1, cex = 0.64, col = "#666666")
}

render_sketch <- function() {
  graphics::par(mfrow = c(3, 2), mar = c(3.2, 4.4, 5.8, 1.0),
                oma = c(4.3, 0, 3.5, 0), family = "sans")
  for (panel in panels) {
    draw_panel(panel)
  }
  graphics::mtext("RFC 004 | Schematic proposal, not implemented API output",
                  outer = TRUE, side = 3, line = 1.5, cex = 1.25, font = 2)
  graphics::mtext("Observed points only. Triangle = baseline; grey = beyond H when defined.",
                  outer = TRUE, side = 1, line = 0.7, cex = 0.82)
  graphics::mtext(
    "Rail: F/C = first return/candidate, Q = confirmation; bracket = observed support span.",
    outer = TRUE, side = 1, line = 1.8, cex = 0.82
  )
  graphics::mtext(
    paste("Hollow Q + dashed bracket = any confirmation-run sample missing.",
          "Example rule: delta .25, P 4, G 3, H 10."),
    outer = TRUE, side = 1, line = 2.9, cex = 0.8
  )
}

grDevices::png("dev/examples/004-result-views.png", width = 2000, height = 2100, res = 170)
render_sketch()
grDevices::dev.off()
cat("Atomic view conversions and explicit evidence checks passed; schematic PNG written.\n")
