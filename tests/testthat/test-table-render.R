# The renderer (M6.6): the cell frame that every table reduces to, the one
# place that emits {gt} calls, and the layout/style verbs. These tests pin
# down the frame's structure (the M6.1 fields, in order, as plain data), the
# `modify_layout()` presets (the `levels` shape of the retired hazard tables;
# the `interaction` deferral), the `modify_style()` generalization of the old
# accents machinery (criteria on any statistic, instructions beyond bold —
# the defect where `tbl_beta()` recognized only `p <` and hard-coded bold),
# and the two mechanisms that live only in the renderer: the group-scoped
# rowspan emulation and the drawing of `type = "plot"` cells with their
# shared x-scale and reserved `.axis` row.

render_data <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	d
}

render_table <- function(d = render_data()) {
	fmls(mpg ~ .x(wt) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
}

surv_data <- function() {
	d <- survival::lung
	d$sex <- factor(d$sex, levels = 1:2, labels = c("male", "female"))
	d
}

surv_table <- function(d = surv_data()) {
	fmls(Surv(time, status) ~ .x(sex)) |>
		fit(.fn = survival::coxph, data = d, raw = FALSE) |>
		model_table(data = d)
}

# A bare spec shell for driving `render_cell_frame()` with hand-built frames:
# the renderer reads only the layout preset and the style slot
render_spec <- function(preset = "adjustment") {
	structure(
		list(
			layout = list(preset = preset, row_groups = "outcome"),
			style = list(accents = list(), digits = NULL, missing_text = NULL)
		),
		class = "mesa"
	)
}

# One hand-built cell-frame row
frame_row <- function(row_group, row_key, row_index, column_key, column_index,
											value, type = "numeric", row_scope = "row",
											spanner = NA_character_, column_label = "",
											format = list(fmt = "number", digits = 2L,
																		pattern = NULL)) {
	tibble::tibble(
		row_group = row_group, row_key = row_key,
		row_index = as.integer(row_index), row_scope = row_scope,
		spanner = spanner, column_key = column_key,
		column_index = as.integer(column_index), column_label = column_label,
		value = list(value), type = type, format = list(format)
	)
}

# The cell frame ----------------------------------------------------------------

test_that("the cell frame carries the M6.1 fields, in order, as plain data", {

	m <- mesa(render_table())
	frame <- mesa_cell_frame(realize_mesa(m), m)

	expect_equal(names(frame), frame_fields)
	expect_s3_class(frame, "tbl_df")
	expect_type(frame$value, "list")
	expect_type(frame$format, "list")
	expect_true(all(frame$row_scope == "row"))
	expect_true(all(frame$type %in% c("numeric", "text", "reference", "plot")))

	# Values are named lists of the statistics that render together, never
	# formatted text or built plots
	est <- frame$value[[1]]
	expect_named(est, c("estimate", "conf_low", "conf_high"))
	expect_type(est$estimate, "double")

	# The format recipe carries digits and the merge pattern
	expect_equal(frame$format[[1]]$pattern,
							 "{estimate} ({conf_low}, {conf_high})")
})

test_that("reference cells are typed and categorical spanners nest by path", {

	d <- render_data()
	mt <-
		fmls(mpg ~ .x(cyl)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	m <-
		mt |> mesa() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P"))
	frame <- mesa_cell_frame(realize_mesa(m), m)

	# The reference level's estimate and p cells are `reference` cells
	ref <- frame[grepl("cyl::4", frame$column_key, fixed = TRUE), ]
	expect_true(all(ref$type == "reference"))
	expect_true(all(is.na(ref$value[[1]]$estimate)))

	# With statistic headers, each level is an inner spanner under the term:
	# the spanner field carries the path, outermost first
	expect_true(any(grepl(paste0("cyl", spanner_sep, "8"), frame$spanner,
												fixed = TRUE)))

	# The frame is what renders: level `8` appears as a spanner, statistics as
	# headers beneath it
	html <- gt::as_raw_html(as_gt(m))
	expect_true(grepl(">8<", html))
	expect_true(grepl("B (CI)", html, fixed = TRUE))
})

# modify_layout -------------------------------------------------------------------

test_that("modify_layout() validates its preset and row groups at verb time", {

	m <- mesa(render_table())

	expect_error(modify_layout(mtcars), "inherit from")
	expect_error(modify_layout(m, preset = "banana"), "launch layout presets")
	expect_error(modify_layout(m, row_groups = "exposure"), "`row_groups`")

	# No arguments is a no-op, not a replacement
	expect_identical(modify_layout(m), m)

	# A repeat replaces the earlier layout instruction with a message
	m2 <- modify_layout(m, preset = "levels")
	expect_equal(m2$layout$preset, "levels")
	expect_message(m3 <- modify_layout(m2, preset = "adjustment"),
								 "replaces the earlier layout")
	expect_equal(m3$layout$preset, "adjustment")
})

test_that("the interaction preset defers to add_interaction() (M6.9)", {

	m <- mesa(render_table()) |> modify_layout(preset = "interaction")
	expect_error(as_gt(m), "add_interaction")
})

test_that("the levels preset lays statistics on rows and levels on columns", {

	skip_if_not_installed("survival")

	m <-
		surv_table() |>
		mesa() |>
		modify_layout(preset = "levels") |>
		add_events(followup = time) |>
		add_rate_difference()
	g <- as_gt(m)
	dat <- g[["_data"]]

	# The statistic rows come first, then the adjustment rows — the retired
	# hazard-table shape
	expect_equal(
		dat$row_key,
		c("Events", "Rate per 100 person-years", "Model 1")
	)
	# One column per term level (reference first), the rate difference its own
	expect_true(all(c("sex::male", "sex::female", "sex::rate_difference")
									%in% names(dat)))

	# The cells agree with pyears(): events whole, rates to the block digits
	d <- surv_data()
	py <- survival::pyears(
		survival::Surv(time, status) ~ sex, data = d, scale = 365.25
	)
	rate <- as.numeric(py$event) / (as.numeric(py$pyears) / 100)
	expect_equal(dat[["sex::male"]][1],
							 formatC(unname(py$event[1]), format = "f", digits = 0))
	expect_equal(dat[["sex::male"]][2],
							 formatC(unname(rate[1]), format = "f", digits = 1))

	# The term-scoped rate difference sits on the rate row alone
	expect_equal(dat[["sex::rate_difference"]][c(1, 3)], c("", ""))
	expect_true(nzchar(dat[["sex::rate_difference"]][2]))

	# The estimate box fills the adjustment row, the reference level blank
	expect_equal(dat[["sex::male"]][3], "")
	expect_match(dat[["sex::female"]][3], "^\\d")
})

test_that("the levels preset has no place for a p column, and says so", {

	skip_if_not_installed("survival")

	m <-
		surv_table() |>
		mesa() |>
		modify_layout(preset = "levels") |>
		add_estimates(columns = list(beta ~ "HR", conf ~ "95% CI", p ~ "P"))
	expect_error(as_gt(m), "no place for a separate `p`")
})

# modify_style --------------------------------------------------------------------

test_that("modify_style() validates its accents at verb time", {

	m <- mesa(render_table())

	expect_error(modify_style(mtcars), "inherit from")
	expect_error(modify_style(m, accents = list(~"bold")), "two-sided")
	expect_error(modify_style(m, accents = list(q < 0.05 ~ "bold")),
							 "recognized statistics")
	expect_error(modify_style(m, accents = list(p < 0.05 ~ 2)), "instruction")
	expect_error(modify_style(m, digits = -1), "`digits`")
	expect_error(modify_style(m, missing_text = 1), "`missing_text`")

	# No arguments is a no-op; repeating the same field replaces it with a
	# message naming that field
	expect_identical(modify_style(m), m)
	m2 <- modify_style(m, digits = 3)
	expect_message(modify_style(m2, digits = 4), "replaces the earlier .digits.")

	# A different field does not message, and does not wipe the first (M6.11)
	m3 <- expect_no_message(modify_style(m2, missing_text = "-"))
	expect_equal(m3$style$digits, 3)
	expect_equal(m3$style$missing_text, "-")
})

test_that("modify_style() fields merge order-independently and survive a later single-field call (M6.11)", {

	m <- mesa(render_table())

	a <-
		m |>
		modify_style(accents = list(p < 0.05 ~ "bold")) |>
		modify_style(digits = 3) |>
		modify_style(missing_text = "-")
	b <-
		m |>
		modify_style(missing_text = "-") |>
		modify_style(accents = list(p < 0.05 ~ "bold")) |>
		modify_style(digits = 3)

	expect_equal(a$style, b$style)
	expect_equal(length(a$style$accents), 1)
	expect_equal(a$style$digits, 3)
	expect_equal(a$style$missing_text, "-")

	# The accents recorded first are still applied at render after the later
	# digits-only call -- the defect this rule fixes
	d <- render_data()
	mt <-
		fmls(mpg ~ .x(wt)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
	rendered <-
		mt |> mesa() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P")) |>
		modify_style(accents = list(p < 0.05 ~ "bold")) |>
		modify_style(digits = 4) |>
		as_gt()
	styles <- rendered[["_styles"]]
	body <- styles[styles$locname == "data", ]
	flat <- vapply(body$styles, function(s) {
		paste(names(unlist(s)), unlist(s), sep = "=", collapse = ";")
	}, character(1))
	expect_true(any(grepl("weight=bold", flat)))
})

test_that("accents take criteria on any statistic and instructions beyond
					 bold (the old tbl_beta defect)", {

	d <- render_data()
	mt <-
		fmls(mpg ~ .x(wt)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	# wt: strongly significant, negative estimate — so a p criterion and an
	# estimate criterion (which the old machinery could not express) both hit
	m <-
		mt |> mesa() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P")) |>
		modify_style(accents = list(
			p < 0.05 ~ "bold",
			estimate < 0 ~ c("italic", "#B22222")
		))
	styles <- as_gt(m)[["_styles"]]
	body <- styles[styles$locname == "data", ]
	flat <- vapply(body$styles, function(s) {
		paste(names(unlist(s)), unlist(s), sep = "=", collapse = ";")
	}, character(1))

	expect_true(any(grepl("weight=bold", flat)))
	expect_true(any(grepl("style=italic", flat)))
	expect_true(any(grepl("color=#B22222", flat, ignore.case = TRUE)))

	# The accent covers the whole term-level context: the estimate cell and its
	# p cell both bold
	boldCols <- unique(body$colname[grepl("weight=bold", flat)])
	expect_setequal(boldCols, c("wt::est", "wt::p"))

	# A criterion nothing meets accents nothing
	quiet <-
		mt |> mesa() |>
		modify_style(accents = list(p < 1e-30 ~ "bold")) |>
		as_gt()
	quietStyles <- quiet[["_styles"]]
	expect_false(any(quietStyles$locname == "data"))
})

test_that("modify_style() digits and missing text reach the render", {

	d <- render_data()
	mt <-
		fmls(mpg ~ .x(wt)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
	beta <- unname(stats::coef(stats::lm(mpg ~ wt, data = d))["wt"])

	html <-
		mt |> mesa() |> modify_style(digits = 4) |> as_gt() |>
		gt::as_raw_html()
	expect_true(grepl(formatC(beta, format = "f", digits = 4), html,
										fixed = TRUE))

	# A block's own digits still win for its columns
	html2 <-
		mt |> mesa() |>
		add_estimates(columns = list(beta ~ "B"), digits = 1) |>
		modify_style(digits = 4) |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl(formatC(beta, format = "f", digits = 1), html2,
										fixed = TRUE))

	# Missing text fills the reference cells
	dcat <- render_data()
	mcat <-
		fmls(mpg ~ .x(cyl)) |>
		fit(.fn = lm, data = dcat, raw = FALSE) |>
		model_table(data = dcat)
	g <-
		mcat |> mesa() |> modify_style(missing_text = "—") |> as_gt()
	expect_true(any(g[["_data"]][["cyl::4::est"]] == "—"))
})

# The renderer's own mechanisms --------------------------------------------------

test_that("format_cell applies the recipe: digits, patterns, and missing
					 statistics", {

	est <- list(estimate = 1.234, conf_low = 1.1, conf_high = 1.4)
	fmt <- list(fmt = "number", digits = 2L,
							pattern = "{estimate} ({conf_low}, {conf_high})")

	expect_equal(format_cell(est, fmt, ""), "1.23 (1.10, 1.40)")

	# A missing interval drops its parenthetical; a missing estimate empties
	# the cell; an all-missing (reference) cell is the missing text
	expect_equal(
		format_cell(list(estimate = 1.234, conf_low = NA, conf_high = NA),
								fmt, ""),
		"1.23"
	)
	expect_equal(
		format_cell(list(estimate = NA, conf_low = 1.1, conf_high = 1.4),
								fmt, "-"),
		"-"
	)
	expect_equal(
		format_cell(list(estimate = NA, conf_low = NA, conf_high = NA),
								fmt, "—"),
		"—"
	)

	# The p and count formats
	expect_equal(
		format_cell(list(p_value = 0.0004),
								list(fmt = "p", digits = 3L, pattern = "{p_value}"), ""),
		"<0.001"
	)
	expect_equal(
		format_cell(list(n = 32),
								list(fmt = "count", digits = 0L, pattern = NULL), ""),
		"32"
	)
})

test_that("format_cell()'s missing sentinel does not collide with a character
					 statistic that legitimately reads \"NA\" (M6.14)", {

	# A text-typed statistic's own value happening to be the string "NA" must
	# render as-is, not be mistaken for the missing-value marker
	expect_equal(
		format_cell(list(x = "NA"), list(fmt = "number", pattern = "{x}"), "-"),
		"NA"
	)

	# A genuinely missing statistic still blanks the cell
	expect_equal(
		format_cell(list(x = NA_character_), list(fmt = "number", pattern = "{x}"),
								"-"),
		"-"
	)
})

test_that("group-scoped cells emulate a rowspan: duplicated, one visible,
					 the rest masked", {

	frame <- dplyr::bind_rows(
		frame_row("G", "low", 1, "t::est", 1, list(estimate = 1.2,
																							 conf_low = 1.0,
																							 conf_high = 1.4),
							format = list(fmt = "number", digits = 2L,
														pattern = "{estimate} ({conf_low}, {conf_high})")),
		frame_row("G", "high", 2, "t::est", 1, list(estimate = 1.6,
																								conf_low = 1.3,
																								conf_high = 1.9),
							format = list(fmt = "number", digits = 2L,
														pattern = "{estimate} ({conf_low}, {conf_high})")),
		# The across-levels statistic: one cell for the whole band
		frame_row("G", NA_character_, NA, "t::p", 2, list(p_value = 0.021),
							row_scope = "group",
							format = list(fmt = "p", digits = 3L, pattern = "{p_value}"))
	)

	g <- render_cell_frame(frame, render_spec())
	dat <- g[["_data"]]

	# The value is written into every row of its group...
	expect_equal(dat[["t::p"]], c("0.021", "0.021"))

	# ...exactly one visible (with two rows: the first, floated on the seam by
	# bottom alignment), the duplicate blanked by a text transform — content
	# substitution, so the mask holds on dark themes and non-HTML outputs
	styles <- g[["_styles"]]
	pStyles <- styles[styles$colname == "t::p" & styles$locname == "data", ]
	flat <- vapply(pStyles$styles, function(s) {
		paste(names(unlist(s)), unlist(s), sep = "=", collapse = ";")
	}, character(1))
	expect_true(any(pStyles$rownum == 1 & grepl("v_align=bottom", flat)))

	maskTransforms <- Filter(function(t) {
		identical(t$resolved$colnames, "t::p")
	}, g[["_transforms"]])
	expect_length(maskTransforms, 1)
	expect_equal(maskTransforms[[1]]$resolved$rows, 2L)
	expect_equal(maskTransforms[[1]]$fn("0.021"), "")
})

test_that("plot cells draw at render on one shared x-scale, with the
					 reserved .axis row last", {

	skip_if_not(capabilities("png"), "no png device")

	est <- function(e, l, h) list(estimate = e, conf_low = l, conf_high = h)
	plotFormat <- list(fmt = "number", digits = 2L, pattern = NULL,
										 axis = list())
	frame <- dplyr::bind_rows(
		frame_row("G", "a", 1, "t::est", 1, est(1.2, 1.0, 1.4),
							format = list(fmt = "number", digits = 2L,
														pattern = "{estimate} ({conf_low}, {conf_high})")),
		frame_row("G", "b", 2, "t::est", 1, est(0.8, 0.5, 1.3),
							format = list(fmt = "number", digits = 2L,
														pattern = "{estimate} ({conf_low}, {conf_high})")),
		frame_row("G", "a", 1, "t::forest", 2, est(1.2, 1.0, 1.4),
							type = "plot", format = plotFormat),
		frame_row("G", "b", 2, "t::forest", 2, est(0.8, 0.5, 1.3),
							type = "plot", format = plotFormat),
		frame_row(NA_character_, ".axis", NA, "t::forest", 2,
							list(estimate = NA_real_), type = "plot", format = plotFormat)
	)

	g <- render_cell_frame(frame, render_spec())
	dat <- g[["_data"]]

	# The reserved row sorts last, after every row group, other columns blank
	expect_equal(dat$row_key[nrow(dat)], ".axis")
	expect_equal(dat[["t::est"]][nrow(dat)], "")

	# The frame itself stays plain data — drawing happens at render
	expect_type(frame$value[[3]], "list")
	html <- gt::as_raw_html(g)
	expect_true(grepl("<img", html, fixed = TRUE))
})

test_that("the shared plot scale resolves across cells, and axis options
					 override the guesses", {

	values <- list(
		list(estimate = 1.2, conf_low = 1.0, conf_high = 1.4),
		list(estimate = 0.8, conf_low = 0.5, conf_high = 1.3)
	)

	guessed <- resolve_plot_scale(values)
	expect_lte(guessed$limits[1], 0.5)
	expect_gte(guessed$limits[2], 1.4)
	expect_equal(guessed$intercept, 0)
	expect_false(guessed$log)

	log <- resolve_plot_scale(values, options = list(log = TRUE))
	expect_equal(log$intercept, 1)

	forced <- resolve_plot_scale(
		values,
		options = list(limits = c(0.25, 4), intercept = 1, breaks = c(0.5, 1, 2))
	)
	expect_equal(forced$limits, c(0.25, 4))
	expect_equal(forced$breaks, c(0.5, 1, 2))
})

test_that("theme_gt_compact() remains compatible with the renderer", {

	g <- as_gt(mesa(render_table()))
	themed <- theme_gt_compact(g)
	expect_s3_class(themed, "gt_tbl")
})
