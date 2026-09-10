# Run explicitly from the repository root; never silently skip the assessment.
needed <- c("pkgload", "testthat", "tidySingleCellExperiment", "dplyr")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("The optional assessment requires: ", paste(missing, collapse = ", "))
}

packages <- c(
  "nostos", "TreeSummarizedExperiment", "SingleCellExperiment",
  "SummarizedExperiment", "S4Vectors", "tidySingleCellExperiment", "dplyr"
)
pkgload::load_all(".", quiet = TRUE, export_all = FALSE, helpers = FALSE)
cat(R.version.string, "\n")
for (package in packages) {
  cat(package, as.character(utils::packageVersion(package)), "\n")
}
testthat::test_file("dev/tests/test-tidy.R", stop_on_failure = TRUE)
