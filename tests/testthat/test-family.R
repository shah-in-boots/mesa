# Family identification: `identify_family()` reads causal roles and sorts
# formulas into families, naming each family's pattern and the relations
# between families

test_that("a sequential ladder is one family", {

	f <- fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential")
	fam <- identify_family(f)

	expect_s3_class(fam, "tbl_df")
	expect_equal(nrow(fam), 3)
	expect_equal(unique(fam$family), 1L)
	expect_equal(unique(fam$pattern), "sequential")
	expect_true(all(is.na(fam$relation)))
	expect_equal(unique(fam$outcome), "mpg")
	expect_equal(unique(fam$exposure), "wt")
	# The ladder climbs: 0, 1, 2 covariates
	expect_equal(sort(lengths(fam$covariates)), 0:2)

})

test_that("parallel adjustment sets are one parallel family", {

	f <- fmls(mpg ~ .x(wt) + hp + cyl, pattern = "parallel")
	fam <- identify_family(f)

	expect_equal(unique(fam$family), 1L)
	expect_equal(unique(fam$pattern), "parallel")

})

test_that("a single formula is a direct family", {

	fam <- identify_family(fmls(mpg ~ .x(wt) + hp))
	expect_equal(fam$pattern, "direct")
	expect_true(is.na(fam$relation))

})

test_that("a mediation triad binds into one family across outcomes", {

	f <- fmls(mpg ~ .x(wt) + .m(hp) + cyl)
	fam <- identify_family(f)

	# Three formulas, one family, despite `hp ~ wt` having its own outcome
	expect_equal(nrow(fam), 3)
	expect_equal(unique(fam$family), 1L)
	expect_equal(unique(fam$pattern), "mediation")
	expect_setequal(fam$outcome, c("mpg", "hp"))
	expect_equal(unique(fam$mediator), "hp")

})

test_that("same outcome and ladder over different exposures relate as varied exposures", {

	f <- c(
		fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential"),
		fmls(mpg ~ .x(disp) + hp + cyl, pattern = "sequential")
	)
	fam <- identify_family(f)

	expect_equal(sort(unique(fam$family)), c(1L, 2L))
	expect_equal(unique(fam$pattern), "sequential")
	expect_equal(unique(fam$relation), "varied exposures")

})

test_that("same exposure and ladder over different outcomes relate as varied outcomes", {

	f <- c(
		fmls(mpg ~ .x(wt) + hp),
		fmls(qsec ~ .x(wt) + hp)
	)
	fam <- identify_family(f)

	expect_equal(sort(unique(fam$family)), c(1L, 2L))
	expect_equal(unique(fam$relation), "varied outcomes")

})

test_that("differing ladders do not relate across exposures", {

	f <- c(
		fmls(mpg ~ .x(wt) + hp),
		fmls(mpg ~ .x(disp) + cyl)
	)
	fam <- identify_family(f)

	expect_equal(sort(unique(fam$family)), c(1L, 2L))
	expect_true(all(is.na(fam$relation)))

})

test_that("strata ride along and report levels when data is stamped", {

	f <- fmls(mpg ~ .x(wt) + hp + .s(am))

	bare <- identify_family(f)
	expect_equal(bare$strata, "am")
	expect_equal(nrow(bare), 1)

	stamped <- identify_family(f, data = mtcars)
	expect_equal(stamped$strata, "am (2 levels)")

})

test_that("an empty fmls identifies no families", {

	fam <- identify_family(fmls())
	expect_s3_class(fam, "tbl_df")
	expect_equal(nrow(fam), 0)

})
