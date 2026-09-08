if (!requireNamespace("rcmdcheck", quietly = TRUE)) {
  stop("Install the development dependency 'rcmdcheck' before checking the package.")
}

options(crayon.enabled = FALSE)
rcmdcheck::rcmdcheck(
  args = c("--no-manual", "--timings"),
  build_args = "--no-manual",
  error_on = "warning",
  check_dir = "check"
)
