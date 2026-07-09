# Column blocks (M6.4 model statistics, M6.5 data statistics) -----------------
#
# The `add_*` verbs append *column blocks* — ordered instructions on the
# `columns` slot of a `<mesa>` specification. Like every verb, they record and
# defer: computation and formatting happen at realization, and re-calling a
# verb replaces its earlier block with a message. `add_estimates()` and
# `add_n()` read the models alone (the tidy estimates and the recorded
# `nobs`); `add_events()` and `add_rate_difference()` are the data-derived
# blocks, computed from the attached data each model's `data_id` resolves to —
# there is no `data =` argument anywhere in the table layer, and every
# data-needing error points to `attach_data()`.

#' Add model-statistic columns to a `<mesa>`
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' These verbs append a *column block* to a [mesa()] specification — an
#' instruction for a set of statistic columns, computed and formatted only when
#' the table is realized by [as_gt()].
#'
#' - `add_estimates()` declares the estimate block: which of the point estimate
#'   (`beta`), confidence interval (`conf`), and p-value (`p`) columns are
#'   shown, under what labels, on what scale, and to how many digits. The
#'   estimate and interval render merged into a single displayed column
#'   (`1.4 (1.1, 1.8)`); the p-value renders as its own column.
#' - `add_n()` adds the model-level number of observations, read from the
#'   `nobs` recorded at fit time — so it never needs attached data.
#'
#' A bare specification without `add_estimates()` already renders estimate +
#' CI; call the verb when you want to choose the statistics, their labels
#' (`beta ~ "HR"`), the scale, or the digits. Re-calling a verb replaces its
#' earlier block with a message (the same replacement behavior as every other
#' verb).
#'
#' @details
#'
#' ## Exponentiation
#'
#' `exponentiate = NULL` (the default) defers the scale decision to the model
#' family inference of [flatten_models()]: Cox-family models and GLMs on a
#' `log`/`logit`/`cloglog` link come back exponentiated (hazard, odds, or rate
#' ratios), everything else stays linear. `TRUE` or `FALSE` overrides the
#' inference for every model on the mesa.
#'
#' ## Formatting
#'
#' `digits` applies to the estimate and its interval; left unset, it falls to
#' the table-wide default ([modify_style()]'s `digits`, or 2). P-values render
#' with three decimals, with values below shown as `<0.001`.
#'
#' @param x A `<mesa>` specification (from [mesa()])
#'
#' @param columns Which estimate statistics to show, as labeled formulas (see
#'   [labeled_formulas_to_named_list()]). The recognized statistics are `beta`
#'   (the point estimate), `conf` (the confidence interval), and `p` (the
#'   p-value); the labels become the column headers
#'
#' @param exponentiate Controls the scale of the estimates: `NULL` (default)
#'   infers per model family (see Details), `TRUE`/`FALSE` overrides
#'
#' @param digits Number of digits the estimate and interval are formatted to;
#'   unset, the table-wide default applies (see [modify_style()])
#'
#' @param label The column header for the `n` column
#'
#' @return The modified `<mesa>` specification.
#'
#' @seealso [mesa()], [as_gt()]
#'
#' @name add_estimates
#' @export
add_estimates <- function(x,
													columns = list(beta ~ "Estimate",
																				 conf ~ "95% CI",
																				 p ~ "P value"),
													exponentiate = NULL,
													digits = NULL) {

	validate_class(x, "mesa")

	statistics <- labeled_formulas_to_named_list(columns)
	if (length(statistics) == 0) {
		stop(
			"`add_estimates()` needs at least one statistic in `columns`.",
			call. = FALSE
		)
	}
	known <- table_statistic_names("add_estimates")
	unknown <- setdiff(names(statistics), known)
	if (length(unknown) > 0) {
		stop(
			"`add_estimates()` does not know the statistic ",
			paste0("`", unknown, "`", collapse = ", "),
			". The estimate statistics are: ",
			paste0("`", known, "`", collapse = ", "), ".",
			call. = FALSE
		)
	}
	if (!is.null(exponentiate) &&
			!(is.logical(exponentiate) && length(exponentiate) == 1 &&
				!is.na(exponentiate))) {
		stop(
			"`exponentiate` must be `NULL` (infer per model family), `TRUE`, or ",
			"`FALSE`.",
			call. = FALSE
		)
	}
	validate_scalar(digits, "digits", min = 0, allow_null = TRUE)

	block <- list(
		type = "estimates",
		statistics = lapply(statistics, as.character),
		exponentiate = exponentiate,
		digits = if (is.null(digits)) NULL else as.integer(digits)
	)
	record_column_block(x, block, "add_estimates")
}

