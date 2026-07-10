# Interaction rows (M6.9). `add_interaction()` defines the rows of the
# `interaction` layout: one per interaction level, banded by interaction
# term, with per-level estimates derived by the generalized
# `estimate_interaction()` and the single across-levels p-value carried as a
# group-scoped cell the renderer floats over the band — the first-class
# replacement for the old `tbl_interaction_forest()` white-out hack. The old
# forest table is now just the chain *interaction layout + add_n() +
# add_estimates() + add_forest()*, verified here the way 6.7 verified the
# other monoliths; `tbl_interaction_forest()` is deleted on the same terms.

interaction_table <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	m1 <-
		fmls(mpg ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	m2 <-
		fmls(mpg ~ .x(hp) + .i(cyl)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	suppressMessages(model_table(m1, m2, data = d))
}

interaction_chain <- function(mt = interaction_table()) {
	# `add_interaction()` implies the `interaction` layout (M6.12) -- no
	# `modify_layout()` gesture needed for the common case
	suppressMessages(
		mt |>
			mesa() |>
			add_interaction() |>
			add_n(label = "No.") |>
			add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI",
																	 p ~ "P for interaction"))
	)
}

test_that("add_interaction() validates and records like every verb", {

	m <- mesa(interaction_table())

	expect_error(add_interaction(mtcars), "inherit from")
	expect_error(add_interaction(m, conf_level = 0), "`conf_level`")
	expect_error(add_interaction(m, conf_level = 1), "`conf_level`")

	m2 <- suppressMessages(add_interaction(m))
	expect_message(add_interaction(m2, conf_level = 0.9),
								 "replaces the earlier interaction")

	out <- utils::capture.output(print(m2))
	expect_true(any(grepl("interaction rows", out)))
})

test_that("add_interaction() implies the interaction layout (M6.12)", {

	mt <- interaction_table()

	# Declaring the block alone is enough -- no modify_layout() gesture needed
	expect_message(
		implied <- mt |> mesa() |> add_interaction(),
		"sets the layout to the `interaction` preset"
	)
	expect_equal(implied$layout$preset, "interaction")
	expect_no_error(implied |> add_n() |> add_estimates() |> as_gt())

	# Calling it again (layout already `interaction`) is silent about the layout
	# -- only the column-block replacement message fires
	once <- suppressMessages(mt |> mesa() |> add_interaction())
	msgs <- testthat::capture_messages(add_interaction(once))
	expect_false(any(grepl("sets the layout", msgs)))
	expect_true(any(grepl("replaces the earlier interaction", msgs)))

	# An explicitly conflicting preset errors rather than silently overriding
	expect_error(
		mt |> mesa() |> modify_layout(preset = "levels") |> add_interaction(),
		"already selected the `levels` preset"
	)
})

test_that("the block and the layout come as a pair, erroring apart", {

	mt <- interaction_table()

	# The layout has no rows without the block, even when declared explicitly
	expect_error(
		mt |> mesa() |> modify_layout(preset = "interaction") |> as_gt(),
		"defined by `add_interaction\\(\\)`"
	)

	# Interaction-less models have nothing to lay out
	d <- mtcars
	plain <-
		fmls(mpg ~ .x(hp)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
	expect_error(
		plain |> mesa() |> add_interaction() |> as_gt(),
		"models fitted with an interaction term"
	)
})

test_that("one model per interaction term: shared terms error instead of
					 overwriting each other's cells", {

	# Two models around the same interaction term realize rows with the same
	# term x level keys; they would collide at pivot, so the layout refuses
	# until the mesa is narrowed to one model per term
	d <- mtcars
	m1 <- suppressMessages(
		fmls(mpg ~ .x(hp) + .i(am)) |>
			fit(.fn = lm, data = d, raw = FALSE)
	)
	m2 <- suppressMessages(
		fmls(mpg ~ .x(hp) + wt + .i(am)) |>
			fit(.fn = lm, data = d, raw = FALSE)
	)
	mt <- suppressMessages(model_table(m1, m2, data = d))

	spec <- suppressMessages(
		mt |> mesa() |> add_interaction() |> add_estimates()
	)
	expect_error(as_gt(spec), "one model per interaction term")

	# Narrowed to a single adjustment set, the same chain lays out fine
	narrowed <- suppressMessages(
		mt |> mesa() |> select_adjustment(2 ~ "Adjusted") |>
			add_interaction() |> add_estimates()
	)
	expect_no_error(as_gt(narrowed))

})

