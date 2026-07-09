# Laying out the <mesa> cell frame (M6.6, split out in M6.14) -----------------
#
# The *layout* stage: the decorated frame (or, for the interaction preset, its
# own realization), the recorded column blocks, and the layout preset reduce
# to the **cell frame** -- the long tibble of the M6.1 spec, one row per
# rendered cell, which `render_cell_frame()` (table-render.R) consumes and
# nothing else. `mesa_frame()` is the one dispatch point between the
# `"adjustment"`/`"levels"` path (`realize_mesa()` + `mesa_cell_frame()`) and
# the `"interaction"` path (`realize_interaction()` + `cell_frame_interaction()`,
# bundled in `mesa_interaction_frame()` because the interaction preset's rows
# don't pass through the standard flatten-and-decorate frame) -- replacing the
# fork that used to live separately in `as_gt.mesa()`, `mesa_cell_frame()`'s
# switch, and `mesa_interaction_frame()`'s own guards.

#' The single fork between the standard and interaction layout paths
#'
#' Every other choice point in the file used to re-derive this same condition
#' (`as_gt.mesa()`'s branch, a redundant guard inside `mesa_cell_frame()`'s
#' preset switch, `mesa_interaction_frame()`'s own checks); this is the one
#' place it is decided.
#' @keywords internal
#' @noRd
mesa_frame <- function(x) {
	if (identical(x$layout$preset, "interaction") ||
			!is.null(mesa_column_block(x, "interaction"))) {
		mesa_interaction_frame(x)
	} else {
		mesa_cell_frame(realize_mesa(x), x)
	}
}


#' The fields of the cell frame, in their canonical order (the M6.1 spec)
#' @keywords internal
#' @noRd
frame_fields <- c(
	"row_group", "row_key", "row_index", "row_scope", "spanner",
	"column_key", "column_index", "column_label", "value", "type", "format"
)

#' The delimiter separating nested spanner-path components in the frame's
#' `spanner` field (outermost first): a categorical term's level spanner under
#' its term spanner is `"Cylinders///8"`
#' @keywords internal
#' @noRd
spanner_sep <- "///"

#' Reduce a realized `<mesa>` to its cell frame
#'
#' The *layout* stage of the grammar: the decorated frame, the recorded column
#' blocks, and the layout preset reduce to one long tibble with a row per
#' rendered cell -- the only thing `render_cell_frame()` consumes. Cell values
#' stay plain data (named lists of the statistics that render together);
#' formatting is a recipe on the cell, applied at render.
#' @keywords internal
#' @noRd
mesa_cell_frame <- function(dec, spec) {

	ctx <- frame_context(dec, spec)

	switch(
		spec$layout$preset,
		adjustment = cell_frame_adjustment(dec, spec, ctx),
		levels = cell_frame_levels(dec, spec, ctx),
		stop(
			"Unknown layout preset `", spec$layout$preset, "`.",
			call. = FALSE
		)
	)
}

