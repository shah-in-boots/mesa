test_that("forest plot for interaction can be made", {

	skip()

	f <- vec_c(fmls(hp + mpg ~ .x(wt) + .i(am) + cyl),
						 fmls(hp + mpg ~ .x(wt) + .i(vs) + cyl)) |>
		suppressMessages()
	m <- fit(f, .fn = lm, data = mtcars, raw = FALSE)
	object <- model_table(linear = m, data = mtcars)

	# Variables of interest for filtering are function arguments
	outcomes <- list(hp ~ "Horsepower")
	exposures <- list(wt ~ "Weight")
	interactions <- list(am ~ "Transmission", vs ~ "Engine")
	level_labels <- list(am ~ c("Automatic", "Manual"),
											 vs ~ c("V8", "V6"))

	# Forest plot modifying variables
	columns <- list(beta ~ "Estimate", conf ~ "95% CI", n ~ "No.", p ~ "Interaction p-value")
	axis <- list(scale ~ "continuous", title ~ "Forest")
	width <- list(forest ~ 0.4)
	forest <- list()

	gtbl <-
		tbl_interaction_forest(
			object = object,
			outcomes = outcomes,
			exposures = exposures,
			interactions = interactions,
			level_labels = level_labels,
			columns = columns,
			axis = axis,
			forest = forest
		)

	expect_s3_class(gtbl, "gt_tbl")
	expect_contains(unlist(gtbl$`_boxhead`$column_label), c("Estimate", "Forest"))
	expect_equal(nrow(gtbl$`_stub_df`), 5)
	expect_equal({
		dat <- gtbl$`_styles`
		# Second row should be colored white for p-value
		sty <- dat[dat$colname == "p_value" & dat$rownum == 2, ]$styles[[1]]
		sty$cell_text$color
	}, "#FFFFFF")
	expect_equal({
		dat <- gtbl$`_styles`
		# First row should be vertically aligned at the bottom
		sty <- dat[dat$colname == "p_value" & dat$rownum == 1, ]$styles[[1]]
		sty$cell_text$v_align
	}, "bottom")

})

test_that("interaction table errors appropriately", {

	cars <-
		mtcars |>
		dplyr::mutate(heavy = ifelse(wt > 3.2, 1, 0))

	m1 <-
		fmls(heavy ~ .x(hp) + .i(vs)) |>
		fit(.fn = glm, data = cars, raw = FALSE)
	m2 <-
		fmls(heavy ~ .x(hp) + .i(am)) |>
		fit(.fn = glm, data = cars, raw = FALSE)

	mt <- vlndr::model_table(one = m1, two = m2)

	expect_error({
		tbl_interaction_forest(
			object = mt,
			outcomes = hvy ~ "Weight",
			exposures = hp ~ 'Horsepower',
			interactions = list(vs ~ "V/S", am ~ "Transmission"),
			level_labels = list(
				vs ~ c("yes", "no"),
				am ~ c("Manual", "Automatic")
			)
		)
	}, regexp = "object\\$outcome")

	expect_error({
		tbl_interaction_forest(
			object = mt,
			outcomes = heavy ~ "Weight",
			exposures = hp ~ 'Horsepower',
			interactions = list(vs ~ "V/S", am ~ "Transmission"),
			level_labels = list(
				vs ~ c("yes", "no"),
				am ~ c("Manual", "Automatic")
			)
		)
	}, regexp = "does not have the data")

	expect_error({
		tbl_interaction_forest(
			object = mt,
			outcomes = heavy ~ "Weight",
			exposures = horsy ~ 'Horsepower',
			interactions = list(vs ~ "V/S", am ~ "Transmission"),
			level_labels = list(
				vs ~ c("yes", "no"),
				am ~ c("Manual", "Automatic")
			)
		)
	}, regexp = "object\\$exposure")

})

test_that("multiple interaction terms", {

	cars <-
		mtcars |>
		dplyr::mutate(heavy = ifelse(wt > 3.2, 1, 0))

	expect_message({
		m1 <-
			fmls(heavy ~ .x(hp) + .i(vs)) |>
			fit(.fn = glm, data = cars, raw = FALSE) |>
			suppressMessages()
		m2 <-
			fmls(heavy ~ .x(hp) + .i(am)) |>
			fit(.fn = glm, data = cars, raw = FALSE)
	}, regexp = "Interaction term")

	mt <- vlndr::model_table(one = m1, two = m2, data = cars)

	x <- tbl_interaction_forest(
		object = mt,
		outcomes = heavy ~ "Weight",
		exposures = hp ~ 'Horsepower',
		interactions = list(vs ~ "V/S", am ~ "Transmission"),
		level_labels = list(
			vs ~ c("yes", "no"),
			am ~ c("Manual", "Automatic")
		)
	)

	expect_s3_class(x, "gt_tbl")

})

test_that("carrs data works", {
	skip()

	obj <-
		targets::tar_read(carrs1_mdls, store = "~/OneDrive - University of Illinois Chicago/targets/carrs")

	vlndr::tbl_interaction_forest(
		object = obj,
		outcomes = qrs_tang ~ "QRS-T Angle",
		exposures = lab_hba1c ~ "Hemoglobin A1c",
		interactions = list(
			drugs_dm ~ "Glucose-lowering medications"
		),
		level_labels = list(
			drugs_dm ~ c("No", "Yes")
		),
		columns = list(beta ~ "Estimate", conf ~ "95% CI", n ~ "No.", p ~ "Interaction p-value"),
		axis = list(
			title ~ "Forest Plot",
			scale ~ "continuous"
		),
		width = forest ~ 0.7,
		exponentiate = FALSE
	)
})
