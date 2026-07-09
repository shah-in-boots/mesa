# The <mesa> specification (M6.3) is the declarative object the grammar grows.
# These tests pin down its three contracts: the constructor validates before it
# builds, the verbs record instructions that compose in any order (a repeat
# replaces with a message), and realization decorates the selected rows —
# joining term metadata and injecting a reference row for every categorical
# term — before the minimal renderer emits estimate + CI.

# A small fitted table on mtcars, cyl as a factor so a categorical term is in
# play and reference-row injection is exercised.
spec_data <- function() {
	d <- mtcars
	d$cyl <- factor(d$cyl)
	d$am <- factor(d$am, levels = c(0, 1), labels = c("Manual", "Automatic"))
	d
}

spec_table <- function(d = spec_data()) {
	fmls(mpg ~ .x(am) + .x(cyl) + hp + disp, pattern = "sequential") |>
		fit(.fn = lm, data = d, raw = FALSE) |>
		model_table(data = d)
}

test_that("mesa() rejects anything but a fitted mdl_tbl", {

	expect_error(mesa(mtcars), "inherit from")

	# A table of unfit formulas has nothing to lay out
	unfit <- model_table(fmls(mpg ~ .x(wt) + hp))
	expect_error(mesa(unfit), "needs fitted models")
})

test_that("mesa() holds a single model family, erroring when mixed", {

	d <- spec_data()
	m_lm <- fmls(mpg ~ .x(hp)) |> fit(.fn = lm, data = d, raw = FALSE)
	# A gaussian glm is a distinct family from lm without the separation noise a
	# binomial fit on this data would produce
	m_glm <-
		fmls(mpg ~ .x(hp)) |>
		fit(.fn = glm, family = stats::gaussian, data = d, raw = FALSE)
	mixed <- model_table(m_lm, m_glm, data = d)

	expect_error(mesa(mixed), "single model family")

	# One family builds cleanly
	expect_s3_class(mesa(spec_table(d)), "mesa")
})

test_that("mesa() messages, but does not error, on more than one dataset", {

	d <- spec_data()
	d2 <- d[1:20, ]
	m1 <- fmls(mpg ~ .x(hp)) |> fit(.fn = lm, data = d, raw = FALSE)
	m2 <- fmls(mpg ~ .x(hp)) |> fit(.fn = lm, data = d2, raw = FALSE)
	mt <- model_table(m1, m2, data = d) |> attach_data(d2)

	expect_message(mesa(mt), "more than one dataset")
})

test_that("a bare mesa lays out the exposures and realizes to estimates", {

	m <- mesa(spec_table())
	expect_s3_class(m, "mesa")

	dec <- realize_mesa(m)
	# The two exposures are shown; the adjusted-only covariates are not
	expect_setequal(unique(dec$variable), c("am", "cyl"))
	expect_false(any(dec$variable %in% c("hp", "disp")))

	# Estimates carry through on the (linear, for lm) scale
	expect_true(all(dec$exponentiated[!dec$is_reference] == FALSE))
	expect_true(any(!is.na(dec$estimate)))
})

test_that("realization injects a reference row for each categorical term", {

	dec <- realize_mesa(mesa(spec_table()))

	# `am` (Manual/Automatic) and `cyl` (4/6/8) each contribute a reference row
	# per adjustment set, carrying the reference level and no estimate
	amRef <- dec[dec$variable == "am" & dec$is_reference, ]
	expect_true(all(amRef$level == "Manual"))
	expect_true(all(is.na(amRef$estimate)))

	cylRef <- dec[dec$variable == "cyl" & dec$is_reference, ]
	expect_true(all(cylRef$level == "4"))

	# One reference row per adjustment set for each categorical term
	expect_equal(nrow(amRef), length(unique(dec$adj_index)))
})

test_that("mesa() errors on unused arguments", {

	expect_error(mesa(spec_table(), foo = "bar"), "Unused argument")
	expect_error(mesa(spec_table(), 1), "no selection arguments")
})

test_that("select_*() with no arguments clears the dimension", {

	m <- mesa(spec_table()) |> select_terms(~ am)
	expect_equal(unique(realize_mesa(m)$variable), "am")

	# Calling the verb again with nothing clears the earlier selection, with a
	# message, and the mesa falls back to its default (both exposures)
	expect_message(cleared <- select_terms(m), "replaces the earlier terms")
	expect_setequal(unique(realize_mesa(cleared)$variable), c("am", "cyl"))
})

