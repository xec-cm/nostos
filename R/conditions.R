.recovery_abort <- function(message,
                            class = "recoverome_error_input",
                            component = NULL,
                            ids = character(),
                            call = rlang::caller_env()) {
  rlang::abort(
    message,
    class = c(class, "recoverome_error"),
    component = component,
    ids = ids,
    call = call
  )
}
