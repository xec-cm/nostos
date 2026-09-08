if (!requireNamespace("BiocCheck", quietly = TRUE)) {
  stop("Install the development dependency 'BiocCheck' before running this report.")
}

archives <- list.files("check", pattern = "\\.tar\\.gz$", full.names = TRUE)
if (!length(archives)) {
  stop("No package archive found in check/. Run dev/check-package.R first.")
}
archive <- archives[which.max(file.info(archives)$mtime)]
report_path <- "bioccheck-report.txt"
report <- tryCatch(
  {
    result <- BiocCheck::BiocCheck(archive, `quit-with-status` = FALSE)
    counts <- result$getNum(c("error", "warning", "note"))
    c(
      paste("BiocCheck report for", basename(archive)),
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
message("BiocCheck is advisory during scaffolding; review bioccheck-report.txt.")