test_that("selection verbs record instructions and compose in any order", {

	mt <- spec_table()

	a <-
		mt |> mesa() |>
		select_outcomes(mpg ~ "MPG") |>
		select_adjustment(1 ~ "Crude", 3 ~ "Adjusted") |>
		select_terms(cyl ~ "Cylinders")
	b <-
		mt |> mesa() |>
		select_terms(cyl ~ "Cylinders") |>
		select_adjustment(1 ~ "Crude", 3 ~ "Adjusted") |>
		select_outcomes(mpg ~ "MPG")

	# Any permutation of the same verbs realizes to the same table
	expect_equal(realize_mesa(a), realize_mesa(b))

	# The recorded labels flow through to the decorated frame
	dec <- realize_mesa(a)
	expect_equal(unique(dec$term_label), "Cylinders")
	expect_setequal(unique(dec$adj_label), c("Crude", "Adjusted"))
})

test_that("repeating a verb replaces its instruction with a message", {

	m <- mesa(spec_table()) |> select_terms(~ am)
	expect_message(m2 <- select_terms(m, ~ cyl), "replaces the earlier terms")

	# The replacement wins; the earlier selection is gone
	expect_equal(unique(realize_mesa(m2)$variable), "cyl")
})

test_that("modify_labels relabels terms and levels late", {

	mt <- spec_table()

	# Term relabel
	g <- mt |> mesa() |> select_terms(~ am) |> modify_labels(am ~ "Transmission")
	expect_equal(unique(realize_mesa(g)$term_label), "Transmission")

	# Level relabel by a bare level value, wherever it appears
	h <- mt |> mesa() |> select_terms(~ cyl) |> modify_labels(6 ~ "Six")
	dec <- realize_mesa(h)
	expect_equal(unique(dec$level_label[!is.na(dec$level) & dec$level == "6"]), "Six")

	# A repeated modify_labels replaces the earlier instruction
	expect_message(
		modify_labels(g, am ~ "Gearbox"),
		"replaces the earlier label"
	)
})

test_that("modify_labels() merges per name (M6.11)", {

	mt <- spec_table()

	# Relabeling `cyl` after `am` keeps both -- no restating the first
	m <-
		mt |> mesa() |> select_terms(~ am, ~ cyl) |>
		modify_labels(am ~ "Transmission") |>
		modify_labels(cyl ~ "Cylinders")
	dec <- realize_mesa(m)
	expect_equal(unique(dec$term_label[dec$variable == "am"]), "Transmission")
	expect_equal(unique(dec$term_label[dec$variable == "cyl"]), "Cylinders")

	# Naming the same term again replaces only that term's label, with a
	# message naming it; the other term's label is untouched
	expect_message(
		m2 <- modify_labels(m, am ~ "Gearbox"),
		"replaces the earlier label for `am`"
	)
	dec2 <- realize_mesa(m2)
	expect_equal(unique(dec2$term_label[dec2$variable == "am"]), "Gearbox")
	expect_equal(unique(dec2$term_label[dec2$variable == "cyl"]), "Cylinders")

	# The same merge rule applies order-independently
	m3 <-
		mt |> mesa() |> select_terms(~ am, ~ cyl) |>
		modify_labels(cyl ~ "Cylinders") |>
		modify_labels(am ~ "Transmission")
	expect_equal(realize_mesa(m), realize_mesa(m3))
})

test_that("selection is resolved lazily — bad selections error at realization", {

	# Recording a nonexistent term does not error at verb time
	s <- mesa(spec_table()) |> select_terms(~ nonexistent)
	expect_s3_class(s, "mesa")

	# It surfaces only when the spec is realized
	expect_error(as_gt(s), "No term matches")
})

test_that("as_gt() renders a minimal estimate + CI table from a bare spec", {

	g <- as_gt(mesa(spec_table()))
	expect_s3_class(g, "gt_tbl")

	# It renders, and a chosen term label reaches the output as a spanner
	html <-
		spec_table() |>
		mesa() |>
		select_terms(cyl ~ "Cylinders") |>
		as_gt() |>
		gt::as_raw_html()
	expect_true(grepl("Cylinders", html))
	# The reference level heads its own (blank) column
	expect_true(grepl(">4<", html))
})

test_that("print.mesa shows the models, layout, and selection", {

	out <- utils::capture.output(print(mesa(spec_table())))
	expect_true(any(grepl("<mesa> specification", out)))
	expect_true(any(grepl("6 fitted models", out)))
	expect_true(any(grepl("layout: adjustment", out)))
	expect_true(any(grepl("everything fitted", out)))
})
