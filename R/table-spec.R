# The <mesa> specification (M6.3) ---------------------------------------------
#
# The table grammar is composition-first: `mesa()` lifts a fitted `mdl_tbl`
# onto a declarative specification, small pipeable verbs refine it, and
# `as_gt()` (in table-render.R) realizes it. The spec carries *instructions*,
# not results — selection, labels, column blocks, layout, and style — so verbs
# compose in any order and resolution is deferred to realization. This is the
# same lazy contract a `{ggplot2}` plot is grown under (with the pipe, not `+`).
#
# This file owns the constructor, the selection verbs, `modify_labels()`, the
# validation, and the print method. The `add_*` column verbs (M6.4/6.5), the
# `modify_layout()`/`modify_style()` verbs (M6.6), and the renderer live
# elsewhere as they land.

#' The `<mesa>` table specification
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `mesa()` lays a collection of fitted models out on the *mesa* — the table
#' upon which the models are displayed — as a declarative specification. It is
#' deliberately bare: it takes no selection arguments and puts everything
#' fitted on the mesa with default labels drawn from the term table and the
#' attached data. The table is then grown one decision at a time with pipeable
#' verbs, exactly the way a `{ggplot2}` plot is grown:
#'
#' - `select_outcomes()`, `select_exposures()`, `select_terms()`,
#'   `select_adjustment()`, `select_strata()` narrow what is shown;
#' - `modify_labels()` relabels terms and levels late, without reselecting;
#' - `as_gt()` renders the specification to a `{gt}` table (see [as_gt()]).
#'
#' Because the specification is declarative — the verbs record instructions and
#' resolution happens only at [as_gt()]/`print()` — the verbs may arrive in any
#' order, and a repeated verb replaces its earlier instruction with a message
#' (the `{ggplot2}` scale-replacement behavior). A bare
#' `mesa(mt) |> as_gt()` already renders a minimal estimate-and-interval table,
#' so the grammar is usable from the first verb.
#'
#' @details
#'
#' `mesa()` validates before it builds. The object must be a `mdl_tbl`; only
#' its fitted rows are laid out (failed and unfit rows are set aside); the
#' table must hold a single model family (one fitting function) or it errors;
#' and more than one attached dataset is reported with a message. See
#' [model_table()] for the collection these are drawn from and [attach_data()]
#' for supplying the data that categorical levels and data-derived statistics
#' are read from.
#'
#' @param object A `mdl_tbl` object holding at least one fitted model
#'
#' @param x A `<mesa>` specification (for the verbs and `print()`)
#'
#' @param ... For the selection verbs, labeled-formula selection input (a
#'   `formula`, a `list` of formulas, or a `character` vector — see
#'   [labeled_formulas_to_named_list()]); for `print()`, unused
#'
#' @return `mesa()` and the verbs return a `<mesa>` specification object.
#'
#' @seealso [as_gt()] to render, [model_table()] for the model collection
#'
#' @name mesa
#' @export
mesa <- function(object, ...) {

	validate_class(object, "mdl_tbl")

	# Only fitted rows go on the mesa; failed and unfit rows are set aside
	status <- model_table_status(object)
	fitted <- object[status == "fitted", , drop = FALSE]
	if (nrow(fitted) == 0) {
		stop(
			"A `mesa` needs fitted models, but none of the ", nrow(object),
			" row(s) are fitted. Fit formulas with ",
			"`fit(..., raw = FALSE)` first",
			if (any(status == "failed")) " (`model_failures()` shows why some failed)",
			".",
			call. = FALSE
		)
	}

	# One table, one model family: mixing e.g. `lm` and `coxph` estimates in a
	# single table is not interpretable
	families <- unique(stats::na.omit(fitted$model_call))
	if (length(families) > 1) {
		stop(
			"A `mesa` holds a single model family, but this table mixes ",
			paste0("`", families, "`", collapse = ", "),
			". Subset to one family (e.g. with `dplyr::filter(model_call == ...)`) ",
			"before laying it out.",
			call. = FALSE
		)
	}

	# One dataset is the common case; more than one is allowed but worth noting,
	# because data-derived statistics resolve through the attached data
	datasets <- unique(stats::na.omit(fitted$data_id))
	if (length(datasets) > 1) {
		message(
			"This table's models reference more than one dataset (",
			paste(datasets, collapse = ", "),
			"); data-derived statistics resolve each model against its own."
		)
	}

	new_mesa(fitted)
}

