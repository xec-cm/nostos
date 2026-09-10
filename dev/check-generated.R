needed <- c("roxygen2", "rmarkdown", "pkgdown")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Install development dependencies: ", paste(missing, collapse = ", "))
}
if (!rmarkdown::pandoc_available()) {
  stop("Pandoc is required. Add it to PATH or set RSTUDIO_PANDOC to its directory.")
}

tracked_outputs <- function() {
  c("DESCRIPTION", "NAMESPACE", "README.md",
    list.files("man", pattern = "\\.Rd$", full.names = TRUE))
}
before_files <- tracked_outputs()
before <- tools::md5sum(before_files)
roxygen2::roxygenise()
rmarkdown::render("README.Rmd", quiet = TRUE, envir = new.env())
after_files <- tracked_outputs()
after <- tools::md5sum(after_files)
if (!identical(before, after)) {
  stop("Generated files changed. Regenerate and commit DESCRIPTION, README.md, NAMESPACE and man/.")
}
pkgdown::check_pkgdown(".")
message("Generated documentation is current; pkgdown configuration is valid.")
