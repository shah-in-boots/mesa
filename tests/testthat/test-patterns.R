test_that("basic patterns can be applied", {

	x <- tm(witch ~ wicked + west)
	yd <- apply_pattern(x, "direct")
	expect_length(yd, 3)
	ys <- apply_pattern(x, "sequential")
	expect_length(ys, 3)
	expect_length(ys$outcome, 2)
	yp <- apply_pattern(x, "parallel")
	expect_length(yp, 2)
	expect_named(yp, c("outcome", "covariate_1"))
	yf <- apply_pattern(x, "fundamental")
	expect_length(yf, 2)
	expect_named(yf, c("left", "right"))

	x <- tm(witch ~ wicked + west + green)
	y <- apply_sequential_pattern(x)
	expect_named(y, c("outcome", paste0("covariate_", 1:3)))

	x <- tm(witch ~ .x(wicked) + west + green)
	y <- apply_parallel_pattern(x)
	expect_named(y, c("outcome", "exposure", "covariate_1"))
	expect_length(y, 3)
	expect_length(y$exposure, 2)
	expect_length(unique(y$exposure), 1)

	# Sequential with restricted terms
	x <- tm(witch ~ wicked)
	ys <- apply_sequential_pattern(x)
	yp <- apply_parallel_pattern(x)
	yf <- apply_fundamental_pattern(x)
	yd <- apply_direct_pattern(x)

})

test_that("grouped covariates stay together in the parallel pattern", {

	# Regression: tiers other than zero used to vanish (group == 0L bug)
	x <- tm(y ~ .x(ex) + .g1(a) + .g1(b) + .g2(c) + .g2(d))
	tbl <- apply_parallel_pattern(x)
	expect_equal(nrow(tbl), 2)
	expect_named(tbl, c("outcome", "exposure", "covariate_1", "covariate_2"))

	f <- fmls(x, pattern = "parallel")
	expect_equal(nrow(f), 2)
	expect_setequal(
		unname(as.character(f)),
		c("y ~ ex + a + b", "y ~ ex + c + d")
	)

})

test_that("patterns are an open registry", {

	# Built-ins are registered
	expect_true(all(c("direct", "sequential", "parallel", "fundamental") %in%
										formula_patterns()))

	# Unknown patterns point at the registry
	expect_error(fmls(y ~ x, pattern = "spiral"), regexp = "not registered")

	# User-defined patterns become available to `fmls()` by name
	register_pattern("unadjusted", function(x) {
		tmTab <- vec_proxy(x)
		tidyr::expand_grid(
			outcome = tmTab$term[tmTab$role == "outcome"],
			exposure = tmTab$term[tmTab$role == "exposure"]
		)
	})
	f <- fmls(y ~ .x(ex) + a + b, pattern = "unadjusted")
	expect_equal(nrow(f), 1)
	expect_equal(unname(as.character(f)), "y ~ ex")

})
