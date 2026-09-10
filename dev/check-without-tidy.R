# A separate R session sees a temporary library with the adapters omitted.
# Symlinks leave installed packages untouched; no installation or download occurs.
excluded <- c("tidySingleCellExperiment", "tidySummarizedExperiment", "tidyomics")
child <- "--isolated-child" %in% commandArgs(trailingOnly = TRUE)

if (child) {
  stopifnot(!any(vapply(excluded, requireNamespace, logical(1), quietly = TRUE)))
  cat("Optional adapters are unavailable in the isolated library.\n")
  testthat::test_local(".", stop_on_failure = TRUE)
  stopifnot(!any(excluded %in% loadedNamespaces()))
  source("dev/check-package.R")
  stopifnot(!any(vapply(excluded, requireNamespace, logical(1), quietly = TRUE)))
  cat("Core tests and package check completed with optional adapters unavailable.\n")
} else {
  # R always includes its base library, so verify it cannot restore an adapter.
  stopifnot(!any(dir.exists(file.path(.Library, excluded))))
  isolated_library <- tempfile("recoverome-without-tidy-")
  dir.create(isolated_library)
  package_paths <- unlist(lapply(.libPaths(), list.dirs, recursive = FALSE))
  package_names <- basename(package_paths)
  keep <- !duplicated(package_names) & !package_names %in% excluded
  linked <- file.symlink(
    package_paths[keep], file.path(isolated_library, package_names[keep])
  )
  stopifnot(all(linked))
  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "dev/check-without-tidy.R", "--isolated-child"),
    env = c("R_LIBS=", "R_LIBS_SITE=", paste0("R_LIBS_USER=", shQuote(isolated_library)))
  )
  unlink(isolated_library, recursive = TRUE)
  if (status != 0L) {
    stop("Core checks without tidy adapters failed; child exit status: ", status)
  }
}