#' The shared layout context: which statistics are displayed, under what
#' headers, in which formats
#'
#' Resolves the column blocks and the late `modify_labels(columns =)` /
#' `modify_style()` overrides once, ahead of the preset builders. Digits
#' resolve block first, then the table-wide style, then 2.
#' @keywords internal
#' @noRd
frame_context <- function(dec, spec) {

	estBlock <- mesa_column_block(spec, "estimates")
	nBlock <- mesa_column_block(spec, "n")
	evBlock <- mesa_column_block(spec, "events")
	rdBlock <- mesa_column_block(spec, "rate_difference")
	forestBlock <- mesa_column_block(spec, "forest")

	digits <- first_of(
		if (!is.null(estBlock)) estBlock$digits,
		spec$style$digits,
		2L
	)

	# Which estimate statistics are displayed and under what headers: the bare
	# default is the merged estimate + CI, headers from the statistics registry
	# (M6.13); `modify_labels(columns=)` overrides the headers late
	estReg <- table_statistics("add_estimates")
	statistics <-
		if (is.null(estBlock)) {
			list(beta = estReg$beta$header, conf = estReg$conf$header)
		} else {
			estBlock$statistics
		}

	# A `modify_labels(columns =)` name must map to a column actually on the
	# mesa; an unrecognized name used to be a silent no-op (M6.11)
	knownColumns <- c(
		names(statistics),
		if (!is.null(evBlock)) c("events", "rate"),
		if (!is.null(rdBlock)) "rate_difference",
		if (!is.null(nBlock)) "n",
		if (!is.null(forestBlock)) "forest"
	)
	unknown <- setdiff(names(spec$labels$columns), knownColumns)
	if (length(unknown) > 0) {
		stop(
			"`modify_labels(columns = )` names a column not on the mesa: ",
			paste0("`", unknown, "`", collapse = ", "),
			". The displayed columns are: ",
			paste0("`", knownColumns, "`", collapse = ", "), ".",
			call. = FALSE
		)
	}

	for (nm in names(spec$labels$columns)) {
		if (nm %in% names(statistics)) {
			statistics[[nm]] <- as.character(spec$labels$columns[[nm]])
		}
	}
	showBeta <- "beta" %in% names(statistics)
	showConf <- "conf" %in% names(statistics)
	showEst <- showBeta || showConf
	showP <- "p" %in% names(statistics)

	# A forest column reads the estimate and interval; it computes nothing new,
	# so both statistics must be on the specification
	if (!is.null(forestBlock) && !(showBeta && showConf)) {
		stop(
			"`add_forest()` draws the estimate and its interval, so the ",
			"specification must carry both: keep `beta` and `conf` in ",
			"`add_estimates()`.",
			call. = FALSE
		)
	}

	# The data statistics sit ahead of the estimates within a level (the old
	# hazard tables' reading order: events, rate, then the adjusted estimates);
	# a forest column trails its estimates
	statCols <- c(
		if (!is.null(evBlock)) c("events", "rate"),
		if (showEst) "est", if (showP) "p",
		if (!is.null(forestBlock)) "forest"
	)

	# The data-statistic headers, base text from the registry (M6.13),
	# overridable late by `modify_labels(columns=)`
	dataHeaders <- list(
		events = table_statistics("add_events")$events$header,
		rate = if (!is.null(evBlock)) {
			paste0(table_statistics("add_events")$rate$header, " per ",
						 evBlock$person_years, " person-years")
		},
		rate_difference = if (!is.null(rdBlock)) {
			paste0(table_statistics("add_rate_difference")$rate_difference$header,
						 " (", format(rdBlock$conf_level * 100), "% CI)")
		}
	)
	for (nm in names(spec$labels$columns)) {
		if (nm %in% names(dataHeaders)) {
			dataHeaders[[nm]] <- as.character(spec$labels$columns[[nm]])
		}
	}

	nLabel <- nBlock$label
	if (!is.null(spec$labels$columns[["n"]])) {
		nLabel <- as.character(spec$labels$columns[["n"]])
	}
	forestLabel <- ""
	if (!is.null(spec$labels$columns[["forest"]])) {
		forestLabel <- as.character(spec$labels$columns[["forest"]])
	}

	# An explicit `add_estimates()` always shows its statistic labels as the
	# column headers (the term label moves up to a spanner); only the bare
	# default keeps the compact term-label headers
	statHeaders <- !is.null(estBlock) || length(statCols) > 1

	# The header of the merged estimate box: "HR (95% CI)" when both statistics
	# are present, either alone otherwise -- and the merge pattern its cells
	# render through
	estHeader <-
		if (showBeta && showConf) {
			paste0(statistics$beta, " (", statistics$conf, ")")
		} else if (showBeta) {
			statistics$beta
		} else if (showConf) {
			statistics$conf
		}
	estPattern <-
		if (showBeta && showConf) {
			"{estimate} ({conf_low}, {conf_high})"
		} else if (showBeta) {
			"{estimate}"
		} else if (showConf) {
			"({conf_low}, {conf_high})"
		}

	list(
		estBlock = estBlock, nBlock = nBlock, evBlock = evBlock,
		rdBlock = rdBlock, forestBlock = forestBlock,
		statistics = statistics, statCols = statCols,
		statHeaders = statHeaders, showP = showP,
		estHeader = estHeader, estPattern = estPattern,
		dataHeaders = dataHeaders, nLabel = nLabel, forestLabel = forestLabel,
		forestFormat = if (!is.null(forestBlock)) {
			list(fmt = "number", digits = digits, pattern = NULL,
					 axis = forestBlock$axis, width = forestBlock$width)
		},
		estFormat = list(fmt = "number", digits = digits, pattern = estPattern),
		pFormat = list(fmt = "p", digits = 3L, pattern = "{p_value}"),
		countFormat = list(fmt = "count", digits = 0L, pattern = NULL),
		rateFormat = list(
			fmt = "number",
			digits = if (!is.null(evBlock)) evBlock$digits else 1L,
			pattern = "{rate}"
		),
		rdFormat = list(
			fmt = "number",
			digits = if (!is.null(evBlock)) evBlock$digits else 1L,
			pattern = "{estimate} ({conf_low}, {conf_high})"
		)
	)
}

