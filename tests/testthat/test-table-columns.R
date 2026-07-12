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

	m <- mdl_gt(columns_table())

	expect_error(add_estimates(mtcars), "inherit from")
	expect_error(add_estimates(m, columns = list(se ~ "SE")), "does not know")
	expect_error(add_estimates(m, columns = list()), "at least one statistic")
	expect_error(add_estimates(m, exponentiate = "yes"), "`exponentiate`")
	expect_error(add_estimates(m, digits = -1), "`digits`")
	expect_error(add_n(m, label = 2), "single string")
})

test_that("column verbs append blocks; a repeat replaces with a message", {

	m <- mdl_gt(columns_table())

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
	dec <- realize_mdl_gt(mdl_gt(mt) |> add_estimates())
	expect_true(all(dec$exponentiated))
	expect_equal(
		dec$estimate[dec$term == "wt"],
		unname(exp(stats::coef(reference)["wt"])),
		tolerance = 1e-6
	)

	# An explicit override pins the linear scale
	decLinear <- realize_mdl_gt(mdl_gt(mt) |> add_estimates(exponentiate = FALSE))
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
		mdl_gt() |>
		add_estimates(columns = list(beta ~ "Beta", conf ~ "95% CI", p ~ "P value")) |>
		as_gt() |>
		gt::as_raw_html()

	# The merged estimate header and the p column header both appear
	expect_true(grepl("Beta (95% CI)", html, fixed = TRUE))
	expect_true(grepl("P value", html, fixed = TRUE))

	# Dropping p drops its column
	htmlNoP <-
		columns_table() |>
		mdl_gt() |>
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
		mt |> mdl_gt() |> add_n(label = "No. observed") |> as_gt() |>
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
		mt |> mdl_gt() |> add_estimates(columns = list(beta ~ "B"), digits = 4) |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl(formatC(beta, format = "f", digits = 4), html, fixed = TRUE))
})

test_that("modify_labels(columns=) overrides block headers late", {

	html <-
		columns_table() |>
		mdl_gt() |>
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
		columns_table() |> mdl_gt() |>
		modify_labels(columns = list(betaa ~ "HR"))
	expect_s3_class(m, "mdl_gt")
	expect_error(as_gt(m), "not on the mesa")

	# Naming a real statistic that simply is not on this mesa also errors
	m2 <-
		columns_table() |> mdl_gt() |>
		modify_labels(columns = list(events ~ "No. events"))
	expect_error(as_gt(m2), "not on the mesa")
})

test_that("column verbs keep the grammar order-independent", {

	mt <- columns_table()

	a <-
		mt |> mdl_gt() |>
		add_estimates(columns = list(beta ~ "B", p ~ "P")) |>
		select_adjustment(1 ~ "Crude") |>
		add_n()
	b <-
		mt |> mdl_gt() |>
		add_n() |>
		add_estimates(columns = list(beta ~ "B", p ~ "P")) |>
		select_adjustment(1 ~ "Crude")

	expect_equal(realize_mdl_gt(a), realize_mdl_gt(b))

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
		mt |> mdl_gt() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P")) |>
		as_gt() |>
		gt::as_raw_html()

	# Levels appear as (inner) spanners, statistics as headers beneath them
	expect_true(grepl(">6<", html))
	expect_true(grepl(">8<", html))
	expect_true(grepl("B (CI)", html, fixed = TRUE))
	expect_true(grepl(">P<", html))
})

test_that("print.mdl_gt describes the recorded column blocks", {

	m <-
		mdl_gt(columns_table()) |>
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
	m <- mdl_gt(events_table())

	expect_error(add_events(m, followup = c("a", "b")), "single column name")
	expect_error(add_events(m, followup = time, person_years = 0),
							 "`person_years`")
	expect_error(add_events(m, followup = time, scale = -1), "`scale`")
	expect_error(add_events(m, followup = time, digits = -1), "`digits`")
	expect_error(add_rate_difference(m, conf_level = 1), "`conf_level`")
	expect_error(add_rate_difference(m, conf_level = 0), "`conf_level`")

	# A plain (non-Surv()) outcome cannot infer a follow-up column (M6.12)
	expect_error(add_events(mdl_gt(columns_table())), "`followup`")

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

	inferred <- events_table(d) |> mdl_gt() |> add_events() |> realize_mdl_gt()
	explicit <-
		events_table(d) |> mdl_gt() |> add_events(followup = time) |> realize_mdl_gt()
	expect_equal(inferred$events, explicit$events)
	expect_equal(inferred$rate, explicit$rate)

	# An explicit `followup` still overrides the inference — a data column
	# that does not match the fitted formula's time argument (the frame
	# attaches whole, so any column is reachable)
	d$time2 <- d$time
	overridden <-
		events_table(d) |> mdl_gt() |> add_events(followup = time2) |> realize_mdl_gt()
	expect_equal(overridden$events, explicit$events)
})

