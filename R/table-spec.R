# The <mdl_gt> specification (M6.3) ---------------------------------------------
#
# The table grammar is composition-first: `mdl_gt()` lifts a fitted `mdl_tbl`
# onto a declarative specification, small pipeable verbs refine it, and
# `as_gt()` (in table-render.R) realizes it. The spec carries *instructions*,
# not results — selection, labels, column blocks, layout, and style — so verbs
# compose in any order and resolution is deferred to realization. This is the
# same lazy contract a `{ggplot2}` plot is grown under (with the pipe, not `+`).
#
# This file owns the constructor, the verbs that adjust the spec's slots (the
# `select_*` selection verbs, `modify_labels()`, `modify_layout()`,
# `modify_style()`), the validation, and the print method. The `add_*` column
# verbs live in table-columns.R (M6.4/6.5); the cell-frame renderer lives in
# table-render.R (M6.6).

#' The `<mdl_gt>` table specification
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `mdl_gt()` lays a collection of fitted models out on the *mesa* — the table
#' upon which the models are displayed — as a declarative specification. The
#' division of labor with [model_table()] is deliberate: **which models sit on
#' the mesa is decided on the `mdl_tbl`**, with ordinary `dplyr` verbs over its
#' provenance columns (`outcome`, `exposure`, `strata`, ...) and the family
#' columns [identify_family()] stamps on — whittle, print, verify. `mdl_gt()`
#' is then the gate: it verifies what arrives is *one presentable analysis*
#' (see Details) and takes no selection arguments, putting everything fitted
#' on the mesa with default labels drawn from the term table and the attached
#' data. From there the table is grown one **display** decision at a time with
#' pipeable verbs, exactly the way a `{ggplot2}` plot is grown:
#'
#' - `select_adjustment()` chooses which rungs of the adjustment ladder are
#'   displayed (e.g. only the crude and fully adjusted rows —
#'   [adjustment_sets()] shows the rungs and the numbers they are selected
#'   by), and `select_terms()` which terms' cells are shown;
#' - the `add_*()` verbs append column blocks derived from the models and the
#'   attached data (estimates, events, rates, sample sizes);
#' - `modify_labels()` relabels outcomes, terms, and levels late, without
#'   reselecting;
#' - `as_gt()` renders the specification to a `{gt}` table (see [as_gt()]).
#'
#' Because the specification is declarative — the verbs record instructions and
#' resolution happens only at [as_gt()]/`print()` — the verbs may arrive in any
#' order. **A verb replaces only what you name.** Repeating a verb with the
#' same instruction — the same selection dimension, block type, style field,
#' or label name — replaces just that instruction with a message, and leaves
#' everything else recorded on the specification standing (the `{ggplot2}`
#' `labs()` merge behavior); calling a `select_*()` verb with no arguments
#' clears that dimension, which is the way to undo an earlier selection. A
#' bare `mdl_gt(mt) |> as_gt()` already renders a minimal estimate-and-interval
#' table, so the grammar is usable from the first verb.
#'
#' @details
#'
#' The unit of a mesa is the **term × effect cell**: one term (or term level)
#' crossed with one effect — an estimate, its interval, a p-value, an event
#' count, a rate, an observation count. The `add_*()` verbs append *column
#' blocks*, groups of effects that travel together (an estimate with its CI
#' and p), so blocks compose freely — adding, dropping, or reordering one
#' never changes another's cells — and the layout presets place the same
#' cells wide (levels on columns) or long (levels on rows) without
#' recomputing anything.
#'
#' `mdl_gt()` validates before it builds. The object must be a `mdl_tbl`; only
#' its fitted rows are laid out (failed and unfit rows are set aside); the
#' table must hold a single model family (one fitting function, on one link)
#' or it errors; and more than one attached dataset is reported with a
#' message.
#'
#' It then verifies the models form **one presentable analysis**, in
#' [identify_family()]'s terms: a single formula family (an adjustment ladder,
#' a mediation triad, parallel adjustment sets, or a lone model), or several
#' families bound by a shared relation — `varied exposures` or `varied
#' outcomes` over one adjustment ladder, the wide-table shapes. Unrelated
#' families error, pointing back at the `mdl_tbl`: stamp it with
#' `identify_family()`, `dplyr::filter()` it down, and lay out one analysis at
#' a time. See [model_table()] for the collection these are drawn from and
#' [attach_data()] for supplying the data that categorical levels and
#' data-derived statistics are read from.
#'
#' @param object A `mdl_tbl` object holding at least one fitted model
#'
#' @param x A `<mdl_gt>` specification (for the verbs and `print()`)
#'
#' @param ... For `mdl_gt()`, unused — it deliberately takes no selection
#'   arguments, and an unused argument errors; for the selection verbs,
#'   labeled-formula selection input (a `formula`, a `list` of formulas, or a
#'   `character` vector — see [labeled_formulas_to_named_list()]), or nothing
#'   at all to clear that dimension's selection; for `print()`, unused
#'
#' @return `mdl_gt()` and the verbs return a `<mdl_gt>` specification object.
#'
#' @examples
#' # The "adjustment" chain — adjustment sets on rows, outcomes as row
#' # groups, a statistic block per term (the retired `tbl_beta()` shape)
#' d <- mtcars
#' d$cyl <- factor(d$cyl)
#' mt <-
#'   fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential") |>
#'   fit(.fn = lm, data = d, raw = FALSE) |>
#'   model_table(data = d)
#' mt |>
#'   mdl_gt() |>
#'   select_adjustment(1 ~ "Unadjusted", 3 ~ "Fully adjusted") |>
#'   add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI")) |>
#'   modify_labels(wt ~ "Weight (1000 lbs)") |>
#'   as_gt()
#'
#' @examplesIf requireNamespace("survival", quietly = TRUE)
#' # The "levels" chain — event and rate rows over adjusted estimates, term
#' # levels on columns (the retired hazard-table shape)
#' lung <- survival::lung
#' lung$sex <- factor(lung$sex, levels = 1:2, labels = c("Male", "Female"))
#' mt <-
#'   fmls(Surv(time, status) ~ .x(sex) + age, pattern = "sequential") |>
#'   fit(.fn = survival::coxph, data = lung, raw = FALSE) |>
#'   model_table(data = lung)
#' mt |>
#'   mdl_gt() |>
#'   modify_layout(preset = "levels") |>
#'   select_adjustment(1 ~ "Unadjusted", 2 ~ "Age-adjusted") |>
#'   add_events(followup = time) |>
#'   add_rate_difference() |>
#'   add_estimates(columns = list(beta ~ "HR", conf ~ "95% CI")) |>
#'   as_gt()
#'
#' @seealso [as_gt()] to render, [model_table()] for the model collection
#'
#' @name mdl_gt
#' @export
mdl_gt <- function(object, ...) {

	validate_class(object, "mdl_tbl")

	dots <- list(...)
	if (length(dots) > 0) {
		nms <- names(dots)
		unnamed <- is.null(nms) || !any(nzchar(nms))
		stop(
			"`mdl_gt()` takes no selection arguments; it lays out everything ",
			"fitted with default labels, and the `select_*()` verbs narrow it ",
			"afterward.",
			if (!unnamed) {
				paste0(
					" Unused argument", if (sum(nzchar(nms)) > 1) "s" else "", ": ",
					paste0("`", nms[nzchar(nms)], "`", collapse = ", "), "."
				)
			},
			call. = FALSE
		)
	}

	# Only fitted rows go on the mesa; failed and unfit rows are set aside
	status <- model_table_status(object)
	fitted <- object[status == "fitted", , drop = FALSE]
	if (nrow(fitted) == 0) {
		stop(
			"A `mdl_gt` needs fitted models, but none of the ", nrow(object),
			" row(s) are fitted. Fit formulas with ",
			"`fit(..., raw = FALSE)` first",
			if (any(status == "failed")) " (`model_failures()` shows why some failed)",
			".",
			call. = FALSE
		)
	}

	# One table, one model family: mixing e.g. `lm` and `coxph` estimates -- or
	# two `glm`s on different links (logit vs identity), whose estimates live
	# on different scales -- in a single table is not interpretable
	links <- vapply(fitted$model_summary, function(s) {
		if (is.list(s) && length(s$model_link) == 1 && !is.na(s$model_link)) {
			s$model_link
		} else {
			NA_character_
		}
	}, character(1))
	families <- unique(stats::na.omit(
		paste0(fitted$model_call,
					 ifelse(is.na(links), "", paste0(" (", links, ")")))
	))
	if (length(families) > 1) {
		stop(
			"A `mdl_gt` holds a single model family, but this table mixes ",
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

	# One mesa, one analysis: a single formula family, or several families
	# bound by a shared relation over *one* adjustment ladder (varied
	# exposures / varied outcomes -- the wide-table shapes). Anything looser
	# has no coherent layout, so it is turned back toward the model table's
	# own verbs
	fam <- identify_family(model_table_formulas(fitted))
	famTab <- fam[!duplicated(fam$family),
								c("family", "pattern", "relation", "outcome", "exposure"),
								drop = FALSE]
	if (nrow(famTab) > 1) {
		relSets <- lapply(famTab$relation, function(r) {
			if (is.na(r)) character() else trimws(strsplit(r, ",")[[1]])
		})
		shared <- Reduce(intersect, relSets)
		if (length(shared) == 0) {
			lines <- paste0(
				"family ", famTab$family, " (", famTab$pattern, "): ",
				famTab$outcome,
				ifelse(is.na(famTab$exposure), "",
							 paste0(" ~ ", famTab$exposure))
			)
			stop(
				"A `mdl_gt` holds one analysis: a single family, or families ",
				"related by varied exposures/outcomes over a shared adjustment ",
				"ladder. This table holds unrelated families:\n  ",
				paste(lines, collapse = "\n  "),
				"\nWhittle the model table down first, e.g. ",
				"`identify_family(x) |> keep_models(family = 1)`.",
				call. = FALSE
			)
		}
		# A relation label shared across two *different* ladders is two
		# analyses standing side by side (e.g. two varied-exposure pairs on
		# unrelated adjustment sets) -- their rows could never align
		ladders <- vapply(
			split(fam$covariates, fam$family),
			ladder_signature, character(1)
		)
		if (length(unique(ladders)) > 1) {
			stop(
				"A `mdl_gt` holds one analysis, but these families share the ",
				paste0("`", shared, "`", collapse = "/"),
				" relation across ", length(unique(ladders)),
				" different adjustment ladders — several analyses side by ",
				"side. Whittle the model table to one ladder first ",
				"(`identify_family()` to look, `keep_models()` to cut).",
				call. = FALSE
			)
		}
	}

	# The spec starts with empty defaults: everything fitted is selected, the
	# layout groups adjustment-set rows by outcome (`modify_layout()` swaps
	# presets), and style is unset until `modify_style()` records instructions
	# (the renderer resolves fallbacks -- digits 2, missing text "", padding
	# from the blocks -- at render, after any column block's own `digits`)
	structure(
		list(
			mdl_tbl = fitted,
			family = famTab,
			selection = list(terms = NULL, adjustment = NULL),
			labels = list(relabels = list(), columns = list()),
			columns = list(),
			layout = list(preset = "adjustment", row_groups = "outcome"),
			style = list(accents = list(), digits = NULL, missing_text = NULL,
									 padding = NULL)
		),
		class = "mdl_gt"
	)
}

# Selection verbs -------------------------------------------------------------

#' Collect labeled-formula verb input into a single object
#'
#' The verbs accept the documented labeled-formula forms directly
#' (`select_terms(m, cyl ~ "Cylinders")`), a list (`list(...)`), a character
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

#' Record a selection instruction, replacing any earlier one with a message.
#' Calling the verb with no arguments records `NULL`, which clears the
#' dimension — the documented way to undo an earlier `select_*()` call.
#' @keywords internal
#' @noRd
record_selection <- function(x, dimension, input, verb) {
	if (!is.null(x$selection[[dimension]])) {
		message("`", verb, "()` replaces the earlier ", dimension, " selection.")
	}
	x$selection[[dimension]] <- input
	x
}

#' @rdname mdl_gt
#' @export
select_terms <- function(x, ...) {
	validate_class(x, "mdl_gt")
	record_selection(x, "terms", collect_labeled(...), "select_terms")
}

#' @rdname mdl_gt
#' @export
select_adjustment <- function(x, ...) {
	validate_class(x, "mdl_gt")
	record_selection(x, "adjustment", collect_labeled(...), "select_adjustment")
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
#'   (`0 ~ "Absent"`);
#' - an outcome relabels its **row group** (`mpg ~ "Miles per gallon"`); a
#'   name that is both a displayed term and an outcome — a mediator —
#'   relabels both.
#'
#' Column (statistic) relabelings are supplied through `columns` and consumed
#' by the column verbs. Like every verb, `modify_labels()` merges: naming a
#' term, level, or column again replaces just that one label, with a message
#' naming it, while every other label already recorded — from this call or an
#' earlier one — stands (the `{ggplot2}` `labs()` merge behavior). So
#' rethinking one label late never forces restating the rest.
#'
#' @param x A `<mdl_gt>` specification
#' @param ... Labeled formulas relabeling terms or levels (see Description)
#' @param columns A labeled-formula input relabeling statistic columns
#'
#' @return The modified `<mdl_gt>` specification.
#'
#' @seealso [mdl_gt()]
#' @export
modify_labels <- function(x, ..., columns = NULL) {

	validate_class(x, "mdl_gt")

	relabels <- collect_labeled(...)
	if (is.null(relabels) && is.null(columns)) {
		return(x)
	}

	if (!is.null(relabels)) {
		new <- labeled_formulas_to_named_list(relabels)
		repeated <- intersect(names(new), names(x$labels$relabels))
		if (length(repeated) > 0) {
			message(
				"`modify_labels()` replaces the earlier label for ",
				paste0("`", repeated, "`", collapse = ", "), "."
			)
		}
		x$labels$relabels[names(new)] <- new
	}

	if (!is.null(columns)) {
		new <- labeled_formulas_to_named_list(columns)
		repeated <- intersect(names(new), names(x$labels$columns))
		if (length(repeated) > 0) {
			message(
				"`modify_labels()` replaces the earlier column label for ",
				paste0("`", repeated, "`", collapse = ", "), "."
			)
		}
		x$labels$columns[names(new)] <- new
	}

	x
}

#' Choose a layout preset for a `<mdl_gt>`
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `modify_layout()` selects the layout preset — the complete assignment of the
#' grammar's four axes (rows, row groups, columns, spanners) — and, optionally,
#' the row-group dimension. The launch presets are:
#'
#' - `"adjustment"` (the default): adjustment sets on rows, outcomes as row
#'   groups, a statistic block per term or term level on columns, terms
#'   spanning their levels.
#' - `"levels"`: statistic rows (the event count and incidence rate when
#'   [add_events()] is on the mesa, then one row per adjustment set), term
#'   levels on columns, terms as spanners — the shape of the retired hazard
#'   tables.
#' - `"interaction"`: interaction levels on rows, grouped by interaction
#'   term, the across-levels p-value floating over each band. Its rows are
#'   *defined* by [add_interaction()], which the specification must carry.
#'
#' `row_groups` swaps the row-group dimension between `"outcome"` (the
#' default) and `"strata"`. Like every verb, a repeated `modify_layout()`
#' replaces the earlier instruction with a message.
#'
#' @param x A `<mdl_gt>` specification
#' @param preset One of `"adjustment"`, `"levels"`, or `"interaction"`
#' @param row_groups The row-group dimension: `"outcome"` or `"strata"`
#'
#' @return The modified `<mdl_gt>` specification.
#'
#' @seealso [mdl_gt()], [as_gt()]
#' @export
modify_layout <- function(x, preset = NULL, row_groups = NULL) {

	validate_class(x, "mdl_gt")

	if (is.null(preset) && is.null(row_groups)) {
		return(x)
	}

	presets <- c("adjustment", "levels", "interaction")
	if (!is.null(preset)) {
		if (!is.character(preset) || length(preset) != 1 ||
				!preset %in% presets) {
			stop(
				"`preset` must be one of the launch layout presets: ",
				paste0("`\"", presets, "\"`", collapse = ", "), ".",
				call. = FALSE
			)
		}
	}
	groups <- c("outcome", "strata")
	if (!is.null(row_groups)) {
		if (!is.character(row_groups) || length(row_groups) != 1 ||
				!row_groups %in% groups) {
			stop(
				"`row_groups` must be one of: ",
				paste0("`\"", groups, "\"`", collapse = ", "), ".",
				call. = FALSE
			)
		}
	}

	if (isTRUE(x$layout$declared)) {
		message("`modify_layout()` replaces the earlier layout instruction.")
	}

	if (!is.null(preset)) {
		x$layout$preset <- preset
	}
	if (!is.null(row_groups)) {
		x$layout$row_groups <- row_groups
	}
	x$layout$declared <- TRUE
	x
}

#' Style a `<mdl_gt>` at render
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `modify_style()` records style instructions, applied when the table is
#' rendered by [as_gt()]:
#'
#' - `accents` emphasize the cells that meet a criterion. Each accent is a
#'   two-sided formula whose **left side** is a criterion on any displayed
#'   statistic (`p < 0.05`, `estimate > 1`, `rate >= 10`) and whose **right
#'   side** is the instruction: `"bold"`, `"italic"`, or a text color (any
#'   color name or hex value); several may be combined
#'   (`p < 0.05 ~ c("bold", "italic")`). A criterion is evaluated once per
#'   term-level within each row, against all of that context's statistics, and
#'   accents every cell of the context — so `p < 0.05 ~ "bold"` bolds both the
#'   estimate and the p-value it belongs to. The recognized statistic names
#'   are `estimate` (alias `beta`), `conf_low`, `conf_high`, `p` (alias
#'   `p_value`), `n`, `events`, `rate`, and `rate_difference`.
#' - `digits` sets the table-wide formatting default. A column block's own
#'   `digits` still wins for its columns; p-values keep their three-decimal
#'   rule.
#' - `missing_text` fills every cell with nothing to show (reference levels,
#'   estimates a model did not produce). The default is an empty cell.
#' - `padding` scales the table's vertical row padding (as
#'   [gt::opt_vertical_padding()] does). A table carrying a forest column
#'   defaults to `0` — the dense canvas its plot cells need to read as one —
#'   and this overrides that default.
#'
#' Like every verb, `modify_style()` merges: naming `digits` again after an
#' earlier `accents` call replaces only `digits`, with a message naming it —
#' the accents already recorded stand. Each of `accents`, `digits`,
#' `missing_text`, and `padding` replaces only itself.
#'
#' @param x A `<mdl_gt>` specification
#' @param accents A formula or list of formulas: `criterion ~ instruction`
#'   (see Description)
#' @param digits Number of digits estimates are formatted to
#' @param missing_text Text shown in cells with nothing to display
#' @param padding Vertical padding scale, `0` (dense) upward
#'
#' @return The modified `<mdl_gt>` specification.
#'
#' @seealso [mdl_gt()], [as_gt()]
#' @export
modify_style <- function(x, accents = NULL, digits = NULL,
												 missing_text = NULL, padding = NULL) {

	validate_class(x, "mdl_gt")

	if (is.null(accents) && is.null(digits) && is.null(missing_text) &&
			is.null(padding)) {
		return(x)
	}

	if (!is.null(accents)) {
		if (inherits(accents, "formula")) {
			accents <- list(accents)
		}
		accents <- lapply(accents, validate_accent)
	}
	validate_scalar(digits, "digits", min = 0, allow_null = TRUE)
	validate_scalar(missing_text, "missing_text", type = "string",
									 allow_null = TRUE)
	validate_scalar(padding, "padding", min = 0, allow_null = TRUE)

	# Each argument replaces only its own field, with a message only when that
	# field was already recorded — the other style instructions stand (M6.11)
	if (!is.null(accents)) {
		if (length(x$style$accents) > 0) {
			message("`modify_style()` replaces the earlier `accents` instruction.")
		}
		x$style$accents <- accents
	}
	if (!is.null(digits)) {
		if (!is.null(x$style$digits)) {
			message("`modify_style()` replaces the earlier `digits` instruction.")
		}
		x$style$digits <- as.integer(digits)
	}
	if (!is.null(missing_text)) {
		if (!is.null(x$style$missing_text)) {
			message(
				"`modify_style()` replaces the earlier `missing_text` instruction."
			)
		}
		x$style$missing_text <- missing_text
	}
	if (!is.null(padding)) {
		if (!is.null(x$style$padding)) {
			message("`modify_style()` replaces the earlier `padding` instruction.")
		}
		x$style$padding <- as.numeric(padding)
	}

	x
}

#' Validate one accent formula into a criterion + instruction pair
#'
#' The criterion (LHS) must be a comparison over the recognized statistic
#' names; the instruction (RHS) must evaluate to a character vector of
#' `"bold"`, `"italic"`, and/or a text color. Validated at verb time —
#' recording a bad accent and failing at render would waste the laziness.
#' @keywords internal
#' @noRd
validate_accent <- function(f) {

	if (!inherits(f, "formula") || length(f) != 3) {
		stop(
			"Each accent must be a two-sided formula: `criterion ~ instruction`, ",
			"e.g. `p < 0.05 ~ \"bold\"`.",
			call. = FALSE
		)
	}

	criterion <- f[[2]]
	# The accent vocabulary: every alias of every accentable statistic
	known <- unlist(
		lapply(Filter(function(s) isTRUE(s$accentable), table_statistics()),
					 `[[`, "aliases"),
		use.names = FALSE
	)
	used <- all.vars(criterion)
	unknown <- setdiff(used, known)
	if (length(used) == 0 || length(unknown) > 0) {
		stop(
			"An accent criterion compares a displayed statistic",
			if (length(unknown) > 0) {
				paste0(", but `", paste(unknown, collapse = "`, `"),
							 "` is not one. The recognized statistics are: ")
			} else {
				". The recognized statistics are: "
			},
			paste0("`", known, "`", collapse = ", "), ".",
			call. = FALSE
		)
	}

	instruction <- tryCatch(
		eval(f[[3]], envir = environment(f)),
		error = function(e) NULL
	)
	if (!is.character(instruction) || length(instruction) == 0 ||
			anyNA(instruction)) {
		stop(
			"An accent instruction is a character vector: `\"bold\"`, ",
			"`\"italic\"`, and/or a text color (`\"red\"`, `\"#B22222\"`).",
			call. = FALSE
		)
	}

	list(criterion = criterion, instruction = instruction)
}

# Printing --------------------------------------------------------------------

#' @rdname mdl_gt
#' @export
print.mdl_gt <- function(x, ...) {
	cat(format(x, ...), sep = "\n")
	invisible(x)
}

#' @rdname mdl_gt
#' @export
format.mdl_gt <- function(x, ...) {

	mt <- x$mdl_tbl
	family <- unique(stats::na.omit(mt$model_call))
	datasets <- unique(stats::na.omit(mt$data_id))

	header <- paste0(
		"<mdl_gt> specification: ", nrow(mt),
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

	# The verified analysis: its family pattern(s), and the relation binding
	# several families when the mesa is a wide-table shape
	familyLine <-
		if (!is.null(x$family) && nrow(x$family) > 0) {
			rels <- unique(stats::na.omit(x$family$relation))
			paste0(
				"  analysis: ", nrow(x$family),
				if (nrow(x$family) == 1) " family (" else " families (",
				paste(unique(x$family$pattern), collapse = ", "), ")",
				if (length(rels) > 0) paste0(" — ", paste(rels, collapse = "; "))
			)
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
						 paste(vapply(x$columns, describe_column_block, character(1)),
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

	c(header, dataLine, familyLine, layoutLine, selectionBlock, columnsLine,
		labelsLine, "", hint)
}
