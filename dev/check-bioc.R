if (!requireNamespace("BiocCheck", quietly = TRUE)) {
  stop("Install the development dependency 'BiocCheck' before running this report.")
}

description <- read.dcf("DESCRIPTION")
version <- description[1L, "Version"]
archive <- file.path("check", paste0(description[1L, "Package"], "_", version, ".tar.gz"))
if (!file.exists(archive)) {
  stop("Build the current version with dev/check-package.R before running this report.")
}
new_package <- grepl("^0[.]99[.]", version)
report_path <- "bioccheck-report.txt"
report <- tryCatch(
  {
    result <- BiocCheck::BiocCheck(
      archive,
      `new-package` = new_package,
      `quit-with-status` = FALSE
    )
    counts <- result$getNum(c("error", "warning", "note"))
    c(
      paste("BiocCheck report for", basename(archive)),
      paste("New-package checks:", new_package),
      sprintf(
        "ERRORS: %d | WARNINGS: %d | NOTES: %d",
        counts[["error"]], counts[["warning"]], counts[["note"]]
      ),
      "",
      result$composeReport(debug = FALSE)
    )
  },
  error = function(error) {
    writeLines(
      c("BiocCheck could not complete.", conditionMessage(error)),
      report_path
    )
    stop("BiocCheck infrastructure failed; see bioccheck-report.txt.", call. = FALSE)
  }
)
writeLines(report, report_path)
message("BiocCheck findings require review before submission; see bioccheck-report.txt.")
