# The selection resolver (M6.2) -----------------------------------------------
#
# One internal engine, shared by every table verb and run when a table
# specification is realized. It answers two questions about a `mdl_tbl`:
#
#   1. which model *rows* survive the adjustment-set filter (narrowing by
#      outcome, exposure, or strata happens upstream, on the `mdl_tbl`
#      itself, before `mdl_gt()`), and
#   2. which tidy-term *keys* each requested term covers.
#
# Both answers are exact. Names are matched against the `outcome`/`exposure`
# provenance columns and the term table by identity, never by `grepl()`
# substring — so selecting `am` never drags in `gam`, and `wt` never drags in
# `wt2`. Categorical term levels (`cyl6`, `cyl8`) resolve through the
# variable-level relationship carried by the term table (stamped from the
# attached data), not by string prefixing.
#
# Adjustment-set identity is the *actual covariate set*: each distinct set
# is one rung, and related families sharing a ladder share rung numbers, so
# their rows align on the mesa by the covariates themselves rather than by
# position (`adjustment_sets()` displays the mapping).

#' The resolved `<mdl_gt>` selection
#'
#' A plain data record produced by [resolve_selection()] and read by the
#' realizers. It sits at the opposite end of the S7 spectrum from `<mdl_gt>`:
#' where the spec is a rich object (custom constructor, validator, verbs), this
#' is a *value* -- all typed properties, no behavior. It earns its S7 keep by
#' letting `resolve_selection()` return one self-documenting, type-checked
#' object instead of a bare list, and it needs neither a hand-written
#' constructor nor a validator: S7 generates the constructor from the
#' properties, and there are no cross-field invariants to guard.
#' @include table-spec.R
#' @keywords internal
#' @noRd
mdl_gt_selection <- S7::new_class(
	"mdl_gt_selection",
	package = "epigram",
	properties = list(
		models           = S7_mdl_tbl,
		adjustment_index = S7::class_integer,
		terms            = S7::class_data.frame,
		# `NULL` when no terms were requested, else a character vector of keys
		term_keys        = S7::class_any,
		labels           = S7::class_list
	)
)

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

#' The adjustment-set index of every model row
#'
#' Each distinct adjustment set — the covariates a model carries beyond its
#' outcome, exposure, mediator, and meta terms — is one rung, numbered by set
#' size and then order of first appearance. The index is the *identity* of
#' the set, not its position within a family: models carrying the same
#' covariates share a rung wherever they sit (so related families' rows align
#' on the mesa by the actual adjustment), and different sets never collide,
#' even at equal term counts. [adjustment_sets()] displays the mapping.
#' @return An integer vector, one entry per row of `x`.
#' @keywords internal
adjustment_set_index <- function(x) {

	fam <- identify_families(model_table_formulas(x))
	if (nrow(fam) == 0) {
		return(integer())
	}

	sig <- vapply(fam$covariates, paste, character(1), collapse = "\r")
	first <- !duplicated(sig)
	sizes <- lengths(fam$covariates)[first]
	rungs <- sig[first][order(sizes, seq_along(sizes))]
	match(sig, rungs)
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

#' Resolve a table selection against a model table
#'
#' The shared engine behind every table verb: filter a `mdl_tbl` by adjustment
#' set and resolve the requested terms to the exact tidy-term keys they cover.
#' All matching is by identity — against the term table — never `grepl()`.
#' (Narrowing by outcome, exposure, or strata is the `mdl_tbl`'s own job,
#' before `mdl_gt()`.)
#'
#' @param x A `mdl_tbl` object.
#' @param terms,adjustment Selection instructions in the documented
#'   labeled-formula forms (see [labeled_formulas_to_named_list()]); `NULL`
#'   leaves that dimension unfiltered. `adjustment` selects by the
#'   adjustment-set index (see [adjustment_set_index()]; [adjustment_sets()]
#'   displays it), so its left-hand sides are integers.
#'
#' @return A `mdl_gt_selection` object (a list) with: `models`, the filtered
#'   `mdl_tbl`; `adjustment_index`, the sequential index aligned to those rows;
#'   `terms`, the resolved-term metadata tibble; `term_keys`, the union of
#'   exact tidy-term keys (or `NULL` when no terms were requested); and
#'   `labels`, the recorded labels for each dimension.
#' @keywords internal
resolve_selection <- function(x,
															terms = NULL,
															adjustment = NULL) {

	validate_class(x, "mdl_tbl")

	tmSel <- selection_input(terms)
	adjSel <- selection_input(adjustment)

	# Adjustment-set index over the whole table, before any filtering, so an
	# adjustment set keeps its identity regardless of the other filters
	adjIdx <- adjustment_set_index(x)

	# Row filter: adjustment-set membership
	keep <- rep(TRUE, nrow(x))

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
				" is available. The adjustment sets on this mesa are numbered ",
				"1\u2013", max(availIdx), " by their covariate sets; ",
				"`adjustment_sets()` shows them.",
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

	# S7 generates this constructor from the properties above; it type-checks
	# each slot as it builds (`models` really is a `mdl_tbl`, and so on).
	mdl_gt_selection(
		models = models,
		adjustment_index = adjIdx[keep],
		terms = resolvedTerms,
		term_keys = termKeys,
		labels = list(
			terms = tmSel,
			adjustment = adjSel
		)
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