#' The row identity each decorated row lays out under: its row-group band and
#' its stub label
#'
#' The default groups by outcome; `modify_layout(row_groups = "strata")` swaps
#' the group to the stratum band and moves the outcome into the stub's
#' parenthetical qualifier instead.
#' @keywords internal
#' @noRd
frame_row_context <- function(dec, layout) {

	if (identical(layout$row_groups, "strata")) {
		group <- ifelse(
			is.na(dec$strata),
			"",
			paste0(dec$strata, ": ", naToBlank(dec$stratum_level))
		)
		nOut <- length(unique(dec$outcome_label))
		nData <- length(unique(stats::na.omit(dec$data_id)))
		qual <- vapply(seq_len(nrow(dec)), function(i) {
			parts <- c(
				if (nOut > 1) dec$outcome_label[i],
				if (!is.na(dec$subset[i])) dec$subset[i],
				if (nData > 1 && !is.na(dec$data_id[i])) dec$data_id[i]
			)
			if (length(parts) > 0) {
				paste0(" (", paste(parts, collapse = ", "), ")")
			} else {
				""
			}
		}, character(1))
		list(group = group, key = paste0(dec$adj_label, qual))
	} else {
		list(
			group = dec$outcome_label,
			key = paste0(dec$adj_label, row_qualifier(dec))
		)
	}
}

#' One term-level's stable column-key base: `wt`, or `cyl::8`
#' @keywords internal
#' @noRd
column_key_base <- function(variable, level) {
	ifelse(is.na(level), variable, paste0(variable, "::", level))
}

