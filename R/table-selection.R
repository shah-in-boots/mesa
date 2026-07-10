# The selection resolver (M6.2) -----------------------------------------------
#
# One internal engine, shared by every table verb and run when a table
# specification is realized. It answers two questions about a `mdl_tbl`:
#
#   1. which model *rows* survive the outcome, exposure, strata, and
#      adjustment-set filters, and
#   2. which tidy-term *keys* each requested term covers.
#
# Both answers are exact. Names are matched against the `outcome`/`exposure`
# provenance columns and the term table by identity, never by `grepl()`
# substring — so selecting `am` never drags in `gam`, and `wt` never drags in
# `wt2`. Categorical term levels (`cyl6`, `cyl8`) resolve through the
# variable-level relationship carried by the term table (stamped from the
# attached data), not by string prefixing.
#
# Adjustment-set identity is the *sequential model index* within an
# outcome x exposure family, so two models that happen to share a right-hand
# side term count no longer collide (the raw `number` column did).

#' Normalize a selection input to a named list
#'
#' Accepts the documented labeled-formula inputs (a `formula`, a `list` of
#' formulas, or a `character` vector) through the single
#' [labeled_formulas_to_named_list()] mechanism; `NULL` (and the empty
#' `formula()` default the old table functions used) means "no filter".
#' @keywords internal
selection_input <- function(x) {
	if (is.null(x)) {
		return(list())
	}
	labeled_formulas_to_named_list(x)
}

#' The sequential adjustment index of every model row
#'
#' Within an outcome x exposure (x strata x level x subset x data x model)
#' family, models are ordered by their adjustment degree (`number`, ties
#' broken by row order) and numbered `1, 2, 3, ...`. This index — not the raw
#' term count — is the identity an adjustment set is selected by, so models
#' with equal term counts stay distinct.
#' @return An integer vector, one entry per row of `x`.
#' @keywords internal
family_adjustment_index <- function(x) {

	naTo <- function(v) ifelse(is.na(v), ".NA", as.character(v))
	fam <- paste(
		naTo(x$outcome), naTo(x$exposure), naTo(x$strata), naTo(x$level),
		naTo(x$subset), naTo(x$data_id), naTo(x$model_call),
		sep = "\r"
	)

	idx <- integer(nrow(x))
	for (g in unique(fam)) {
		rows <- which(fam == g)
		# Order by adjustment degree, breaking ties by original row order so the
		# sequence is deterministic even when term counts collide
		ord <- rows[order(x$number[rows], seq_along(rows))]
		idx[ord] <- seq_along(ord)
	}
	idx
}

#' Resolve requested terms to their metadata and exact keys
#'
#' @param x A `mdl_tbl` object.
#' @param tmSel A named list (from [selection_input()]) of requested terms; the
#'   names are variables in the term table, the values are display labels.
#' @return A `tibble`, one row per requested term, carrying its role, label,
#'   type, distribution, observed levels, reference level, and the exact
#'   tidy-term keys it covers.
#' @keywords internal
resolve_term_metadata <- function(x, tmSel) {

	# The term table carries the variable-level relationship; stamp it from the
	# attached data so categorical levels are known (the fit pipeline leaves
	# them empty). Each term takes its levels from the first dataset -- in
	# reference order -- that carries its column, so models spanning several
	# datasets each find their own terms stamped. Datasets the rows reference
	# come first (in row order); attached-but-unreferenced datasets follow as
	# fallbacks
	datLs <- attr(x, "dataList")
	referenced <- unique(stats::na.omit(x$data_id))
	hit <- referenced[referenced %in% names(datLs)]
	tmTab <- vec_restore(attr(x, "termTable"), to = tm())
	seen <- character()
	for (data in datLs[c(hit, setdiff(names(datLs), hit))]) {
		newCols <- setdiff(names(data), seen)
		if (length(newCols) > 0) {
			tmTab <- set_data(tmTab, data[newCols])
			seen <- c(seen, newCols)
		}
	}
	proxy <- vec_proxy(tmTab)

	empty <- tibble::tibble(
		variable = character(),
		role = character(),
		label = character(),
		type = character(),
		distribution = character(),
		levels = list(),
		reference = character(),
		keys = list()
	)
	if (length(tmSel) == 0) {
		return(empty)
	}

	# Every requested variable must exist in the term table — exact identity,
	# so a typo or a substring collision errors instead of silently matching
	requested <- names(tmSel)
	unknown <- setdiff(requested, proxy$term)
	if (length(unknown) > 0) {
		stop(
			"No term matches ", paste0("`", unknown, "`", collapse = ", "),
			". The table's terms are: ",
			paste0("`", unique(proxy$term), "`", collapse = ", "), ".",
			call. = FALSE
		)
	}

	rows <- lapply(requested, function(v) {
		row <- proxy[proxy$term == v, , drop = FALSE][1, , drop = FALSE]
		lvls <- row$level[[1]]
		if (is.null(lvls)) {
			lvls <- character()
		}
		label <- tmSel[[v]]
		label <-
			if (length(label) > 0 && !is.na(label[1]) && nzchar(label[1]) &&
					!identical(as.character(label[1]), v)) {
				as.character(label[1])
			} else if (!is.na(row$label) && nzchar(row$label)) {
				row$label
			} else {
				v
			}
		# The tidy-term keys: a continuous term is its own key; a categorical
		# term keeps its bare name *and* gains one key per non-reference level
		# (`paste0(term, level)`, the treatment-contrast naming `broom::tidy()`
		# produces). The bare name is always kept so a dichotomous variable
		# modeled numerically (tidy term `am`) resolves as readily as one
		# modeled as a factor (tidy term `am1`)
		keys <- if (length(lvls) > 1) {
			unique(c(v, paste0(v, lvls[-1])))
		} else {
			v
		}
		tibble::tibble(
			variable = v,
			role = as.character(row$role),
			label = label,
			type = as.character(row$type),
			distribution = as.character(row$distribution),
			levels = list(lvls),
			reference = if (length(lvls) > 0) lvls[1] else NA_character_,
			keys = list(keys)
		)
	})

	do.call(rbind, rows)
}

