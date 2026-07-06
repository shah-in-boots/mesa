test_that("linear regression can be made into gt table", {

	# Variables for the gt table
	data  <-
		mtcars |>
		dplyr::mutate(cyl = factor(cyl),
									am = factor(am, levels = c(0, 1), labels = c("Manual", "Automatic")))

	object <-
		mesa::fmls(
			mpg ~ .x(cyl) + .x(am) + .x(qsec) + hp + disp,
			pattern = "sequential"
		) |>
		mesa::fit(
			.fn = lm,
			data = data,
			raw = FALSE
		) |>
		mesa::mdl_tbl(gas = _, data = data)


	# Filtering variables
	outcomes <- list(
		mpg ~ "Miles per gallon"
	)

	terms <- list(
		cyl ~ "Cylinders",
		am ~ "Transmission",
		qsec ~ "Seconds"
	)

	adjustment <-
		list(
			1 ~ "Unadjusted",
			2 ~ "Adjusted for horsepower",
			3 ~ "Adjusted for both HP and disp"
		)

	columns <- list(beta ~ "beta",
									conf ~ "95% CI",
									p ~ "P value")

	# Create the gt table
	gtbl <- tbl_beta(
		object = object,
		data = data,
		outcomes = outcomes,
		terms = terms,
		adjustment = adjustment,
		columns = columns
	)

	expect_s3_class(gtbl, 'gt_tbl')
})

