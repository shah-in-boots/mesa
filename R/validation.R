

# Class validation -------------------------------------------------------------

#' @keywords internal
#' @noRd
validate_class <- function(x, what) {
	if (!inherits(x, what)) {
		stop(
			deparse(substitute(x)),
			" needs to inherit from `",
			paste(what),
			#paste("c(", paste(what, collapse = ", "), ")", sep = ""),
			"`, but is of class `",
			paste(class(x), collapse = ', '),
			"`.",
			call. = FALSE
		)
	}
	invisible(TRUE)
}

#' Validate arguments for term creation
#' @keywords internal
#' @noRd
validate_classes <- function(x, what) {

	varnames <- names(x)

	lapply(
		varnames,
		FUN = function(.x) {
			if (!inherits(x[[.x]], what)) {
				stop(
					"`",
					.x,
					"` needs to inherit from `",
					paste("c(", paste(what, collapse = ", "),
								")",
								sep = ""
					),
					"`.",
					call. = FALSE
				)
			}
		}
	)

	invisible(TRUE)

}


#' Check objects for their class type If its incorrect based on the validator,
#' should message about the problem object. Returns TRUE invisibly if all
#' objects are appropriate.
#' @keywords internal
#' @noRd
check_classes <- function(x, fn) {

	stopifnot("Must check classes via logical determinant function `is_***()`"
						= inherits(fn, "function"))

	functionName <- as.character(match.call()[3])

	y <-
		sapply(x, function(.x) {
			.y <- fn(.x)
			if (!.y) {
				message("Element `", deparse1(.x),
								"` returns FALSE for `", functionName, "()`")
			}
			.y
		}, USE.NAMES = FALSE)


	invisible(all(y))

}
