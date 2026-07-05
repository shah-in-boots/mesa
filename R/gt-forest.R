#' Forest plot and table
#'
#' @description
#' Forest plots are usually ways to describe contrasting data, such as between
#' strata, or to show interaction (if present). We can show the estimates of
#' each parameter along a dichotomous subgroup, or we can show the estimates of
#' a primary exposure along a multitude of subgroups. This function allows both
#' methods (and some spectrum in between) to demonstrate these.
#'
#' @inheritParams tbls
#'
#' @param invert A `<logical>` to determine if the odds or hazard ratio should
#'   be shown as the reciprocal values. Instead of a decreasing hazard for every
#'   unit increase, it describes an increasing hazard for every unit decrease.
#'   Default is `FALSE`
#'
#' @param axis Argument to help modify the forest plot itself. This is a
#'   `<formula>` or list of formulas of the following parameters. If they are
#'   not named, the function will attempt to "guess" the optimal parameters. The
#'   options are:
#'
#'   - title = label or title for the column describing the forest plot
#'
#'   - lim = x-axis limits
#'
#'   - breaks = x-axis tick marks or break points that should be numbers
#'
#'   - int = x-axis intercept
#'
#'   - lab = label for the x-axis
#'
#'   - scale = defaults to continuous, but may also use a log transformation as
#'   well `c("continuous", "log")`
#'
#'   For example: `list(title ~ "Decreasing Hazard", lab ~ "HR (95% CI))`
#'
#' @param width Describes the width of each column in a `<formula>` or list of
#'   formulas. The **RHS** is a decimal reflecting the percent each column
#'   should take of the entire table. The forest plot is usually given 30% of
#'   the width. The default options attempt to be sensible. Options, indicated
#'   by the term on the -*LHS** of the formula, include:
#'
#'   - n = Column describing number of observations
#'
#'   - beta = Column of estimate and confidence intervals (usually combined)
#'
#'   - forest = Column containing forest plots
#'
#'   For example: `list(n ~ .1, forest ~ 0.3)`
#'
#' @param forest A `<formula>` or list of formulas that can be used to help
#'   customize the forest plot prior to generation of the table. The options
#'   directly correspond to `ggplot2` aesthetic specifications that can modify
#'   the visual aspects of the forest plot. The currently supported arguments:
#'
#'   - size = Relative size of the marker for point estimate
#'
#'   - shape = Shape of the marker for point estimate
#'
#'   - fill = Fill of the marker for point estimate
#'
#'   - linetype = Vertical line that serves as the x-intercept across the table
#'
#'   - linewidth = Thickness of lines, for both vertical and horixontal axes
#'
#' @param digits The number of significant figures to present. If the numbers
#'   are not scaled in a presentable fashion, can always adjust the table
#'   subsequently.
#'
#' @import gt ggplot2
#' @name tbl_forest
NULL

