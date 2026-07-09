

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

#' Validate a scalar argument: a single number or string, with optional bounds
#'
#' Collapses the hand-rolled `!is.numeric(x) || length(x) != 1 || is.na(x)`
#' validation blocks repeated across the table verbs (M6.13 ride-along) into
#' one call. `min`/`max` bound a numeric scalar (inclusive by default);
#' `type = "string"` validates a single non-`NA` character instead (`nzchar =
#' TRUE` additionally requires it non-empty). `allow_null = TRUE` treats a
#' `NULL` argument as valid — the "unset, falls back to a default" contract
#' most of these table-verb arguments carry.
#' @keywords internal
#' @noRd
validate_scalar <- function(x, name, type = "numeric", min = NULL, max = NULL,
														 inclusive = TRUE, allow_null = FALSE,
														 nzchar = FALSE) {

	if (allow_null && is.null(x)) {
		return(invisible(TRUE))
	}

	ok <- switch(
		type,
		numeric = is.numeric(x) && length(x) == 1 && !is.na(x),
		string = is.character(x) && length(x) == 1 && !is.na(x) &&
			(!nzchar || base::nzchar(x))
	)
	if (isTRUE(ok) && type == "numeric") {
		if (!is.null(min)) ok <- ok && (if (inclusive) x >= min else x > min)
		if (!is.null(max)) ok <- ok && (if (inclusive) x <= max else x < max)
	}
	if (!isTRUE(ok)) {
		bound <- if (type == "numeric" && (!is.null(min) || !is.null(max))) {
			if (!is.null(min) && !is.null(max)) {
				paste0(if (inclusive) " between " else " strictly between ",
							 min, " and ", max)
			} else if (!is.null(min)) {
				paste0(if (inclusive) " \u2265 " else " > ", min)
			} else {
				paste0(if (inclusive) " \u2264 " else " < ", max)
			}
		}
		stop(
			"`", name, "` must be a single ",
			if (type == "numeric") "number" else "string",
			bound, ".",
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
