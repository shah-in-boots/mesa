# The forest column block (M6.8). A forest column is a column type available
# to any table, not a separate table family: `add_forest()` records a block
# that *reads* the estimate and interval already on the specification and
# computes nothing new. Its cells enter the cell frame as plain numbers
# (`type = "plot"`), the shared x-scale resolves at render across the whole
# column, the bottom axis strip is the reserved `.axis` row, and the block's
# dense style enters as overridable defaults. The invariant this buys — and
# the blueprint asks to test — is that adding or dropping the block changes
# no other cell. `invert` is implemented for real here (it was dead code
# behind `if (FALSE)` in the old forest table).

forest_table <- function() {
	d <- mtcars
	fmls(mpg ~ .x(wt) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
}

test_that("add_forest() validates at verb time and records like every verb", {

	m <- mesa(forest_table())

	expect_error(add_forest(mtcars), "inherit from")
	expect_error(add_forest(m, axis = list(1, 2)), "named list")
	expect_error(add_forest(m, axis = list(color = "red")),
							 "does not know the option")
	expect_error(add_forest(m, axis = list(limits = 1)), "length-2")
	expect_error(add_forest(m, width = -5), "`width`")
	expect_error(add_forest(m, invert = NA), "`invert`")

	m2 <- add_forest(m, axis = list(log = TRUE))
	types <- vapply(m2$columns, function(b) b$type, character(1))
	expect_equal(types, "forest")
	expect_message(add_forest(m2, width = 200), "replaces the earlier forest")

	out <- utils::capture.output(print(add_forest(m, invert = TRUE)))
	expect_true(any(grepl("forest \\(inverted\\)", out)))
})

test_that("a forest block requires estimate and conf on the specification", {

	# It reads them and computes nothing new; the check surfaces at
	# realization, keeping the verbs order-independent
	m <-
		forest_table() |>
		mesa() |>
		add_estimates(columns = list(p ~ "P")) |>
		add_forest()
	expect_error(as_gt(m), "keep `beta` and `conf`")

	# The bare default carries both, so a bare mesa takes a forest column
	bare <- forest_table() |> mesa() |> add_forest()
	frame <- mesa_cell_frame(realize_mesa(bare), bare)
	expect_true(any(frame$type == "plot"))
})

test_that("adding or dropping add_forest() changes no other cell", {

	base <-
		forest_table() |>
		mesa() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P"))
	withForest <- base |> add_forest()

	f0 <- mesa_cell_frame(realize_mesa(base), base)
	f1 <- mesa_cell_frame(realize_mesa(withForest), withForest)

	# Only the forest columns and the reserved .axis row appear
	extra <- f1[grepl("::forest$", f1$column_key) | f1$row_key == ".axis", ]
	expect_true(all(extra$type == "plot" | extra$type == "reference"))
	expect_true(".axis" %in% f1$row_key)
	expect_false(".axis" %in% f0$row_key)

	# Every other cell is untouched (column indexes renumber around the new
	# columns; everything else must match exactly)
	rest <- f1[!grepl("::forest$", f1$column_key) & f1$row_key != ".axis", ]
	drop <- function(f) f[setdiff(names(f), "column_index")]
	expect_equal(drop(rest), drop(f0), ignore_attr = TRUE)

	# And the surviving columns keep their relative order
	shared <- intersect(unique(f1$column_key), unique(f0$column_key))
	expect_equal(
		unique(f0$column_key[f0$column_key %in% shared]),
		unique(f1$column_key[f1$column_key %in% shared])
	)
})

test_that("forest cells read the estimate cells' numbers; invert draws
					 reciprocals with swapped bounds", {

	m <- forest_table() |> mesa() |> add_forest()
	frame <- mesa_cell_frame(realize_mesa(m), m)

	fcells <- frame[frame$column_key == "wt::forest" &
										frame$row_key != ".axis", ]
	ecells <- frame[frame$column_key == "wt::est", ]
	expect_equal(fcells$value, ecells$value)

	minv <- forest_table() |> mesa() |> add_forest(invert = TRUE)
	finv <- mesa_cell_frame(realize_mesa(minv), minv)
	icells <- finv[finv$column_key == "wt::forest" & finv$row_key != ".axis", ]
	for (i in seq_len(nrow(icells))) {
		expect_equal(icells$value[[i]]$estimate,
								 1 / ecells$value[[i]]$estimate)
		expect_equal(icells$value[[i]]$conf_low,
								 1 / ecells$value[[i]]$conf_high)
		expect_equal(icells$value[[i]]$conf_high,
								 1 / ecells$value[[i]]$conf_low)
	}
})

test_that("the axis options flow to the shared scale; the block renders", {

	skip_if_not(capabilities("png"), "no png device")

	m <-
		forest_table() |>
		mesa() |>
		add_forest(axis = list(limits = c(-10, 2), intercept = 0))
	g <- as_gt(m)
	dat <- g[["_data"]]

	# The reserved row sorts last, blank in every other column
	expect_equal(dat$row_key[nrow(dat)], ".axis")
	expect_equal(dat[["wt::est"]][nrow(dat)], "")

	html <- gt::as_raw_html(g)
	expect_true(grepl("<img", html, fixed = TRUE))
})

test_that("the dense padding is a default the style layer can override", {

	m <- forest_table() |> mesa() |> add_forest()
	dense <- as_gt(m)
	spacious <- as_gt(modify_style(m, padding = 1))
	plain <- as_gt(mesa(forest_table()))

	padOf <- function(g) {
		opts <- g[["_options"]]
		opts$value[opts$parameter == "data_row_padding"][[1]]
	}
	expect_false(identical(padOf(dense), padOf(plain)))
	expect_false(identical(padOf(dense), padOf(spacious)))

	# modify_style validates its new knob like the others
	expect_error(modify_style(m, padding = -1), "`padding`")
})

test_that("the levels layout defers the forest column, clearly", {

	m <-
		forest_table() |>
		mesa() |>
		modify_layout(preset = "levels") |>
		add_forest()
	expect_error(as_gt(m), "deferred past launch")
})