#' @rdname tbl_forest
#' @export
tbl_interaction_forest <- function(object,
																	 outcomes = formula(),
																	 exposures = formula(),
																	 interactions = formula(),
																	 level_labels = formula(),
																	 columns = list(beta ~ "Estimate",
																	 							 conf ~ "95% CI",
																	 							 n ~ "No."),
																	 axis = list(scale ~ "continuous"),
																	 width = list(),
																	 forest = list(),
																	 exponentiate = FALSE,
																	 invert = FALSE,
																	 digits = 2,
																	 ...) {

	# Validation
	# 	Appropriate objects are `mdl_tbl`
	# 	The models must be of the same type for comparison sake
	# 	Must have interaction terms available
	# 	Dataset for interaction must be attached

	# Table arguments ----

	checkmate::assert_class(object, 'mdl_tbl')

	## Outcomes = outcomes and how to rename
	out <- labeled_formulas_to_named_list(outcomes)
	out_nms <- names(out)
	out_lab <- unlist(unname(out))
	checkmate::assert_true(all(out_nms %in% object$outcome))
	stopifnot(
		'`tbl_*_forest()` only displays a single outcome at a time currently. Please file an issue if there is interest in multi-outcome forest tables.' =
			length(out_nms) == 1
	)

	## Exposures
	exp <- labeled_formulas_to_named_list(exposures)
	exp_nms <- names(exp)
	exp_lab <- unlist(unname(exp))
	checkmate::assert_true(all(exp_nms %in% object$exposure))

	## Interactions
	int <- labeled_formulas_to_named_list(interactions)
	int_nms <- names(int)
	int_lab <- unlist(unname(int))
	it <- levels(interaction(exp_nms, int_nms, sep = ":"))
	checkmate::assert_true(all(int_nms %in% object$interaction))

	## Levels
	# Approach to relabeling interaction levels
	# If multiple strata, may have multiple levels to relabel
	lvl <- labeled_formulas_to_named_list(level_labels)
	lvl_nms <- names(lvl)
	lvl_lab <-
		lvl |>
		lapply(str2lang) |>
		lapply(as.character) |>
		lapply(utils::tail, -1)

	# Table ----

	## Table setup
	# Each table can only show one outcome ~ exposure relationship
	# Thus, n_tables = n_outcomes x n_exposures
	# Rows are dependent on number of interactions being assessed
	tbl_exp <- list()
	tbl_out <- list()

	# Loop through each outcome and exposure
	for (o in out_nms) {
		for (e in exp_nms) {

			# Limited to the current exposure, outcome, and any interaction terms
			obj <-
				object |>
				dplyr::filter(outcome == o) |>
				dplyr::filter(exposure == e) |>
				dplyr::filter(interaction %in% int_nms)

			# Get interaction terms that are available in this subset
			intVars <-
				obj$interaction |>
				gsub(paste0(e, ":"), "", x = _)

			# Rows of table will be be rows in the <mdl_tbl> object
			# Should be the same length as interaction variables that are available
			n <- nrow(obj)
			stopifnot(
				"Number of interaction variables not equal to number of rows in <mdl_tbl> object." =
					length(intVars) == max(n)
			)

			# List of interaction estimates
			# Need to get p-value from each interaction
			# Need to get confidence interval from each interaction
			# Put all rows together in a table (and ensure named appropriately)
			intRows <- vector("list", length(n))
			for (i in seq(n)) {
				intRows[[i]] <-
					estimate_interaction(obj[i, ], exposure = e, interaction = intVars[i])
			}
			names(intRows) <- intVars
			intTab <- dplyr::bind_rows(intRows, .id = 'interaction')

			# Invert the values if necessary to get reciprocals
			if (FALSE) {
				intTab <-
					dplyr::mutate(intTab, across(
						c(all_of(estVar), -any_of('p_value')),
						~ 1 / .x
					))

				if ("conf_low" %in% estVar) {
					intTab <-
						intTab |>
						dplyr::rename(conf_high = conf_low, conf_low = conf_high)
				}
			}

			# Store in list by exposure status
			tbl_exp[[e]] <- intTab

		}
		# For each outcome, store in list by outcome status
		tbl_out[[o]] <- dplyr::bind_rows(tbl_exp, .id = "exposure")
	}

	# Now, in the darkness, bind them
	tbl <- dplyr::bind_rows(tbl_out, .id = 'outcome')

	# Plot arguments ----

	## Columns
	cols <- labeled_formulas_to_named_list(columns)
	estVar <- character()
	modVar <- character()
	if ("beta" %in% names(cols)) {
		estVar <- append(estVar, "estimate")
	}
	if ("conf" %in% names(cols)) {
		estVar <- append(estVar, c("conf_low", "conf_high"))
	}
	if ("p" %in% names(cols)) {
		estVar <- append(estVar, "p_value")
	}
	if ("n" %in% names(cols)) {
		modVar <- append(modVar, "nobs")
	}

	## Column widths
	colWidths <-
		labeled_formulas_to_named_list(width) |>
		lapply(as.numeric)
	if (is.null(colWidths$n)) {
		colWidths$n <- 0.1
	}
	if (is.null(colWidths$beta)) {
		colWidths$beta <- 0.4
	}
	if (is.null(colWidths$forest)) {
		colWidths$forest <- 0.4
	}

	## Axis arguments
	x_vars <- labeled_formulas_to_named_list(axis)

	if ("title" %in% names(x_vars)) {
		title <- x_vars$title
	} else {
		title <- ""
	}

	if ('lim' %in% names(x_vars)) {
		lim_val <- eval(str2lang(x_vars$lim))
		xmin <- min(lim_val)
		xmax <- max(lim_val)
	} else {
		xmin <- min(tbl$conf_low, na.rm = TRUE)
		xmax <- max(tbl$conf_high, na.rm = TRUE)
	}

	if ('int' %in% names(x_vars)) {
		xint <- eval(x_vars$int)
	} else {
		xint <- dplyr::case_when(
			xmin < -1 & xmax <= 0 ~ -1,
			xmin > -1 & xmax <= 0 ~ 0,
			xmin < 0 & xmax > 0 ~ 0,
			xmin >= 0 & xmax <= 1 ~ 0,
			xmin >= 0 & xmax > 1 ~ 1
		)
	}

	if ('breaks' %in% names(x_vars)) {
		breaks <- eval(x_vars$breaks)
	} else {
		breaks <- ggplot2::waiver()
	}

	if ('lab' %in% names(x_vars)) {
		lab <- x_vars$lab
	} else {
		lab <- NULL
	}

	if ('scale' %in% names(x_vars)) {
		scale <- x_vars$scale
	} else if (unique(object$model_call) %in% c('glm', 'coxph')) {
		scale <- 'log'
	} else {
		scale <- 'continuous'
	}

	## Basic plots in table format
	# Will inject the general sizing of plots here
	# These options will scale with each other, and start and sensible default
	forestOptions <- labeled_formulas_to_named_list(forest)

	# Default plot options
	plotOptions <- list(
		size = 1,
		shape = 'circle',
		linetype = 3,
		linewidth = 1
	)

	for (i in names(forestOptions)) {
		plotOptions[[i]] <- forestOptions[[i]]
	}


	# Plot ----

	ptbl <-
		tbl |>
		dplyr::group_by(outcome, exposure, interaction, level) |>
		tidyr::nest() |>
		dplyr::mutate(gg = purrr::map(data, ~ {
			ggplot(.x, aes(x = estimate, y = 0)) +
				geom_point(size = plotOptions$size * 30, shape = plotOptions$shape) +
				geom_linerange(aes(
					xmax = conf_high,
					xmin = conf_low,
					linewidth = plotOptions$linewidth
				)) +
				geom_vline(
					xintercept = xint,
					linetype = plotOptions$linetype,
					linewidth = plotOptions$linewidth * 5
				) +
				#theme_minimal() +
				theme_void() +
				theme(
					axis.text.y = element_blank(),
					axis.title.y = element_blank(),
					axis.text.x = element_blank(),
					axis.title.x = element_blank(),
					axis.line.x = element_blank(),
					legend.position = "none",
					panel.grid.major = element_blank(),
					panel.grid.minor = element_blank()
				) +
				{
					if(scale == "log") {
						scale_x_continuous(
							trans = scales::pseudo_log_trans(sigma = 0.1, base = exp(1)),
							breaks = breaks,
							limits = c(xmin, xmax),
							oob = scales::oob_squish
						)
					} else {
						scale_x_continuous(
							breaks = breaks,
							limits = c(xmin, xmax),
							oob = scales::oob_squish
						)
					}
				}
		})) |>
		tidyr::unnest(data) |>
		dplyr::ungroup() |>
		dplyr::add_row()

	## Create axis at bottom
	tmp <- ptbl$gg[[1]]
	tmp$layers[1:2] <- NULL
	btm_axis <-
		tmp +
		xlab(lab) +
		theme(
			axis.text.x = element_text(margin = margin(10, 0 , 0 , 0), size = plotOptions$size * 50),
			axis.ticks.x = element_line(linewidth = plotOptions$size * 5),
			axis.ticks.length.x = unit(30, "pt"),
			axis.title.x = element_text(margin = margin(10, 0, 0 , 0), size = plotOptions$size * 100),
			axis.line.x = element_line(
				linewidth = plotOptions$size * 5,
				arrow = grid::arrow(
					length = grid::unit(50, "pt"),
					ends = "both",
					type = "closed"
				),
				colour = 'black'
			)
		)

	ptbl$gg[nrow(ptbl)] <- list(btm_axis)

	## Masks
	# As we will be whiting out every other row, will need a masking layer
	# Will pick the "lowest level" in each strata to "white out"
	# To use to help filter for which variables to modify in grouped rows
	masking_lvls <-
		tbl |>
		dplyr::group_by(outcome, exposure, interaction) |>
		dplyr::mutate(mask = dplyr::if_else(level == min(level), FALSE, TRUE)) |>
		dplyr::pull(mask)

	## Template table
	# Adding in parallel positions for plots
	ftbl <-
		tbl |>
		# Rename or relabel components
		dplyr::group_by(outcome, exposure, interaction) |>
		dplyr::rowwise() |>
		dplyr::mutate(level = lvl_lab[[interaction]][as.numeric(level) + 1]) |>
		dplyr::mutate(
			outcome = out[[outcome]],
			exposure = exp[[exposure]],
			interaction = int[[interaction]],
		) |>
		dplyr::ungroup() |>
		# Add masking data
		dplyr::mutate(mask = masking_lvls) |>
		dplyr::mutate(ggplots = NA) |>
		dplyr::add_row() |>
		# Place in correct columnar order
		dplyr::select(interaction,
									level,
									any_of(modVar),
									any_of(estVar),
									ggplots,
									mask)


	## Grouping variables
	# May need to consider the number of exposures and outcomes
	rowCol <- "level"
	groupCol <- "interaction"

	## `gt` table
	# Convert to a `gt` table here and convert plots
	# Variable that are meant to fine tune the graph are evaluated here
	gtbl <-
		ftbl |>
		gt(rowname_col = rowCol, groupname_col = groupCol) |>
		# Estimates and confidence intervals
		{\(.) {
			if (all(c("estimate", "conf_low", "conf_high") %in% estVar)) {
				. |>
					cols_merge(columns = estVar[1:3],
										 pattern = "{1} ({2}, {3})") |>
					cols_width(estimate ~ pct(40)) |>
					cols_label(estimate = cols$beta)
			} else {
				.
			}
		}}() |>
		# Number of observations
		{\(.) {
			if (all(c("nobs") %in% modVar)) {
				. |>
					cols_width(nobs ~ pct(10)) |>
					cols_label(nobs = cols$n)
			} else {
				.
			}
		}}() |>
		# P value included for interaction groups
		{\(.) {
			if (all(c("p_value") %in% estVar)) {
				. |>
					cols_move_to_end(p_value) |>
					cols_label(p_value = cols$p) |>
					tab_style(
						style = list(
							cell_text(color = "white", size = px(0)),
							cell_borders(sides = "all", color = NULL)
						),
						locations = list(
							cells_body(columns = p_value,
												 rows = mask == TRUE)
						)
					) |>
					tab_style(
						style = list(
							cell_text(align = "center", v_align = "bottom")
						),
						locations = list(
							cells_body(columns = p_value,
												 rows = mask == FALSE)
						)
					)
			} else {
				.
			}
		}}() |>
		# Control digits and significant figures
		fmt_number(
			columns = where(is.numeric),
			drop_trailing_zeros = TRUE,
			n_sigfig = 2
		) |>
		tab_style(
			style = list(
				cell_borders(sides = "all", color = NULL)
			),
			locations = list(
				cells_body(columns = c(all_of(modVar), all_of(estVar))),
				cells_stub(rows = everything())
			)
		) |>
		# Hide and white-out sections of plots appropriately
		cols_hide(mask) |>
		opt_vertical_padding(scale = 0) |>
		opt_table_outline(style = "none") |>
		tab_options(
			data_row.padding = px(0),
			table_body.border.bottom.width = px(0),
			table_body.border.top.width = px(0),
			column_labels.border.top.width = px(0)
		) |>
		tab_style(
			style = list(
				cell_text(color = "white", size = px(0)),
				cell_borders(sides = "all", color = NULL)
			),
			locations = list(
				cells_body(columns = ggplots),
				cells_row_groups(groups = "NA"),
				cells_stub(rows = is.na(level))
			)
		) |>
		tab_style(
			style = list(
				cell_text(color = "white", size = px(0))
			),
			locations = list(
				cells_body(columns = c(all_of(modVar), all_of(estVar)),
									 rows = is.na(level))
			)
		) |>
		# Modification of ggplot
		cols_label(
			ggplots = title
		) |>
		text_transform(
			locations = cells_body(columns = ggplots),
			fn = function(x) {
				purrr::map(ptbl$gg,
									 ggplot_image,
									 height = px(50),
									 aspect_ratio = 1.5)
			}
		)

	# Return
	gtbl
}
