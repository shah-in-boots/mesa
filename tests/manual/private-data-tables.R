# Manual, author-only checks against private datasets (AFEQT, CARRS, MIMS).
# These are not part of the automated suite: they read from local {targets}
# stores that exist only on the author's machine. Milestone 6 of blueprint.md
# replaces them with public-data equivalents in tests/testthat/.
# Run interactively with devtools::load_all() and library(testthat).

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

test_that("carrs data works", {
	skip()

	obj <-
		targets::tar_read(carrs1_mdls, store = "~/OneDrive - University of Illinois Chicago/targets/carrs")

	mesa::tbl_interaction_forest(
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

test_that("for dichotomous variables", {
	skip()

	object <-
		targets::tar_read(cox_mdls, store = '~/OneDrive - University of Illinois Chicago/targets/mims/') |>
		dplyr::filter(name == 'parsimonious')

	data <-
		targets::tar_read(clinical, store = '~/OneDrive - University of Illinois Chicago/targets/mims/') |>
		dplyr::mutate(lf_delta_bin = factor(
			lf_delta_bin,
			levels = c(1, 0),
			labels = c('Yes', 'No')
		)) |>
		dplyr::mutate(lf_rest_quartile = factor(
			lf_rest_quartile,
			levels = c(1, 0),
			labels = c('Yes', 'No')
		))

	outcomes <-
		list('death_cv_yn' ~ 'Cardiovascular mortality',
				 'death_any_yn' ~ 'All-cause mortality')

	followup <- 'death_timeto'

	terms <- list(lf_delta_bin ~ 'Mental stress-induced HRV decrease',
								lf_rest_quartile ~ 'Low rest HRV')

	adjustment <-
		list(
			3 ~ 'Unadjusted',
			5 ~ 'Adjusted for demo',
			7 ~ 'Adjust for above + clinical',
			8 ~ 'Adjust for above + stress testing'
		)

	rate_difference <- TRUE

	gtbl <- tbl_dichotomous_hazard(
		object = object,
		data = data,
		outcomes = outcomes,
		follow = followup,
		terms = terms,
		adjustment = adjustment,
		rate_difference = rate_difference
	)

	expect_s3_class(gtbl, 'gt_tbl')

})

test_that("for categorical variables", {
	skip()

	object <-
		targets::tar_read(cox_mdls, store = '~/OneDrive - University of Illinois Chicago/targets/mims/') |>
		dplyr::filter(name == 'groups')

	data <-
		targets::tar_read(clinical, store = '~/OneDrive - University of Illinois Chicago/targets/mims/') |>
		dplyr::mutate(lf_grps = factor(
			lf_grps,
			levels = c(0, 1, 2, 3),
			labels = c(
				'Normal rest & stress-induced increase',
				'Low rest & stress-induced increase',
				'Normal rest & stress-induced decrease',
				'Low rest & stress-induced decrease'
			)
		)) |>
		dplyr::mutate(hf_grps = factor(
			hf_grps,
			levels = c(0, 1, 2, 3),
			labels = c(
				'Normal rest & stress-induced increase',
				'Low rest & stress-induced increase',
				'Normal rest & stress-induced decrease',
				'Low rest & stress-induced decrease'
			)
		))

	outcomes <-
		list(death_cv_yn ~ 'Cardiovascular mortality',
				 death_any_yn ~ 'All-cause mortality')

	followup <- 'death_timeto'

	terms <- lf_grps ~ 'HRV response category v. reference'

	adjustment <- list(2 ~ 'Unadjusted',
										 5 ~ 'Adjusted for demo',
										 7 ~ 'Adjust for above + clinical',
										 8 ~ 'Adjust for above + stress testing')

	rate_difference <- FALSE

	gtbl <- tbl_categorical_hazard(
		object = object,
		data = data,
		outcomes = outcomes,
		follow = followup,
		terms = terms,
		adjustment = adjustment,
		rate_difference = rate_difference
	)

	expect_s3_class(gtbl, 'gt_tbl')
})
