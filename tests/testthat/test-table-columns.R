# The model-statistic column blocks (M6.4) and the data-statistic blocks
# (M6.5). These tests pin down the verb contract — the `add_*` verbs record
# blocks that compose like every other verb, a repeat replaces with a message —
# and the realization behavior the blocks buy: statistic choice and labels,
# digits, the model-level n from the recorded `nobs`, exponentiation deferred
# to the M5 family inference by default (the correction of the old
# hazard-scale defect), and the events / rate / rate-difference statistics
# computed from the attached data (the corrections of the old `qnorm(0.9725)`,
# ignored-`person_years`, and level-count-precedence defects; issue #30).

columns_data <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	d
}

columns_table <- function(d = columns_data()) {
	fmls(mpg ~ .x(wt) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
}

test_that("add_estimates() validates its inputs at verb time", {

	m <- mesa(columns_table())

	expect_error(add_estimates(mtcars), "inherit from")
	expect_error(add_estimates(m, columns = list(se ~ "SE")), "does not know")
	expect_error(add_estimates(m, columns = list()), "at least one statistic")
	expect_error(add_estimates(m, exponentiate = "yes"), "`exponentiate`")
	expect_error(add_estimates(m, digits = -1), "`digits`")
	expect_error(add_n(m, label = 2), "single string")
})

test_that("column verbs append blocks; a repeat replaces with a message", {

	m <- mesa(columns_table())

	m2 <- m |> add_estimates(columns = list(beta ~ "B")) |> add_n()
	types <- vapply(m2$columns, function(b) b$type, character(1))
	expect_equal(types, c("estimates", "n"))

	# Replacement keeps the block's position and wins
	expect_message(
		m3 <- add_estimates(m2, columns = list(beta ~ "Coef", p ~ "P")),
		"replaces the earlier estimates"
	)
	types3 <- vapply(m3$columns, function(b) b$type, character(1))
	expect_equal(types3, c("estimates", "n"))
	expect_equal(names(m3$columns[[1]]$statistics), c("beta", "p"))

	expect_message(add_n(m2, label = "Obs"), "replaces the earlier n")
})

test_that("exponentiation defers to the family inference by default", {

	d <- columns_data()
	mt <-
		fmls(am ~ .x(wt)) |>
		fit(.fn = glm, family = stats::binomial, data = d, raw = FALSE) |>
		model_table(data = d)
	reference <- stats::glm(am ~ wt, family = stats::binomial, data = d)

	# The bare mesa and the default block both infer: a logit link comes back
	# exponentiated (odds ratios) — the correction of the old hazard-scale
	# defect, where log-scale values were labeled as ratios
	dec <- realize_mesa(mesa(mt) |> add_estimates())
	expect_true(all(dec$exponentiated))
	expect_equal(
		dec$estimate[dec$term == "wt"],
		unname(exp(stats::coef(reference)["wt"])),
		tolerance = 1e-6
	)

	# An explicit override pins the linear scale
	decLinear <- realize_mesa(mesa(mt) |> add_estimates(exponentiate = FALSE))
	expect_true(all(!decLinear$exponentiated))
	expect_equal(
		decLinear$estimate[decLinear$term == "wt"],
		unname(stats::coef(reference)["wt"]),
		tolerance = 1e-6
	)
})

test_that("statistic choice and labels reach the rendered table", {

	html <-
		columns_table() |>
		mesa() |>
		add_estimates(columns = list(beta ~ "Beta", conf ~ "95% CI", p ~ "P value")) |>
		as_gt() |>
		gt::as_raw_html()

	# The merged estimate header and the p column header both appear
	expect_true(grepl("Beta (95% CI)", html, fixed = TRUE))
	expect_true(grepl("P value", html, fixed = TRUE))

	# Dropping p drops its column
	htmlNoP <-
		columns_table() |>
		mesa() |>
		add_estimates(columns = list(beta ~ "Beta", conf ~ "95% CI")) |>
		as_gt() |>
		gt::as_raw_html()
	expect_false(grepl("P value", htmlNoP, fixed = TRUE))
})

test_that("add_n() shows the recorded nobs without attached data", {

	d <- columns_data()
	mt <-
		fmls(mpg ~ .x(wt)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table() # deliberately no data attached

	html <-
		mt |> mesa() |> add_n(label = "No. observed") |> as_gt() |>
		gt::as_raw_html()
	expect_true(grepl("No. observed", html, fixed = TRUE))
	expect_true(grepl(paste0(">", nrow(d), "<"), html))
})

test_that("digits are honored per estimates block", {

	d <- columns_data()
	mt <-
		fmls(mpg ~ .x(wt)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
	beta <- unname(stats::coef(stats::lm(mpg ~ wt, data = d))["wt"])

	html <-
		mt |> mesa() |> add_estimates(columns = list(beta ~ "B"), digits = 4) |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl(formatC(beta, format = "f", digits = 4), html, fixed = TRUE))
})

test_that("modify_labels(columns=) overrides block headers late", {

	html <-
		columns_table() |>
		mesa() |>
		add_estimates(columns = list(beta ~ "Beta", conf ~ "CI")) |>
		add_n() |>
		modify_labels(columns = list(beta ~ "OR", n ~ "Obs")) |>
		as_gt() |>
		gt::as_raw_html()

	expect_true(grepl("OR (CI)", html, fixed = TRUE))
	expect_true(grepl("Obs", html, fixed = TRUE))
	expect_false(grepl("Beta", html, fixed = TRUE))
})

test_that("modify_labels(columns=) errors at realization on an unknown column", {

	# Recording the label does not error at verb time -- only at realization,
	# matching every other selection input (M6.11)
	m <-
		columns_table() |> mesa() |>
		modify_labels(columns = list(betaa ~ "HR"))
	expect_s3_class(m, "mesa")
	expect_error(as_gt(m), "not on the mesa")

	# Naming a real statistic that simply is not on this mesa also errors
	m2 <-
		columns_table() |> mesa() |>
		modify_labels(columns = list(events ~ "No. events"))
	expect_error(as_gt(m2), "not on the mesa")
})

test_that("column verbs keep the grammar order-independent", {

	mt <- columns_table()

	a <-
		mt |> mesa() |>
		add_estimates(columns = list(beta ~ "B", p ~ "P")) |>
		select_adjustment(1 ~ "Crude") |>
		add_n()
	b <-
		mt |> mesa() |>
		add_n() |>
		add_estimates(columns = list(beta ~ "B", p ~ "P")) |>
		select_adjustment(1 ~ "Crude")

	expect_equal(realize_mesa(a), realize_mesa(b))

	# The rendered tables agree on their data, headers, and spanners (the raw
	# html differs only by gt's per-build random table id)
	gtA <- as_gt(a)
	gtB <- as_gt(b)
	expect_equal(gtA[["_data"]], gtB[["_data"]])
	expect_equal(gtA[["_boxhead"]], gtB[["_boxhead"]])
	expect_equal(gtA[["_spanners"]], gtB[["_spanners"]])
})

test_that("categorical terms nest level spanners over statistic columns", {

	d <- columns_data()
	mt <-
		fmls(mpg ~ .x(cyl)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)

	html <-
		mt |> mesa() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P")) |>
		as_gt() |>
		gt::as_raw_html()

	# Levels appear as (inner) spanners, statistics as headers beneath them
	expect_true(grepl(">6<", html))
	expect_true(grepl(">8<", html))
	expect_true(grepl("B (CI)", html, fixed = TRUE))
	expect_true(grepl(">P<", html))
})

test_that("print.mesa describes the recorded column blocks", {

	m <-
		mesa(columns_table()) |>
		add_estimates(columns = list(beta ~ "B", p ~ "P")) |>
		add_n()
	out <- utils::capture.output(print(m))
	expect_true(any(grepl("estimates \\(beta \\+ p\\), n", out)))
})

# The data-statistic blocks (M6.5) ---------------------------------------------

events_data <- function() {
	d <- survival::lung
	d$sex <- factor(d$sex, levels = 1:2, labels = c("male", "female"))
	d
}

events_table <- function(d = events_data(), rhs = "sex") {
	f <- stats::as.formula(paste("Surv(time, status) ~ .x(", rhs, ")"))
	fmls(f) |>
		fit(.fn = survival::coxph, data = d, raw = FALSE) |>
		model_table(data = d)
}

test_that("add_events() and add_rate_difference() validate at verb time", {

	skip_if_not_installed("survival")
	m <- mesa(events_table())

	expect_error(add_events(m, followup = c("a", "b")), "single column name")
	expect_error(add_events(m, followup = time, person_years = 0),
							 "`person_years`")
	expect_error(add_events(m, followup = time, scale = -1), "`scale`")
	expect_error(add_events(m, followup = time, digits = -1), "`digits`")
	expect_error(add_rate_difference(m, conf_level = 1), "`conf_level`")
	expect_error(add_rate_difference(m, conf_level = 0), "`conf_level`")

	# A plain (non-Surv()) outcome cannot infer a follow-up column (M6.12)
	expect_error(add_events(mesa(columns_table())), "`followup`")

	# Blocks record and a repeat replaces with a message, like every verb
	m2 <- m |> add_events(followup = time) |> add_rate_difference()
	types <- vapply(m2$columns, function(b) b$type, character(1))
	expect_equal(types, c("events", "rate_difference"))
	expect_message(add_events(m2, followup = "time", person_years = 1000),
								 "replaces the earlier events")
	expect_message(add_rate_difference(m2, conf_level = 0.9),
								 "replaces the earlier rate_difference")
})

test_that("add_events() infers `followup` from a Surv() outcome (M6.12)", {

	skip_if_not_installed("survival")
	d <- events_data()

	inferred <- events_table(d) |> mesa() |> add_events() |> realize_mesa()
	explicit <-
		events_table(d) |> mesa() |> add_events(followup = time) |> realize_mesa()
	expect_equal(inferred$events, explicit$events)
	expect_equal(inferred$rate, explicit$rate)

	# An explicit `followup` still overrides the inference — a data column
	# that does not match the fitted formula's time argument (the frame
	# attaches whole, so any column is reachable)
	d$time2 <- d$time
	overridden <-
		events_table(d) |> mesa() |> add_events(followup = time2) |> realize_mesa()
	expect_equal(overridden$events, explicit$events)
})

test_that("events and rates match survival::pyears() per level", {

	skip_if_not_installed("survival")
	d <- events_data()

	# `followup` composes as a bare name or a string
	dec <-
		events_table(d) |>
		mesa() |>
		add_events(followup = time) |>
		realize_mesa()
	decChr <-
		events_table(d) |>
		mesa() |>
		add_events(followup = "time") |>
		realize_mesa()
	expect_equal(dec$events, decChr$events)

	py <- survival::pyears(
		survival::Surv(time, status) ~ sex, data = d, scale = 365.25
	)
	rate <- as.numeric(py$event) / (as.numeric(py$pyears) / 100)

	# The reference level carries events and a rate even without an estimate
	ref <- dec[dec$is_reference, ]
	lvl <- dec[!dec$is_reference, ]
	expect_equal(ref$level, "male")
	expect_equal(ref$events, as.numeric(py$event)[1])
	expect_equal(ref$rate, rate[1], tolerance = 1e-8)
	expect_true(is.na(ref$estimate))
	expect_equal(lvl$events, as.numeric(py$event)[2])
	expect_equal(lvl$rate, rate[2], tolerance = 1e-8)
})

test_that("the rate difference is corrected: qnorm(0.975), person-years
					 honored, non-reference minus reference (issue #30)", {

	skip_if_not_installed("survival")
	d <- events_data()

	dec <-
		events_table(d) |>
		mesa() |>
		add_events(followup = time) |>
		add_rate_difference() |>
		realize_mesa()

	py <- survival::pyears(
		survival::Surv(time, status) ~ sex, data = d, scale = 365.25
	)
	events <- as.numeric(py$event)
	pt <- as.numeric(py$pyears) / 100
	est <- events[2] / pt[2] - events[1] / pt[1]
	se <- sqrt(events[2] / pt[2]^2 + events[1] / pt[1]^2)

	expect_equal(unique(dec$rate_diff), est, tolerance = 1e-8)
	# The corrected critical value: qnorm(0.975), not the old qnorm(0.9725)
	expect_equal(unique(dec$rate_diff_low), est - stats::qnorm(0.975) * se,
							 tolerance = 1e-8)
	expect_equal(unique(dec$rate_diff_high), est + stats::qnorm(0.975) * se,
							 tolerance = 1e-8)
	wrong <- est - stats::qnorm(0.9725) * se
	expect_gt(abs(unique(dec$rate_diff_low) - wrong), 1e-8)

	# A different confidence level moves the critical value with it
	dec90 <-
		events_table(d) |>
		mesa() |>
		add_events(followup = time) |>
		add_rate_difference(conf_level = 0.90) |>
		realize_mesa()
	expect_equal(unique(dec90$rate_diff_low), est - stats::qnorm(0.95) * se,
							 tolerance = 1e-8)

	# `person_years` is honored, not hard-coded to 100: rates and the
	# difference scale linearly with it
	dec1000 <-
		events_table(d) |>
		mesa() |>
		add_events(followup = time, person_years = 1000) |>
		add_rate_difference() |>
		realize_mesa()
	expect_equal(dec1000$rate, dec$rate * 10, tolerance = 1e-8)
	expect_equal(unique(dec1000$rate_diff), est * 10, tolerance = 1e-8)
	expect_equal(unique(dec1000$rate_diff_low),
							 (est - stats::qnorm(0.975) * se) * 10,
							 tolerance = 1e-8)
})

test_that("the rate difference needs exactly 2 levels, by an actual count", {

	skip_if_not_installed("survival")
	d <- events_data()
	d$ph.ecog <- factor(d$ph.ecog)
	mt <- events_table(d, rhs = "ph.ecog")

	# Events per level still compute for a many-level term...
	dec <-
		mt |> mesa() |> add_events(followup = time) |> realize_mesa()
	expect_true(all(!is.na(dec$events)))

	# ...but the two-level comparison errors on the real level count (the old
	# gate, `length(levels(x) == 2)`, was truthy for any count)
	expect_error(
		mt |> mesa() |> add_events(followup = time) |> add_rate_difference() |>
			realize_mesa(),
		"exactly 2 levels.*4 levels"
	)
})

test_that("the data-statistic errors are clear and point to attach_data()", {

	skip_if_not_installed("survival")
	d <- events_data()

	# No attached data: the error names the single path to it (a continuous
	# exposure, whose tidy key resolves without data — a categorical term
	# already fails at selection for want of its levels)
	unattached <-
		fmls(Surv(time, status) ~ .x(ph.karno)) |>
		fit(.fn = survival::coxph, data = d, raw = FALSE) |>
		model_table()
	expect_error(
		unattached |> mesa() |> add_events(followup = time) |> realize_mesa(),
		"attach_data"
	)

	# A rate difference without an events block names the missing verb
	expect_error(
		events_table(d) |> mesa() |> add_rate_difference() |> realize_mesa(),
		"add_events"
	)

	# A continuous term has no levels to count events over
	expect_error(
		events_table(d, rhs = "ph.karno") |> mesa() |>
			add_events(followup = time) |> realize_mesa(),
		"not a categorical"
	)

	# A follow-up column the data does not carry
	expect_error(
		events_table(d) |> mesa() |> add_events(followup = followup_days) |>
			realize_mesa(),
		"follow-up column"
	)
})

test_that("events, rates, and the rate difference reach the rendered table", {

	skip_if_not_installed("survival")

	m <-
		events_table() |>
		mesa() |>
		add_events(followup = time) |>
		add_rate_difference()
	html <- gt::as_raw_html(as_gt(m))

	d <- events_data()
	py <- survival::pyears(
		survival::Surv(time, status) ~ sex, data = d, scale = 365.25
	)
	rate <- as.numeric(py$event) / (as.numeric(py$pyears) / 100)

	expect_true(grepl("Events", html, fixed = TRUE))
	expect_true(grepl("Rate per 100 person-years", html, fixed = TRUE))
	expect_true(grepl("Rate difference (95% CI)", html, fixed = TRUE))
	# The computed cells: integer events, one-decimal rates
	expect_true(grepl(paste0(">", py$event[1], "<"), html))
	expect_true(grepl(formatC(rate[1], format = "f", digits = 1), html,
										fixed = TRUE))

	# Header overrides arrive late through modify_labels(columns =)
	htmlRelabeled <-
		m |>
		modify_labels(columns = list(events ~ "No. events",
																 rate_difference ~ "IR difference")) |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl("No. events", htmlRelabeled, fixed = TRUE))
	expect_true(grepl("IR difference", htmlRelabeled, fixed = TRUE))
	expect_false(grepl("Rate difference", htmlRelabeled, fixed = TRUE))
})

