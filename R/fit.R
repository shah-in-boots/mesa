#' @importFrom generics fit
#' @export
generics::fit

#' Fit the family of models a `fmls` object describes
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' Fitting happens in two steps: a *plan* is drawn up, then executed. The plan
#' crosses every formula in the family with every stratum level (from `.s()`
#' terms) and every subset instruction (from [subset_data()]), so one `fmls`
#' object can quietly describe dozens of models. The plan itself can be
#' inspected before anything is fit through [plan_fit()] — this is the "play"
#' step, where the shape of the analysis is visible before it runs.
#'
#' Failures are soft: if one model in a batch cannot be fit, it is recorded
#' with its error message (`fit_status` becomes `FALSE` in a downstream
#' [model_table()]) rather than sinking the rest of the fleet.
#'
#' @param object A `fmls` object
#'
#' @param .fn The modeling approach, given as any of:
#'
#'   - a fitting function, e.g. `lm` or `lme4::lmer`
#'
#'   - the name of a fitting function, e.g. `"glm"`
#'
#'   - a `{parsnip}` model specification, e.g.
#'   `parsnip::logistic_reg() |> parsnip::set_engine("glm")`, which lets any
#'   engine `{parsnip}` knows about serve as the modeling approach
#'
#' @param ... Additional arguments passed to the fitting function (e.g.
#'   `family = "binomial"`)
#'
#' @param data A `data.frame` containing the modeling variables
#'
#' @param raw A `logical`. When `FALSE` (default), returns a `mdl` vector
#'   that carries the causal context forward into [model_table()]. When
#'   `TRUE`, returns the list of fitted model objects as the fitting function
#'   made them (for `{parsnip}` specifications, the underlying engine fit).
#'
#' @return A `mdl` vector (when `raw = FALSE`, the default) or a `list` of
#'   models
#'
#' @export
fit.fmls <- function(object,
										 .fn,
										 ...,
										 data,
										 raw = FALSE) {

	cl <- match.call()
	dots <- list(...)

	# Resolve the modeling approach by name, not position
	engine <- resolve_fit_engine(.fn, cl[[".fn"]])

	# Check data. A bare name is a usable dataset id as-is (the common
	# `data = d` case); an inline expression (`data = subset(d, am == 1)`)
	# would deparse into an unusable id, so it takes a stable content-derived
	# one instead: `data_<hash>`, the same id the identical frame gets
	# anywhere else (e.g. `attach_data()`), so the two meet without the user
	# retyping anything
	stopifnot(is.data.frame(data))
	if (is.symbol(cl[["data"]])) {
		dataName <- deparse1(cl[["data"]])
	} else {
		dataName <- data_content_name(data)
		message(
			"The `data` argument is an expression, not a name; its models record ",
			"the dataset as `", dataName, "`."
		)
	}

	# Draw up the plan: formula x stratum x subset
	plan <- plan_fit(object, data = data)

	# Models to be returned
	if (raw) {
		ml <- list()
	} else {
		ml <- mdl()
	}

	for (i in seq_len(nrow(plan))) {

		# Prepare the data slice this model sees
		fitData <- data
		if (!is.na(plan$subset[i])) {
			keep <- rlang::eval_tidy(plan$subset_expr[[i]], data = fitData)
			fitData <- fitData[which(keep), ]
		}
		if (!is.na(plan$strata_variable[i])) {
			strataVar <- plan$strata_variable[i]
			strataLvl <- plan$strata_level[[i]]
			fitData <- fitData[which(fitData[[strataVar]] == strataLvl), ]
		}

		# Fit softly: an error becomes a record, not a stop
		x <- tryCatch(
			execute_fit(engine, plan$formula[[i]], fitData, dots, dataName),
			error = function(e) e
		)

		if (raw) {
			if (inherits(x, "error")) {
				warning(
					"Model ", i, " (", plan$formula_call[i], ") failed to fit: ",
					conditionMessage(x),
					call. = FALSE
				)
			}
			ml <- append(ml, list(x))
		} else {
			# One shape for the shared context: an error only swaps the model
			# object for its message
			context <- list(
				formulas = object[plan$formula_index[i], ],
				data_name = dataName,
				strata_variable = plan$strata_variable[i],
				strata_level = plan$strata_level[[i]],
				subset_name = plan$subset[i]
			)
			y <-
				if (inherits(x, "error")) {
					do.call(mdl, c(
						list(engine$name,
								 summary_info = list(error = conditionMessage(x))),
						context
					))
				} else {
					do.call(mdl, c(list(x), context))
				}
			ml <- c(ml, y)
		}
	}

	# Return the models in either list form or modified as `mdl`
	ml

}

