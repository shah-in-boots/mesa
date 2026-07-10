# Pattern registry -------------------------------------------------------------

# Patterns are a small open grammar: each is a function `tm -> tbl_df`
# conforming to the contract documented in `apply_pattern()`. The registry
# is the authoritative lookup, so new patterns can be added without touching
# `fmls()` itself.
.pattern_registry <- new.env(parent = emptyenv())

#' Register a formula expansion pattern
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' Patterns are the rules by which a set of terms expands into a family of
#' formulas. Each pattern is a function that takes a `tm` vector and returns a
#' `tbl_df` precursor table (see [apply_pattern()] for the contract). The
#' built-in patterns (`r paste(.patterns, collapse = ", ")`) are registered
#' this way; user-defined patterns can join them and become available to
#' [fmls()] by name.
#'
#' @param name A single string naming the pattern
#'
#' @param fn A function accepting a `tm` vector and returning a `tbl_df` that
#'   follows the pattern contract
#'
#' @return The pattern name, invisibly
#'
#' @examples
#' # A pattern that ignores covariates entirely
#' unadjusted <- function(x) {
#'   apply_fundamental_pattern(x)
#' }
#' register_pattern("unadjusted", unadjusted)
#' "unadjusted" %in% formula_patterns()
#'
#' @export
register_pattern <- function(name, fn) {
	checkmate::assert_string(name)
	checkmate::assert_function(fn)
	assign(name, fn, envir = .pattern_registry)
	invisible(name)
}

#' @rdname vocabulary
#' @export
formula_patterns <- function() {
	sort(ls(.pattern_registry))
}

# Basic patterns ---------------------------------------------------------------

#' Apply patterns to formulas
#'
#' The family of `apply_*_pattern()` functions that are used to expand `fmls`
#' by specified patterns. These functions are not intended to be used directly
#' but as internal functions. They have been exposed to allow for potential
#' user-defined use cases, and new patterns can be added through
#' [register_pattern()].
#'
#' Built-in patterns are: `r paste(.patterns, collapse = ", ")`.
#'
#' @return Returns a `tbl_df` object that has special column names and rows.
#'   Each row is essentially a precursor to a new formula.
#'
#'   These columns and rows must be present to be used with the `fmls()`
#'   function, and generally are the expected result of the specified pattern.
#'   They will undergo further internal modification prior to being turned into
#'   a `fmls` object, but this is an developer consideration. If developing a
#'   pattern, please use this guide to ensure that the output is compatible with
#'   the `fmls()` function.
#'
#'   - outcome: a single term that is the expected outcome variable
#'
#'   - exposure: a single term that is the expected exposure variable, which may not be present in every row
#'
#'   - covariate_*: the covariates expand based on the number that are present (e.g. "covariate_1", "covariate_2", etc)
#'
#' @param x A `tm` object
#' @param pattern A character string that specifies the pattern to use
#' @name patterns
#' @export
apply_pattern <- function(x, pattern) {

	# Only accept objects as `tm` objects
	validate_class(x, "tm")

	# Look the pattern up in the registry
	if (!pattern %in% ls(.pattern_registry)) {
		stop(
			"Pattern '",
			pattern,
			"' is not registered. Available patterns: ",
			paste(formula_patterns(), collapse = ", "),
			". See `register_pattern()` to add one.",
			call. = FALSE
		)
	}

	patternFn <- get(pattern, envir = .pattern_registry)
	patternFn(x)
}

#' The terms of each causal role, pulled once from a term table
#' @keywords internal
#' @noRd
pattern_roles <- function(tmTab) {
	roles <- c("outcome", "exposure", "predictor", "confounder",
						 "mediator", "interaction", "strata")
	stats::setNames(
		lapply(roles, function(r) tmTab$term[tmTab$role == r]),
		roles
	)
}

#' The outcome x exposure "key pair" grid every pattern expands from
#' @keywords internal
#' @noRd
key_pair_grid <- function(out, exp) {
	if (length(out) > 0 && length(exp) > 0) {
		tidyr::expand_grid(outcome = out, exposure = exp)
	} else if (length(out) > 0) {
		tidyr::expand_grid(outcome = out)
	} else if (length(exp) > 0) {
		tidyr::expand_grid(exposure = exp)
	} else {
		tidyr::expand_grid()
	}
}

