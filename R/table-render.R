# Realizing and rendering the <mesa> (M6.3) -----------------------------------
#
# A `<mesa>` specification carries instructions; realization runs them against
# the `mdl_tbl`. `realize_mesa()` performs the first two stages of the grammar
# — *select* (through the M6.2 resolver) and *decorate* (join each estimate row
# with its term metadata, and inject a reference row for every categorical
# term) — and returns the decorated long tibble that later stages consume. The
# full cell-frame layout, the column blocks, and the forest/group-scoped
# machinery arrive with M6.4–6.9; `as_gt()` here is the minimal renderer that
# makes the grammar usable from the first verb (estimate + confidence interval).

#' Render a `<mesa>` specification to a `{gt}` table
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' `as_gt()` realizes a [mesa()] specification: it resolves the recorded
#' selection against the model table, decorates each estimate with its term
#' metadata, and emits a `{gt}` table. On a bare specification it renders a
#' minimal default — each displayed term's point estimate and 95% confidence
#' interval, with adjustment sets on rows and outcomes as row groups.
#'
#' @param x A `<mesa>` specification (from [mesa()])
#' @param ... Passed to methods
#'
#' @return A `gt_tbl` object.
#'
#' @seealso [mesa()]
#' @export
as_gt <- function(x, ...) {
	UseMethod("as_gt")
}

#' @rdname as_gt
#' @export
as_gt.mesa <- function(x, ...) {

	dec <- realize_mesa(x)
	render_minimal(dec, x)
}

# Realization -----------------------------------------------------------------

#' Realize a `<mesa>` to its decorated estimate rows
#'
#' Runs the *select* and *decorate* stages of the grammar. Returns a long
#' tibble with one row per displayed estimate, plus an injected reference row
#' for each categorical term, carrying the metadata the layout stages need:
#' the causal role, the term and level labels, the level and reference flags,
#' the adjustment-set index and label, and the estimate itself.
#' @keywords internal
#' @noRd
realize_mesa <- function(x) {

	validate_class(x, "mesa")
	mt <- x$mdl_tbl

	# Stage 1 — select: filter the models and resolve the requested terms
	sel <- resolve_selection(
		mt,
		outcomes = x$selection$outcomes,
		exposures = x$selection$exposures,
		terms = x$selection$terms,
		adjustment = x$selection$adjustment,
		strata = x$selection$strata
	)
	models <- sel$models
	if (nrow(models) == 0) {
		stop("No models on the mesa match the current selection.", call. = FALSE)
	}

	# The terms whose estimates become columns: an explicit `select_terms()`,
	# else the exposures, else every non-outcome term the models carry
	displayTerms <- mesa_display_terms(mt, x$selection, sel)
	if (nrow(displayTerms) == 0) {
		stop(
			"Nothing to display: no terms were selected and the models declare ",
			"no exposure. Use `select_terms()` to choose the terms to show.",
			call. = FALSE
		)
	}

	# Estimates on the inferred scale (Cox / logit families exponentiate); the
	# decision is carried in `exponentiated`, so the message is redundant here
	flat <- suppressMessages(flatten_models(models))
	# `level` in a flattened row is the model's stratum level; free the name for
	# the term's factor level, which decoration adds next
	flat$stratum_level <- flat$level
	flat$level <- NULL
	# A model whose tidy output lacked intervals or a p-value should still slot
	# in; fill the estimate columns the layout stages read
	for (col in c("estimate", "conf_low", "conf_high", "p_value")) {
		if (!col %in% names(flat)) flat[[col]] <- NA_real_
	}
	if (!"nobs" %in% names(flat)) flat$nobs <- NA_integer_
	if (!"exponentiated" %in% names(flat)) flat$exponentiated <- NA

	# Keep only the parameter rows that belong to a displayed term (exact key
	# membership, never `grepl()`), and stamp on the variable each maps to
	flat$variable <- match_term_keys(flat$term, displayTerms)
	flat <- flat[!is.na(flat$variable), , drop = FALSE]
	if (nrow(flat) == 0) {
		stop(
			"The selected terms have no estimates among the selected models.",
			call. = FALSE
		)
	}

	# The sequential adjustment index is a per-model property; carry it onto the
	# parameter rows by matching each row back to its model (by identity, so
	# colliding term counts stay distinct)
	lookupKey <- model_identity_key(
		models$data_id, models$model_call, models$outcome, models$exposure,
		models$strata, models$level, models$subset, models$formula_call
	)
	flatKey <- model_identity_key(
		flat$data_id, flat$model_call, flat$outcome, flat$exposure,
		flat$strata, flat$stratum_level, flat$subset, flat$formula_call
	)
	flat$adj_index <- sel$adjustment_index[match(flatKey, lookupKey)]

	# Stage 2 — decorate: join term metadata and derive the factor level a key
	# stands for
	meta <- tibble::tibble(
		variable = displayTerms$variable,
		role = displayTerms$role,
		term_label = displayTerms$label,
		reference = displayTerms$reference,
		levels = displayTerms$levels,
		categorical = lengths(displayTerms$levels) > 1
	)
	dec <- dplyr::left_join(flat, meta, by = "variable")
	dec$level <- vapply(seq_len(nrow(dec)), function(i) {
		key_to_level(dec$variable[i], dec$term[i], dec$levels[[i]])
	}, character(1))
	dec$is_reference <- FALSE

	# Inject a reference row for every categorical term in every model context,
	# generalizing `tbl_beta`'s `_ref` column: the reference level carries no
	# estimate but holds the term's place among its levels
	refRows <- inject_reference_rows(dec)
	dec <- dplyr::bind_rows(dec, refRows)

	# Labels: outcomes and adjustment sets from the recorded selection; terms and
	# levels from `modify_labels()`
	dec <- apply_context_labels(dec, sel)
	dec <- apply_relabels(dec, x$labels$relabels)

	# A stable ordering for downstream layout: outcome, stratum, subset,
	# adjustment index, then term and level (reference level first)
	dec <- dec[order(
		dec$outcome_label,
		naToBlank(dec$strata), naToBlank(dec$stratum_level),
		naToBlank(dec$subset), dec$adj_index,
		match(dec$variable, unique(displayTerms$variable)),
		!dec$is_reference, naToBlank(dec$level)
	), , drop = FALSE]

	tibble::as_tibble(dec)
}

