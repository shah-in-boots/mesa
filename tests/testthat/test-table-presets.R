# The presets prove the grammar (M6.7): the retired monoliths' tables are
# recovered as plain grammar chains on public data, asserted against
# hand-fitted references — content equivalence where the old outputs were
# right, and the corrected values where they were wrong (the hazard tables
# displayed log-hazards labeled `HR (95% CI)`). The chains are the documented
# form (`?mesa`); the `tbl_beta()` / `tbl_dichotomous_hazard()` /
# `tbl_categorical_hazard()` functions are deleted, not deprecated, while the
# package is pre-release.

test_that("the adjustment chain reproduces the tbl_beta() table", {

	d <- mtcars
	d$cyl <- factor(d$cyl)
	mt <-
		fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	g <-
		mt |>
		mdl_gt() |>
		select_adjustment(1 ~ "Unadjusted", 3 ~ "Fully adjusted") |>
		add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI",
																 p ~ "P value")) |>
		modify_labels(wt ~ "Weight") |>
		as_gt()
	dat <- g[["_data"]]

	# Adjustment sets on rows under their outcome group, by their labels
	expect_equal(dat$row_key, c("Unadjusted", "Fully adjusted"))
	expect_equal(unique(dat$row_group), "mpg")

	# The crude and adjusted estimates agree with hand-fitted references
	crude <- stats::lm(mpg ~ wt, data = d)
	full <- stats::lm(mpg ~ wt + hp + cyl, data = d)
	crudeCell <- paste0(
		formatC(stats::coef(crude)["wt"], format = "f", digits = 2), " (",
		formatC(stats::confint(crude)["wt", 1], format = "f", digits = 2), ", ",
		formatC(stats::confint(crude)["wt", 2], format = "f", digits = 2), ")"
	)
	expect_equal(dat[["wt::est"]][1], unname(crudeCell))
	expect_equal(
		dat[["wt::est"]][2],
		unname(paste0(
			formatC(stats::coef(full)["wt"], format = "f", digits = 2), " (",
			formatC(stats::confint(full)["wt", 1], format = "f", digits = 2), ", ",
			formatC(stats::confint(full)["wt", 2], format = "f", digits = 2), ")"
		))
	)

	# The relabeled term heads the statistic columns as their spanner
	html <- gt::as_raw_html(g)
	expect_true(grepl("Weight", html, fixed = TRUE))
	expect_true(grepl("Estimate (95% CI)", html, fixed = TRUE))
})

test_that("the levels chain reproduces the dichotomous hazard table, on the
					 corrected HR scale", {

	skip_if_not_installed("survival")

	d <- survival::lung
	d$sex <- factor(d$sex, levels = 1:2, labels = c("Male", "Female"))
	mt <-
		fmls(Surv(time, status) ~ .x(sex) + age, pattern = "sequential") |>
		fit(.fn = survival::coxph, data = d, raw = FALSE) |>
		model_table(data = d)

	g <-
		mt |>
		mdl_gt() |>
		modify_layout(preset = "levels") |>
		select_adjustment(1 ~ "Unadjusted", 2 ~ "Age-adjusted") |>
		add_events(followup = time) |>
		add_rate_difference() |>
		add_estimates(columns = list(beta ~ "HR", conf ~ "95% CI")) |>
		as_gt()
	dat <- g[["_data"]]

	# The hazard-table shape: statistic rows, then the adjusted estimates
	expect_equal(
		dat$row_key,
		c("Events", "Rate per 100 person-years", "Unadjusted", "Age-adjusted")
	)

	# Events and rates per level match pyears(), the reference level included
	py <- survival::pyears(
		survival::Surv(time, status) ~ sex, data = d, scale = 365.25
	)
	events <- as.numeric(py$event)
	rate <- events / (as.numeric(py$pyears) / 100)
	expect_equal(dat[["sex::Male"]][1:2], c(
		formatC(events[1], format = "f", digits = 0),
		formatC(rate[1], format = "f", digits = 1)
	))
	expect_equal(dat[["sex::Female"]][1:2], c(
		formatC(events[2], format = "f", digits = 0),
		formatC(rate[2], format = "f", digits = 1)
	))

	# The displayed hazard ratio is exponentiated — the correction of the old
	# defect, where the flattened log-hazard was labeled `HR (95% CI)`
	crude <- survival::coxph(survival::Surv(time, status) ~ sex, data = d)
	hr <- exp(stats::coef(crude)[["sexFemale"]])
	ci <- exp(stats::confint(crude)["sexFemale", ])
	expect_equal(
		dat[["sex::Female"]][3],
		paste0(
			formatC(hr, format = "f", digits = 2), " (",
			formatC(ci[[1]], format = "f", digits = 2), ", ",
			formatC(ci[[2]], format = "f", digits = 2), ")"
		)
	)
	# The old (wrong) log-scale value does not appear
	expect_false(grepl(
		formatC(stats::coef(crude)[["sexFemale"]], format = "f", digits = 2),
		dat[["sex::Female"]][3],
		fixed = TRUE
	))
	# The reference level's estimate rows stay blank
	expect_equal(dat[["sex::Male"]][3:4], c("", ""))

	# The rate difference (non-reference minus reference, qnorm(0.975)) sits on
	# the rate row of its own column
	pt <- as.numeric(py$pyears) / 100
	est <- rate[2] - rate[1]
	se <- sqrt(events[2] / pt[2]^2 + events[1] / pt[1]^2)
	expect_equal(
		dat[["sex::rate_difference"]][2],
		paste0(
			formatC(est, format = "f", digits = 1), " (",
			formatC(est - stats::qnorm(0.975) * se, format = "f", digits = 1),
			", ",
			formatC(est + stats::qnorm(0.975) * se, format = "f", digits = 1), ")"
		)
	)
})

test_that("the levels chain covers the categorical hazard table too", {

	skip_if_not_installed("survival")

	d <- survival::lung
	d$ph.ecog <- factor(d$ph.ecog)
	mt <-
		fmls(Surv(time, status) ~ .x(ph.ecog)) |>
		fit(.fn = survival::coxph, data = d, raw = FALSE) |>
		model_table(data = d)

	g <-
		mt |>
		mdl_gt() |>
		modify_layout(preset = "levels") |>
		add_events(followup = time) |>
		add_estimates(columns = list(beta ~ "HR", conf ~ "95% CI")) |>
		as_gt()
	dat <- g[["_data"]]

	# One column per level, the reference first
	expect_true(all(paste0("ph.ecog::", 0:3) %in% names(dat)))

	# Each level's hazard ratio matches the hand fit, exponentiated (the model
	# row sits under the two statistic rows)
	ref <- survival::coxph(survival::Surv(time, status) ~ ph.ecog, data = d)
	for (lv in 1:3) {
		hr <- exp(stats::coef(ref)[[paste0("ph.ecog", lv)]])
		expect_match(
			dat[[paste0("ph.ecog::", lv)]][3],
			paste0("^", formatC(hr, format = "f", digits = 2))
		)
	}

	# Events per level match pyears(), the sparse top level included
	py <- survival::pyears(
		survival::Surv(time, status) ~ ph.ecog, data = d, scale = 365.25
	)
	events <- as.numeric(py$event)
	for (i in 1:4) {
		expect_equal(dat[[paste0("ph.ecog::", i - 1)]][1],
								 formatC(events[i], format = "f", digits = 0))
	}
})

test_that("the retired monoliths are gone", {

	expect_false(any(c("tbl_beta", "tbl_dichotomous_hazard",
										 "tbl_categorical_hazard")
									 %in% getNamespaceExports("epigram")))
})
