#' Table of hazard ratios
#'
#' @description
#' Function that takes a `<mdl_tbl>` object that includes survival-model data,
#' usually in the form of Cox proportional hazard models, and allows them to be
#' displayed.
#'
#' @inheritParams tbls
#'
#' @param followup Character vector naming the followup duration variable. Must
#'   be either same length as __outcomes__ or be of length of 1 (which will be
#'   recycled).
#'
#' @param rate_difference If there are only two levels in the term, the rate
#'   difference between the levels will be calculated. Defaults to `FALSE`.
#'   Presumes a 95% confidence interval as the default. If `TRUE` will calculate
#'   the rate by the __person_years__ provided.
#'
#' @param person_years The length or duration of person-years to use. Is an
#'   integer, and usually is 10 or 100. Default is `100`, which would represent
#'   the incidence for every *100 person-years*. Argument only used if
#'   __rate_difference__ is set to `TRUE`. Currently not working!
#'
#' @import gt
#' @name tbl_hazard
NULL

#' @rdname tbl_hazard
#' @export
tbl_dichotomous_hazard <- function(object,
																	 data,
																	 outcomes = formula(),
																	 followup = character(),
																	 terms = formula(),
																	 adjustment = formula(),
																	 rate_difference = FALSE,
																	 person_years = 100,
																	 ...) {

	# Validation
	# 	Ensure correct object type
	# 	Ensure only one model family is present
	checkmate::assert_class(object, 'mdl_tbl')
	if (length(unique(object$name)) > 1) {
		stop('Cannot combine models from different datasets or regressions into a table safely.')
	}

	# Get relevant filtering variables
	## Outcomes
	out <- labeled_formulas_to_named_list(outcomes)
	out_nms <- names(out)
	out_lab <- unlist(unname(out))
	## Terms
	tms <- labeled_formulas_to_named_list(terms)
	tms_nms <- names(tms)
	tms_lab <- unlist(unname(tms))
	## Adjustment
	lvl <- labeled_formulas_to_named_list(adjustment)
	lvl_nms <- names(lvl)
	lvl_lab <- unlist(unname(lvl))

	# Create subset of model_table
	obj <-
		object |>
		dplyr::filter(grepl(paste0(out_nms, collapse = '|'), outcome)) |>
		flatten_models() |>
		dplyr::filter(grepl(paste0(tms_nms, collapse = '|'), term)) |>
		dplyr::select(number, outcome, term, estimate, conf_low, conf_high, p_value)

	# Data set to be used
	dat <- data[c(out_nms, followup, tms_nms)]

	# Check early to see if terms are in the appropriate adjustment sets
	for (t in tms_nms) {

		possible_terms <- obj[obj$number == as.numeric(lvl_nms[1]),]$term

		if (!any(grepl(t, possible_terms))) {
			stop(
				'Adjustment sets do not contain the term `',
				t,
				'`. Please reselect terms or adjustment set levels.'
			)
		}

		if (!inherits(dat[[t]], 'factor')) {
			stop(
				'The term `',
				t,
				'` should be given as a factor to ensure appropriate term levels.'
			)
		}

		if (length(levels(dat[[t]])) != 2) {
			stop(
				'This function is intended for only dichotomous levels, and `',
				t,
				'` does not have uniquely 2 levels.'
			)
		}

	}

	# Number of tables to make depends on...
	#		Number of outcomes
	# 	Number of terms

	# Get tables ready to be stored
	tbl_tms <- list()
	tbl_out <- list()

	for (t in tms_nms) {
		for (o in out_nms) {

			# Adjusted hazards first
			adj <-
				obj |>
				dplyr::filter(grepl(t, term)) |>
				dplyr::filter(grepl(o, outcome)) |>
				tidyr::pivot_wider(
					names_from = term,
					values_from = c(estimate, conf_low, conf_high, p_value),
					names_glue = '{term}_{.value}'
				) |>
				dplyr::filter(number %in% as.numeric(lvl_nms)) |>
				dplyr::mutate(outcome = o) |>
				dplyr::mutate(number = as.character(number))

			# Person years into table
			py <-
				survival::pyears(survival::Surv(dat[[followup]], dat[[o]]) ~ dat[[t]])

			py$pyears <- py$pyears / 100

			rates <-
				rbind(
					n = py$n,
					events = py$event,
					risk = py$event / py$pyears
				) |>
				as.data.frame() |>
				rownames_to_column(var = 'row')

			# Save number per group for later in the table
			n <- rates[1, -1]

			# Add in rate differences if needed
			if (rate_difference) {

				# Number of Disease in Exposed & Controls
				nde <- py$event[1]
				ndc <- py$event[2]
				nd <- nde + ndc

				# Person-Time in Exposed & Controls
				pte <- py$pyears[1]
				ptc <- py$pyears[2]
				pt <- pte + ptc

				# Incidence Rate in Exposded & Controls
				ire <- nde/pte
				irc <- ndc/ptc
				ir <- nd/pt

				# Estimates & Confidence Intervals (95%)
				est <- ire - irc
				cl <- est - stats::qnorm(0.9725) * sqrt(nde / pte^2 + ndc / ptc^2)
				ch <- est + stats::qnorm(0.9725) * sqrt(nde / pte^2 + ndc / ptc^2)

				# Add buffering rows
				rd <-
					dplyr::bind_cols(rd_est = est, rd_conf_low = cl, rd_conf_high = ch) |>
					dplyr::add_row(rd_est = rep(NA, 2), .before = 1)

				# Revise table names for this specific term
				names(rd) <- paste0(names(rd), '_', t)

				# Add to rates
				rates <- dplyr::bind_cols(rates, rd)
			}

			# Make compatible with binding
			unadj <-
				rates[-1, ] |>
				tibble::add_row(row = as.character(adj$number))

			# Bind the tables together
			# Order of columns is that reference is on left
			# Each level is then with incidence rate and to the right is hazard

			lvls <- levels(dat[[t]]) # Reference is first
			vars <- unique(grep(t, obj$term, value = TRUE))

			stopifnot(
				'Levels of variables are not consistent within the specificed term'
				= length(lvls)  == length(vars) + 1
			)

			# Basic table merge
			tbl <-
				dplyr::full_join(unadj, adj, by = dplyr::join_by(row == number)) |>
				dplyr::mutate(outcome = o)

			# Organize columns
			for (v in seq_along(vars)) {
				tbl <-
					tbl |>
					dplyr::relocate(contains(vars[v]), .after = lvls[v + 1])
			}

			# Rename columns
			names(tbl)[names(tbl) %in% names(n)] <-
				paste0(names(n), ' (n = ', n, ')')

			# We are rotating through each outcome for a single term
			tbl_out[[o]] <- tbl

		}

		# Now the outcomes can be bound together
		# Don't want to duplicate the outcome and label lines so will drop if dups
		if (length(tbl_tms) == 0) {
			tbl_tms[[t]] <- dplyr::bind_rows(tbl_out)
		} else {
			tbl_tms[[t]] <- dplyr::bind_rows(tbl_out) |>
				dplyr::select(-row, -outcome)
		}

	}

	# Now the terms are bound together and clean up
	tab <-
		dplyr::bind_cols(tbl_tms) |>
		dplyr::mutate(row = as.character(factor(
			row,
			levels = c('events', 'risk', lvl_nms),
			labels = c('Total No. of events', paste('Rate per', person_years, 'person-years'), lvl_lab)
		))) |>
		dplyr::mutate(outcome = factor(outcome, levels = out_nms, labels = out_lab))

	# Convert into gt table
	gtbl <-
		gt(tab, rowname_col = 'row', groupname_col = 'outcome') |>
		cols_hide(columns = contains('p_value')) |>
		sub_missing(missing_text = '') |>
		fmt_number(drop_trailing_zeros = TRUE)


	# Make changes to table programmatically
	for (t in tms_nms) {

		# Specific variables for each term (which is essentially a column group)
		vars <- unique(grep(t, obj$term, value = TRUE))

		# Merge columns together
		for (v in vars) {
			gtbl <-
				gtbl |>
				cols_merge(
					columns = starts_with(v),
					pattern = '{1} ({2}, {3})',
					rows = contains(lvl_lab)
				)

			if (rate_difference) {
				gtbl <-
					gtbl |>
					cols_merge(
						columns = starts_with('rd_') & ends_with(v),
						pattern = '{1} ({2}, {3})',
						rows = contains('Rate')
					)
			}
		}

		# Rename hazard ratio columns
		col_lab <- rep('HR (95% CI)', length(vars))
		names(col_lab) <- paste0(vars, '_estimate')
		gtbl <- gtbl |> cols_label(.list = col_lab)

		# Rename rate differences
		gtbl <-
			gtbl |>
			cols_label(contains('rd_') ~ paste('Rate difference per', 100, 'person-years (95% CI)'))

		# Add table spanners for the dichotomous terms
		# Individual variable coverts the names of the levels only
		cols <- gtbl[['_boxhead']]$var
		left <- min(grep(vars, cols))
		span <- (left - 2):(left - 1)
		gtbl <-
			gtbl |>
			tab_spanner(label = tms[[t]], columns = span)
	}


	# Visual modifications
	# 	Indent adjustment lines
	# 	Align headings
	gtbl <-
		gtbl |>
		tab_stub_indent(rows = contains(lvl_lab[-1]), indent = 3) |>
		opt_align_table_header('left') |>
		tab_style(
			style = cell_text(align = 'left'),
			locations = cells_column_spanners()
		) |>
		tab_style(
			style = cell_text(align = 'left'),
			locations = cells_column_labels()
		) |>
		tab_style(
			style = cell_text(align = 'left'),
			locations = cells_body()
		)

	# Return gt table
	gtbl
}