#' @rdname patterns
#' @export
apply_fundamental_pattern <- function(x) {

	# Term table
	tmTab <- vec_proxy(x)

	# Handle roles
	out <- tmTab$term[tmTab$role == "outcome"]
	exp <- tmTab$term[tmTab$role == "exposure"]

	# Fundamental decomposition pairs each outcome with exactly one
	# right-hand-side term per formula. The exposure keeps its key-pair
	# column; every other non-outcome term takes a row as the single
	# covariate. (Meta terms are demoted to predictors by `fmls()` before
	# this pattern runs, so they decompose like any other term.)
	cov <- tmTab$term[!tmTab$role %in% c("outcome", "exposure")]

	pair <- function(col, terms) {
		if (length(terms) == 0) {
			return(NULL)
		}
		if (length(out) > 0) {
			tidyr::expand_grid(outcome = out, "{col}" := terms)
		} else {
			tibble::tibble("{col}" := terms)
		}
	}

	tbl <- dplyr::bind_rows(pair("exposure", exp), pair("covariate_1", cov))
	if (nrow(tbl) == 0) {
		tbl <- tidyr::expand_grid(outcome = out)
	}

	# Return
	tbl

}


#' @rdname patterns
#' @export
apply_direct_pattern <- function(x) {

	# Roles
	roles <- pattern_roles(vec_proxy(x))

	# Outcomes and exposures should be set as a "key pair"
	tbl <- key_pair_grid(roles$outcome, roles$exposure)

	# Covariates would be everything
	cov <- c(roles$predictor, roles$confounder, roles$interaction)

	if (length(cov) > 0) {
		for (i in seq_along(cov)) {
			tbl <-
				tidyr::expand_grid(tbl, "{paste0('covariate_', i)}" := cov[i])
		}
	}

	# Return
	tbl
}

#' @rdname patterns
#' @export
apply_sequential_pattern <- function(x) {

	# Roles
	roles <- pattern_roles(vec_proxy(x))

	# Outcomes and exposures should be set as a "key pair"
	tbl <- key_pair_grid(roles$outcome, roles$exposure)

	## Covariate order
	# Covariates are all predictors on RHS
	# They need to be the same order as the original terms however
	# Cool enough, 'x' as a `tm` works for matching as a `character`
	# Interaction terms should be placed next to each other

	cov <- c(roles$predictor, roles$confounder, roles$interaction)
	cov <- cov[order(match(cov, x))]
	n <- length(cov)

	if (n == 0) {
		return(tbl)
	}

	# The sequential family is the covariate prefixes — {}, {c1}, {c1, c2},
	# ... — built directly, one row per prefix; the bare key-pair row only
	# stands when an exposure anchors it
	prefixes <- seq(if ("exposure" %in% names(tbl)) 0 else 1, n)
	covTbl <-
		dplyr::bind_rows(lapply(prefixes, function(k) {
			vals <- as.list(c(cov[seq_len(k)], rep(NA_character_, n - k)))
			names(vals) <- paste0("covariate_", seq_len(n))
			tibble::as_tibble(vals)
		}))

	tidyr::expand_grid(tbl, covTbl)
}

#' @rdname patterns
#' @export
apply_parallel_pattern <- function(x) {

	# Term table (the grouping tiers below need more than the role names)
	tmTab <- vec_proxy(x)
	roles <- pattern_roles(tmTab)

	# Outcomes and exposures should be set as a "key pair"
	tbl <- key_pair_grid(roles$outcome, roles$exposure)

	# This needs to handle the issue of grouped variables
	# Group = NA generic variables that can be parallelized
	# Group = set(0, inf) integers that must be placed together
	#   Covariate columns = max(group != NA)
	groupLevels <- with(tmTab, unique(group[!is.na(group)]))
	groupedCov <- list()
	for (g in groupLevels) {
	  groupedCov[[as.character(g)]] <-
	    with(tmTab, term[group == g & role != "exposure" & !is.na(group)])
	}

	# Ungrouped variables
	ungroupedCov <-
	  with(tmTab, term[side == "right" & role != "exposure" & is.na(group)]) |>
	  as.list()

	# Covariates
	covList <- c(ungroupedCov, groupedCov)

	tabList <- list()
	for (i in seq_along(covList)) {
	  cov <- covList[[i]]
	  rowList <- list()
	  for (j in seq_along(cov)) {
	    rowList[[j]] <-
	      #tidyr::expand_grid(tbl, "{paste0('covariate_', j)}" := cov[[j]])
	      #tibble::add_column(tbl, "{paste0('covariate_', j)}" := cov[[j]])
	      tibble::tibble("{paste0('covariate_', j)}" := cov[[j]])
	  }
	  tabList[[i]] <- dplyr::bind_cols(rowList)
	}

	tbl <-
	  tidyr::expand_grid(tbl, dplyr::bind_rows(tabList))

	# Return
	tbl
}

# Registration of built-in patterns ---------------------------------------------

register_pattern("fundamental", apply_fundamental_pattern)
register_pattern("direct", apply_direct_pattern)
register_pattern("sequential", apply_sequential_pattern)
register_pattern("parallel", apply_parallel_pattern)

