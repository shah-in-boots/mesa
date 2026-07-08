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
#' Runs the *select*, *decorate*, and *compute* stages of the grammar. Returns
#' a long tibble with one row per displayed estimate, plus an injected
#' reference row for each categorical term, carrying the metadata the layout
#' stages need: the causal role, the term and level labels, the level and
#' reference flags, the adjustment-set index and label, the estimate itself,
#' and any data-derived statistics the column blocks request.
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

	# Estimates on the inferred scale (Cox / logit families exponentiate) unless
	# an `add_estimates()` block overrides it; the decision is carried in
	# `exponentiated`, so the message is redundant here
	estBlock <- mesa_column_block(x, "estimates")
	flat <- suppressMessages(
		flatten_models(models, exponentiate = estBlock$exponentiate)
	)
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

	# Stage 3 — compute: the data-derived statistics the column blocks request
	# (events and rates per level, the term-scoped rate difference), resolved
	# against the attached data through each model's `data_id`
	dec <- compute_data_statistics(dec, x)

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

#' Render the decorated frame as a minimal statistic-column table
#'
#' The interim renderer of the grammar: one displayed column per term level and
#' statistic, adjustment sets on rows, outcomes as row groups. Without an
#' `add_estimates()` block the bare default shows the point estimate and
#' confidence interval merged into a single box; the block chooses the
#' statistics (`beta`, `conf`, `p`), their labels, and the digits, and
#' `add_n()` prepends the model-level observation count. Categorical terms
#' span their level columns, with the reference level shown blank. The full
#' cell-frame renderer (merges, forest, group-scoped cells) lands in M6.6.
#' @keywords internal
#' @noRd
render_minimal <- function(dec, spec) {

	estBlock <- mesa_column_block(spec, "estimates")
	nBlock <- mesa_column_block(spec, "n")
	evBlock <- mesa_column_block(spec, "events")
	rdBlock <- mesa_column_block(spec, "rate_difference")

	digits <-
		if (!is.null(estBlock)) {
			estBlock$digits
		} else if (is.null(spec$style$digits)) 2 else spec$style$digits
	missing_text <- if (is.null(spec$style$missing_text)) "" else spec$style$missing_text

	# Which estimate statistics are displayed and under what headers: the bare
	# default is the merged estimate + CI; `modify_labels(columns=)` overrides
	# the headers late
	statistics <-
		if (is.null(estBlock)) {
			list(beta = "Estimate", conf = "95% CI")
		} else {
			estBlock$statistics
		}
	for (nm in names(spec$labels$columns)) {
		if (nm %in% names(statistics)) {
			statistics[[nm]] <- as.character(spec$labels$columns[[nm]])
		}
	}
	showEst <- any(c("beta", "conf") %in% names(statistics))
	showP <- "p" %in% names(statistics)
	# The data statistics sit ahead of the estimates within a level (the old
	# hazard tables' reading order: events, rate, then the adjusted estimates)
	statCols <- c(
		if (!is.null(evBlock)) c("events", "rate"),
		if (showEst) "est", if (showP) "p"
	)

	# The data-statistic headers, overridable late by `modify_labels(columns=)`
	dataHeaders <- list(
		events = "Events",
		rate = if (!is.null(evBlock)) {
			paste0("Rate per ", evBlock$person_years, " person-years")
		},
		rate_difference = if (!is.null(rdBlock)) {
			paste0("Rate difference (", format(rdBlock$conf_level * 100), "% CI)")
		}
	)
	for (nm in names(spec$labels$columns)) {
		if (nm %in% names(dataHeaders)) {
			dataHeaders[[nm]] <- as.character(spec$labels$columns[[nm]])
		}
	}

	# An explicit `add_estimates()` always shows its statistic labels as the
	# column headers (the term label moves up to a spanner); only the bare
	# default keeps the compact term-label headers
	statHeaders <- !is.null(estBlock) || length(statCols) > 1

	# The header of the merged estimate box: "HR (95% CI)" when both statistics
	# are present, either alone otherwise
	estHeader <-
		if (all(c("beta", "conf") %in% names(statistics))) {
			paste0(statistics$beta, " (", statistics$conf, ")")
		} else if ("beta" %in% names(statistics)) {
			statistics$beta
		} else if ("conf" %in% names(statistics)) {
			statistics$conf
		}

	# The finished cells: the estimate box honors which of beta/conf are shown
	dec$cell_est <- format_estimate(
		dec$estimate, dec$conf_low, dec$conf_high, digits, missing_text,
		show_beta = "beta" %in% names(statistics),
		show_conf = "conf" %in% names(statistics)
	)
	dec$cell_p <- format_p_value(dec$p_value, missing_text)
	if (!is.null(evBlock)) {
		dec$cell_events <- format_count(dec$events, missing_text)
		dec$cell_rate <- ifelse(
			is.na(dec$rate),
			missing_text,
			formatC(dec$rate, format = "f", digits = evBlock$digits)
		)
	}

	# A stub that keeps stratified / subset / multi-dataset rows distinct even in
	# the minimal layout
	dec$stub <- paste0(dec$adj_label, row_qualifier(dec))

	# One long cell per (term level, statistic column), keyed stably
	cells <- do.call(rbind, lapply(statCols, function(s) {
		d <- dec
		d$stat <- s
		d$cell <- switch(
			s,
			est = d$cell_est, p = d$cell_p,
			events = d$cell_events, rate = d$cell_rate
		)
		d
	}))
	cells$col_key <- paste0(
		ifelse(is.na(cells$level), cells$variable,
					 paste0(cells$variable, "::", cells$level)),
		"::", cells$stat
	)

	# The rate difference is term-scoped — computed across a term's levels — so
	# where the levels are columns it gets one displayed column per term (the
	# group-scoped-cell rule of the 6.1 spec), constant down its rows
	if (!is.null(rdBlock) && "rate_diff" %in% names(dec)) {
		rd <- dec
		rd$stat <- "rate_difference"
		rd$cell <- format_estimate(
			rd$rate_diff, rd$rate_diff_low, rd$rate_diff_high,
			evBlock$digits, missing_text
		)
		rd$level <- NA_character_
		rd$level_label <- NA_character_
		rd$is_reference <- FALSE
		rd$col_key <- paste0(rd$variable, "::rate_difference")
		rd <- rd[!duplicated(paste(rd$outcome_label, rd$stub, rd$col_key)), ,
						 drop = FALSE]
		cells <- rbind(cells, rd)
	}

	# Column order: term order (as decorated), reference level first within a
	# term, data statistics before the estimate and p within a level, the
	# term-scoped rate difference after the term's level columns
	statOrder <- c(statCols, "rate_difference")
	colOrder <- unique(cells$col_key[order(
		match(cells$variable, unique(cells$variable)),
		cells$stat == "rate_difference",
		!cells$is_reference, naToBlank(cells$level),
		match(cells$stat, statOrder)
	)])

	# Row order preserved from the decorated frame
	rowKeys <- unique(dec[c("outcome_label", "stub")])

	wide <-
		cells[c("outcome_label", "stub", "col_key", "cell")] |>
		tidyr::pivot_wider(names_from = "col_key", values_from = "cell")
	ord <- match(
		paste(wide$outcome_label, wide$stub),
		paste(rowKeys$outcome_label, rowKeys$stub)
	)

	# The model-level n, recorded at fit time, sits ahead of the term columns
	nKey <- character()
	if (!is.null(nBlock)) {
		nKey <- ".n"
		nLookup <- dec[!duplicated(paste(dec$outcome_label, dec$stub)), ,
									 drop = FALSE]
		wide[[nKey]] <- nLookup$nobs[match(
			paste(wide$outcome_label, wide$stub),
			paste(nLookup$outcome_label, nLookup$stub)
		)]
	}
	wide <- wide[order(ord), c("outcome_label", "stub", nKey, colOrder),
							 drop = FALSE]

	gtbl <-
		gt::gt(wide, rowname_col = "stub", groupname_col = "outcome_label") |>
		gt::sub_missing(missing_text = missing_text)

	# Column labels and spanners, per displayed term
	colLabels <- list()
	if (!is.null(nBlock)) {
		nLabel <- nBlock$label
		if (!is.null(spec$labels$columns[["n"]])) {
			nLabel <- as.character(spec$labels$columns[["n"]])
		}
		colLabels[[nKey]] <- nLabel
	}
	statLabel <- function(s) {
		switch(
			s,
			est = estHeader,
			p = statistics$p,
			events = dataHeaders$events,
			rate = dataHeaders$rate,
			rate_difference = dataHeaders$rate_difference
		)
	}

	labelLookup <- cells[!duplicated(cells$col_key), , drop = FALSE]
	for (v in unique(dec$variable)) {
		vCols <- labelLookup[labelLookup$variable == v, , drop = FALSE]
		vCols <- vCols[match(intersect(colOrder, vCols$col_key), vCols$col_key), ,
									 drop = FALSE]
		termLabel <- vCols$term_label[1]

		# The term-scoped rate difference never sits under a level spanner: it
		# carries its own header directly, inside the term's outer spanner
		rdCols <- vCols[vCols$stat == "rate_difference", , drop = FALSE]
		lvlCols <- vCols[vCols$stat != "rate_difference", , drop = FALSE]
		for (i in seq_len(nrow(rdCols))) {
			colLabels[[rdCols$col_key[i]]] <- statLabel(rdCols$stat[i])
		}

		if (isTRUE(vCols$categorical[1])) {
			# Levels are the columns; the term label is their spanner. With
			# statistic headers, each level becomes an inner spanner over its
			# statistic columns
			if (statHeaders) {
				for (lv in unique(lvlCols$level)) {
					lvCols <- lvlCols[lvlCols$level %in% lv, , drop = FALSE]
					lab <- lvCols$level_label[1]
					gtbl <- gt::tab_spanner(
						gtbl,
						label = if (is.na(lab)) "" else lab,
						columns = dplyr::all_of(lvCols$col_key),
						id = paste0("sp::", v, "::", lv)
					)
					for (i in seq_len(nrow(lvCols))) {
						colLabels[[lvCols$col_key[i]]] <- statLabel(lvCols$stat[i])
					}
				}
			} else {
				for (i in seq_len(nrow(lvlCols))) {
					lab <- lvlCols$level_label[i]
					colLabels[[lvlCols$col_key[i]]] <- if (is.na(lab)) "" else lab
				}
			}
			gtbl <- gt::tab_spanner(
				gtbl, label = termLabel, columns = dplyr::all_of(vCols$col_key),
				id = paste0("sp::", v)
			)
		} else if (statHeaders) {
			# Statistic headers under a term-label spanner
			for (i in seq_len(nrow(lvlCols))) {
				colLabels[[lvlCols$col_key[i]]] <- statLabel(lvlCols$stat[i])
			}
			gtbl <- gt::tab_spanner(
				gtbl, label = termLabel, columns = dplyr::all_of(vCols$col_key),
				id = paste0("sp::", v)
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
#'
#' Honors which of the point estimate and interval are shown: both merge into
#' `"estimate (low, high)"`, either renders alone, and a missing estimate is
#' the `missing_text`.
#' @keywords internal
#' @noRd
format_estimate <- function(estimate, low, high, digits, missing_text,
														show_beta = TRUE, show_conf = TRUE) {
	num <- function(v) formatC(v, format = "f", digits = digits)
	conf <- ifelse(
		is.na(low) | is.na(high),
		NA_character_,
		paste0("(", num(low), ", ", num(high), ")")
	)
	ifelse(
		is.na(estimate),
		missing_text,
		if (show_beta && show_conf) {
			ifelse(is.na(conf), num(estimate), paste(num(estimate), conf))
		} else if (show_beta) {
			num(estimate)
		} else {
			ifelse(is.na(conf), missing_text, conf)
		}
	)
}

#' Format whole-number counts (events, n) for display
#' @keywords internal
#' @noRd
format_count <- function(n, missing_text) {
	ifelse(is.na(n), missing_text, formatC(n, format = "f", digits = 0))
}

#' Format p-values for display: three decimals, `<0.001` below
#' @keywords internal
#' @noRd
format_p_value <- function(p, missing_text) {
	ifelse(
		is.na(p),
		missing_text,
		ifelse(p < 0.001, "<0.001", formatC(p, format = "f", digits = 3))
	)
}
