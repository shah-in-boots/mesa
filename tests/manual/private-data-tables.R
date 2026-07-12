# Manual, author-only checks against private datasets (AFEQT, CARRS, MIMS).
# These are not part of the automated suite: they read from local {targets}
# stores that exist only on the author's machine. The automated equivalents
# live in tests/testthat/ on public data (test-table-presets.R,
# test-table-columns.R, test-table-render.R). Rewritten for M6.10 against
# the table grammar — the retired `tbl_*` monoliths these once exercised are
# gone. Run interactively with devtools::load_all() and library(testthat).

test_that("complex test from AFEQT dataset works (the adjustment chain)", {
	skip()

	mdls <-
		targets::tar_read(afeqt_mdls, store = '~/OneDrive - University of Illinois Chicago/targets/aflubber/')

	afeqt_dataset <-
		targets::tar_read(afeqt_labeled, store = '~/OneDrive - University of Illinois Chicago/targets/aflubber/') |>
		dplyr::filter(cohort == "longitudinal")

	object <- dplyr::filter(
		mdls,
		name %in% c(
			"total_by_traditional",
			"activities_by_traditional",
			"symptoms_by_traditional",
			"treatment_by_traditional"
		)
	)

	gtbl <-
		object |>
		attach_data(afeqt_dataset) |>
		mdl_gt() |>
		modify_labels(
			afeqt_total_delta ~ "Change in Total AFEQT Score",
			afeqt_activities_delta ~ "Change in Activities AFEQT Score",
			afeqt_symptoms_delta ~ "Change in Symptoms AFEQT Score",
			afeqt_treatment_delta ~ "Change in Treatment AFEQT Score"
		) |>
		select_terms(list(
			ndi_quartile ~ "NDI Quartile",
			ancestry ~ "Race-Ethnicity",
			gender ~ "Sex",
			insurance_grps ~ "Insurance",
			language_grps ~ "Language"
		)) |>
		select_adjustment(list(
			2 ~ "Model 1 = Model 1 (adjusted for baseline AFEQT",
			3 ~ "Model 2 = Model 1 + age",
			7 ~ "Model 3 = Model 2 + cardiovascular risk factors",
			11 ~ "Model 4 = Model 3 + major cardiovascular adverse events"
		)) |>
		add_estimates(
			columns = list(beta ~ "beta", conf ~ "95% CI", p ~ "p-value"),
			exponentiate = TRUE
		) |>
		modify_style(accents = list(p < 0.05 ~ "bold")) |>
		as_gt()

	expect_s3_class(gtbl, 'gt_tbl')

	# Again, dropping the p column and its accent target
	gtbl <-
		object |>
		attach_data(afeqt_dataset) |>
		mdl_gt() |>
		add_estimates(columns = list(beta ~ "beta", conf ~ "95% CI")) |>
		as_gt()

	expect_s3_class(gtbl, 'gt_tbl')
})

test_that("carrs data works (the interaction chain)", {
	skip()

	obj <-
		targets::tar_read(carrs1_mdls, store = "~/OneDrive - University of Illinois Chicago/targets/carrs")

	gtbl <-
		obj |>
		dplyr::filter(outcome == "qrs_tang", exposure == "lab_hba1c") |>
		mdl_gt() |>
		modify_layout(preset = "interaction") |>
		add_interaction() |>
		add_n(label = "No.") |>
		add_estimates(
			columns = list(beta ~ "Estimate", conf ~ "95% CI",
										 p ~ "Interaction p-value"),
			exponentiate = FALSE
		) |>
		add_forest() |>
		modify_labels(drugs_dm ~ c("No", "Yes")) |>
		as_gt()

	expect_s3_class(gtbl, 'gt_tbl')
})

test_that("for dichotomous variables (the levels chain)", {
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

	gtbl <-
		object |>
		attach_data(data) |>
		mdl_gt() |>
		modify_layout(preset = "levels") |>
		modify_labels('death_cv_yn' ~ 'Cardiovascular mortality',
									'death_any_yn' ~ 'All-cause mortality') |>
		select_terms(list(lf_delta_bin ~ 'Mental stress-induced HRV decrease',
											lf_rest_quartile ~ 'Low rest HRV')) |>
		select_adjustment(list(
			3 ~ 'Unadjusted',
			5 ~ 'Adjusted for demo',
			7 ~ 'Adjust for above + clinical',
			8 ~ 'Adjust for above + stress testing'
		)) |>
		add_events(followup = death_timeto) |>
		add_rate_difference() |>
		add_estimates(columns = list(beta ~ 'HR', conf ~ '95% CI')) |>
		as_gt()

	expect_s3_class(gtbl, 'gt_tbl')
})

test_that("for categorical variables (the levels chain)", {
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
		))

	gtbl <-
		object |>
		attach_data(data) |>
		mdl_gt() |>
		modify_layout(preset = "levels") |>
		modify_labels(death_cv_yn ~ 'Cardiovascular mortality',
									death_any_yn ~ 'All-cause mortality') |>
		select_terms(lf_grps ~ 'HRV response category v. reference') |>
		select_adjustment(list(2 ~ 'Unadjusted',
													 5 ~ 'Adjusted for demo',
													 7 ~ 'Adjust for above + clinical',
													 8 ~ 'Adjust for above + stress testing')) |>
		add_events(followup = death_timeto) |>
		add_estimates(columns = list(beta ~ 'HR', conf ~ '95% CI')) |>
		as_gt()

	expect_s3_class(gtbl, 'gt_tbl')
})
