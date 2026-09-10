# Build a local preview or CI artifact; never deploy from this script.
build_documentation_site <- function() {
  if (dir.exists("pkgdown/favicon")) {
    stop("Remove generated pkgdown/favicon before building the PNG-only site.")
  }
  # pkgdown otherwise generates additional SVG/ICO favicons via an online service.
  previous_ci <- Sys.getenv("CI", unset = NA_character_)
  on.exit(if (is.na(previous_ci)) Sys.unsetenv("CI") else Sys.setenv(CI = previous_ci))
  Sys.setenv(CI = "true")
  pkgdown::check_pkgdown(".")
  pkgdown::build_site_github_pages(new_process = FALSE, install = TRUE)
}

build_documentation_site()