#' Draw up the fitting plan for a family of formulas
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' Every call to [fit()] first builds a plan: one row per model that will be
#' fit, crossing each formula in the family with each stratum level of its
#' `.s()` terms and each subset instruction from [subset_data()]. Exposing the
#' plan lets the shape of an analysis be inspected — and played with — before
#' any model is run.
#'
#' A stratifying term must exist in `data` when data is supplied: a stratum
#' with no column would otherwise expand to zero levels and silently erase
#' every model of its formula from the plan, so the mismatch is an error
#' instead.
#'
#' @param object A `fmls` object
#'
#' @param data An optional `data.frame`; when supplied, stratum levels are
#'   enumerated from the data, otherwise they are left unresolved (`NA`)
#'
#' @param ... Arguments to be passed to or from other methods
#'
#' @return A `tbl_df` with one row per model to be fit and the columns
#'   `formula_index`, `formula_call`, `formula` (as a list), `strata_variable`,
#'   `strata_level` (as a list, since levels keep their native type),
#'   `subset`, and `subset_expr`
#'
#' @export
plan_fit <- function(object, data = NULL, ...) {

	# Global variables
	role <- NULL

	validate_class(object, "fmls")

	termList <- formulas_to_terms(object)
	inst <- attr(object, "instructions")
	subsets <- if (is.null(inst)) list() else inst$subsets

	rows <- list()
	for (i in seq_along(termList)) {

		t <- termList[[i]]
		f <- stats::as.formula(t)
		sta <- filter(t, role == "strata")

		# Stratum expansion: one row per level per stratifying term
		if (length(sta) == 0) {
			strataTbl <- tibble::tibble(
				strata_variable = NA_character_,
				strata_level = list(NA)
			)
		} else {
			strataRows <- list()
			for (j in seq_along(sta)) {
				strataVar <- as.character(sta[j])
				if (is.null(data)) {
					strataRows[[j]] <- tibble::tibble(
						strata_variable = strataVar,
						strata_level = list(NA)
					)
				} else {
					# A stratum without a column would expand to zero levels and
					# silently drop every model of this formula from the plan
					if (!strataVar %in% names(data)) {
						stop(
							"The stratifying term `", strataVar, "` is not a column of ",
							"`data`, so its models cannot be planned. Remove it with ",
							"`remove_strata()` or supply data that carries it.",
							call. = FALSE
						)
					}
					lvls <- unique(stats::na.omit(data[[strataVar]]))
					strataRows[[j]] <- tibble::tibble(
						strata_variable = strataVar,
						strata_level = as.list(lvls)
					)
				}
			}
			strataTbl <- dplyr::bind_rows(strataRows)
		}

		# Subset expansion: one row per instruction (none means the full data)
		if (length(subsets) == 0) {
			subsetTbl <- tibble::tibble(
				subset = NA_character_,
				subset_expr = list(NULL)
			)
		} else {
			subsetTbl <- tibble::tibble(
				subset = names(subsets),
				subset_expr = unname(subsets)
			)
		}

		rows[[i]] <-
			tidyr::expand_grid(
				tibble::tibble(
					formula_index = i,
					formula_call = deparse1(f),
					formula = list(f)
				),
				strataTbl,
				subsetTbl
			)
	}

	dplyr::bind_rows(rows)
}

#' Resolve the modeling approach from a function, name, or parsnip spec
#' @keywords internal
#' @noRd
resolve_fit_engine <- function(.fn, expr) {

	if (inherits(.fn, "model_spec")) {
		if (!requireNamespace("parsnip", quietly = TRUE)) {
			stop(
				"The {parsnip} package is required to fit model specifications.",
				call. = FALSE
			)
		}
		name <-
			if (!is.null(.fn$engine)) {
				.fn$engine
			} else {
				class(.fn)[1]
			}
		return(list(type = "parsnip", fn = .fn, name = name))
	}

	if (is.character(.fn) && length(.fn) == 1) {
		return(list(type = "function", fn = match.fun(.fn), name = .fn))
	}

	if (is.function(.fn)) {
		name <- sub("^.*::", "", deparse1(expr))
		return(list(type = "function", fn = .fn, name = name))
	}

	stop(
		"`.fn` should be a fitting function, the name of one, ",
		"or a {parsnip} model specification.",
		call. = FALSE
	)
}

#' Fit one model from the plan
#' @keywords internal
#' @noRd
execute_fit <- function(engine, f, fitData, dots, dataName) {

	if (engine$type == "parsnip") {
		fitted <- do.call(
			parsnip::fit,
			c(list(engine$fn, formula = f, data = fitData), dots)
		)
		x <- parsnip::extract_fit_engine(fitted)
	} else {
		args <- c(list(formula = f), dots)
		args$data <- quote(fitData)
		x <- do.call(engine$fn, args = args)
	}

	# Normalize the recorded call so models compare cleanly: the fitting
	# function appears by name (not as an inlined closure from `do.call()`)
	# and the data by its name rather than an embedded copy; S4 fits
	# (e.g. merMod) are handled through their call slot
	x <- tryCatch({
		if (isS4(x)) {
			cl <- x@call
			cl[[1]] <- as.name(engine$name)
			cl[["data"]] <- as.name(dataName)
			if (!is.null(cl[["formula"]])) {
				cl[["formula"]] <- str2lang(deparse1(cl[["formula"]]))
			}
			x@call <- cl
		} else {
			x$call[[1]] <- as.name(engine$name)
			x$call[["formula"]] <- str2lang(deparse1(x$call[["formula"]]))
			x$call[["data"]] <- as.name(dataName)
		}
		x
	}, error = function(e) x)

	x
}

#' @importFrom generics tidy
#' @export
generics::tidy

#' Create a "fail-safe" of tidying fits
#'
#' Estimates are stored on the linear scale, always; exponentiation is
#' deferred to [flatten_models()], so no `exponentiate` argument is offered.
#' @noRd
my_tidy <- function(x,
										conf.int = TRUE,
										conf.level = 0.95,
										...) {
	broom::tidy(x,
							conf.int = conf.int,
							conf.level = conf.level,
							exponentiate = FALSE) |>
		dplyr::rename_with(.fn = ~ gsub("\\.", "_", x = .x))
}

#' Local load of it if not when package starts
#' @noRd
possible_tidy <-
	purrr::possibly(my_tidy, otherwise = NA, quiet = FALSE)

#' @importFrom generics glance
#' @export
generics::glance

#' Create a "fail-safe" of glance at fits
#' @noRd
my_glance <- function(x, ...) {
	broom::glance(x) |>
		dplyr::rename_with(.fn = ~ gsub("\\.", "_", x = .x))
}

#' Local load of it if not when package starts
#' @noRd
possible_glance <-
	purrr::possibly(my_glance, otherwise = NA, quiet = FALSE)