#' The terms whose estimates a mesa displays
#'
#' An explicit `select_terms()` wins; otherwise the models' exposures are
#' shown; failing that (models with no declared exposure), every non-outcome,
#' non-meta term in the term table.
#' @keywords internal
#' @noRd
mesa_display_terms <- function(mt, selection, sel) {

	if (!is.null(selection$terms)) {
		return(sel$terms)
	}

	exposures <- unique(stats::na.omit(sel$models$exposure))
	if (length(exposures) > 0) {
		return(resolve_term_metadata(
			mt, stats::setNames(as.list(exposures), exposures)
		))
	}

	proxy <- vec_proxy(term_table(mt))
	keep <- proxy$role != "outcome"
	if ("side" %in% names(proxy)) {
		keep <- keep & proxy$side != "meta"
	}
	vars <- unique(proxy$term[keep])
	if (length(vars) == 0) {
		return(resolve_term_metadata(mt, list()))
	}
	resolve_term_metadata(mt, stats::setNames(as.list(vars), vars))
}

#' A per-model identity key, matching the resolver's family grouping plus the
#' formula, so parameter rows can be joined back to their model
#' @keywords internal
#' @noRd
model_identity_key <- function(data_id, model_call, outcome, exposure,
															 strata, level, subset, formula_call) {
	naTo <- function(v) ifelse(is.na(v), ".NA", as.character(v))
	paste(
		naTo(data_id), naTo(model_call), naTo(outcome), naTo(exposure),
		naTo(strata), naTo(level), naTo(subset), naTo(formula_call),
		sep = "\r"
	)
}

