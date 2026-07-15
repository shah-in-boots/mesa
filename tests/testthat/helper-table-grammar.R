table_fixture_data <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	d$am <- factor(d$am)
	d
}

regression_mdl_tbl <- function() {
	d <- table_fixture_data()
	fmls(mpg ~ .x(cyl) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d) |>
		model_table(data = d)
}

multi_outcome_mdl_tbl <- function() {
	d <- table_fixture_data()
	c(
		fmls(mpg ~ .x(cyl) + hp, pattern = "sequential"),
		fmls(qsec ~ .x(cyl) + hp, pattern = "sequential")
	) |>
		fit(.fn = lm, data = d) |>
		model_table(data = d)
}

wide_categorical_mdl_tbl <- function() {
	d <- table_fixture_data()
	c(
		fmls(mpg ~ .x(cyl) + hp, pattern = "sequential"),
		fmls(mpg ~ .x(am) + hp, pattern = "sequential")
	) |>
		fit(.fn = lm, data = d) |>
		model_table(data = d)
}

interaction_mdl_tbl <- function(stratified = FALSE) {
	d <- table_fixture_data()
	formula <- if (stratified) {
		mpg ~ .x(hp) + .i(cyl) + .s(am)
	} else {
		mpg ~ .x(hp) + .i(cyl)
	}
	fmls(formula) |>
		fit(.fn = lm, data = d) |>
		model_table(data = d)
}

survival_mdl_tbl <- function() {
	d <- survival::lung
	d$sex <- factor(d$sex, levels = 1:2, labels = c("Male", "Female"))
	fmls(Surv(time, status) ~ .x(sex) + age, pattern = "sequential") |>
		fit(.fn = survival::coxph, data = d) |>
		model_table(data = d)
}
