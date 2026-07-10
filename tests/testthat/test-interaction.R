test_that('interaction estimates can be made', {
	# Survival model
	library(survival)

	# Since sex is a two level structure, interaction must happen at both levels
	x <-
		fmls(Surv(time, status) ~ .x(age) + ph.karno + .i(sex),
				 pattern = 'sequential') |>
		fit(.fn = coxph, data = lung, raw = FALSE) |>
		suppressMessages()

	mt <- model_table(int_sex = x, data = lung)
	expect_s3_class(mt, 'mdl_tbl')
	expect_equal(nrow(mt), 3)
	expect_error(estimate_interaction(mt), regexp = "single row")

	object <- dplyr::filter(mt, interaction == 'sex')
	expect_equal(nrow(object), 1)
	expect_error(
	  estimate_interaction(object, exposure = "ph.karno"),
	  regexp = "exposure"
	)
	expect_error(
	  estimate_interaction(object, exposure = "age", interaction = "ph.karno"),
	  regexp = "interaction"
	)

	i <- estimate_interaction(
	  object,
	  exposure = "age",
	  interaction = "sex",
	  conf_level = 0.95
	)

	expect_length(i, 6)
	expect_equal(nrow(i), 2)
	expect_named(i, c("estimate", "conf_low", "conf_high", "p_value", "nobs", "level"))

})

test_that("interaction generalizes to categorical levels, against
					 hand-computed references (M6.9)", {

	d <- mtcars
	d$cyl <- factor(d$cyl)

	mt <-
		fmls(mpg ~ .x(hp) + .i(cyl)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d) |>
		suppressMessages()
	object <- dplyr::filter(mt, interaction == "cyl")

	i <- estimate_interaction(object, exposure = "hp", interaction = "cyl")
	expect_equal(nrow(i), 3)
	expect_equal(i$level, c("4", "6", "8"))

	# Per-level effects and intervals from the variance-covariance matrix, by
	# name (Figueiras et al. 1998), against a hand fit
	ref <- stats::lm(mpg ~ hp * cyl, data = d)
	b <- stats::coef(ref)
	V <- stats::vcov(ref)
	crit <- stats::qt(0.975, df = stats::df.residual(ref))

	expect_equal(i$estimate[1], unname(b["hp"]))
	expect_equal(i$conf_low[1], unname(b["hp"] - crit * sqrt(V["hp", "hp"])))
	for (k in c("6", "8")) {
		key <- paste0("hp:cyl", k)
		at <- match(k, i$level)
		est <- unname(b["hp"] + b[key])
		se <- sqrt(V["hp", "hp"] + V[key, key] + 2 * V["hp", key])
		expect_equal(i$estimate[at], est)
		expect_equal(i$conf_low[at], est - crit * se)
		expect_equal(i$conf_high[at], est + crit * se)
	}

	# The across-levels p-value is the joint Wald test of the interaction
	# coefficients, repeated on every row
	keys <- c("hp:cyl6", "hp:cyl8")
	stat <- drop(t(b[keys]) %*% solve(V[keys, keys]) %*% b[keys])
	expect_equal(unique(i$p_value),
							 stats::pchisq(stat, df = 2, lower.tail = FALSE))

	# Per-level observation counts come from the attached data
	expect_equal(i$nobs, unname(as.integer(table(d$cyl))))
})

test_that("a categorical exposure derives one row-set per exposure contrast", {

	d <- mtcars
	d$cyl <- factor(d$cyl)

	mt <-
		fmls(mpg ~ .x(cyl) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d) |>
		suppressMessages()
	object <- dplyr::filter(mt, interaction == "am")

	i <- estimate_interaction(object, exposure = "cyl", interaction = "am")

	# Two non-reference exposure levels x two interaction levels, with the
	# exposure contrast named on every row
	expect_named(
		i,
		c("estimate", "conf_low", "conf_high", "p_value", "nobs", "level",
			"exposure_level")
	)
	expect_equal(nrow(i), 4)
	expect_equal(i$exposure_level, c("6", "6", "8", "8"))
	expect_equal(i$level, c("0", "1", "0", "1"))

	# Against a hand fit: within am = 0 the effect of level k is its own
	# coefficient; within am = 1 it adds the interaction coefficient, with the
	# covariance in the variance (Figueiras et al. 1998)
	ref <- stats::lm(mpg ~ cyl * am, data = d)
	b <- stats::coef(ref)
	V <- stats::vcov(ref)
	crit <- stats::qt(0.975, df = stats::df.residual(ref))
	for (k in c("6", "8")) {
		expKey <- paste0("cyl", k)
		intKey <- paste0("cyl", k, ":am")
		at0 <- which(i$exposure_level == k & i$level == "0")
		at1 <- which(i$exposure_level == k & i$level == "1")
		expect_equal(i$estimate[at0], unname(b[expKey]))
		expect_equal(i$estimate[at1], unname(b[expKey] + b[intKey]))
		se1 <- sqrt(V[expKey, expKey] + V[intKey, intKey] +
									2 * V[expKey, intKey])
		expect_equal(i$conf_low[at1], unname(b[expKey] + b[intKey]) - crit * se1)
	}

	# The across-levels p-value is the joint Wald test over every interaction
	# coefficient the exposure's contrasts carry
	keys <- c("cyl6:am", "cyl8:am")
	stat <- drop(t(b[keys]) %*% solve(V[keys, keys]) %*% b[keys])
	expect_equal(unique(i$p_value),
							 stats::pchisq(stat, df = 2, lower.tail = FALSE))

})

test_that("interaction terms match by identity, never by substring", {

	# `am` must not match `gam`, the adversarial-naming rule of M6.2
	d <- mtcars
	d$gam <- rev(d$am)

	mt <-
		fmls(mpg ~ .x(hp) + .i(gam)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d) |>
		suppressMessages()
	object <- dplyr::filter(mt, interaction == "gam")

	# The model interacts on `gam`; asking for `am` is an identity miss
	expect_error(
		estimate_interaction(object, exposure = "hp", interaction = "am"),
		"interaction"
	)

	# And the true term resolves through its exact keys
	i <- estimate_interaction(object, exposure = "hp", interaction = "gam")
	ref <- stats::lm(mpg ~ hp * gam, data = d)
	expect_equal(i$estimate[1], unname(stats::coef(ref)["hp"]))
	expect_equal(
		i$estimate[2],
		unname(stats::coef(ref)["hp"] + stats::coef(ref)["hp:gam"])
	)
})
