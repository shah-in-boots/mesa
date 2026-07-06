# Round trips: formula -> tm -> formula must be lossless ----

test_that("plain formulas round-trip through `tm` losslessly", {

	fl <- list(
		mpg ~ wt,
		mpg ~ wt + hp,
		witch ~ green + wicked:west,
		witch ~ wicked + west + wicked:west + green
	)

	for (f in fl) {
		t <- tm(f)
		expect_equal(deparse1(stats::formula(t)), deparse1(f))
	}

})

test_that("role shortcuts reconstruct to their explicit formula", {

	# Roles annotate terms; reconstruction drops the runes but keeps structure
	t <- tm(output ~ .x(input) + log(modifier) + another)
	expect_equal(
		deparse1(stats::formula(t)),
		"output ~ input + log(modifier) + another"
	)

	# Interaction shortcuts expand to the explicit product
	expect_message(t <- tm(witch ~ .x(wicked) + .i(west)))
	expect_equal(
		deparse1(stats::formula(t)),
		"witch ~ wicked + west + wicked:west"
	)

})

test_that("opaque calls survive the round trip", {

	f <- survival::Surv(time, status) ~ ph.karno + cluster(sex)
	t <- tm(survival::Surv(time, status) ~ ph.karno + cluster(sex))
	expect_true("cluster(sex)" %in% vec_data(t)$term)

})

test_that("meta terms leave the fitting formula but stay on the term", {

	# Strata guide fitting; they are not covariates
	t <- tm(mpg ~ wt + .s(am))
	expect_equal(deparse1(stats::formula(t)), "mpg ~ wt")
	expect_equal(describe(t, "role")$am, "strata")

	# Random effects render in hierarchical form
	t <- tm(mpg ~ .x(wt) + .r(id))
	expect_equal(deparse1(stats::formula(t)), "mpg ~ wt + (1 | id)")
	expect_equal(describe(t, "role")$id, "random")
	expect_equal(describe(t, "side")$id, "meta")

})

# M1 additions to the term layer ----

test_that("group tiers accept multiple digits", {

	t <- tm(witch ~ west + .g10(green) + .g10(wicked))
	expect_equal(describe(t, "group")$green, 10)
	expect_equal(describe(t, "group")$wicked, 10)

})

test_that("roles wrap transformations without confusion", {

	# Nested runes: role outside, transformation inside
	t <- tm(output ~ .x(log(input)) + modifier)
	d <- vec_data(t)
	expect_equal(d$role[d$term == "log(input)"], "exposure")
	expect_equal(d$transformation[d$term == "log(input)"], "log")

	# The transformation vocabulary extends beyond log
	t <- tm(output ~ sqrt(input) + factor(group))
	d <- vec_data(t)
	expect_equal(d$transformation[d$term == "sqrt(input)"], "sqrt")
	expect_equal(d$transformation[d$term == "factor(group)"], "factor")

})

test_that("terms carry levels once known", {

	t <- tm("am", role = "strata", level = c("0", "1"))
	expect_equal(describe(t, "level")$am, c("0", "1"))

	# Updating levels through `update()`
	t <- tm(mpg ~ wt + .s(am))
	t2 <- update(t, level = am ~ c("automatic", "manual"))
	expect_equal(describe(t2, "level")$am, c("automatic", "manual"))

})