#' Construct a `<mesa>` specification with its default slots
#' @keywords internal
#' @noRd
new_mesa <- function(mdl_tbl,
										 selection = default_selection(),
										 labels = default_labels(),
										 columns = list(),
										 layout = default_layout(),
										 style = default_style()) {

	structure(
		list(
			mdl_tbl = mdl_tbl,
			selection = selection,
			labels = labels,
			columns = columns,
			layout = layout,
			style = style
		),
		class = "mesa"
	)
}

#' Empty defaults for the declarative spec slots
#' @keywords internal
#' @noRd
default_selection <- function() {
	list(outcomes = NULL, exposures = NULL, terms = NULL,
			 adjustment = NULL, strata = NULL)
}

#' @keywords internal
#' @noRd
default_labels <- function() {
	list(relabels = list(), columns = list())
}

#' @keywords internal
#' @noRd
default_layout <- function() {
	# The bare default: adjustment-set rows grouped by outcome. `modify_layout()`
	# (M6.6) will select the other presets and swap the row-group dimension.
	list(preset = "adjustment", row_groups = "outcome")
}

#' @keywords internal
#' @noRd
default_style <- function() {
	# `modify_style()` (M6.6) generalizes these; here they are the render
	# defaults the minimal `as_gt()` reads.
	list(digits = 2, missing_text = "")
}

# Selection verbs -------------------------------------------------------------

#' Collect labeled-formula verb input into a single object
#'
#' The verbs accept the documented labeled-formula forms directly
#' (`select_outcomes(m, mpg ~ "MPG")`), a list (`list(...)`), a character
#' vector, or several formulas as separate arguments
#' (`select_adjustment(m, 1 ~ "Crude", 3 ~ "Adjusted")`). One argument is
#' passed through untouched; several formulas are gathered into a list, which
#' [labeled_formulas_to_named_list()] understands.
#' @keywords internal
#' @noRd
collect_labeled <- function(...) {
	dots <- list(...)
	if (length(dots) == 0) {
		return(NULL)
	}
	if (length(dots) == 1) {
		return(dots[[1]])
	}
	dots
}

#' Record a selection instruction, replacing any earlier one with a message
#' @keywords internal
#' @noRd
record_selection <- function(x, dimension, input, verb) {
	if (!is.null(x$selection[[dimension]])) {
		message("`", verb, "()` replaces the earlier ", dimension, " selection.")
	}
	x$selection[[dimension]] <- input
	x
}

#' @rdname mesa
#' @export
select_outcomes <- function(x, ...) {
	validate_class(x, "mesa")
	record_selection(x, "outcomes", collect_labeled(...), "select_outcomes")
}

#' @rdname mesa
#' @export
select_exposures <- function(x, ...) {
	validate_class(x, "mesa")
	record_selection(x, "exposures", collect_labeled(...), "select_exposures")
}

#' @rdname mesa
#' @export
select_terms <- function(x, ...) {
	validate_class(x, "mesa")
	record_selection(x, "terms", collect_labeled(...), "select_terms")
}

#' @rdname mesa
#' @export
select_adjustment <- function(x, ...) {
	validate_class(x, "mesa")
	record_selection(x, "adjustment", collect_labeled(...), "select_adjustment")
}

#' @rdname mesa
#' @export
select_strata <- function(x, ...) {
	validate_class(x, "mesa")
	record_selection(x, "strata", collect_labeled(...), "select_strata")
}

