# Realizing the <mdl_gt> (M6.3-M6.5, split out in M6.14) ------------------------
#
# A `<mdl_gt>` specification carries instructions; realization runs them against
# the `mdl_tbl`. `realize_mdl_gt()` performs *select* (the M6.2 resolver),
# *decorate* (term metadata plus injected reference rows), and *compute* (the
# data-derived statistics) for the `"adjustment"` and `"levels"` presets;
# `realize_interaction()` (in table-presets.R, alongside the interaction
# preset it feeds exclusively) is its counterpart for the `"interaction"`
# preset. This file was split out of table-render.R along the grammar's own
# stage seam: realize here, lay out in table-presets.R, render in
# table-render.R.


#' Realize a `<mdl_gt>` to its decorated estimate rows
#'
#' Runs the *select*, *decorate*, and *compute* stages of the grammar. Returns
#' a long tibble with one row per displayed estimate, plus an injected
#' reference row for each categorical term, carrying the metadata the layout
#' stages need: the causal role, the term and level labels, the level and
#' reference flags, the adjustment-set index and label, the estimate itself,
#' and any data-derived statistics the column blocks request.
#' @keywords internal
#' @noRd
realize_mdl_gt <- function(x) {

	validate_class(x, "mdl_gt")
	mt <- x@mdl_tbl

	# Stage 1 -- select: filter the models and resolve the requested terms
	sel <- resolve_selection(
		mt,
		terms = x@selection$terms,
		adjustment = x@selection$adjustment
	)
	models <- sel@models
	if (nrow(models) == 0) {
		stop("No models on the mesa match the current selection.", call. = FALSE)
	}

	# The terms whose estimates become columns: an explicit `select_terms()`,
	# else the exposures, else every non-outcome term the models carry
	displayTerms <- mdl_gt_display_terms(mt, x@selection, sel)
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
	estBlock <- mdl_gt_column_block(x, "estimates")
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

	# The adjustment-set index is a per-model property; carry it onto the
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
	flat$adj_index <- sel@adjustment_index[match(flatKey, lookupKey)]

	# Stage 2 -- decorate: join term metadata and derive the factor level a key
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
	# The factor level a tidy-term key stands for: continuous (and
	# dichotomous-numeric) terms have no level; a categorical term's
	# non-reference level keys are `paste0(variable, level)` (the reference
	# level never appears as a fitted key)
	dec$level <- vapply(seq_len(nrow(dec)), function(i) {
		lvls <- dec$levels[[i]]
		if (length(lvls) <= 1) {
			return(NA_character_)
		}
		nonref <- lvls[-1]
		hit <- nonref[paste0(dec$variable[i], nonref) == dec$term[i]]
		if (length(hit) == 1) hit else NA_character_
	}, character(1))
	dec$is_reference <- FALSE

	# Inject a reference row for every categorical term in every model context,
	# generalizing `tbl_beta`'s `_ref` column: the reference level carries no
	# estimate but holds the term's place among its levels
	refRows <- inject_reference_rows(dec)
	dec <- dplyr::bind_rows(dec, refRows)

	# Stage 3 -- compute: the data-derived statistics the column blocks request
	# (events and rates per level, the term-scoped rate difference), resolved
	# against the attached data through each model's `data_id`
	dec <- compute_data_statistics(dec, x)

	# Labels: adjustment sets from the recorded selection; outcomes, terms, and
	# levels from `modify_labels()`
	dec <- apply_context_labels(dec, sel)
	dec <- apply_relabels(dec, x@labels$relabels)

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
mdl_gt_display_terms <- function(mt, selection, sel) {

	if (!is.null(selection$terms)) {
		return(sel@terms)
	}

	exposures <- unique(stats::na.omit(sel@models$exposure))
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

#' Adjustment-set labels from the recorded selection; the outcome label
#' starts as the outcome itself and `modify_labels()` may rewrite it
#' @keywords internal
#' @noRd
apply_context_labels <- function(dec, sel) {

	dec$outcome_label <- dec$outcome

	adjLabels <- sel@labels$adjustment
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
#' order, or a bare level value) rewrite `level_label`; an outcome named with
#' a scalar label rewrites `outcome_label` (the row-group title). A name that
#' is both a displayed term and an outcome — a mediator — relabels both.
#' @keywords internal
#' @noRd
apply_relabels <- function(dec, relabels) {

	dec$level_label <- dec$level

	for (nm in names(relabels)) {
		val <- relabels[[nm]]
		matched <- FALSE

		if (nm %in% dec$variable) {
			matched <- TRUE
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
		}

		# The interaction frame carries no outcome column; skip the outcome
		# relabel there
		if ("outcome" %in% names(dec) && nm %in% dec$outcome &&
				length(val) == 1) {
			matched <- TRUE
			hit <- !is.na(dec$outcome) & dec$outcome == nm
			dec$outcome_label[hit] <- as.character(val)
		}

		if (!matched) {
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