#' @rdname add_estimates
#' @export
add_n <- function(x, label = "N") {

	validate_class(x, "mesa")
	validate_scalar(label, "label", type = "string")

	block <- list(type = "n", label = label)
	record_column_block(x, block, "add_n")
}

#' Add data-statistic columns to a `<mesa>`
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' These verbs append *column blocks* whose statistics come from the models'
#' **attached data** (see [attach_data()]), not from the fitted coefficients —
#' the M6.1 statistics vocabulary's load-bearing distinction. Like every
#' `<mesa>` verb they only record instructions; the statistics are computed
#' when the table is realized by [as_gt()], against the dataset each model's
#' `data_id` resolves to.
#'
#' - `add_events()` adds the event count and the incidence rate per
#'   `person_years` for every displayed term level, computed by
#'   [survival::pyears()] from the follow-up time column and the outcome's
#'   event indicator.
#' - `add_rate_difference()` adds the incidence-rate difference between a
#'   dichotomous term's two levels (non-reference minus reference), with a
#'   normal-approximation confidence interval. It is a *term-scoped* statistic
#'   — computed across the levels, displayed in a column of its own — and it
#'   reads the follow-up, person-years, and scale recorded by `add_events()`,
#'   so the specification must carry both blocks.
#'
#' @details
#'
#' ## The rate computations
#'
#' Person-time per level comes from `survival::pyears(Surv(followup, event) ~
#' term, scale = scale)`; the event indicator is the outcome itself when it is
#' a column of the data, or the event argument of a `Surv()` outcome. The
#' incidence rate is `events / (person-time / person_years)`. The rate
#' difference between levels `2` and `1` has standard error `sqrt(events_2 /
#' persontime_2^2 + events_1 / persontime_1^2)` (the Poisson variance of each
#' rate), and the interval uses the `qnorm(1 - (1 - conf_level) / 2)` critical
#' value — for the default `conf_level = 0.95`, `qnorm(0.975)`.
#'
#' `add_rate_difference()` errors on any displayed term whose attached-data
#' factor does not have exactly two levels.
#'
#' @param x A `<mesa>` specification (from [mesa()])
#'
#' @param followup The column of the attached data holding each subject's
#'   follow-up time, as a bare name or a string. When the mesa's outcome is a
#'   `Surv()` call, `followup` is inferred from its time argument and may be
#'   omitted; a plain outcome (or outcomes that disagree on the time column)
#'   still requires it explicitly. Supplying `followup` always overrides the
#'   inference, e.g. when the attached data's follow-up column is not the one
#'   named in the fitted formula
#'
#' @param person_years The person-time denominator the rates are expressed in
#'   (`100` shows rates per 100 person-years)
#'
#' @param scale The divisor turning the `followup` units into years, passed to
#'   [survival::pyears()]: the default `365.25` reads follow-up recorded in
#'   days; use `1` when follow-up is already in years
#'
#' @param digits Number of digits the rates (and the rate difference) are
#'   formatted to
#'
#' @param conf_level Confidence level of the rate-difference interval
#'
#' @return The modified `<mesa>` specification.
#'
#' @seealso [mesa()], [as_gt()], [attach_data()]
#'
#' @name add_events
#' @export
add_events <- function(x,
											 followup,
											 person_years = 100,
											 scale = 365.25,
											 digits = 1) {

	validate_class(x, "mesa")

	if (missing(followup)) {
		# Not supplied: infer from a Surv() outcome's time argument (M6.12) —
		# identity, never a guess — and require it explicitly otherwise
		followup <- infer_followup_column(x$mdl_tbl)
		if (is.null(followup)) {
			stop(
				"`add_events()` needs `followup`: the column of the attached data ",
				"holding the follow-up time. It can only be inferred when every ",
				"outcome on the mesa is a `Surv()` call naming the same time ",
				"column; pass `followup` explicitly here.",
				call. = FALSE
			)
		}
	} else {
		fuExpr <- substitute(followup)
		followup <- if (is.symbol(fuExpr)) as.character(fuExpr) else followup
		if (!is.character(followup) || length(followup) != 1 ||
				is.na(followup) || !nzchar(followup)) {
			stop(
				"`followup` must be a single column name (bare or as a string).",
				call. = FALSE
			)
		}
	}
	validate_scalar(person_years, "person_years", min = 0, inclusive = FALSE)
	validate_scalar(scale, "scale", min = 0, inclusive = FALSE)
	validate_scalar(digits, "digits", min = 0)

	block <- list(
		type = "events",
		followup = followup,
		person_years = as.numeric(person_years),
		scale = as.numeric(scale),
		digits = as.integer(digits)
	)
	record_column_block(x, block, "add_events")
}

