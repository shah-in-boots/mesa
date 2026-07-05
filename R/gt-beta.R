#' Table of linear and generalized models
#'
#' @description
#' A `<mdl_tbl>` object of linear or generalized linear models. This serves as a
#' workhorse for a majority of simple regression models and allows them to be
#' displayed using the `{gt}` package format.
#'
#' @inheritParams tbls
#'
#' @param distribution A `<character>` describes the distribution of the key
#'   exposure terms that are being displayed. Can either be *continuous*,
#'   *dichotomous*, or *categorical*.
#'
#' @export
tbl_beta <- function(object,
										 data,
										 outcomes = formula(),
										 terms = formula(),
										 adjustment = formula(),
										 columns = list(beta ~ "Estimate",
										 							 conf ~ "95% CI",
										 							 p ~ "P value"),
										 accents = formula(),
										 suppress_column_labels = FALSE,
										 exponentiate = FALSE,
										 ...) {

	# Validation
	# 	Ensure correct object type
	# 	Message to check for only one model family being present
	checkmate::assert_class(object, "mdl_tbl")
	if (length(unique(object$name)) > 1) {
		message("Combining models from different datasets or regressions in a table is dangerous (may not be interpretable).")
	}

	## Argument evaluation ----

	# Get relevant filtering variables
	## Outcomes
	out <- labeled_formulas_to_named_list(outcomes)
	outNames <- names(out)
	outLabels <- unlist(unname(out))
	## Terms
	tms <- labeled_formulas_to_named_list(terms)
	tmsNames <- names(tms)
	tmsLabels <- unlist(unname(tms))
	## Adjustment
	adj <- labeled_formulas_to_named_list(adjustment)
	adjNames <- names(adj)
	adjLabels <- unlist(unname(adj))
	## Columns
	cols <- labeled_formulas_to_named_list(columns)
	estVar <- character()
	statVar <- character()
	modVar <- character()
	if ("beta" %in% names(cols)) {
		estVar <- append(estVar, "estimate")
	}
	if ("conf" %in% names(cols)) {
		estVar <- append(estVar, c("conf_low", "conf_high"))
	}
	if ("p" %in% names(cols)) {
		statVar <- append(statVar, "p_value")
	}
	if ("n" %in% names(cols)) {
		modVar <- append(modVar, "nobs")
	}
	## Accentuation instructions
	style <- labeled_formulas_to_named_list(accents)
	styleCriteria <- names(style)
	styleInstruction <- unname(unlist(style))

	# Check number of columns per term to be shown
	if (suppress_column_labels) {
		message("Column labels have been explicitly suppressed. This may result in ambigious/duplicate column names if more than one column per display term has been chosen.")
	} else if (length(cols) == 1) {
		suppress_column_labels <- TRUE
	}

	# Create subset of model_table
	obj <-
		object |>
		dplyr::filter(grepl(paste0(outNames, collapse = "|"), outcome)) |>
		flatten_models(exponentiate) |>
		dplyr::filter(grepl(paste0(tmsNames, collapse = "|"), term)) |>
		dplyr::select(number, outcome, term, estimate, conf_low, conf_high, p_value, dplyr::any_of(c(estVar, statVar, modVar)))

	# Data set to be used
	dat <- data[c(outNames, tmsNames)]

	# Check early to see if terms are in the appropriate adjustment sets
	for (t in tmsNames) {
		possible_terms <- obj[obj$number == as.numeric(adjNames[1]),]$term
		if (!any(grepl(t, possible_terms))) {
			stop(
				"Adjustment sets do not contain the term `",
				t,
				"`. Please reselect terms or adjustment set levels."
			)
		}
	}

	## Table creation ----

	# Linear tables are dependent on the number of outcomes, and number of terms
	# Each "column" is a unit containing an outcome x exposure relationship
	# 	The rows in this column-unit are adjustment levels
	# Multiple levels or miniature tables are formed
	# 	Each column in the table then represents different exposure
	# 	Each row group then represents a different outcome
	# Number of tables to make depends on...
	#		Number of outcomes
	# 	Number of terms

	# Get tables ready to be stored
	tblTerms <- list()
	tblOutcomes <- list()

	for (t in tmsNames) {
		for (o in outNames) {

			# Get all the terms of interest into table
			tbl <-
				obj |>
				dplyr::filter(grepl(t, term)) |>
				dplyr::filter(grepl(o, outcome)) |>
				tidyr::pivot_wider(
					names_from = term,
					values_from = c(estimate, conf_low, conf_high, p_value,
													dplyr::any_of(c(estVar, statVar, modVar))),
					names_glue = "{term}_{.value}"
				) |>
				dplyr::filter(number %in% as.numeric(adjNames)) |>
				dplyr::mutate(outcome = o) |>
				dplyr::mutate(number = as.character(number))

			# If this is a variable that has multiple levels, reference is needed
			# Determine if it a non-continuous variable (categorical or dichotomous)
			# Inject reference column named after the level of the missing variable
			# Reference will be minimum of the factor levels of the variable
			if (inherits(dat[[t]], c("factor", "character"))) {
				vars <- unique(grep(t, obj$term, value = TRUE))
				lvls <- levels(dat[[t]])
				if (length(lvls) != length(vars) + 1) {
					stop(paste0(
						"Levels of variable `",
						t,
						"` are not consistent with the modeled levels."
					))
				}

				ref_col <- paste0(t, "_", "ref")
				tbl <- tibble::add_column(tbl, !!ref_col := NA)

				tbl <-
					tbl |>
					dplyr::relocate(starts_with(t), .after = "outcome") |>
					dplyr::relocate(any_of(!!ref_col), .after = "outcome")

			}

			# Save this tbl in this outcome
			# Rotate through all the outcomes
			tblOutcomes[[o]] <- tbl
		}

		# Now the outcomes can be bound together
		if (length(tblTerms) == 0) {
			tblTerms[[t]] <- dplyr::bind_rows(tblOutcomes)
		} else {
			tblTerms[[t]] <- dplyr::bind_rows(tblOutcomes) |>
				dplyr::select(-number, -outcome)
		}
	}

	# Now the terms are bound together and clean up
	tab <-
		dplyr::bind_cols(tblTerms) |>
		dplyr::mutate(number = factor(number, levels = adjNames, labels = adjLabels)) |>
		dplyr::mutate(outcome = factor(outcome, levels = outNames, labels = outLabels))

	## {gt} table creation ----

	# Convert into gt table
	gtbl <-
		gt(tab, rowname_col = "number", groupname_col = "outcome") |>
		# Hide the unnecessary columns based on column selection
		cols_hide(!ends_with(c("_ref", estVar, statVar, modVar))) |>
		sub_missing(missing_text = "") |>
		fmt_number(drop_trailing_zeros = FALSE,
							 drop_trailing_dec_mark = FALSE,
							 decimals = 2)

	# Make changes to table programmatically by term
	# Term distribution changes how each modification is made
	# This depends on if column labels should be suppressed (or not)
	if (suppress_column_labels) {
		for (t in tmsNames) {
			# These are the levels and sublevels (if they exist) for the cont/cat vars
			# Only would need levels if a variable is defined as a factor/character type
			vars <- rev(unique(grep(t, obj$term, value = TRUE)))

			for (v in seq_along(vars)) {
				# Merge selected columns together

				# First check if factor/categorical/character type
				if (inherits(dat[[t]], c("factor", "character"))) {
					# Suspected categorical
					lvls <- levels(dat[[t]])
					ref_col <- paste0(t, "_", "ref")

					# If confidence intervals are available as well
					if (length(estVar) >= 3) {
						gtbl <-
							gtbl |>
							cols_merge(
								columns = starts_with(vars[v]) & ends_with(estVar),
								pattern = "{1} ({2}, {3})"
							) |>
							cols_move(starts_with(vars[v]), after = paste0(t, "_ref"))
					} else {
						gtbl <-
							gtbl |>
							cols_merge(
								columns = starts_with(vars[v]) & ends_with(estVar),
								pattern = "{1}"
							) |>
							cols_move(starts_with(vars[v]), after = paste0(t, "_ref"))
					}

				} else {
					# Suspected to be continuous and not categorical
					gtbl <-
						gtbl |>
						cols_merge(
							columns = starts_with(vars[v]) & ends_with(estVar),
							pattern = "{1} ({2}, {3})"
						)
				}

				# Add column labels for individual variables
				varName <- vars[v]
				varLabel <- rev(lvls)[v]
				gtbl <-
					gtbl |>
					cols_label(rlang::inject(starts_with(!!varName) ~ !!varLabel))
			}

			# Add column labels here (instead of default values)
			# Spanners will be for the term label (instead of individual levels)
			if (inherits(dat[[t]], c("factor", "character"))) {
				lvls <- levels(dat[[t]])
				ref_col <- paste0(t, "_", "ref")
				gtbl <-
					gtbl |>
					cols_label(rlang::inject(!!ref_col ~ !!lvls[1])) |>
					tab_spanner(label = tms[[t]], columns = starts_with(t), gather = FALSE)
			}
		}
	} else {
		for (t in tmsNames) {

			# These are the levels and sublevels (if they exist) for the cont/cat vars
			# Only would need levels if a variable is defined as a factor/character type
			vars <- rev(unique(grep(t, obj$term, value = TRUE)))

			for (v in seq_along(vars)) {
				# Merge selected columns together

				# First check if factor/categorical/character type
				if (inherits(dat[[t]], c("factor", "character"))) {
					# Suspected categorical
					lvls <- levels(dat[[t]])
					ref_col <- paste0(t, "_", "ref")

					if (length(estVar) == 3) {
						gtbl <-
							gtbl |>
							cols_merge(
								columns = starts_with(vars[v]) & ends_with(estVar),
								pattern = "{1} ({2}, {3})"
							) |>
							cols_move(starts_with(vars[v]), after = paste0(t, "_ref")) |>
							tab_spanner(label = rev(lvls[-1])[v], columns = starts_with(vars[v]))
					} else {
						gtbl <-
							gtbl |>
							cols_merge(
								columns = starts_with(vars[v]) & ends_with(estVar),
								pattern = "{1}"
							) |>
							cols_move(starts_with(vars[v]), after = paste0(t, "_ref")) |>
							tab_spanner(label = rev(lvls[-1])[v], columns = starts_with(vars[v]))

					}

				} else {
					# Suspected to be continuous and not categorical
					gtbl <-
						gtbl |>
						cols_merge(
							columns = starts_with(vars[v]) & ends_with(estVar),
							pattern = "{1} ({2}, {3})"
						) |>
						tab_spanner(label = tms[[vars[v]]], columns = starts_with(vars[v]))
				}

			}

			# Reference and variable labels/spanners if needed
			# Relabel reference column
			# Add spanner for entire variable t
			if (inherits(dat[[t]], c("factor", "character"))) {
				lvls <- levels(dat[[t]])
				ref_col <- paste0(t, "_", "ref")
				gtbl <-
					gtbl |>
					tab_spanner(label = lvls[1], columns = !!ref_col) |>
					tab_spanner(label = tms[[t]], columns = starts_with(t), gather = FALSE)
			}

			# Rename columns
			# 	Estimates should be beta + CI (estVar)
			# 	P value if selected can be additional column (statVar)
			# 	Model-level summary variables can be different column (modVar)
			if ("estimate" %in% estVar) {
				if ("conf_low" %in% estVar & "conf_high" %in% estVar) {
					colLabels <- rep(paste0(cols$beta, " (", cols$conf, ")"), length(vars))
					names(colLabels) <- paste0(vars, "_estimate")
					gtbl <- gtbl |> cols_label(.list = colLabels)
				} else {
					colLabels <- rep(cols$beta, length(vars))
					names(colLabels) <- paste0(vars, "_estimate")
					gtbl <- gtbl |> cols_label(.list = colLabels)
				}
			}

			if ("p_value" %in% statVar) {
				colLabels <- rep(cols$p, length(vars))
				names(colLabels) <- paste0(vars, "_p_value")
				gtbl <- gtbl |> cols_label(.list = colLabels)
			}
		}

		# If using data column labels...
		# Cleanup titles and labels for columns
		# Convert beta to beta coefficient symbol if available
		# Add reference categories
		gtbl <-
			gtbl |>
			text_replace(
				locations = cells_column_labels(),
				pattern = "beta",
				replacement = gt::html("\u03B2")
			) |>
			cols_label(ends_with("_ref") ~ "Reference")
	}


	# Add in accents or style changes to the table
	# Use style instructions and criteria to automate
	if (length(accents) > 0) {
  	if (grepl("^p\ ", styleCriteria)) {
  		comp <- str2lang(styleCriteria)[[1]]
  		crit <- str2lang(styleCriteria)[[3]]
  		pval <- grep("_p_value$", gtbl$`_boxhead`$var, value = TRUE)
  
  
  		for (i in seq_along(pval)) {
  			pcomp <- str2lang(paste(paste0("`", pval[i], "`"), comp, crit))
  			gtbl <-
  				gtbl |>
  				tab_style(
  					style = cell_text(weight = "bold"),
  					locations = cells_body(columns = pval[i],
  																 rows = !!pcomp)
  				)
  		}
  
  		if ("estimate" %in% estVar) {
  			est <- grep("_estimate$", gtbl$`_boxhead`$var, value = TRUE)
  			for (i in seq_along(pval)) {
  				pcomp <- str2lang(paste(paste0("`", pval[i], "`"), comp, crit))
  				gtbl <-
  					gtbl |>
  					tab_style(
  						style = cell_text(weight = "bold"),
  						locations = cells_body(columns = est[i],
  																	 rows = !!pcomp)
  					)
  			}
  		}
  	}
	}

	# Visual modifications
	# 	Indent adjustment lines
	# 	Align headings
	gtbl <-
		gtbl |>
		tab_stub_indent(rows = contains(adjLabels[-1]), indent = 3) |>
		opt_align_table_header("left") |>
		tab_style(
			style = cell_text(align = "left"),
			locations = cells_stub()
		) |>
		tab_style(
			style = cell_text(align = "left"),
			locations = cells_column_spanners()
		) |>
		tab_style(
			style = cell_text(align = "left"),
			locations = cells_column_labels()
		) |>
		tab_style(
			style = cell_text(align = "left"),
			locations = cells_body()
		)

	# Return
	gtbl
}