#' The cell frame of the `"adjustment"` preset (and the bare default)
#'
#' Adjustment sets on rows, outcomes (or strata) as row groups, a statistic
#' block per term or term level on columns, terms spanning their levels -- and,
#' with statistic headers, each categorical level an inner spanner over its
#' statistic columns. The term-scoped rate difference takes a column of its
#' own after its term's level columns (the group-scoped-cell rule: here the
#' levels are columns).
#' @keywords internal
#' @noRd
cell_frame_adjustment <- function(dec, spec, ctx) {

	rc <- frame_row_context(dec, spec$layout)
	dec$row_group <- rc$group
	dec$row_key <- rc$key
	dec$key_base <- column_key_base(dec$variable, dec$level)

	# Column descriptors, in display order: n first, then each term's level
	# columns (reference first, as decorated) statistic by statistic, then the
	# term's rate-difference column
	statLabel <- function(s) {
		switch(
			s,
			est = ctx$estHeader, p = ctx$statistics$p,
			events = ctx$dataHeaders$events, rate = ctx$dataHeaders$rate,
			forest = ctx$forestLabel
		)
	}
	cols <- list()
	if (!is.null(ctx$nBlock)) {
		cols[[length(cols) + 1]] <-
			tibble::tibble(column_key = "n", column_label = ctx$nLabel,
										 spanner = NA_character_)
	}
	for (v in unique(dec$variable)) {
		vDec <- dec[dec$variable == v, , drop = FALSE]
		termLabel <- vDec$term_label[1]
		categorical <- isTRUE(vDec$categorical[1])
		lvls <- vDec[!duplicated(vDec$key_base),
								 c("key_base", "level", "level_label"), drop = FALSE]
		for (i in seq_len(nrow(lvls))) {
			levelLabel <- naToBlank(lvls$level_label[i])
			for (s in ctx$statCols) {
				cols[[length(cols) + 1]] <- tibble::tibble(
					column_key = paste0(lvls$key_base[i], "::", s),
					column_label =
						if (categorical && !ctx$statHeaders) {
							levelLabel
						} else {
							statLabel(s)
						},
					spanner =
						if (categorical && ctx$statHeaders) {
							paste(termLabel, levelLabel, sep = spanner_sep)
						} else if (categorical || ctx$statHeaders) {
							termLabel
						} else {
							NA_character_
						}
				)
			}
		}
		# The bare single-statistic column of a continuous term carries the term
		# label directly, with no spanner
		if (!categorical && !ctx$statHeaders) {
			cols[[length(cols)]]$column_label <- termLabel
		}
		if (!is.null(ctx$rdBlock)) {
			cols[[length(cols) + 1]] <- tibble::tibble(
				column_key = paste0(v, "::rate_difference"),
				column_label = ctx$dataHeaders$rate_difference,
				spanner = termLabel
			)
		}
	}
	cols <- dplyr::bind_rows(cols)
	cols$column_index <- seq_len(nrow(cols))

	# Cells, one statistic block at a time. A forest cell reads the same
	# numbers as its estimate cell (inverted to reciprocals when the block
	# says so -- bounds swap because 1/x reverses order); it computes nothing
	forest_value <- function(i) {
		if (isTRUE(ctx$forestBlock$invert)) {
			list(estimate = 1 / dec$estimate[i],
					 conf_low = 1 / dec$conf_high[i],
					 conf_high = 1 / dec$conf_low[i])
		} else {
			list(estimate = dec$estimate[i], conf_low = dec$conf_low[i],
					 conf_high = dec$conf_high[i])
		}
	}
	cells <- list()
	for (s in ctx$statCols) {
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = dec$row_group,
			row_key = dec$row_key,
			column_key = paste0(dec$key_base, "::", s),
			value = switch(
				s,
				est = lapply(seq_len(nrow(dec)), function(i) {
					list(estimate = dec$estimate[i], conf_low = dec$conf_low[i],
							 conf_high = dec$conf_high[i])
				}),
				p = lapply(dec$p_value, function(p) list(p_value = p)),
				events = lapply(dec$events, function(e) list(events = e)),
				rate = lapply(dec$rate, function(r) list(rate = r)),
				forest = lapply(seq_len(nrow(dec)), forest_value)
			),
			type = ifelse(
				dec$is_reference & s %in% c("est", "p", "forest"),
				"reference",
				if (s == "forest") "plot" else "numeric"
			),
			format = rep(list(switch(
				s,
				est = ctx$estFormat, p = ctx$pFormat,
				events = ctx$countFormat, rate = ctx$rateFormat,
				forest = ctx$forestFormat
			)), nrow(dec))
		)
	}
	if (!is.null(ctx$nBlock)) {
		nDec <- dec[!duplicated(paste(dec$row_group, dec$row_key)), ,
								drop = FALSE]
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = nDec$row_group,
			row_key = nDec$row_key,
			column_key = "n",
			value = lapply(nDec$nobs, function(n) list(n = n)),
			type = "numeric",
			format = rep(list(ctx$countFormat), nrow(nDec))
		)
	}
	if (!is.null(ctx$rdBlock)) {
		rdDec <- dec[!duplicated(paste(dec$row_group, dec$row_key,
																	 dec$variable)), , drop = FALSE]
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = rdDec$row_group,
			row_key = rdDec$row_key,
			column_key = paste0(rdDec$variable, "::rate_difference"),
			value = lapply(seq_len(nrow(rdDec)), function(i) {
				list(estimate = rdDec$rate_diff[i],
						 conf_low = rdDec$rate_diff_low[i],
						 conf_high = rdDec$rate_diff_high[i])
			}),
			type = "numeric",
			format = rep(list(ctx$rdFormat), nrow(rdDec))
		)
	}
	cells <- dplyr::bind_rows(cells)
	rows <- unique(dec[c("row_group", "row_key")])

	# The forest block's one sanctioned alteration of the row axis: the
	# reserved `.axis` row, holding each forest column's bottom axis strip,
	# always sorted after every row group
	if (!is.null(ctx$forestBlock)) {
		forestKeys <- unique(paste0(dec$key_base, "::forest"))
		cells <- dplyr::bind_rows(cells, tibble::tibble(
			row_group = NA_character_,
			row_key = ".axis",
			column_key = forestKeys,
			value = rep(list(list(estimate = NA_real_)), length(forestKeys)),
			type = "plot",
			format = rep(list(ctx$forestFormat), length(forestKeys))
		))
		rows <- dplyr::bind_rows(
			rows,
			tibble::tibble(row_group = NA_character_, row_key = ".axis")
		)
	}

	assemble_cell_frame(cells, rows, cols)
}