#' Add interaction rows to a `<mesa>`
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `add_interaction()` puts effect modification on the mesa: one row per level
#' of each model's interaction variable, grouped by interaction term, with the
#' exposure's within-level estimate derived from the stored coefficients and
#' variance-covariance matrix by [estimate_interaction()] — nothing is refit.
#'
#' The block *defines* the rows of the table, so declaring it **implies** the
#' `"interaction"` layout: if no layout has been declared yet, `add_interaction()`
#' selects it (with a message); if [modify_layout()] already declared a
#' different preset, `add_interaction()` errors naming the conflict rather than
#' silently overriding it. `modify_layout(preset = "interaction")` on its own
#' — without `add_interaction()` — still errors at realization, since the
#' block is what defines the rows. Its statistics carry two scopes: the
#' per-level cells (estimate/CI from [add_estimates()]; the per-level `n` from
#' [add_n()], which counts the attached data) are ordinary rows, while the
#' single across-levels interaction p-value is a *group-scoped* cell the
#' renderer floats over the level rows. A forest column ([add_forest()]) reads
#' the same per-level estimates.
#'
#' @param x A `<mesa>` specification (from [mesa()])
#'
#' @param conf_level Confidence level of the within-level intervals
#'
#' @return The modified `<mesa>` specification.
#'
#' @seealso [mesa()], [modify_layout()], [estimate_interaction()]
#' @export
add_interaction <- function(x, conf_level = 0.95) {

	validate_class(x, "mesa")
	validate_scalar(conf_level, "conf_level", min = 0, max = 1, inclusive = FALSE)

	# The block defines the interaction layout's rows, so declaring it implies
	# the layout (M6.12) — one gesture for one decision, rather than the
	# mandatory add_interaction() + modify_layout(preset = "interaction") pair
	if (isTRUE(x$layout$declared) &&
			!identical(x$layout$preset, "interaction")) {
		stop(
			"`add_interaction()` defines the rows of the `interaction` layout, ",
			"but `modify_layout()` already selected the `", x$layout$preset,
			"` preset. Use `modify_layout(preset = \"interaction\")`, or drop ",
			"the earlier `modify_layout()` call.",
			call. = FALSE
		)
	}
	if (!identical(x$layout$preset, "interaction")) {
		message("`add_interaction()` sets the layout to the `interaction` preset.")
		x$layout$preset <- "interaction"
		x$layout$declared <- TRUE
	}

	block <- list(type = "interaction", conf_level = as.numeric(conf_level))
	record_column_block(x, block, "add_interaction")
}

