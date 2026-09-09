expect_deviation_error <- function(tse, class = "recoverome_error") {
  before <- serialize(tse, NULL)
  testthat::expect_error(
    recoverome::add_deviation(tse, "antibiotic"),
    class = class
  )
  testthat::expect_identical(serialize(tse, NULL), before)
}
