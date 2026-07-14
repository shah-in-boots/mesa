# Family identification: `identify_families()` reads causal roles and sorts
# a `fmls` object's formulas into families, naming each family's pattern and
# the relations between families. A `mdl_tbl` carries the result as `family`,
# `pattern`, and `relation` columns, auto-stamped on build and every reshape.

test_that("a sequential ladder is one family", {

	f <- fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential")
	fam <- identify_families(f)

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
	fam <- identify_families(f)

	expect_equal(unique(fam$family), 1L)
	expect_equal(unique(fam$pattern), "parallel")

})

test_that("a single formula is a direct family", {

	fam <- identify_families(fmls(mpg ~ .x(wt) + hp))
	expect_equal(fam$pattern, "direct")
	expect_true(is.na(fam$relation))

})

test_that("a mediation triad binds into one family across outcomes", {

	f <- fmls(mpg ~ .x(wt) + .m(hp) + cyl)
	fam <- identify_families(f)

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
	fam <- identify_families(f)

	expect_equal(sort(unique(fam$family)), c(1L, 2L))
	expect_equal(unique(fam$pattern), "sequential")
	expect_equal(unique(fam$relation), "varied exposures")

})

test_that("same exposure and ladder over different outcomes relate as varied outcomes", {

	f <- c(
		fmls(mpg ~ .x(wt) + hp),
		fmls(qsec ~ .x(wt) + hp)
	)
	fam <- identify_families(f)

	expect_equal(sort(unique(fam$family)), c(1L, 2L))
	expect_equal(unique(fam$relation), "varied outcomes")

})

test_that("differing ladders do not relate across exposures", {

	f <- c(
		fmls(mpg ~ .x(wt) + hp),
		fmls(mpg ~ .x(disp) + cyl)
	)
	fam <- identify_families(f)

	expect_equal(sort(unique(fam$family)), c(1L, 2L))
	expect_true(all(is.na(fam$relation)))

})

test_that("strata ride along and report levels when data is stamped", {

	f <- fmls(mpg ~ .x(wt) + hp + .s(am))

	bare <- identify_families(f)
	expect_equal(bare$strata, "am")
	expect_equal(nrow(bare), 1)

	stamped <- identify_families(f, data = mtcars)
	expect_equal(stamped$strata, "am (2 levels)")

})

test_that("an empty fmls identifies no families", {

	fam <- identify_families(fmls())
	expect_s3_class(fam, "tbl_df")
	expect_equal(nrow(fam), 0)

})

test_that("a family group can be identified in mixed formulas", {

	# Two expossures but the same outcome and same adjustment set
  f1 <- fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential")
  f2 <- fmls(mpg ~ .x(disp) + hp + cyl, pattern = "sequential")
	# A mediation analysis with similar variables
	f3 <- fmls(mpg ~ .x(wt) + .m(hp) + cyl)

	f <- c(f1, f2, f3)
	fam <- identify_families(f)

	# Expect that f1 and f2 could be a complex sequential family
	# They could have varied exposures, but the outcome is the same
	# Adjustment set is the same
	# Would look good in a table together side by side (column groups)
	# Thus would expect them to have an overlap in potential families
	# Additionally would expect that can regenerate mediation pattern with f3

	# f1 and f2: two sequential ladders, and the shared outcome + shared
	# adjustment set marks their overlap as `varied exposures` — the
	# side-by-side (column group) table shape
	ladders <- fam[fam$family %in% 1:2, ]
	expect_equal(ladders$family, rep(c(1L, 2L), each = 3))
	expect_equal(unique(ladders$pattern), "sequential")
	expect_equal(unique(ladders$relation), "varied exposures")
	expect_equal(unique(ladders$outcome), "mpg")
	expect_setequal(unique(ladders$exposure), c("wt", "disp"))

	# f3's mediation triad regenerates intact as its own family: `hp` stays
	# the mediator there even though f1 and f2 adjusted for it as a plain
	# predictor
	triad <- fam[fam$family == 3L, ]
	expect_equal(nrow(triad), 3)
	expect_equal(unique(triad$pattern), "mediation")
	expect_equal(unique(triad$mediator), "hp")
	expect_setequal(triad$outcome, c("mpg", "hp"))

})
test_that("a mdl_tbl carries auto-stamped family columns", {

	d <- mtcars
	mt <- suppressMessages(
		c(
			fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential"),
			fmls(mpg ~ .x(disp) + hp + cyl, pattern = "sequential")
		) |>
			fit(.fn = lm, data = d, raw = FALSE) |>
			model_table(data = d)
	)

	# The identification rides on as ordinary columns from construction, no
	# separate call; ids number across every model at once
	expect_true(all(c("family", "pattern", "relation") %in% names(mt)))
	expect_equal(mt$family, rep(c(1L, 2L), each = 3))
	expect_equal(unique(mt$pattern), "sequential")
	expect_equal(unique(mt$relation), "varied exposures")

	# Paring by family keeps the class and prunes the attributes
	one <- suppressMessages(dplyr::filter(mt, family == 1))
	expect_s3_class(one, "mdl_tbl")
	expect_equal(nrow(one), 3L)
	expect_equal(unique(one$exposure), "wt")

	# The reshape refreshes: the pared table renumbers from 1 and the
	# varied-exposures relation dissolves when only one exposure remains
	expect_equal(unique(one$family), 1L)
	expect_true(all(is.na(one$relation)))
})

test_that("a stratified mdl_tbl stamps one family across its stratum rows", {

	d <- mtcars
	mt <- suppressMessages(
		fmls(mpg ~ .x(wt) + hp, pattern = "sequential") |>
			add_strata(am) |>
			fit(.fn = lm, data = d, raw = FALSE) |>
			model_table(data = d)
	)

	# One formula family; the stratum expansion multiplies rows, not families
	expect_equal(unique(mt$family), 1L)
	expect_equal(unique(mt$pattern), "sequential")
})