#' Add a forest column to a `<mesa>`
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `add_forest()` appends a forest-plot column block to a [mesa()]
#' specification — available to any table, not just interaction tables. Its
#' cells *read* the estimate and interval already on the specification and
#' compute nothing new, so the block requires `estimate` + `conf` statistics
#' (the bare default carries them; an [add_estimates()] block must keep them).
#'
#' Per the grammar, the block is resolved at render: forest cells enter the
#' cell frame as plain numbers, [as_gt()] resolves one shared x-scale across
#' the whole column (limits, intercept, breaks, log versus linear — with
#' `axis` overriding the guesses), draws each cell, and emits the bottom axis
#' strip as a reserved row after every row group. Adding or dropping the
#' block never changes any other cell.
#'
#' The block's dense look (zero vertical padding, borderless plot cells)
#' enters as *defaults* to the style layer; [modify_style()]'s `padding`
#' overrides it.
#'
#' @param x A `<mesa>` specification (from [mesa()])
#'
#' @param axis Options overriding the guessed x-scale, as a named list:
#'   `limits` (length-2 numeric), `breaks` (numeric), `intercept` (the
#'   reference line), and `log` (`TRUE` for a log scale)
#'
#' @param width Width of the drawn cells, in pixels
#'
#' @param invert Show reciprocal estimates: each cell draws `1 / estimate`
#'   with the interval bounds swapped and inverted, so a protective ratio
#'   reads as risk (and vice versa). The axis mirrors with the cells, since
#'   the shared scale is resolved from the drawn values.
#'
#' @return The modified `<mesa>` specification.
#'
#' @seealso [mesa()], [as_gt()], [add_estimates()]
#' @export
add_forest <- function(x, axis = list(), width = 100, invert = FALSE) {

	validate_class(x, "mesa")

	if (!is.list(axis) ||
			(length(axis) > 0 && is.null(names(axis)))) {
		stop("`axis` must be a named list of axis options.", call. = FALSE)
	}
	known <- c("limits", "breaks", "intercept", "log")
	unknown <- setdiff(names(axis), known)
	if (length(unknown) > 0) {
		stop(
			"`axis` does not know the option ",
			paste0("`", unknown, "`", collapse = ", "),
			". The axis options are: ",
			paste0("`", known, "`", collapse = ", "), ".",
			call. = FALSE
		)
	}
	if (!is.null(axis$limits) &&
			(!is.numeric(axis$limits) || length(axis$limits) != 2)) {
		stop("`axis$limits` must be a length-2 numeric.", call. = FALSE)
	}
	validate_scalar(width, "width", min = 0, inclusive = FALSE)
	if (!is.logical(invert) || length(invert) != 1 || is.na(invert)) {
		stop("`invert` must be `TRUE` or `FALSE`.", call. = FALSE)
	}

	block <- list(
		type = "forest",
		axis = axis,
		width = as.numeric(width),
		invert = invert
	)
	record_column_block(x, block, "add_forest")
}

#' @rdname add_events
#' @export
add_rate_difference <- function(x, conf_level = 0.95) {

	validate_class(x, "mesa")
	validate_scalar(conf_level, "conf_level", min = 0, max = 1, inclusive = FALSE)

	block <- list(type = "rate_difference", conf_level = as.numeric(conf_level))
	record_column_block(x, block, "add_rate_difference")
}

# The compute stage of the data-derived blocks ---------------------------------