test_that("events and rates match survival::pyears() per level", {

	skip_if_not_installed("survival")
	d <- events_data()

	# `followup` composes as a bare name or a string
	dec <-
		events_table(d) |>
		mdl_gt() |>
		add_events(followup = time) |>
		realize_mdl_gt()
	decChr <-
		events_table(d) |>
		mdl_gt() |>
		add_events(followup = "time") |>
		realize_mdl_gt()
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
		mdl_gt() |>
		add_events(followup = time) |>
		add_rate_difference() |>
		realize_mdl_gt()

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
		mdl_gt() |>
		add_events(followup = time) |>
		add_rate_difference(conf_level = 0.90) |>
		realize_mdl_gt()
	expect_equal(unique(dec90$rate_diff_low), est - stats::qnorm(0.95) * se,
							 tolerance = 1e-8)

	# `person_years` is honored, not hard-coded to 100: rates and the
	# difference scale linearly with it
	dec1000 <-
		events_table(d) |>
		mdl_gt() |>
		add_events(followup = time, person_years = 1000) |>
		add_rate_difference() |>
		realize_mdl_gt()
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
		mt |> mdl_gt() |> add_events(followup = time) |> realize_mdl_gt()
	expect_true(all(!is.na(dec$events)))

	# ...but the two-level comparison errors on the real level count (the old
	# gate, `length(levels(x) == 2)`, was truthy for any count)
	expect_error(
		mt |> mdl_gt() |> add_events(followup = time) |> add_rate_difference() |>
			realize_mdl_gt(),
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
		unattached |> mdl_gt() |> add_events(followup = time) |> realize_mdl_gt(),
		"attach_data"
	)

	# A rate difference without an events block names the missing verb
	expect_error(
		events_table(d) |> mdl_gt() |> add_rate_difference() |> realize_mdl_gt(),
		"add_events"
	)

	# A continuous term has no levels to count events over
	expect_error(
		events_table(d, rhs = "ph.karno") |> mdl_gt() |>
			add_events(followup = time) |> realize_mdl_gt(),
		"not a categorical"
	)

	# A follow-up column the data does not carry
	expect_error(
		events_table(d) |> mdl_gt() |> add_events(followup = followup_days) |>
			realize_mdl_gt(),
		"follow-up column"
	)
})

