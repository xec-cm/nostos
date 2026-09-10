# Assisted-by: OpenAI Codex; see inst/PROVENANCE.md.
# Run from the repository root against an already built source archive.
check_installed_candidate <- function(archive) {
  if ("recoverome" %in% loadedNamespaces()) {
    stop("Run this check in a fresh Rscript --vanilla session.")
  }
  archive <- normalizePath(archive, mustWork = TRUE)
  expected_version <- read.dcf("DESCRIPTION")[1L, "Version"]
  workspace <- tempfile("recoverome-installed-")
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  library_path <- file.path(workspace, "library")
  dir.create(library_path)
  original_libraries <- .libPaths()
  on.exit(.libPaths(original_libraries), add = TRUE)
  .libPaths(c(library_path, original_libraries))

  utils::install.packages(archive, repos = NULL, type = "source", lib = library_path)
  package_path <- find.package("recoverome", lib.loc = library_path)
  stopifnot(as.character(utils::packageVersion("recoverome")) == expected_version)
  sources <- c(
    "README.Rmd",
    system.file("doc", "recoverome.Rmd", package = "recoverome", mustWork = TRUE)
  )
  stopifnot(all(file.copy(sources, workspace)))
  for (source in basename(sources)) {
    rmarkdown::render(file.path(workspace, source), quiet = TRUE, envir = new.env())
  }

  adapters <- c("tidySingleCellExperiment", "tidySummarizedExperiment", "tidyomics")
  stopifnot(
    normalizePath(getNamespaceInfo("recoverome", "path")) == normalizePath(package_path),
    !any(adapters %in% loadedNamespaces())
  )
  cat("Installed source archive:", archive, "\n")
  cat("Package version:", expected_version, "\n")
  cat("README and installed vignette completed without loading a tidy adapter.\n")
  print(utils::sessionInfo())
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript --vanilla dev/check-installed.R path/to/package.tar.gz")
}
check_installed_candidate(arguments[[1L]])