#' The factor level a tidy-term key stands for
#'
#' Continuous (and dichotomous-numeric) terms have no level. A categorical
#' term's non-reference level keys are `paste0(variable, level)`; the reference
#' level never appears as a fitted key.
#' @keywords internal
#' @noRd
key_to_level <- function(variable, key, levels) {
	if (length(levels) <= 1) {
		return(NA_character_)
	}
	nonref <- levels[-1]
	hit <- nonref[paste0(variable, nonref) == key]
	if (length(hit) == 1) hit else NA_character_
}

#' Reference rows for the categorical terms, one per model context
#' @keywords internal
#' @noRd
inject_reference_rows <- function(dec) {

	cat <- dec[dec$categorical & !is.na(dec$categorical), , drop = FALSE]
	if (nrow(cat) == 0) {
		return(cat[0, , drop = FALSE])
	}

	keys <- c("outcome", "adj_index", "data_id", "strata", "stratum_level",
						"subset", "variable", "role", "term_label", "reference",
						"categorical", "nobs", "exponentiated")
	keys <- intersect(keys, names(cat))
	ref <- dplyr::distinct(cat[keys])

	ref$term <- paste0(ref$variable, "__ref")
	ref$level <- ref$reference
	ref$is_reference <- TRUE
	ref$estimate <- NA_real_
	ref$conf_low <- NA_real_
	ref$conf_high <- NA_real_
	ref$p_value <- NA_real_

	ref
}

#' Outcome and adjustment-set labels from the recorded selection
#' @keywords internal
#' @noRd
apply_context_labels <- function(dec, sel) {

	outLabels <- sel$labels$outcomes
	dec$outcome_label <-
		if (length(outLabels) > 0) {
			vapply(dec$outcome, function(o) {
				lab <- outLabels[[o]]
				if (is.null(lab)) o else as.character(lab)
			}, character(1))
		} else {
			dec$outcome
		}

	adjLabels <- sel$labels$adjustment
	dec$adj_label <-
		if (length(adjLabels) > 0) {
			vapply(as.character(dec$adj_index), function(k) {
				lab <- adjLabels[[k]]
				if (is.null(lab)) paste0("Model ", k) else as.character(lab)
			}, character(1))
		} else {
			paste0("Model ", dec$adj_index)
		}

	dec
}

#' Apply `modify_labels()` relabelings to the decorated frame
#'
#' Term relabels (a variable named with a scalar label) rewrite `term_label`;
#' level relabels (a variable with a vector label, mapped in ascending level
#' order, or a bare level value) rewrite `level_label`.
#' @keywords internal
#' @noRd
apply_relabels <- function(dec, relabels) {

	dec$level_label <- dec$level

	for (nm in names(relabels)) {
		val <- relabels[[nm]]

		if (nm %in% dec$variable) {
			if (length(val) == 1) {
				# Term relabel
				dec$term_label[dec$variable == nm] <- as.character(val)
			} else {
				# Level relabel by position, ascending level order
				lvls <- sort(unique(stats::na.omit(dec$level[dec$variable == nm])))
				for (i in seq_along(lvls)) {
					if (i <= length(val)) {
						hit <- dec$variable == nm & !is.na(dec$level) & dec$level == lvls[i]
						dec$level_label[hit] <- as.character(val[i])
					}
				}
			}
		} else {
			# Bare level value relabel, wherever that level appears
			hit <- !is.na(dec$level) & dec$level == nm
			dec$level_label[hit] <- as.character(val[1])
		}
	}

	dec
}

#' NA-safe blank for ordering keys
#' @keywords internal
#' @noRd
naToBlank <- function(v) ifelse(is.na(v), "", as.character(v))

# The minimal renderer --------------------------------------------------------

