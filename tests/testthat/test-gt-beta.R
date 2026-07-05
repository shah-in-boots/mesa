test_that("linear regression can be made into gt table", {

	# Variables for the gt table
	data  <-
		mtcars |>
		dplyr::mutate(cyl = factor(cyl),
									am = factor(am, levels = c(0, 1), labels = c("Manual", "Automatic")))

	object <-
		vlndr::fmls(
			mpg ~ .x(cyl) + .x(am) + .x(qsec) + hp + disp,
			pattern = "sequential"
		) |>
		vlndr::fit(
			.fn = lm,
			data = data,
			raw = FALSE
		) |>
		vlndr::mdl_tbl(gas = _, data = data)


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

test_that("complex test from AFEQT dataset works", {
	skip()

	mdls <-
		targets::tar_read(afeqt_mdls, store = '~/OneDrive - University of Illinois Chicago/targets/aflubber/')

	afeqt_dataset <-
		targets::tar_read(afeqt_labeled, store = '~/OneDrive - University of Illinois Chicago/targets/aflubber/') |>
		dplyr::filter(cohort == "longitudinal")

	object = dplyr::filter(
		mdls,
		name %in% c(
			"total_by_traditional",
			"activities_by_traditional",
			"symptoms_by_traditional",
			"treatment_by_traditional"
		)
	)

	data = afeqt_dataset

	outcomes = list(
		afeqt_total_delta ~ "Change in Total AFEQT Score",
		afeqt_activities_delta ~ "Change in Activities AFEQT Score",
		afeqt_symptoms_delta ~ "Change in Symptoms AFEQT Score",
		afeqt_treatment_delta ~ "Change in Treatment AFEQT Score"
	)

	terms = list(
		ndi_quartile ~ "NDI Quartile",
		ancestry ~ "Race-Ethnicity",
		gender ~ "Sex",
		insurance_grps ~ "Insurance",
		language_grps ~ "Language"
	)

	adjustment = list(
		2 ~ "Model 1 = Model 1 (adjusted for baseline AFEQT",
		3 ~ "Model 2 = Model 1 + age",
		7 ~ "Model 3 = Model 2 + cardiovascular risk factors",
		11 ~ "Model 4 = Model 3 + major cardiovascular adverse events"
	)

	columns = list(beta ~ "beta", conf ~ "95% CI", p ~ "p-value")

	accents = list(
		p < 0.05 ~ "bold"
	)

	suppress_column_labels = FALSE

	# Create the gt table
	gtbl <- tbl_beta(
		object = object,
		data = data,
		outcomes = outcomes,
		terms = terms,
		adjustment = adjustment,
		columns = columns,
		accents = accents,
		suppress_column_labels = suppress_column_labels,
		exponentiate = TRUE
	)

	# Now again with swapping of column labels
	suppress_column_labels = TRUE
	columns = list(beta ~ "beta", conf ~ "95% CI")
	gtbl <- tbl_beta(
		object = object,
		data = data,
		outcomes = outcomes,
		terms = terms,
		adjustment = adjustment,
		columns = columns,
		accents = accents,
		suppress_column_labels = suppress_column_labels
	)


})
