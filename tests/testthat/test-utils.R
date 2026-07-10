test_that("purrr::possibly functions work", {
	m1 <- stats::lm(mpg ~ hp, mtcars)
	expect_s3_class(my_tidy(m1), "tbl_df")
	expect_s3_class(possible_tidy(m1), "tbl_df")

})

test_that("formulas can be converted to named lists", {

	# Standard formula
	x <- mpg ~ "Mileage"
	y <- labeled_formulas_to_named_list(x)
	expect_named(y, "mpg")
	expect_equal(y$mpg, "Mileage")

	# Unlabeled formula
	x <- ~ mpg
	y <- labeled_formulas_to_named_list(x)
	expect_named(y, "mpg")
	expect_equal(y$mpg, "mpg")

	# List of formulas (simple) - expect each element to be a formula
	x <- list(mpg ~ "Mileage", hp ~ "Horsepower")
	y <- labeled_formulas_to_named_list(x)
	expect_length(y, 2)
	expect_named(y, c("mpg", "hp"))
	expect_equal(unlist(unname(y)), c("Mileage", "Horsepower"))

	# Mixed labels list of formulas
	x <- list(mpg ~ "Mileage", ~ hp)
	y <- labeled_formulas_to_named_list(x)
	expect_length(y, 2)
	expect_named(y, c("mpg", "hp"))
	expect_equal(unlist(unname(y)), c("Mileage", "hp"))

	# Mixed list with elements that are not formulas will error
	x <- list(mpg ~ "Mileage", "hp")
	expect_error(y <- labeled_formulas_to_named_list(x))

	# Character (simple)
	x <- "mpg"
	y <- labeled_formulas_to_named_list(x)
	expect_named(y, "mpg")
	expect_equal(y$mpg, "mpg")

	# Character vector
	x <- c("mpg", "hp")
	y <- labeled_formulas_to_named_list(x)
	expect_named(y, c("mpg", "hp"))
	expect_equal(y$mpg, "mpg")
	expect_equal(y$hp, "hp")

})

test_that("rhs() splits on additive structure, not on characters", {

	# `I(a + b)` is one term: the `+` inside the call does not split it
	expect_equal(rhs(y ~ I(a + b) + c), c("I(a + b)", "c"))

	# A label containing `+` or `-` stays whole
	x <- wt ~ "Weight (+/- SD)"
	y <- labeled_formulas_to_named_list(x)
	expect_equal(y$wt, "Weight (+/- SD)")

	# `a * b` still expands to its components and their interaction
	expect_setequal(rhs(y ~ a * b), c("a", "b", "a:b"))

	# Runes keep their text (rhs() reports the formula as written)
	expect_match(rhs(y ~ .x(wt) + hp), ".x", all = FALSE, fixed = TRUE)

})