test_that("events, rates, and the rate difference reach the rendered table", {

	skip_if_not_installed("survival")

	m <-
		events_table() |>
		mdl_gt() |>
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



# Interaction rows (M6.9). `add_interaction()` defines the rows of the
# `interaction` layout: one per interaction level, banded by interaction
# term, with per-level estimates derived by the generalized
# `estimate_interaction()` and the single across-levels p-value carried as a
# group-scoped cell the renderer floats over the band — the first-class
# replacement for the old `tbl_interaction_forest()` white-out hack. The old
# forest table is now just the chain *interaction layout + add_n() +
# add_estimates() + add_forest()*, verified here the way 6.7 verified the
# other monoliths; `tbl_interaction_forest()` is deleted on the same terms.

interaction_table <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	m1 <-
		fmls(mpg ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	m2 <-
		fmls(mpg ~ .x(hp) + .i(cyl)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	suppressMessages(model_table(m1, m2, data = d))
}

interaction_chain <- function(mt = interaction_table()) {
	# `add_interaction()` implies the `interaction` layout (M6.12) -- no
	# `modify_layout()` gesture needed for the common case
	suppressMessages(
		mt |>
			mdl_gt() |>
			add_interaction() |>
			add_n(label = "No.") |>
			add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI",
																	 p ~ "P for interaction"))
	)
}

test_that("add_interaction() validates and records like every verb", {

	m <- mdl_gt(interaction_table())

	expect_error(add_interaction(mtcars), "inherit from")
	expect_error(add_interaction(m, conf_level = 0), "`conf_level`")
	expect_error(add_interaction(m, conf_level = 1), "`conf_level`")

	m2 <- suppressMessages(add_interaction(m))
	expect_message(add_interaction(m2, conf_level = 0.9),
								 "replaces the earlier interaction")

	out <- utils::capture.output(print(m2))
	expect_true(any(grepl("interaction rows", out)))
})

test_that("add_interaction() implies the interaction layout (M6.12)", {

	mt <- interaction_table()

	# Declaring the block alone is enough -- no modify_layout() gesture needed
	expect_message(
		implied <- mt |> mdl_gt() |> add_interaction(),
		"sets the layout to the `interaction` preset"
	)
	expect_equal(implied$layout$preset, "interaction")
	expect_no_error(implied |> add_n() |> add_estimates() |> as_gt())

	# Calling it again (layout already `interaction`) is silent about the layout
	# -- only the column-block replacement message fires
	once <- suppressMessages(mt |> mdl_gt() |> add_interaction())
	msgs <- testthat::capture_messages(add_interaction(once))
	expect_false(any(grepl("sets the layout", msgs)))
	expect_true(any(grepl("replaces the earlier interaction", msgs)))

	# An explicitly conflicting preset errors rather than silently overriding
	expect_error(
		mt |> mdl_gt() |> modify_layout(preset = "levels") |> add_interaction(),
		"already selected the `levels` preset"
	)
})

test_that("the block and the layout come as a pair, erroring apart", {

	mt <- interaction_table()

	# The layout has no rows without the block, even when declared explicitly
	expect_error(
		mt |> mdl_gt() |> modify_layout(preset = "interaction") |> as_gt(),
		"defined by `add_interaction\\(\\)`"
	)

	# Interaction-less models have nothing to lay out
	d <- mtcars
	plain <-
		fmls(mpg ~ .x(hp)) |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
	expect_error(
		plain |> mdl_gt() |> add_interaction() |> as_gt(),
		"models fitted with an interaction term"
	)
})

test_that("one model per interaction term: shared terms error instead of
					 overwriting each other's cells", {

	# Two models around the same interaction term realize rows with the same
	# term x level keys; they would collide at pivot, so the layout refuses
	# until the mesa is narrowed to one model per term
	d <- mtcars
	m1 <- suppressMessages(
		fmls(mpg ~ .x(hp) + .i(am)) |>
			fit(.fn = lm, data = d, raw = FALSE)
	)
	m2 <- suppressMessages(
		fmls(mpg ~ .x(hp) + wt + .i(am)) |>
			fit(.fn = lm, data = d, raw = FALSE)
	)
	mt <- suppressMessages(model_table(m1, m2, data = d))

	spec <- suppressMessages(
		mt |> mdl_gt() |> add_interaction() |> add_estimates()
	)
	expect_error(as_gt(spec), "one model per interaction term")

	# Narrowed to a single adjustment set, the same chain lays out fine
	narrowed <- suppressMessages(
		mt |> mdl_gt() |> select_adjustment(2 ~ "Adjusted") |>
			add_interaction() |> add_estimates()
	)
	expect_no_error(as_gt(narrowed))

})

