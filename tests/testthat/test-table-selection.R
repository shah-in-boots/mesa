# The selection resolver (M6.2) is the shared engine every table verb runs
# when a specification is realized. These tests pin down its two contracts:
# exact matching (no `grepl()` substring bleed) and adjustment-set identity by
# sequential index rather than raw term count.

# A dataset whose variable names are deliberately adversarial: `gam` contains
# `am`, `wt2` contains `wt`. Substring matching would confuse them.
adversarial_data <- function() {
	d <- mtcars
	d$gam <- d$qsec
	d$wt2 <- d$wt^2
	d$cyl <- factor(d$cyl)
	d
}

test_that("exposure selection matches names exactly, not as substrings", {

	d <- adversarial_data()
	am_model <- fmls(mpg ~ .x(am) + wt) |> fit(.fn = lm, data = d, raw = FALSE)
	gam_model <- fmls(mpg ~ .x(gam) + wt) |> fit(.fn = lm, data = d, raw = FALSE)
	x <- model_table(am_model, gam_model, data = d)

	sel <- resolve_selection(x, exposures = ~ am)

	# `am` must not drag in the `gam` model
	expect_equal(nrow(sel$models), 1L)
	expect_equal(sel$models$exposure, "am")

	# and `gam` selects only itself
	sel_gam <- resolve_selection(x, exposures = ~ gam)
	expect_equal(nrow(sel_gam$models), 1L)
	expect_equal(sel_gam$models$exposure, "gam")
})

test_that("outcome selection matches names exactly", {

	d <- adversarial_data()
	# Two outcomes, one a substring of the other
	m_am <- fmls(am ~ .x(wt) + hp) |> fit(.fn = lm, data = d, raw = FALSE)
	m_gam <- fmls(gam ~ .x(wt) + hp) |> fit(.fn = lm, data = d, raw = FALSE)
	x <- model_table(m_am, m_gam, data = d)

	sel <- resolve_selection(x, outcomes = ~ am)
	expect_equal(nrow(sel$models), 1L)
	expect_equal(sel$models$outcome, "am")
})

test_that("continuous term keys are exact (wt does not select wt2)", {

	d <- adversarial_data()
	x <-
		fmls(mpg ~ .x(wt) + wt2 + hp) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	sel <- resolve_selection(x, terms = ~ wt)
	expect_equal(sel$term_keys, "wt")
	expect_false("wt2" %in% sel$term_keys)

	# The reverse selection is just as clean
	sel2 <- resolve_selection(x, terms = ~ wt2)
	expect_equal(sel2$term_keys, "wt2")
})

test_that("categorical terms resolve to their non-reference level keys", {

	d <- adversarial_data() # cyl is a factor with levels 4, 6, 8
	x <-
		fmls(mpg ~ .x(wt) + cyl) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	sel <- resolve_selection(x, terms = ~ cyl)

	# The bare name plus one key per non-reference level, from the term table's
	# variable-level relationship (stamped from the attached data)
	expect_true(all(c("cyl", "cyl6", "cyl8") %in% sel$term_keys))
	expect_false("cyl4" %in% sel$term_keys) # reference level is dropped

	# Metadata is carried alongside the keys
	row <- sel$terms
	expect_equal(row$variable, "cyl")
	expect_equal(row$reference, "4")
	expect_equal(row$levels[[1]], c("4", "6", "8"))

	# The tidy terms broom actually produced map back to `cyl`, exactly
	tidy_terms <- flatten_models(x)$term |> unique()
	mapped <- match_term_keys(tidy_terms, sel$terms)
	expect_equal(mapped[tidy_terms == "cyl6"], "cyl")
	expect_equal(mapped[tidy_terms == "cyl8"], "cyl")
	expect_true(is.na(mapped[tidy_terms == "wt"]))
})

test_that("adjustment sets are indexed sequentially, colliding counts stay distinct", {

	d <- adversarial_data()
	# Two models: same outcome, same exposure, same term count (2), different
	# right-hand sides. The old `number`-based selection collided here.
	m1 <- fmls(mpg ~ .x(wt) + hp) |> fit(.fn = lm, data = d, raw = FALSE)
	m2 <- fmls(mpg ~ .x(wt) + drat) |> fit(.fn = lm, data = d, raw = FALSE)
	x <- model_table(m1, m2, data = d)

	idx <- family_adjustment_index(x)
	expect_equal(idx, c(1L, 2L)) # distinct despite equal `number`
	expect_equal(unique(x$number), 2L)

	# Selecting adjustment set 1 picks exactly the first model
	sel1 <- resolve_selection(x, adjustment = 1 ~ "First")
	expect_equal(nrow(sel1$models), 1L)
	expect_equal(sel1$models$formula_call, "mpg ~ wt + hp")

	sel2 <- resolve_selection(x, adjustment = 2 ~ "Second")
	expect_equal(sel2$models$formula_call, "mpg ~ wt + drat")
})