#' The cell frame of the `"levels"` preset
#'
#' The shape of the retired hazard tables: statistic rows -- the event count
#' and the incidence rate when `add_events()` is on the mesa, then one row per
#' adjustment set -- with the term levels on columns and terms as spanners.
#' Each level column merges the estimate and interval into one box, so a
#' separate `p` column has no place here (it errors, per the launch-support
#' rule). The term-scoped rate difference is a column of its own; its value
#' sits on the rate row.
#' @keywords internal
#' @noRd
cell_frame_levels <- function(dec, spec, ctx) {

	if (ctx$showP) {
		stop(
			"The `levels` layout merges each level's estimate and interval into ",
			"one column, and has no place for a separate `p` column at launch. ",
			"Drop `p` from `add_estimates()`, or use the `adjustment` preset.",
			call. = FALSE
		)
	}
	if (!is.null(ctx$forestBlock)) {
		stop(
			"The `levels` layout merges each level into one displayed column; a ",
			"forest column there is deferred past launch. Use the `adjustment` ",
			"or `interaction` preset.",
			call. = FALSE
		)
	}

	rc <- frame_row_context(dec, spec$layout)
	dec$row_group <- rc$group
	dec$row_key <- rc$key
	dec$key_base <- column_key_base(dec$variable, dec$level)

	hasEvents <- !is.null(ctx$evBlock)
	eventsKey <- ctx$dataHeaders$events
	rateKey <- ctx$dataHeaders$rate

	# Rows per group: the statistic rows first, then the adjustment rows in
	# their decorated order
	adjRows <- unique(dec[c("row_group", "row_key")])
	rows <- dplyr::bind_rows(lapply(unique(adjRows$row_group), function(g) {
		tibble::tibble(
			row_group = g,
			row_key = c(
				if (hasEvents) c(eventsKey, rateKey),
				adjRows$row_key[adjRows$row_group == g]
			)
		)
	}))

	# Column descriptors: n first, then each term's level columns (reference
	# first) and its rate-difference column
	cols <- list()
	if (!is.null(ctx$nBlock)) {
		cols[[length(cols) + 1]] <-
			tibble::tibble(column_key = "n", column_label = ctx$nLabel,
										 spanner = NA_character_)
	}
	for (v in unique(dec$variable)) {
		vDec <- dec[dec$variable == v, , drop = FALSE]
		termLabel <- vDec$term_label[1]
		categorical <- isTRUE(vDec$categorical[1])
		lvls <- vDec[!duplicated(vDec$key_base),
								 c("key_base", "level_label"), drop = FALSE]
		cols[[length(cols) + 1]] <- tibble::tibble(
			column_key = lvls$key_base,
			column_label =
				if (categorical) naToBlank(lvls$level_label) else termLabel,
			spanner = if (categorical) termLabel else NA_character_
		)
		if (!is.null(ctx$rdBlock)) {
			cols[[length(cols) + 1]] <- tibble::tibble(
				column_key = paste0(v, "::rate_difference"),
				column_label = ctx$dataHeaders$rate_difference,
				spanner = termLabel
			)
		}
	}
	cols <- dplyr::bind_rows(cols)
	cols$column_index <- seq_len(nrow(cols))

	cells <- list()

	# The estimate box of each adjustment row x level column
	if ("est" %in% ctx$statCols) {
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = dec$row_group,
			row_key = dec$row_key,
			column_key = dec$key_base,
			value = lapply(seq_len(nrow(dec)), function(i) {
				list(estimate = dec$estimate[i], conf_low = dec$conf_low[i],
						 conf_high = dec$conf_high[i])
			}),
			type = ifelse(dec$is_reference, "reference", "numeric"),
			format = rep(list(ctx$estFormat), nrow(dec))
		)
	}

	# The data-statistic rows, one value per (group, term level); models within
	# a group share them, so the first decorated row of each level speaks for it
	if (hasEvents) {
		evDec <- dec[!duplicated(paste(dec$row_group, dec$key_base)), ,
								 drop = FALSE]
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = evDec$row_group,
			row_key = eventsKey,
			column_key = evDec$key_base,
			value = lapply(evDec$events, function(e) list(events = e)),
			type = "numeric",
			format = rep(list(ctx$countFormat), nrow(evDec))
		)
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = evDec$row_group,
			row_key = rateKey,
			column_key = evDec$key_base,
			value = lapply(evDec$rate, function(r) list(rate = r)),
			type = "numeric",
			format = rep(list(ctx$rateFormat), nrow(evDec))
		)
	}
	if (!is.null(ctx$rdBlock)) {
		rdDec <- dec[!duplicated(paste(dec$row_group, dec$variable)), ,
								 drop = FALSE]
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = rdDec$row_group,
			row_key = rateKey,
			column_key = paste0(rdDec$variable, "::rate_difference"),
			value = lapply(seq_len(nrow(rdDec)), function(i) {
				list(estimate = rdDec$rate_diff[i],
						 conf_low = rdDec$rate_diff_low[i],
						 conf_high = rdDec$rate_diff_high[i])
			}),
			type = "numeric",
			format = rep(list(ctx$rdFormat), nrow(rdDec))
		)
	}
	if (!is.null(ctx$nBlock)) {
		nDec <- dec[!duplicated(paste(dec$row_group, dec$row_key)), ,
								drop = FALSE]
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = nDec$row_group,
			row_key = nDec$row_key,
			column_key = "n",
			value = lapply(nDec$nobs, function(n) list(n = n)),
			type = "numeric",
			format = rep(list(ctx$countFormat), nrow(nDec))
		)
	}
	cells <- dplyr::bind_rows(cells)

	assemble_cell_frame(cells, rows, cols)
}

