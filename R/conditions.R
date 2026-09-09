.recovery_abort <- function(message,
                            class = "recoverome_error_input",
                            component = NULL,
                            ids = character(),
                            call = parent.frame(),
                            .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = c(class, "recoverome_error"),
    component = component,
    ids = ids,
    call = call,
    .envir = .envir
  )
}
