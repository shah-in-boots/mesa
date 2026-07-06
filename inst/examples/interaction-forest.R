library(mesa)

cars <-
	mtcars |>
	dplyr::mutate(heavy = ifelse(wt > 3.2, 1, 0))

m1 <-
	fmls(heavy ~ .x(hp) + .i(vs)) |>
	fit(.fn = glm, family = 'binomial', data = cars, raw = FALSE)
m2 <-
	fmls(heavy ~ .x(hp) + .i(am)) |>
	fit(.fn = glm, family = 'binomial', data = cars, raw = FALSE)

mt <- mesa::model_table(one = m1, two = m2, data = cars)

tbl_interaction_forest(
	object = mt,
	outcomes = heavy ~ "Big Car",
	exposures = hp ~ 'Horsepower',
	interactions = list(vs ~ "V/S", am ~ "Transmission"),
	level_labels = list(
		vs ~ c("yes", "no"),
		am ~ c("Manual", "Automatic")
	)
)
