test_files <- list.files("tests/testthat", pattern = "^test.*\\.[rR]$")
if (!length(test_files)) {
  message("Coverage unavailable: no executable tests in the initial scaffold.")
  summary_path <- Sys.getenv("GITHUB_STEP_SUMMARY")
  if (nzchar(summary_path)) {
    cat("### Coverage\n\nUnavailable: no analytical functions or executable tests yet.\n",
      file = summary_path, append = TRUE
    )
  }
  quit(status = 0L)
}
if (!requireNamespace("covr", quietly = TRUE)) {
  stop("Install the development dependency 'covr' before calculating coverage.")
}
coverage <- covr::package_coverage(type = "tests")
print(coverage)
covr::to_cobertura(coverage, filename = "coverage.xml")