#' The `<mesa>` realization of the `"interaction"` layout
#'
#' The interaction preset and `add_interaction()` come as a pair -- the block
#' *defines* the preset's rows -- so both mismatches error here, and the frame
#' is built from `estimate_interaction()`'s within-level effects rather than
#' the standard flatten-and-decorate path.
#' @keywords internal
#' @noRd
mesa_interaction_frame <- function(x) {

	block <- mesa_column_block(x, "interaction")
	if (identical(x$layout$preset, "interaction") && is.null(block)) {
		stop(
			"The `interaction` layout's rows are defined by `add_interaction()`; ",
			"add it to the specification.",
			call. = FALSE
		)
	}
	if (!identical(x$layout$preset, "interaction")) {
		stop(
			"`add_interaction()` defines the rows of the `interaction` layout, ",
			"so it cannot be an add-on to the `", x$layout$preset, "` preset. ",
			"Select the layout with `modify_layout(preset = \"interaction\")`.",
			call. = FALSE
		)
	}
	ctx <- frame_context(NULL, x)
	if (!is.null(ctx$evBlock) || !is.null(ctx$rdBlock)) {
		stop(
			"The `interaction` layout does not carry event or rate columns at ",
			"launch.",
			call. = FALSE
		)
	}

	dec <- realize_interaction(x, block)
	cell_frame_interaction(dec, x, ctx)
}