test_that("adjustment index tracks adjustment degree within a family", {

	d <- adversarial_data()
	x <-
		fmls(mpg ~ .x(wt) + hp + drat, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	idx <- family_adjustment_index(x)
	expect_equal(idx, c(1L, 2L, 3L))

	sel <- resolve_selection(x, adjustment = list(1 ~ "Crude", 3 ~ "Adjusted"))
	expect_equal(sel$adjustment_index, c(1L, 3L))
	expect_setequal(sel$models$number, c(1L, 3L))
})

test_that("strata select exactly and each stratum numbers its own adjustment sets", {

	d <- adversarial_data()
	x <-
		fmls(mpg ~ .x(wt) + hp + .s(am), pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	# Two strata levels (am = 0, 1), each with two adjustment sets
	idx <- family_adjustment_index(x)
	expect_equal(sort(unique(idx)), c(1L, 2L))
	expect_equal(sum(idx == 1L), 2L) # one crude model per stratum level

	sel <- resolve_selection(x, strata = ~ am, adjustment = 1 ~ "Crude")
	expect_equal(nrow(sel$models), 2L) # one per stratum level
	expect_true(all(sel$models$strata == "am"))
})

test_that("verb order does not change the resolved rows", {

	d <- adversarial_data()
	x <-
		fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	a <- resolve_selection(x, outcomes = ~ mpg, adjustment = list(1 ~ "A", 2 ~ "B"))
	b <- resolve_selection(x, adjustment = list(2 ~ "B", 1 ~ "A"), outcomes = ~ mpg)

	expect_equal(a$models$id, b$models$id)
	expect_equal(a$adjustment_index, b$adjustment_index)
})

test_that("unresolvable selections error clearly", {

	d <- adversarial_data()
	x <-
		fmls(mpg ~ .x(wt) + hp) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	expect_error(resolve_selection(x, outcomes = ~ disp), "Available outcome")
	expect_error(resolve_selection(x, exposures = ~ hp), "Available exposure")
	expect_error(resolve_selection(x, terms = ~ nothing), "table's terms")
	expect_error(resolve_selection(x, adjustment = 9 ~ "Nope"), "adjustment set")
})

test_that("labeled-formula inputs flow through one mechanism", {

	d <- adversarial_data()
	x <-
		fmls(mpg ~ .x(wt) + cyl) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	# formula, list, and character forms all reach the same place
	f <- resolve_selection(x, terms = ~ cyl)
	l <- resolve_selection(x, terms = list(cyl ~ "Cylinders"))
	c_ <- resolve_selection(x, terms = "cyl")

	expect_equal(f$term_keys, l$term_keys)
	expect_equal(f$term_keys, c_$term_keys)

	# The label rides along on the resolved term when supplied
	expect_equal(l$terms$label, "Cylinders")
	expect_equal(f$terms$label, "cyl") # falls back to the variable name
})

test_that("term levels stamp from each term's own dataset when models span
					 several", {

	d1 <- mtcars
	d1$cyl <- factor(d1$cyl)
	d2 <- data.frame(y = mtcars$mpg, grp = factor(mtcars$gear))

	suppressMessages({
		m1 <- fit(fmls(mpg ~ .x(cyl)), .fn = lm, data = d1)
		m2 <- fit(fmls(y ~ .x(grp)), .fn = lm, data = d2)
		mt <- model_table(m1, m2)
		mt <- attach_data(mt, d1)
		mt <- attach_data(mt, d2)
	})

	meta <- resolve_term_metadata(mt, list(cyl = "cyl", grp = "grp"))

	# `grp` lives only in the second dataset; it still finds its levels
	expect_setequal(meta$levels[[which(meta$variable == "cyl")]], c("4", "6", "8"))
	expect_setequal(meta$levels[[which(meta$variable == "grp")]], c("3", "4", "5"))

})
