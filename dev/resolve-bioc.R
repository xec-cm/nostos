needed <- c("yaml", "jsonlite")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Install configuration dependencies: ", paste(missing, collapse = ", "))
}
config_file <- tempfile(fileext = ".yaml")
utils::download.file("https://bioconductor.org/config.yaml", config_file, quiet = TRUE)
config <- yaml::read_yaml(config_file)
unlink(config_file)

major_minor <- function(value) {
  value <- as.character(value)
  if (length(value) != 1L || !grepl("^[0-9]+\\.[0-9]+", value)) {
    stop("Invalid R version in Bioconductor configuration.")
  }
  sub("^([0-9]+\\.[0-9]+).*$", "\\1", value)
}
release_r <- major_minor(config$r_version_associated_with_release)
devel_r <- major_minor(config$r_version_associated_with_devel)
if (devel_r != release_r) {
  devel_r <- "devel"
}
release_bioc <- as.character(config$release_version)
devel_bioc <- as.character(config$devel_version)
valid_versions <- length(release_bioc) == 1L && length(devel_bioc) == 1L &&
  grepl("^[0-9]+\\.[0-9]+$", release_bioc) &&
  grepl("^[0-9]+\\.[0-9]+$", devel_bioc)
if (!valid_versions) {
  stop("Invalid Bioconductor release or development version.")
}
entries <- lapply(c("ubuntu-latest", "macos-latest", "windows-latest"), function(os) {
  list(os = os, r = release_r, bioc = release_bioc, channel = "release")
})
entries[[4L]] <- list(
  os = "ubuntu-latest", r = devel_r, bioc = devel_bioc, channel = "devel"
)
cat("matrix=", jsonlite::toJSON(list(include = entries), auto_unbox = TRUE), "\n", sep = "")