test_that("the interaction frame: level rows per band, per-level statistics,
					 the p-value group-scoped", {

	m <- interaction_chain()
	frame <- mdl_gt_interaction_frame(m)

	# One band per interaction term, one row per level of its variable
	expect_setequal(unique(stats::na.omit(frame$row_group)), c("am", "cyl"))
	amRows <- unique(frame$row_key[frame$row_group %in% "am" &
																	 frame$row_scope == "row"])
	cylRows <- unique(frame$row_key[frame$row_group %in% "cyl" &
																		frame$row_scope == "row"])
	expect_equal(amRows, c("0", "1"))
	expect_equal(cylRows, c("4", "6", "8"))

	# The across-levels p-value is a group-scoped cell: one per band, no row
	# of its own
	pCells <- frame[frame$column_key == "p", ]
	expect_equal(nrow(pCells), 2)
	expect_true(all(pCells$row_scope == "group"))
	expect_true(all(is.na(pCells$row_key)))

	# Per-level estimates match the generalized estimate_interaction()
	d <- mtcars
	d$cyl <- factor(d$cyl)
	ref <- stats::lm(mpg ~ hp * cyl, data = d)
	b <- stats::coef(ref)
	est8 <- unname(b["hp"] + b["hp:cyl8"])
	cell <- frame$value[frame$row_group %in% "cyl" & frame$row_key %in% "8" &
												frame$column_key == "est"][[1]]
	expect_equal(cell$estimate, est8)

	# The per-level n counts the attached data
	nCell <- frame$value[frame$row_group %in% "cyl" & frame$row_key %in% "8" &
												 frame$column_key == "n"][[1]]
	expect_equal(nCell$n, sum(mtcars$cyl == 8))
})

test_that("the rendered interaction table floats one visible p per band", {

	g <- as_gt(interaction_chain())
	dat <- g[["_data"]]

	# The p-value fills every row of its band (the rowspan emulation)...
	expect_equal(dat$row_key, c("0", "1", "4", "6", "8"))
	expect_equal(dat$p[1], dat$p[2])
	expect_equal(dat$p[3], dat$p[4])
	expect_equal(dat$p[4], dat$p[5])
	expect_false(dat$p[1] == dat$p[3])

	# ...with the duplicates masked and one copy centered on the band: the
	# two-row `am` band floats row 1 on the seam, the three-row `cyl` band
	# keeps its middle row (global row 4)
	styles <- g[["_styles"]]
	pStyles <- styles[styles$colname == "p" & styles$locname == "data", ]
	flat <- vapply(pStyles$styles, function(s) {
		paste(names(unlist(s)), unlist(s), sep = "=", collapse = ";")
	}, character(1))
	visible <- pStyles$rownum[grepl("v_align", flat)]
	expect_setequal(visible, c(1, 4))
	expect_true(any(pStyles$rownum == 1 & grepl("v_align=bottom", flat)))
	expect_true(any(pStyles$rownum == 4 & grepl("v_align=middle", flat)))

	# The duplicates are blanked by a text transform — a content substitution,
	# not a white-text style, so the mask holds on any theme or output format
	masked <- unlist(lapply(g[["_transforms"]], function(t) {
		if (identical(t$resolved$colnames, "p")) t$resolved$rows else integer()
	}))
	expect_setequal(masked, c(2, 3, 5))
	blanked <- vapply(g[["_transforms"]], function(t) {
		identical(t$fn("0.021"), "")
	}, logical(1))
	expect_true(all(blanked[vapply(g[["_transforms"]], function(t) {
		identical(t$resolved$colnames, "p")
	}, logical(1))]))

	# Level relabels arrive late, as everywhere
	html <-
		interaction_chain() |>
		modify_labels(am ~ c("Manual", "Automatic"), cyl ~ "Cylinders") |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl("Manual", html, fixed = TRUE))
	expect_true(grepl("Cylinders", html, fixed = TRUE))
})

test_that("the full old-forest chain renders: estimates, forest, floating p", {

	skip_if_not(capabilities("png"), "no png device")

	g <-
		interaction_chain() |>
		add_forest() |>
		as_gt()
	dat <- g[["_data"]]

	# The reserved axis row lands after both bands
	expect_equal(dat$row_key[nrow(dat)], ".axis")
	html <- gt::as_raw_html(g)
	expect_true(grepl("<img", html, fixed = TRUE))
})

