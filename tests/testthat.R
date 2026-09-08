library(testthat)
library(recoverome)

test_files <- list.files("testthat", pattern = "^test.*\\.[rR]$")
if (length(test_files)) {
  test_check("recoverome")
} else {
  message("No executable tests yet: recoverome currently contains scaffolding only.")
}