#' Compute the data-derived statistics a spec's column blocks request
#'
#' The *compute* stage of realization. For an `events` block, stamps `events`
#' and `rate` onto every decorated row (reference rows included — the
#' reference level has events even though it has no estimate). For a
#' `rate_difference` block, stamps `rate_diff`/`rate_diff_low`/
#' `rate_diff_high` onto every row of each displayed term, the same value per
#' term — it is term-scoped, and the renderer gives it a column of its own.
#' Every combination of dataset, outcome, and term is computed once, resolved
#' through the models' `data_id` against the attached data.
#' @keywords internal
#' @noRd
compute_data_statistics <- function(dec, spec) {

	evBlock <- mesa_column_block(spec, "events")
	rdBlock <- mesa_column_block(spec, "rate_difference")
	if (is.null(evBlock) && is.null(rdBlock)) {
		return(dec)
	}
	if (is.null(evBlock)) {
		stop(
			"`add_rate_difference()` reads the follow-up time and person-years ",
			"recorded by `add_events()`; add `add_events()` to the specification.",
			call. = FALSE
		)
	}
	if (!requireNamespace("survival", quietly = TRUE)) {
		stop(
			"`add_events()` computes person-years through `survival::pyears()`. ",
			"Install the {survival} package to use it.",
			call. = FALSE
		)
	}

	datLs <- attr(spec$mdl_tbl, "dataList")

	dec$events <- NA_real_
	dec$rate <- NA_real_
	if (!is.null(rdBlock)) {
		dec$rate_diff <- NA_real_
		dec$rate_diff_low <- NA_real_
		dec$rate_diff_high <- NA_real_
	}

	combos <- unique(dec[c("data_id", "outcome", "variable")])
	for (i in seq_len(nrow(combos))) {

		id <- combos$data_id[i]
		outcome <- combos$outcome[i]
		variable <- combos$variable[i]

		dat <- if (!is.na(id)) datLs[[id]] else NULL
		if (is.null(dat)) {
			stop(
				"`add_events()` computes its statistics from the models' data, but ",
				"no attached dataset matches ",
				if (is.na(id)) "the models" else paste0("`", id, "`"),
				". Attach the fitting data with `attach_data()`.",
				call. = FALSE
			)
		}
		if (!evBlock$followup %in% names(dat)) {
			stop(
				"The follow-up column `", evBlock$followup, "` is not in the ",
				"attached dataset `", id, "`.",
				call. = FALSE
			)
		}
		event <- outcome_event_column(outcome, dat)
		if (!is.factor(dat[[variable]]) || nlevels(dat[[variable]]) < 2) {
			stop(
				"`add_events()` counts events per term level, but `", variable,
				"` is not a categorical (factor) column of the attached dataset `",
				id, "`.",
				call. = FALSE
			)
		}

		py <- survival::pyears(
			survival::Surv(dat[[evBlock$followup]], dat[[event]]) ~ dat[[variable]],
			scale = evBlock$scale
		)
		lvls <- levels(dat[[variable]])
		events <- as.numeric(py$event)
		persontime <- as.numeric(py$pyears) / evBlock$person_years
		rate <- events / persontime

		at <- which(
			!is.na(dec$data_id) & dec$data_id == id &
				dec$outcome == outcome & dec$variable == variable
		)
		hit <- match(dec$level[at], lvls)
		dec$events[at] <- events[hit]
		dec$rate[at] <- rate[hit]

		if (!is.null(rdBlock)) {
			if (length(lvls) != 2) {
				stop(
					"`add_rate_difference()` compares exactly 2 levels, but `",
					variable, "` has ", length(lvls), " levels in the attached ",
					"dataset `", id, "`.",
					call. = FALSE
				)
			}
			z <- stats::qnorm(1 - (1 - rdBlock$conf_level) / 2)
			est <- rate[2] - rate[1]
			se <- sqrt(events[2] / persontime[2]^2 + events[1] / persontime[1]^2)
			dec$rate_diff[at] <- est
			dec$rate_diff_low[at] <- est - z * se
			dec$rate_diff_high[at] <- est + z * se
		}
	}

	dec
}