test_that("the interaction layout narrows to one outcome × exposure", {

	d <- mtcars
	m1 <-
		fmls(mpg ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	m2 <-
		fmls(qsec ~ .x(hp) + .i(am)) |>
		fit(.fn = lm, data = d, raw = FALSE)
	mt <- suppressMessages(model_table(m1, m2, data = d))

	# The two outcomes relate (varied outcomes), so the gate admits them; the
	# interaction layout itself still demands a single outcome at realization
	spec <-
		mt |> mdl_gt() |> modify_layout(preset = "interaction") |>
		add_interaction()
	expect_error(as_gt(spec), "single outcome")

	# Whittling the model table down narrows it into shape
	g <-
		mt |> dplyr::filter(outcome == "mpg") |> mdl_gt() |>
		modify_layout(preset = "interaction") |> add_interaction() |>
		as_gt()
	expect_s3_class(g, "gt_tbl")

	# The retired monolith is gone
	expect_false("tbl_interaction_forest" %in% getNamespaceExports("mesa"))
})


# The forest column block (M6.8). A forest column is a column type available
# to any table, not a separate table family: `add_forest()` records a block
# that *reads* the estimate and interval already on the specification and
# computes nothing new. Its cells enter the cell frame as plain numbers
# (`type = "plot"`), the shared x-scale resolves at render across the whole
# column, the bottom axis strip is the reserved `.axis` row, and the block's
# dense style enters as overridable defaults. The invariant this buys — and
# the blueprint asks to test — is that adding or dropping the block changes
# no other cell. `invert` is implemented for real here (it was dead code
# behind `if (FALSE)` in the old forest table).

forest_table <- function() {
	d <- mtcars
	fmls(mpg ~ .x(wt) + hp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
}

test_that("add_forest() validates at verb time and records like every verb", {

	m <- mdl_gt(forest_table())

	expect_error(add_forest(mtcars), "inherit from")
	expect_error(add_forest(m, axis = list(1, 2)), "named list")
	expect_error(add_forest(m, axis = list(color = "red")),
							 "does not know the option")
	expect_error(add_forest(m, axis = list(limits = 1)), "length-2")
	expect_error(add_forest(m, axis = list(title = 2)), "single string")
	expect_error(add_forest(m, width = -5), "`width`")
	expect_error(add_forest(m, invert = NA), "`invert`")

	m2 <- add_forest(m, axis = list(log = TRUE))
	types <- vapply(m2$columns, function(b) b$type, character(1))
	expect_equal(types, "forest")
	expect_message(add_forest(m2, width = 200), "replaces the earlier forest")

	out <- utils::capture.output(print(add_forest(m, invert = TRUE)))
	expect_true(any(grepl("forest \\(inverted\\)", out)))
})

test_that("a forest block requires estimate and conf on the specification", {

	# It reads them and computes nothing new; the check surfaces at
	# realization, keeping the verbs order-independent
	m <-
		forest_table() |>
		mdl_gt() |>
		add_estimates(columns = list(p ~ "P")) |>
		add_forest()
	expect_error(as_gt(m), "keep `beta` and `conf`")

	# The bare default carries both, so a bare mesa takes a forest column
	bare <- forest_table() |> mdl_gt() |> add_forest()
	frame <- mdl_gt_cell_frame(realize_mdl_gt(bare), bare)
	expect_true(any(frame$type == "plot"))
})

test_that("adding or dropping add_forest() changes no other cell", {

	base <-
		forest_table() |>
		mdl_gt() |>
		add_estimates(columns = list(beta ~ "B", conf ~ "CI", p ~ "P"))
	withForest <- base |> add_forest()

	f0 <- mdl_gt_cell_frame(realize_mdl_gt(base), base)
	f1 <- mdl_gt_cell_frame(realize_mdl_gt(withForest), withForest)

	# Only the forest columns and the reserved .axis row appear
	extra <- f1[grepl("::forest$", f1$column_key) | f1$row_key == ".axis", ]
	expect_true(all(extra$type == "plot" | extra$type == "reference"))
	expect_true(".axis" %in% f1$row_key)
	expect_false(".axis" %in% f0$row_key)

	# Every other cell is untouched (column indexes renumber around the new
	# columns; everything else must match exactly)
	rest <- f1[!grepl("::forest$", f1$column_key) & f1$row_key != ".axis", ]
	drop <- function(f) f[setdiff(names(f), "column_index")]
	expect_equal(drop(rest), drop(f0), ignore_attr = TRUE)

	# And the surviving columns keep their relative order
	shared <- intersect(unique(f1$column_key), unique(f0$column_key))
	expect_equal(
		unique(f0$column_key[f0$column_key %in% shared]),
		unique(f1$column_key[f1$column_key %in% shared])
	)
})

test_that("forest cells read the estimate cells' numbers; invert draws
					 reciprocals with swapped bounds", {

	m <- forest_table() |> mdl_gt() |> add_forest()
	frame <- mdl_gt_cell_frame(realize_mdl_gt(m), m)

	fcells <- frame[frame$column_key == "wt::forest" &
										frame$row_key != ".axis", ]
	ecells <- frame[frame$column_key == "wt::est", ]
	expect_equal(fcells$value, ecells$value)

	minv <- forest_table() |> mdl_gt() |> add_forest(invert = TRUE)
	finv <- mdl_gt_cell_frame(realize_mdl_gt(minv), minv)
	icells <- finv[finv$column_key == "wt::forest" & finv$row_key != ".axis", ]
	for (i in seq_len(nrow(icells))) {
		expect_equal(icells$value[[i]]$estimate,
								 1 / ecells$value[[i]]$estimate)
		expect_equal(icells$value[[i]]$conf_low,
								 1 / ecells$value[[i]]$conf_high)
		expect_equal(icells$value[[i]]$conf_high,
								 1 / ecells$value[[i]]$conf_low)
	}
})

test_that("the axis options flow to the shared scale; the block renders", {

	skip_if_not(capabilities("png"), "no png device")

	m <-
		forest_table() |>
		mdl_gt() |>
		add_forest(axis = list(limits = c(-10, 2), intercept = 0))
	g <- as_gt(m)
	dat <- g[["_data"]]

	# The reserved row sorts last, blank in every other column
	expect_equal(dat$row_key[nrow(dat)], ".axis")
	expect_equal(dat[["wt::est"]][nrow(dat)], "")

	html <- gt::as_raw_html(g)
	expect_true(grepl("<img", html, fixed = TRUE))
})

test_that("the axis title rides the shared scale and heightens the strip", {

	values <- list(
		list(estimate = 1.2, conf_low = 1.0, conf_high = 1.4),
		list(estimate = 0.8, conf_low = 0.5, conf_high = 1.3)
	)
	expect_null(resolve_plot_scale(values)$title)
	expect_equal(
		resolve_plot_scale(values, options = list(title = "Estimate"))$title,
		"Estimate"
	)

	skip_if_not(capabilities("png"), "no png device")
	skip_if_not(isTRUE(capabilities("cairo")[[1]]), "no cairo (em sizing)")

	m <- forest_table() |> mdl_gt() |> add_forest(axis = list(title = "Estimate"))
	html <- gt::as_raw_html(as_gt(m))
	# Cells stay 30px (1.875em) tall; the titled strip takes 34px (2.125em)
	expect_true(grepl("height:1.875em", html, fixed = TRUE))
	expect_true(grepl("height:2.125em", html, fixed = TRUE))
})

test_that("a plot column turns the whole body borderless, evenly", {

	skip_if_not(capabilities("png"), "no png device")

	optOf <- function(g, parameter) {
		opts <- g[["_options"]]
		opts$value[opts$parameter == parameter][[1]]
	}

	# The per-cell hidden border punched gaps in the header and bottom rules
	# under border-collapse; the native look is a body-wide default instead
	withForest <- as_gt(forest_table() |> mdl_gt() |> add_forest())
	expect_equal(optOf(withForest, "table_body_hlines_style"), "none")
	expect_equal(optOf(withForest, "row_group_border_top_style"), "none")

	plain <- as_gt(mdl_gt(forest_table()))
	expect_false(identical(optOf(plain, "table_body_hlines_style"), "none"))
})

test_that("the dense padding is a default the style layer can override", {

	m <- forest_table() |> mdl_gt() |> add_forest()
	dense <- as_gt(m)
	spacious <- as_gt(modify_style(m, padding = 1))
	plain <- as_gt(mdl_gt(forest_table()))

	padOf <- function(g) {
		opts <- g[["_options"]]
		opts$value[opts$parameter == "data_row_padding"][[1]]
	}
	expect_false(identical(padOf(dense), padOf(plain)))
	expect_false(identical(padOf(dense), padOf(spacious)))

	# modify_style validates its new knob like the others
	expect_error(modify_style(m, padding = -1), "`padding`")
})

test_that("the levels layout defers the forest column, clearly", {

	m <-
		forest_table() |>
		mdl_gt() |>
		modify_layout(preset = "levels") |>
		add_forest()
	expect_error(as_gt(m), "deferred past launch")
})
