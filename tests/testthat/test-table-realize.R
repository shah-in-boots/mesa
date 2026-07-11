# The closing coverage of M6 (6.10): snapshot tests on the **cell frame** for
# every preset and the bare default. Cell frames are plain tibbles, so a
# table regression diffs cleanly in review — each snapshot is one line per
# rendered cell, with the value and format recipes flattened to text. The
# rendered-gt structure has its thin checks throughout the other table
# suites (`_data`, `_boxhead`, `_spanners`, `_styles`).

# One stable line per cell of a frame
frame_lines <- function(frame) {
	flat <- function(l) {
		if (is.null(l) || length(l) == 0) {
			return("-")
		}
		paste(vapply(seq_along(l), function(i) {
			v <- l[[i]]
			nm <- names(l)[i]
			txt <-
				if (is.null(v)) {
					"NULL"
				} else if (is.numeric(v)) {
					paste(formatC(v, format = "g", digits = 6), collapse = ",")
				} else if (is.atomic(v)) {
					paste(as.character(v), collapse = ",")
				} else {
					paste(deparse(v), collapse = "")
				}
			paste0(nm, "=", txt)
		}, character(1)), collapse = " ")
	}
	vapply(seq_len(nrow(frame)), function(i) {
		paste(
			paste0("[", naToBlank(frame$row_group[i]), " | ",
						 naToBlank(frame$row_key[i]), " | ", frame$row_scope[i], "]"),
			paste0("(", frame$column_index[i], ") ", frame$column_key[i]),
			paste0("<", naToBlank(frame$spanner[i]), " / ",
						 naToBlank(frame$column_label[i]), ">"),
			frame$type[i],
			flat(frame$value[[i]]),
			"|", flat(frame$format[[i]]),
			sep = "  "
		)
	}, character(1))
}

snapshot_data <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	d
}

test_that("cell frame snapshot: the bare default (adjustment preset)", {

	d <- snapshot_data()
	m <-
		fmls(mpg ~ .x(cyl) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d) |>
		mdl_gt()

	frame <- mdl_gt_cell_frame(realize_mdl_gt(m), m)
	expect_snapshot(cat(frame_lines(frame), sep = "\n"))
})

test_that("cell frame snapshot: the adjustment preset with column blocks", {

	d <- snapshot_data()
	m <-
		fmls(mpg ~ .x(cyl) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d) |>
		mdl_gt() |>
		select_adjustment(1 ~ "Crude", 2 ~ "Adjusted") |>
		add_n(label = "No.") |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P")) |>
		modify_labels(cyl ~ "Cylinders")

	frame <- mdl_gt_cell_frame(realize_mdl_gt(m), m)
	expect_snapshot(cat(frame_lines(frame), sep = "\n"))
})

test_that("cell frame snapshot: the levels preset", {

	skip_if_not_installed("survival")

	d <- survival::lung
	d$sex <- factor(d$sex, levels = 1:2, labels = c("male", "female"))
	m <-
		fmls(Surv(time, status) ~ .x(sex)) |>
		fit(.fn = survival::coxph, data = d, raw = FALSE) |>
		model_table(data = d) |>
		mdl_gt() |>
		modify_layout(preset = "levels") |>
		add_events(followup = time) |>
		add_rate_difference() |>
		add_estimates(columns = list(beta ~ "HR", conf ~ "95% CI"))

	frame <- mdl_gt_cell_frame(realize_mdl_gt(m), m)
	expect_snapshot(cat(frame_lines(frame), sep = "\n"))
})

test_that("cell frame snapshot: the interaction preset (with forest)", {

	d <- mtcars
	m1 <-
		fmls(mpg ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	mt <- suppressMessages(model_table(m1, data = d))

	m <-
		mt |>
		mdl_gt() |>
		modify_layout(preset = "interaction") |>
		add_interaction() |>
		add_n(label = "No.") |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P")) |>
		add_forest()

	frame <- mdl_gt_interaction_frame(m)
	expect_snapshot(cat(frame_lines(frame), sep = "\n"))
})