#' Parse a `Surv()` outcome call into its time and event arguments
#'
#' `Surv(time, event)` and `Surv(time, time2, event)` are both accepted: the
#' event argument is the `event` argument if named, else the last argument;
#' the time argument is the `time` argument if named, else the first. Returns
#' `NULL` when `outcome` does not parse to a `Surv()` call — identity, never a
#' guess.
#' @keywords internal
#' @noRd
parse_surv_outcome <- function(outcome) {
	expr <- tryCatch(str2lang(outcome), error = function(e) NULL)
	if (!is.call(expr) ||
			!deparse1(expr[[1]]) %in% c("Surv", "survival::Surv")) {
		return(NULL)
	}
	args <- as.list(expr)[-1]
	event <- if (!is.null(args[["event"]])) args[["event"]] else args[[length(args)]]
	time <- if (!is.null(args[["time"]])) args[["time"]] else args[[1]]
	list(time = deparse1(time), event = deparse1(event))
}

#' The event-indicator column an outcome stands for
#'
#' A plain outcome names its own event column; a `Surv()` outcome carries its
#' event column as the `event` argument (or, unnamed, the last argument).
#' @keywords internal
#' @noRd
outcome_event_column <- function(outcome, dat) {

	if (outcome %in% names(dat)) {
		return(outcome)
	}

	surv <- parse_surv_outcome(outcome)
	if (!is.null(surv) && surv$event %in% names(dat)) {
		return(surv$event)
	}

	stop(
		"The outcome `", outcome, "` does not resolve to an event column of the ",
		"attached data, so `add_events()` cannot count its events.",
		call. = FALSE
	)
}

#' Infer the follow-up column from the mesa's `Surv()` outcome(s)
#'
#' `add_events(followup =)` can be inferred exactly when every outcome on the
#' mesa parses to a `Surv()` call (`parse_surv_outcome()`) and they all
#' name the same time argument; a plain outcome, or outcomes disagreeing on
#' the time column, return `NULL` so the caller requires an explicit
#' `followup`.
#' @keywords internal
#' @noRd
infer_followup_column <- function(mt) {
	outcomes <- unique(stats::na.omit(mt$outcome))
	surv <- lapply(outcomes, parse_surv_outcome)
	if (length(outcomes) == 0 || any(vapply(surv, is.null, logical(1)))) {
		return(NULL)
	}
	times <- unique(vapply(surv, `[[`, character(1), "time"))
	if (length(times) != 1) {
		return(NULL)
	}
	times
}

#' Record a column block, replacing an earlier block of the same type with a
#' message (the verb-replacement behavior every `<mesa>` verb shares)
#' @keywords internal
#' @noRd
record_column_block <- function(x, block, verb) {
	types <- vapply(x$columns, function(b) b$type, character(1))
	at <- which(types == block$type)
	if (length(at) > 0) {
		message("`", verb, "()` replaces the earlier ", block$type,
						" column block.")
		x$columns[[at[1]]] <- block
	} else {
		x$columns <- c(x$columns, list(block))
	}
	x
}

#' Retrieve a spec's column block by type
#' @keywords internal
#' @noRd
mesa_column_block <- function(x, type) {
	for (b in x$columns) {
		if (identical(b$type, type)) {
			return(b)
		}
	}
	NULL
}

#' A one-word-per-block description for the `<mesa>` print
#' @keywords internal
#' @noRd
describe_column_block <- function(b) {
	switch(
		b$type,
		estimates = paste0(
			"estimates (", paste(names(b$statistics), collapse = " + "), ")"
		),
		events = paste0("events + rate (per ", b$person_years, " person-years)"),
		rate_difference = "rate difference",
		forest = if (isTRUE(b$invert)) "forest (inverted)" else "forest",
		interaction = "interaction rows",
		b$type
	)
}
