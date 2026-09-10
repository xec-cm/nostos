# Assisted-by: OpenAI Codex; see inst/PROVENANCE.md.
# Run from the repository root against an already built source archive.
check_installed_candidate <- function(archive) {
  if ("nostos" %in% loadedNamespaces()) {
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
  package_path <- find.package("nostos", lib.loc = library_path)
  stopifnot(as.character(utils::packageVersion("nostos")) == expected_version)
  vignette_dir <- system.file("doc", package = "nostos", mustWork = TRUE)
  installed_sources <- list.files(vignette_dir, pattern = "\\.Rmd$", full.names = TRUE)
  expected_sources <- basename(list.files("vignettes", pattern = "\\.Rmd$"))
  stopifnot(length(installed_sources) > 0L,
            setequal(basename(installed_sources), expected_sources))
  sources <- c("README.Rmd", installed_sources)
  stopifnot(all(file.copy(sources, workspace)))
  dir.create(file.path(workspace, "man"))
  stopifnot(file.copy("man/figures", file.path(workspace, "man"), recursive = TRUE))
  for (source in basename(sources)) {
    rmarkdown::render(file.path(workspace, source), quiet = TRUE, envir = new.env())
  }

  adapters <- c("tidySingleCellExperiment", "tidySummarizedExperiment", "tidyomics")
  stopifnot(
    normalizePath(getNamespaceInfo("nostos", "path")) == normalizePath(package_path),
    !any(adapters %in% loadedNamespaces())
  )
  cat("Installed source archive:", archive, "\n")
  cat("Package version:", expected_version, "\n")
  cat("README and all installed vignettes completed without loading a tidy adapter.\n")
  print(utils::sessionInfo())
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript --vanilla dev/check-installed.R path/to/package.tar.gz")
}
check_installed_candidate(arguments[[1L]])