test_that("the interaction frame: level rows per band, per-level statistics,
					 the p-value group-scoped", {

	m <- interaction_chain()
	frame <- mesa_interaction_frame(m)

	# One band per interaction term, one row per level of its variable
	expect_setequal(unique(stats::na.omit(frame$row_group)), c("am", "cyl"))
	amRows <- unique(frame$row_key[frame$row_group %in% "am" &
																	 frame$row_scope == "row"])
	cylRows <- unique(frame$row_key[frame$row_group %in% "cyl" &
																		frame$row_scope == "row"])
	expect_equal(amRows, c("0", "1"))
	expect_equal(cylRows, c("4", "6", "8"))

	# The across-levels p-value is a group-scoped cell: one per band, no row
	# of its own
	pCells <- frame[frame$column_key == "p", ]
	expect_equal(nrow(pCells), 2)
	expect_true(all(pCells$row_scope == "group"))
	expect_true(all(is.na(pCells$row_key)))

	# Per-level estimates match the generalized estimate_interaction()
	d <- mtcars
	d$cyl <- factor(d$cyl)
	ref <- stats::lm(mpg ~ hp * cyl, data = d)
	b <- stats::coef(ref)
	est8 <- unname(b["hp"] + b["hp:cyl8"])
	cell <- frame$value[frame$row_group %in% "cyl" & frame$row_key %in% "8" &
												frame$column_key == "est"][[1]]
	expect_equal(cell$estimate, est8)

	# The per-level n counts the attached data
	nCell <- frame$value[frame$row_group %in% "cyl" & frame$row_key %in% "8" &
												 frame$column_key == "n"][[1]]
	expect_equal(nCell$n, sum(mtcars$cyl == 8))
})

test_that("the rendered interaction table floats one visible p per band", {

	g <- as_gt(interaction_chain())
	dat <- g[["_data"]]

	# The p-value fills every row of its band (the rowspan emulation)...
	expect_equal(dat$row_key, c("0", "1", "4", "6", "8"))
	expect_equal(dat$p[1], dat$p[2])
	expect_equal(dat$p[3], dat$p[4])
	expect_equal(dat$p[4], dat$p[5])
	expect_false(dat$p[1] == dat$p[3])

	# ...with the duplicates masked and one copy centered on the band: the
	# two-row `am` band floats row 1 on the seam, the three-row `cyl` band
	# keeps its middle row (global row 4)
	styles <- g[["_styles"]]
	pStyles <- styles[styles$colname == "p" & styles$locname == "data", ]
	flat <- vapply(pStyles$styles, function(s) {
		paste(names(unlist(s)), unlist(s), sep = "=", collapse = ";")
	}, character(1))
	visible <- pStyles$rownum[grepl("v_align", flat)]
	expect_setequal(visible, c(1, 4))
	expect_true(any(pStyles$rownum == 1 & grepl("v_align=bottom", flat)))
	expect_true(any(pStyles$rownum == 4 & grepl("v_align=middle", flat)))

	# The duplicates are blanked by a text transform — a content substitution,
	# not a white-text style, so the mask holds on any theme or output format
	masked <- unlist(lapply(g[["_transforms"]], function(t) {
		if (identical(t$resolved$colnames, "p")) t$resolved$rows else integer()
	}))
	expect_setequal(masked, c(2, 3, 5))
	blanked <- vapply(g[["_transforms"]], function(t) {
		identical(t$fn("0.021"), "")
	}, logical(1))
	expect_true(all(blanked[vapply(g[["_transforms"]], function(t) {
		identical(t$resolved$colnames, "p")
	}, logical(1))]))

	# Level relabels arrive late, as everywhere
	html <-
		interaction_chain() |>
		modify_labels(am ~ c("Manual", "Automatic"), cyl ~ "Cylinders") |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl("Manual", html, fixed = TRUE))
	expect_true(grepl("Cylinders", html, fixed = TRUE))
})

test_that("the full old-forest chain renders: estimates, forest, floating p", {

	skip_if_not(capabilities("png"), "no png device")

	g <-
		interaction_chain() |>
		add_forest() |>
		as_gt()
	dat <- g[["_data"]]

	# The reserved axis row lands after both bands
	expect_equal(dat$row_key[nrow(dat)], ".axis")
	html <- gt::as_raw_html(g)
	expect_true(grepl("<img", html, fixed = TRUE))
})

test_that("the interaction layout narrows to one outcome × exposure", {

	d <- mtcars
	m1 <-
		fmls(mpg ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	m2 <-
		fmls(qsec ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	mt <- suppressMessages(model_table(m1, m2, data = d))

	spec <-
		mt |> mesa() |> modify_layout(preset = "interaction") |>
		add_interaction()
	expect_error(as_gt(spec), "single outcome")

	# select_outcomes() narrows it into shape
	g <- spec |> select_outcomes(~mpg) |> as_gt()
	expect_s3_class(g, "gt_tbl")

	# The retired monolith is gone
	expect_false("tbl_interaction_forest" %in% getNamespaceExports("mesa"))
})