#' Realize the interaction rows: one per interaction level, per model
#' @keywords internal
#' @noRd
realize_interaction <- function(x, block) {

	mt <- x$mdl_tbl
	sel <- resolve_selection(
		mt,
		outcomes = x$selection$outcomes,
		exposures = x$selection$exposures,
		terms = x$selection$terms,
		adjustment = x$selection$adjustment,
		strata = x$selection$strata
	)
	models <- sel$models[!is.na(sel$models$interaction), , drop = FALSE]
	if (nrow(models) == 0) {
		stop(
			"The `interaction` layout needs models fitted with an interaction ",
			"term (declare one with `.i()` in the formula).",
			call. = FALSE
		)
	}

	# The launch shape is a single outcome x exposure (the 6.1 preset table):
	# the bands are the interaction terms
	if (length(unique(models$outcome)) > 1 ||
			length(unique(models$exposure)) > 1) {
		stop(
			"The `interaction` layout displays a single outcome \u00d7 exposure ",
			"at a time; narrow the mesa with `select_outcomes()` / ",
			"`select_exposures()`.",
			call. = FALSE
		)
	}

	# The scale decision is the estimates block's, deferring to the M5 family
	# inference by default -- the same contract as every other table
	estBlock <- mesa_column_block(x, "estimates")
	flat <- suppressMessages(flatten_models(
		models, exponentiate = if (is.null(estBlock)) NULL else estBlock$exponentiate
	))
	expByModel <- tapply(flat$exponentiated, flat$interaction, unique)

	# Interaction-term labels default from the term table
	ints <- unique(models$interaction)
	meta <- resolve_term_metadata(mt, stats::setNames(as.list(ints), ints))

	dec <- dplyr::bind_rows(lapply(seq_len(nrow(models)), function(i) {
		row <- models[i, , drop = FALSE]
		est <- estimate_interaction(
			row,
			exposure = row$exposure,
			interaction = row$interaction,
			conf_level = block$conf_level
		)
		if (isTRUE(expByModel[[row$interaction]])) {
			est$estimate <- exp(est$estimate)
			est$conf_low <- exp(est$conf_low)
			est$conf_high <- exp(est$conf_high)
		}
		est$variable <- row$interaction
		est$term_label <-
			meta$label[match(row$interaction, meta$variable)]
		est
	}))

	# Late relabels apply to the interaction terms and their levels exactly as
	# they do to any other term
	dec <- apply_relabels(dec, x$labels$relabels)
	dec
}

