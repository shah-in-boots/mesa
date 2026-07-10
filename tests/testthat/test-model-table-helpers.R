# The print and summary methods are the front door of the model table: they
# should say what was fit, what failed, what is waiting, and what to do next.

test_that("printing a model table reports the state of the fleet", {

	withr::local_options(mesa.color = FALSE)

	x <-
		fmls(mpg ~ wt + hp + .s(am), pattern = "sequential") |>
		fit(.fn = lm, data = mtcars, raw = FALSE) |>
		model_table(data = mtcars)

	out <- capture.output(print(x))
	expect_true(any(grepl("<model_table> 4 models", out)))
	expect_true(any(grepl("4 fitted", out)))
	expect_true(any(grepl("mtcars \\[attached\\]", out)))
	expect_true(any(grepl("strata: am", out)))
	expect_true(any(grepl("summary\\(\\)", out)))

	# Stratum provenance shows up per row
	expect_true(any(grepl("am=0", out)))
	expect_true(any(grepl("am=1", out)))

	# The n argument truncates with a pointer to the rest
	out <- capture.output(print(x, n = 2))
	expect_true(any(grepl("2 more models", out)))

})

test_that("printing distinguishes fitted, failed, and unfit models", {

	withr::local_options(mesa.color = FALSE)

	fitted <-
		fmls(mpg ~ wt) |>
		fit(.fn = lm, data = mtcars, raw = FALSE)
	failed <-
		fmls(mpg ~ not_a_column) |>
		fit(.fn = lm, data = mtcars, raw = FALSE) |>
		suppressWarnings()
	pending <- fmls(mpg ~ hp)

	x <- model_table(fitted, failed, pending)
	out <- capture.output(print(x))

	expect_true(any(grepl("1 fitted", out)))
	expect_true(any(grepl("1 failed", out)))
	expect_true(any(grepl("1 unfit", out)))
	expect_true(any(grepl("model_failures\\(\\)", out)))
	expect_true(any(grepl("await `fit\\(\\)`", out)))

	# Unattached data is called out
	expect_true(any(grepl("mtcars \\[not attached\\]", out)))

	# An emptied table explains how to begin
	e <- filter(x, outcome == "zzz")
	out <- capture.output(print(e))
	expect_true(any(grepl("No models yet", out)))

})

test_that("summary maps the fleet and explains failures", {

	withr::local_options(mesa.color = FALSE)

	fitted <-
		fmls(mpg ~ wt + .s(am)) |>
		fit(.fn = lm, data = mtcars, raw = FALSE)
	failed <-
		fmls(mpg ~ not_a_column) |>
		fit(.fn = lm, data = mtcars, raw = FALSE) |>
		suppressWarnings()

	x <- model_table(main = fitted, broken = failed, data = mtcars)

	out <- capture.output(overview <- summary(x))
	expect_true(any(grepl("<model_table> summary", out)))
	expect_true(any(grepl("terms \\|", out)))
	expect_true(any(grepl("not_a_column", out))) # the failure line

	# The grouped overview comes back invisibly for further use
	expect_s3_class(overview, "tbl_df")
	expect_true(all(c("data", "model", "outcome", "models", "fitted") %in%
									names(overview)))
	expect_equal(sum(overview$models), nrow(x))

})

test_that("model_failures returns the attempted-and-errored models", {

	fitted <-
		fmls(mpg ~ wt) |>
		fit(.fn = lm, data = mtcars, raw = FALSE)
	failed <-
		fmls(mpg ~ not_a_column) |>
		fit(.fn = lm, data = mtcars, raw = FALSE) |>
		suppressWarnings()
	pending <- fmls(mpg ~ hp)

	x <- model_table(ok = fitted, broken = failed, pending)

	fails <- model_failures(x)
	expect_s3_class(fails, "tbl_df")
	expect_equal(nrow(fails), 1) # unfit formulas are not failures
	expect_equal(fails$name, "broken")
	expect_match(fails$error, "not_a_column")

	# A clean table reports no failures
	clean <- model_table(fitted)
	expect_equal(nrow(model_failures(clean)), 0)

})

test_that("accessors expose the table attributes without attr() calls", {

	f <- fmls(mpg ~ .x(wt) + hp + .s(am))
	x <-
		f |>
		fit(.fn = lm, data = mtcars, raw = FALSE) |>
		model_table(data = mtcars)

	# Terms come back as a tm vector with their roles
	tms <- term_table(x)
	expect_s3_class(tms, "tm")
	roles <- vec_proxy(tms)$role
	expect_true("exposure" %in% roles)
	expect_true("strata" %in% roles)

	# The same accessor reads a formula family
	expect_s3_class(term_table(f), "tm")

	# The formula matrix is the model-by-term membership grid
	fmMat <- formula_matrix(x)
	expect_s3_class(fmMat, "tbl_df")
	expect_equal(nrow(fmMat), nrow(x))
	expect_true(all(c("mpg", "wt", "hp") %in% names(fmMat)))
	expect_s3_class(formula_matrix(f), "tbl_df")

	# Data recall by name, with a helpful error otherwise
	expect_named(model_data(x), "mtcars")
	expect_identical(model_data(x, "mtcars"), mtcars)
	expect_error(model_data(x, "lung"), regexp = "attached: mtcars")

})

test_that("mixed models flow through the flattening inference", {

	skip_if_not_installed("lme4")
	skip_if_not_installed("broom.mixed")

	x <-
		fmls(mpg ~ .x(wt) + .r(cyl)) |>
		fit(.fn = lme4::lmer, data = mtcars, raw = FALSE) |>
		model_table()

	# A gaussian mixed model stays on the linear scale, silently
	expect_silent(fl <- flatten_models(x))
	expect_false(any(fl$exponentiated))

})

test_that("attach_data() aliases the same frame arriving under another name", {

	d <- mtcars
	mt <- fit(fmls(mpg ~ .x(wt) + hp), .fn = lm, data = d) |>
		model_table()

	renamed <- d
	expect_message(
		mt2 <- attach_data(mt, renamed),
		"attaching it as `d`"
	)
	expect_equal(names(attr(mt2, "dataList")), "d")

	# An explicit `name` is always honored as given
	expect_message(
		mt3 <- attach_data(mt, renamed, name = "renamed"),
		"attached for later use"
	)
	expect_equal(names(attr(mt3, "dataList")), "renamed")

	# A frame missing the models' variables is not aliased
	unrelated <- data.frame(a = 1:3)
	expect_message(
		mt4 <- attach_data(mt, unrelated),
		"attached for later use"
	)
	expect_equal(names(attr(mt4, "dataList")), "unrelated")

})