#' Ensure requested names exist in a provenance column
#' @keywords internal
validate_selection_present <- function(requested, available, what) {
	available <- unique(stats::na.omit(available))
	missing <- setdiff(requested, available)
	if (length(missing) > 0) {
		stop(
			"No models have the ", what, " ",
			paste0("`", missing, "`", collapse = ", "), ". ",
			"Available ", what, ": ",
			if (length(available) > 0) {
				paste0("`", available, "`", collapse = ", ")
			} else {
				"none"
			},
			".", call. = FALSE
		)
	}
	invisible(TRUE)
}

#' Resolve a table selection against a model table
#'
#' The shared engine behind every table verb: filter a `mdl_tbl` by outcome,
#' exposure, strata, and adjustment set, and resolve the requested terms to the
#' exact tidy-term keys they cover. All matching is by identity — against the
#' `outcome`/`exposure` columns and the term table — never `grepl()`.
#'
#' @param x A `mdl_tbl` object.
#' @param outcomes,exposures,terms,adjustment,strata Selection instructions in
#'   the documented labeled-formula forms (see
#'   [labeled_formulas_to_named_list()]); `NULL` leaves that dimension
#'   unfiltered. `adjustment` selects by the sequential adjustment index (see
#'   [family_adjustment_index()]), so its left-hand sides are integers.
#'
#' @return A `mesa_selection` object (a list) with: `models`, the filtered
#'   `mdl_tbl`; `adjustment_index`, the sequential index aligned to those rows;
#'   `terms`, the resolved-term metadata tibble; `term_keys`, the union of
#'   exact tidy-term keys (or `NULL` when no terms were requested); and
#'   `labels`, the recorded labels for each dimension.
#' @keywords internal
resolve_selection <- function(x,
															outcomes = NULL,
															exposures = NULL,
															terms = NULL,
															adjustment = NULL,
															strata = NULL) {

	validate_class(x, "mdl_tbl")

	outSel <- selection_input(outcomes)
	expSel <- selection_input(exposures)
	tmSel <- selection_input(terms)
	adjSel <- selection_input(adjustment)
	staSel <- selection_input(strata)

	# Sequential adjustment index over the whole table, before any filtering,
	# so an adjustment set keeps its identity regardless of the other filters
	adjIdx <- family_adjustment_index(x)

	# Row filter: exact membership against the provenance columns
	keep <- rep(TRUE, nrow(x))

	if (length(outSel) > 0) {
		validate_selection_present(names(outSel), x$outcome, "outcome")
		keep <- keep & x$outcome %in% names(outSel)
	}
	if (length(expSel) > 0) {
		validate_selection_present(names(expSel), x$exposure, "exposure")
		keep <- keep & x$exposure %in% names(expSel)
	}
	if (length(staSel) > 0) {
		validate_selection_present(names(staSel), x$strata, "strata")
		keep <- keep & x$strata %in% names(staSel)
	}
	if (length(adjSel) > 0) {
		wanted <- as.integer(names(adjSel))
		# Validate against the indices actually available among the rows the
		# other filters have kept, so the message names real adjustment sets
		availIdx <- sort(unique(adjIdx[keep]))
		badIdx <- setdiff(wanted, availIdx)
		if (length(badIdx) > 0) {
			stop(
				"No adjustment set numbered ",
				paste(badIdx, collapse = ", "),
				" is available. Adjustment sets run 1\u2013", max(availIdx),
				" within each outcome \u00d7 exposure family.",
				call. = FALSE
			)
		}
		keep <- keep & adjIdx %in% wanted
	}

	# Resolve terms from the full table (metadata is independent of the row
	# filter), then keep only the surviving rows for the models themselves
	resolvedTerms <- resolve_term_metadata(x, tmSel)
	termKeys <-
		if (nrow(resolvedTerms) > 0) {
			unique(unlist(resolvedTerms$keys))
		} else {
			NULL
		}

	models <- x[keep, , drop = FALSE]

	structure(
		list(
			models = models,
			adjustment_index = adjIdx[keep],
			terms = resolvedTerms,
			term_keys = termKeys,
			labels = list(
				outcomes = outSel,
				exposures = expSel,
				terms = tmSel,
				adjustment = adjSel,
				strata = staSel
			)
		),
		class = "mesa_selection"
	)
}

#' Match tidy-term names to their resolved variable
#'
#' Given the tidy-term names present after flattening and a resolved-term
#' tibble (from [resolve_term_metadata()]), returns the variable each tidy term
#' belongs to (exact key membership) or `NA` when it belongs to none. This is
#' how a table's parameter rows are kept and grouped without `grepl()`.
#' @keywords internal
match_term_keys <- function(tidyTerms, resolvedTerms) {
	if (nrow(resolvedTerms) == 0) {
		return(rep(NA_character_, length(tidyTerms)))
	}
	lookup <- character()
	for (i in seq_len(nrow(resolvedTerms))) {
		keys <- resolvedTerms$keys[[i]]
		lookup[keys] <- resolvedTerms$variable[i]
	}
	unname(lookup[tidyTerms])
}