#' The cell frame of the `"interaction"` layout
#'
#' Interaction levels on rows, one band per interaction term, no spanners.
#' The per-level statistics (n, the merged estimate, the forest cell) are
#' ordinary rows; the across-levels p-value is a **group-scoped cell**
#' (`row_scope = "group"`) that the renderer floats over the level rows -- the
#' 6.1 spec's answer to the old white-out hack.
#' @keywords internal
#' @noRd
cell_frame_interaction <- function(dec, spec, ctx) {

	dec$row_group <- dec$term_label
	dec$row_key <- dec$level_label

	forestBlock <- ctx$forestBlock
	cols <- list()
	add_col <- function(key, label) {
		tibble::tibble(column_key = key, column_label = label,
									 spanner = NA_character_)
	}
	if (!is.null(ctx$nBlock)) cols[[length(cols) + 1]] <- add_col("n", ctx$nLabel)
	showEst <- "est" %in% ctx$statCols
	if (showEst) cols[[length(cols) + 1]] <- add_col("est", ctx$estHeader)
	if (!is.null(forestBlock)) {
		cols[[length(cols) + 1]] <- add_col("forest", ctx$forestLabel)
	}
	if (ctx$showP) {
		cols[[length(cols) + 1]] <- add_col("p", ctx$statistics$p)
	}
	cols <- dplyr::bind_rows(cols)
	cols$column_index <- seq_len(nrow(cols))

	forest_value <- function(i) {
		if (isTRUE(forestBlock$invert)) {
			list(estimate = 1 / dec$estimate[i],
					 conf_low = 1 / dec$conf_high[i],
					 conf_high = 1 / dec$conf_low[i])
		} else {
			list(estimate = dec$estimate[i], conf_low = dec$conf_low[i],
					 conf_high = dec$conf_high[i])
		}
	}

	cells <- list()
	if (!is.null(ctx$nBlock)) {
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = dec$row_group, row_key = dec$row_key,
			column_key = "n",
			value = lapply(dec$nobs, function(n) list(n = n)),
			type = "numeric",
			format = rep(list(ctx$countFormat), nrow(dec))
		)
	}
	if (showEst) {
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = dec$row_group, row_key = dec$row_key,
			column_key = "est",
			value = lapply(seq_len(nrow(dec)), function(i) {
				list(estimate = dec$estimate[i], conf_low = dec$conf_low[i],
						 conf_high = dec$conf_high[i])
			}),
			type = "numeric",
			format = rep(list(ctx$estFormat), nrow(dec))
		)
	}
	if (!is.null(forestBlock)) {
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = dec$row_group, row_key = dec$row_key,
			column_key = "forest",
			value = lapply(seq_len(nrow(dec)), forest_value),
			type = "plot",
			format = rep(list(ctx$forestFormat), nrow(dec))
		)
	}
	if (ctx$showP) {
		# One across-levels p-value per band: a group-scoped cell, floated over
		# the level rows by the renderer
		pDec <- dec[!duplicated(dec$row_group), , drop = FALSE]
		cells[[length(cells) + 1]] <- tibble::tibble(
			row_group = pDec$row_group, row_key = NA_character_,
			row_scope = "group",
			column_key = "p",
			value = lapply(pDec$p_value, function(p) list(p_value = p)),
			type = "numeric",
			format = rep(list(ctx$pFormat), nrow(pDec))
		)
	}
	cells <- dplyr::bind_rows(cells)

	rows <- unique(dec[c("row_group", "row_key")])
	if (!is.null(forestBlock)) {
		cells <- dplyr::bind_rows(cells, tibble::tibble(
			row_group = NA_character_, row_key = ".axis",
			column_key = "forest",
			value = list(list(estimate = NA_real_)),
			type = "plot",
			format = list(ctx$forestFormat)
		))
		rows <- dplyr::bind_rows(
			rows, tibble::tibble(row_group = NA_character_, row_key = ".axis")
		)
	}

	assemble_cell_frame(cells, rows, cols)
}

#' Join the cells to their row and column descriptors and put the frame in its
#' canonical field order
#' @keywords internal
#' @noRd
assemble_cell_frame <- function(cells, rows, cols) {

	rows$row_index <- stats::ave(
		seq_len(nrow(rows)), naToBlank(rows$row_group), FUN = seq_along
	)

	frame <- dplyr::left_join(cells, rows, by = c("row_group", "row_key"))
	frame <- dplyr::left_join(
		frame, cols[c("column_key", "column_index", "column_label", "spanner")],
		by = "column_key"
	)
	if (!"row_scope" %in% names(frame)) {
		frame$row_scope <- "row"
	} else {
		frame$row_scope[is.na(frame$row_scope)] <- "row"
	}
	frame$row_index <- as.integer(frame$row_index)
	frame$column_index <- as.integer(frame$column_index)

	frame <- frame[order(
		match(paste(frame$row_group, frame$row_key),
					paste(rows$row_group, rows$row_key)),
		frame$column_index
	), , drop = FALSE]

	tibble::as_tibble(frame[frame_fields])
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