#' Relabel terms, levels, or columns late
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `modify_labels()` rethinks a label without reselecting anything. It absorbs
#' the old `level_labels` argument of the retired `tbl_*` functions, so its
#' labeled formulas may name either a term (the variable) or a specific level:
#'
#' - a variable with a scalar label relabels the **term**
#'   (`smoking ~ "Smoking status"`);
#' - a variable with a vector label relabels the term's **levels** in
#'   ascending order (`am ~ c("Manual", "Automatic")`);
#' - a bare level value relabels that **level** wherever it appears
#'   (`0 ~ "Absent"`).
#'
#' Column (statistic) relabelings are supplied through `columns` and consumed
#' by the column verbs. Like every verb, a repeated `modify_labels()` replaces
#' its earlier instruction with a message.
#'
#' @param x A `<mesa>` specification
#' @param ... Labeled formulas relabeling terms or levels (see Description)
#' @param columns A labeled-formula input relabeling statistic columns
#'
#' @return The modified `<mesa>` specification.
#'
#' @seealso [mesa()]
#' @export
modify_labels <- function(x, ..., columns = NULL) {

	validate_class(x, "mesa")

	relabels <- collect_labeled(...)
	if (is.null(relabels) && is.null(columns)) {
		return(x)
	}

	had <- length(x$labels$relabels) > 0 || length(x$labels$columns) > 0
	if (had) {
		message("`modify_labels()` replaces the earlier label instruction.")
	}

	x$labels$relabels <-
		if (is.null(relabels)) list() else labeled_formulas_to_named_list(relabels)
	x$labels$columns <-
		if (is.null(columns)) list() else labeled_formulas_to_named_list(columns)

	x
}

# Printing --------------------------------------------------------------------

#' @rdname mesa
#' @export
print.mesa <- function(x, ...) {
	cat(format(x, ...), sep = "\n")
	invisible(x)
}

#' @rdname mesa
#' @export
format.mesa <- function(x, ...) {

	mt <- x$mdl_tbl
	family <- unique(stats::na.omit(mt$model_call))
	datasets <- unique(stats::na.omit(mt$data_id))

	header <- paste0(
		"<mesa> specification: ", nrow(mt),
		if (nrow(mt) == 1) " fitted model" else " fitted models",
		if (length(family) > 0) paste0(" \u00d7 ", paste(family, collapse = ", "))
	)

	dataLine <-
		if (length(datasets) > 0) {
			datLs <- attr(mt, "dataList")
			marks <- vapply(datasets, function(d) {
				if (d %in% names(datLs)) d else paste0(d, " [detached]")
			}, character(1))
			paste0("  data: ", paste(marks, collapse = ", "))
		}

	layoutLine <- paste0(
		"  layout: ", x$layout$preset,
		" (rows: ",
		switch(x$layout$preset,
					 adjustment = "adjustment sets",
					 levels = "term levels",
					 interaction = "interaction levels",
					 x$layout$preset),
		", groups: ", x$layout$row_groups, "s)"
	)

	# Declared selection, one line per dimension that has been narrowed
	selLines <- character()
	for (d in names(x$selection)) {
		input <- x$selection[[d]]
		if (!is.null(input)) {
			nm <- names(labeled_formulas_to_named_list(input))
			selLines <- c(selLines, paste0("    ", d, ": ", paste(nm, collapse = ", ")))
		}
	}
	selectionBlock <-
		if (length(selLines) > 0) {
			c("  selection:", selLines)
		} else {
			"  selection: everything fitted (bare mesa)"
		}

	# Column blocks so far; the bare default is estimate + CI
	columnsLine <-
		if (length(x$columns) > 0) {
			paste0("  columns: ",
						 paste(vapply(x$columns, function(b) b$type, character(1)),
						 			collapse = ", "))
		} else {
			"  columns: estimate + CI (default)"
		}

	labelsLine <-
		if (length(x$labels$relabels) > 0 || length(x$labels$columns) > 0) {
			relabelled <- unique(c(names(x$labels$relabels), names(x$labels$columns)))
			paste0("  labels: ", paste(relabelled, collapse = ", "))
		}

	hint <- paste0(
		"# `as_gt()` renders; `select_*()` / `modify_labels()` refine the mesa"
	)

	c(header, dataLine, layoutLine, selectionBlock, columnsLine, labelsLine, "", hint)
}
