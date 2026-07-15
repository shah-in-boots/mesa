test_that("mdl_gt remains a validated S7 specification", {
	spec <- mdl_gt(regression_mdl_tbl())
	expect_true(S7::S7_inherits(spec, mdl_gt))
	expect_true(inherits(spec, mdl_gt))
	expect_named(spec@groups, "effect")
	expect_equal(spec@layout$preset, "adjustment")
	expect_equal(spec@effects$interaction, FALSE)
	expect_match(base::format(spec)[1], "<mdl_gt> specification", fixed = TRUE)
	expect_output(base::print(spec), "<mdl_gt> specification", fixed = TRUE)

	expect_error(
		{ spec@layout$rows <- c("outcome", "banana") },
		"semantic dimensions"
	)
})

test_that("cell-group verbs are keyed and order-independent", {
	mt <- regression_mdl_tbl()
	a <- mt |>
		mdl_gt() |>
		add_n() |>
		add_forest() |>
		add_estimates() |>
		place_cells(p, forest, axis = "columns", .after = "effect")
	b <- mt |>
		mdl_gt() |>
		place_cells(c("p", "forest"), axis = "columns", .after = "effect") |>
		add_estimates() |>
		add_forest() |>
		add_n()

	expect_equal(names(a@groups), c("effect", "p", "n", "forest"))
	expect_equal(names(a@groups), names(b@groups))
	expect_equal(inspect_mdl_gt(a, "effects"), inspect_mdl_gt(b, "effects"))
	expect_equal(inspect_mdl_gt(a, "measures"), inspect_mdl_gt(b, "measures"))
	expect_equal(inspect_mdl_gt(a, "cells"), inspect_mdl_gt(b, "cells"))
})

test_that("layout axes and placements validate at specification time", {
	spec <- mdl_gt(regression_mdl_tbl())
	expect_error(modify_layout(spec, rows = c("outcome", "outcome")),
		"unique dimensions")
	expect_error(modify_layout(spec, rows = "outcome", columns = "outcome"),
		"both")
	expect_error(modify_layout(spec, columns = "unknown"), "unknown dimensions")
	expect_error(place_cells(spec, unknown, axis = "columns"),
		"Unknown cell group")
	expect_error(place_cells(spec, effect, .before = "p", .after = "n"),
		"only one")

	custom <- modify_layout(spec,
		rows = c("outcome", "term"),
		columns = c("adjustment", "contrast")
	)
	expect_equal(custom@layout$rows, c("outcome", "term"))
	expect_equal(custom@layout$columns, c("adjustment", "contrast"))
})

test_that("effect and style instructions merge without changing the S7 class", {
	spec <- regression_mdl_tbl() |>
		mdl_gt() |>
		add_estimates(view = "separate") |>
		modify_labels(cyl ~ "Cylinders", columns = list(beta ~ "B")) |>
		modify_style(
			theme = "compact", widths = list(effect = 140),
			align = list(effect = "right"), reference_text = "Reference"
		)

	expect_true(S7::S7_inherits(spec, mdl_gt))
	expect_equal(spec@groups$effect$view, "separate")
	expect_equal(spec@style$theme, "compact")
	expect_equal(spec@style$reference_text, "Reference")
	cells <- inspect_mdl_gt(spec, "cells")
	expect_true(all(c("B", "95% CI") %in% unique(cells$column_label)))
})

test_that("inspect_mdl_gt exposes every build stage", {
	all <- inspect_mdl_gt(mdl_gt(regression_mdl_tbl()), "all")
	expect_named(all, c(
		"selected", "effects", "conditions", "measures", "groups", "layout",
		"cells"
	))
	expect_s3_class(all$effects, "tbl_df")
	expect_s3_class(all$measures, "tbl_df")
	expect_s3_class(all$cells, "tbl_df")
})