#' @rdname tbl_hazard
#' @export
tbl_categorical_hazard <- function(object,
																	 data,
																	 outcomes = formula(),
																	 followup = character(),
																	 terms = formula(),
																	 adjustment = formula(),
																	 rate_difference = FALSE,
																	 person_years = 100,
																	 ...) {

	# Ensure correct object type
	# Ensure only one model family is present
	checkmate::assert_class(object, 'mdl_tbl')
	if (length(unique(object$name)) > 1) {
		stop('Cannot combine models from different datasets or regressions into a table safely.')
	}

	# Get relevant filtering variables
	## Outcomes
	out <- labeled_formulas_to_named_list(outcomes)
	out_nms <- names(out)
	out_lab <- unlist(unname(out))
	## Terms
	tms <- labeled_formulas_to_named_list(terms)
	tms_nms <- names(tms)
	tms_lab <- unlist(unname(tms))
	## Adjustment
	lvl <- labeled_formulas_to_named_list(adjustment)
	lvl_nms <- names(lvl)
	lvl_lab <- unlist(unname(lvl))

	# Create subset of model_table
	obj <-
		object |>
		dplyr::filter(grepl(paste0(out_nms, collapse = '|'), outcome)) |>
		flatten_models() |>
		dplyr::filter(grepl(paste0(tms_nms, collapse = '|'), term)) |>
		dplyr::select(number, outcome, term, estimate, conf_low, conf_high, p_value)

	# Check early to see if terms are in the appropriate adjustment sets
	for (t in tms_nms) {

		possible_terms <- obj[obj$number == as.numeric(lvl_nms[1]),]$term

		if (!any(grepl(t, possible_terms))) {
			stop(
				'Adjustment sets do not contain the term `',
				t,
				'`. Please reselect terms or adjustment set levels.'
			)
		}

	}

	# Incidence rate data set
	dat <- data[c(out_nms, followup, tms_nms)]

	# Number of tables to make depends on...
	#		Number of outcomes
	# 	Number of terms

	# Get tables ready to be stored
	tbl_tms <- list()
	tbl_out <- list()

	for (t in tms_nms) {
		for (o in out_nms) {

			# Adjusted hazards first
			adj <-
				obj |>
				dplyr::filter(grepl(t, term)) |>
				dplyr::filter(grepl(o, outcome)) |>
				tidyr::pivot_wider(
					names_from = term,
					values_from = c(estimate, conf_low, conf_high, p_value),
					names_glue = '{term}_{.value}'
				) |>
				dplyr::filter(number %in% as.numeric(lvl_nms)) |>
				dplyr::mutate(outcome = o) |>
				dplyr::mutate(number = as.character(number))

			# Person years into table
			py <-
				survival::pyears(survival::Surv(dat[[followup]], dat[[o]]) ~ dat[[t]])

			py$pyears <- py$pyears / 100

			rates <-
				rbind(n = py$n, events = py$event, risk = py$event / py$pyears) |>
				as.data.frame() |>
				rownames_to_column(var = 'row')

			# Save number per group for later in the table
			n <- rates[1, -1]

			# Add in rate differences if needed
			if (rate_difference & length(levels(dat[[t]]) == 2)) {

				# Number of Disease in Exposed & Controls
				nde <- py$event[1]
				ndc <- py$event[2]
				nd <- nde + ndc

				# Person-Time in Exposed & Controls
				pte <- py$pyears[1]
				ptc <- py$pyears[2]
				pt <- pte + ptc

				# Incidence Rate in Exposded & Controls
				ire <- nde/pte
				irc <- ndc/ptc
				ir <- nd/pt

				# Estimates & Confidence Intervals (95%)
				est <- ire - irc
				cl <- est - stats::qnorm(0.9725) * sqrt(nde / pte^2 + ndc / ptc^2)
				ch <- est + stats::qnorm(0.9725) * sqrt(nde / pte^2 + ndc / ptc^2)

				# Add buffering rows
				rd <-
					dplyr::bind_cols(rd_est = est, rd_conf_low = cl, rd_conf_high = ch) |>
					dplyr::add_row(rd_est = rep(NA, 2), .before = 1)

				# Revise table names for this specific term
				names(rd) <- paste0(names(rd), '_', t)

				# Add to rates
				rates <- dplyr::bind_cols(rates, rd)
			}

			# Make compatible with binding
			unadj <-
				rates[-1, ] |>
				tibble::add_row(row = as.character(adj$number))

			# Bind the tables together
			# Order of columns is that reference is on left
			# Each level is then with incidence rate and to the right is hazard

			lvls <- levels(dat[[t]]) # Reference is first
			vars <- unique(grep(t, obj$term, value = TRUE))

			stopifnot(
				'Levels of variables are not consistent within the specificed term'
				= length(lvls)  == length(vars) + 1
			)

			# Basic table merge
			tbl <-
				dplyr::full_join(unadj, adj, by = dplyr::join_by(row == number)) |>
				dplyr::mutate(outcome = o)

			# Organize columns
			for (i in seq_along(vars)) {
				tbl <-
					tbl |>
					dplyr::relocate(contains(vars[i]), .after = lvls[i + 1])
			}

			# Rename columns using just the count
			# The official name for hte level of the term will be on the spanner
			# The first column however is the reference
			names(tbl)[names(tbl) %in% names(n[-1])] <- paste0('n = ', n[-1])
			names(tbl)[names(tbl) %in% names(n[1])] <- paste0('Reference, n = ', n[1])

			# We are rotating through each outcome for a single term
			tbl_out[[o]] <- tbl

		}

		# Now the outcomes can be bound together
		# Don't want to duplicate the outcome and label lines so will drop if dups
		if (length(tbl_tms) == 0) {
			tbl_tms[[t]] <- dplyr::bind_rows(tbl_out)
		} else {
			tbl_tms[[t]] <- dplyr::bind_rows(tbl_out) |>
				dplyr::select(-row, -outcome)
		}

	}

	# Now the terms are bound together and clean up
	tab <-
		dplyr::bind_cols(tbl_tms) |>
		dplyr::mutate(row = as.character(factor(
			row,
			levels = c('events', 'risk', lvl_nms),
			labels = c('Total No. of events', paste('Rate per', person_years, 'person-years'), lvl_lab)
		))) |>
		dplyr::mutate(outcome = factor(outcome, levels = out_nms, labels = out_lab))

	# Convert into gt table
	gtbl <-
		gt(tab, rowname_col = 'row', groupname_col = 'outcome') |>
		cols_hide(columns = contains('p_value')) |>
		sub_missing(missing_text = '') |>
		fmt_number(drop_trailing_zeros = TRUE)

	# Make changes to table programmatically
	for (t in tms_nms) {

		# Specific variables for each term (which is essentially a column group)
		vars <- unique(grep(t, obj$term, value = TRUE))
		lvls <- levels(dat[[t]])

		# Merge hazard estimates together
		# Merge rate differences if available
		for (v in vars) {
			gtbl <-
				gtbl |>
				cols_merge(
					columns = starts_with(v),
					pattern = '{1} ({2}, {3})',
					rows = contains(lvl_lab)
				)

			if (rate_difference & length(levels(dat[[t]])) == 2) {
				gtbl <-
					gtbl |>
					cols_merge(
						columns = starts_with('rd_') & ends_with(v),
						pattern = '{1} ({2}, {3})',
						rows = contains('Rate'))
			}
		}

		# Rename hazard ratio columns
		col_lab <- rep('HR (95% CI)', length(vars))
		names(col_lab) <- paste0(vars, '_estimate')
		gtbl <- gtbl |> cols_label(.list = col_lab)

		# Rename rate differences
		gtbl <-
			gtbl |>
			cols_label(contains('rd_') ~ paste('Rate difference per', 100, 'person-years (95% CI)'))

		# Add table spanners for teh categorcial terms
		# 	Individual variable labels are complex
		#			The reference (on left) is single column
		# 		The rest are grouped by variable name
		#		Overall variable title focuses on the non-reference levels
		# 		Without a rate difference column, the shift left will be 1
		# 	Shift to cover columns dependse on if rate differences are present
		# 		With rate difference, shift left would be 2... I think
		# 		The actual reference category should be left alone
		cols <- gtbl[['_boxhead']]$var
		shift <- ifelse(rate_difference, 2, 1)

		left <-
			vars |>
			sapply(function(.x) {
				min(grep(.x, cols))
			}) |>
			min()

		right <-
			vars |>
			sapply(function(.x) {
				max(grep(.x, cols))
			}) |>
			max()

		# Reference spanner label
		gtbl <-
			gtbl |>
			tab_spanner(label = lvls[1], columns = left - shift - 1)

		# Variable spanner labels
		for (v in seq_along(vars)) {
			lvar <- min(grep(vars[v], cols))
			rvar <- max(grep(vars[v], cols))

			gtbl <-
				gtbl |>
				tab_spanner(label = lvls[1 + v], columns = (lvar - shift):(rvar))
		}

		# Cover the entire non-reference group with label
		gtbl <-
			gtbl |>
			tab_spanner(label = tms[[t]], columns = (left - shift):(right))
	}

	# Visual modifications
	# 	Indent adjustment lines
	# 	Align headings
	gtbl <-
		gtbl |>
		tab_stub_indent(rows = contains(lvl_lab[-1]), indent = 3) |>
		opt_align_table_header('left') |>
		tab_style(
			style = cell_text(align = 'left'),
			locations = cells_column_spanners()
		) |>
		tab_style(
			style = cell_text(align = 'left'),
			locations = cells_column_labels()
		) |>
		tab_style(
			style = cell_text(align = 'left'),
			locations = cells_body()
		)

	# Return gt table
	gtbl
}