#' Render the decorated frame as a minimal estimate-and-interval table
#'
#' The bare default of the grammar: one displayed column per term level (its
#' point estimate and confidence interval merged into a single box), adjustment
#' sets on rows, outcomes as row groups. Categorical terms span their level
#' columns, with the reference level shown blank. The full cell-frame renderer
#' (spanners, merges, forest, group-scoped cells) lands in M6.6.
#' @keywords internal
#' @noRd
render_minimal <- function(dec, spec) {

	digits <- if (is.null(spec$style$digits)) 2 else spec$style$digits
	missing_text <- if (is.null(spec$style$missing_text)) "" else spec$style$missing_text

	# The finished estimate box: "estimate (low, high)", blank when absent
	dec$cell <- format_estimate(
		dec$estimate, dec$conf_low, dec$conf_high, digits, missing_text
	)

	# A stub that keeps stratified / subset / multi-dataset rows distinct even in
	# the minimal layout, and a stable column key per displayed term level
	dec$stub <- paste0(dec$adj_label, row_qualifier(dec))
	dec$col_key <- ifelse(is.na(dec$level), dec$variable,
												paste0(dec$variable, "::", dec$level))

	# Column order: term order (as decorated), reference level first within a term
	colOrder <- unique(dec$col_key[order(
		match(dec$variable, unique(dec$variable)),
		!dec$is_reference, naToBlank(dec$level)
	)])

	# Row order preserved from the decorated frame
	rowKeys <- unique(dec[c("outcome_label", "stub")])

	wide <-
		dec[c("outcome_label", "stub", "col_key", "cell")] |>
		tidyr::pivot_wider(names_from = "col_key", values_from = "cell")
	ord <- match(
		paste(wide$outcome_label, wide$stub),
		paste(rowKeys$outcome_label, rowKeys$stub)
	)
	wide <- wide[order(ord), c("outcome_label", "stub", colOrder), drop = FALSE]

	gtbl <-
		gt::gt(wide, rowname_col = "stub", groupname_col = "outcome_label") |>
		gt::sub_missing(missing_text = missing_text)

	# Column labels and spanners, per displayed term
	labelLookup <- dec[!duplicated(dec$col_key), , drop = FALSE]
	colLabels <- list()
	for (v in unique(dec$variable)) {
		vCols <- labelLookup[labelLookup$variable == v, , drop = FALSE]
		vCols <- vCols[match(intersect(colOrder, vCols$col_key), vCols$col_key), ,
									 drop = FALSE]
		termLabel <- vCols$term_label[1]

		if (isTRUE(vCols$categorical[1])) {
			# Levels are the columns; the term label is their spanner
			for (i in seq_len(nrow(vCols))) {
				lab <- vCols$level_label[i]
				colLabels[[vCols$col_key[i]]] <- if (is.na(lab)) "" else lab
			}
			gtbl <- gt::tab_spanner(
				gtbl, label = termLabel, columns = dplyr::all_of(vCols$col_key)
			)
		} else {
			# A single column carries the term label directly
			colLabels[[vCols$col_key[1]]] <- termLabel
		}
	}
	if (length(colLabels) > 0) {
		gtbl <- gt::cols_label(gtbl, .list = colLabels)
	}

	gtbl |>
		gt::opt_align_table_header("left") |>
		gt::tab_style(
			style = gt::cell_text(align = "left"),
			locations = gt::cells_stub()
		)
}

#' A parenthetical qualifier distinguishing stratified / subset / multi-dataset
#' rows in the minimal layout
#' @keywords internal
#' @noRd
row_qualifier <- function(dec) {
	nData <- length(unique(stats::na.omit(dec$data_id)))
	vapply(seq_len(nrow(dec)), function(i) {
		parts <- c(
			if (!is.na(dec$strata[i])) paste0(dec$strata[i], "=", dec$stratum_level[i]),
			if (!is.na(dec$subset[i])) dec$subset[i],
			if (nData > 1 && !is.na(dec$data_id[i])) dec$data_id[i]
		)
		if (length(parts) > 0) paste0(" (", paste(parts, collapse = ", "), ")") else ""
	}, character(1))
}

#' Format an estimate with its interval into a single display string
#' @keywords internal
#' @noRd
format_estimate <- function(estimate, low, high, digits, missing_text) {
	num <- function(v) formatC(v, format = "f", digits = digits)
	ifelse(
		is.na(estimate),
		missing_text,
		ifelse(
			is.na(low) | is.na(high),
			num(estimate),
			paste0(num(estimate), " (", num(low), ", ", num(high), ")")
		)
	)
}
