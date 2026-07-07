# mesa (developmental version)

This development cycle works through Milestones 0–5 of [blueprint.md](https://github.com/shah-in-boots/mesa/blob/main/blueprint.md), rebuilding the term, formula, fitting, and collection layers so the package feels fluid to play with. Design decisions are recorded in `DESIGN.md`.

## The model table (Milestone 5)

* Printing a `mdl_tbl` now reports the state of the analysis at a glance: how many models are fitted, failed, or awaiting `fit()`; which datasets are attached; the strata and subsets in play; then one readable line per model, ending with pointers to the next move (#18)

* `summary()` maps the fleet — models grouped by dataset, fitting function, outcome, and exposure with their adjustment ranges — lists the terms by causal role, and explains each failure with its error message

* New helpers: `model_failures()` (the attempted-and-errored models with their messages), `term_table()`, `formula_matrix()`, and `model_data()` (documented accessors for the table's attributes)

* `flatten_models()` infers exponentiation from each model's family and link — Cox models and log/logit/cloglog GLMs come back as ratios, `lm` stays linear — with an `exponentiated` marker column, a message when inference kicks in, and `exponentiate = TRUE/FALSE` (or `which =`) as explicit overrides; unfit rows are dropped with a message instead of silently

* Combining model tables is now trustworthy: `model_table(x, y)` combines tables directly, attached datasets survive combination (#26), formula matrices stay parallel to the table's rows, and term tables deduplicate left-most-wins

* `dplyr` verbs reconcile the table's attributes (#23): `filter()`, `arrange()`, `slice()`, `mutate()`, and `[` prune the formula matrix, term table, and data list down to the remaining models (stale strata and role entries are removed — the old #26 symptom); dropping an invariant column returns a plain `data.frame` with a message naming the columns, and `bind_rows()` across unrelated tables points back to `model_table()`

* `model_table()` validates its inputs: raw fitted models are rejected with directions toward `fit(..., raw = FALSE)` or `mdl()` (#46), every construction runs `validate_model_table()`, and the invariant columns are documented in `?model_table`

* A `number` column (the count of right-hand-side terms, i.e. the adjustment degree) is now part of every table; `level` and other provenance columns are type-stable so tables from different datasets combine

* Naming convention settled: spelled-out names are canonical for the public API (`model_table()`), abbreviated forms remain as documented aliases (`mdl_tbl()`) and as the class name

## New features

* `set_data()` stamps `type`, `distribution`, and observed `level`s onto `tm` and `fmls` objects from a dataset, making strata and interactions data-aware before anything is fit (#5)

* Fluent verbs for playing with formula families: `add_strata()`, `remove_strata()`, `add_terms()`, `remove_terms()`, `swap_outcome()`, and `subset_data()` — each pipeable, each returning a modified `fmls`

* Random effects joined the role vocabulary: `.r(id)` (or lme4-native `(1 | id)`) parses, prints, rebuilds as `(1 | id)`, and fits through `{lme4}` with `{broom.mixed}` tidiers

* `fit()` accepts a fitting function, its name, or a `{parsnip}` model specification, resolved by name rather than position; the hard-coded model whitelist is retired

* `fit_plan()` exposes the fitting plan — formula x stratum x subset — as an inspectable table before anything runs

* Fitting fails softly: one failed model records its error (`fit_status = FALSE` in a `mdl_tbl`) instead of sinking the batch

* Subset instructions ride the plan: `subset_data(f, am == 1)` fits the family per subset and lands as a `subset` provenance column in the model table

* Patterns are an open registry: `register_pattern()` makes user-defined expansion patterns available to `fmls()` by name; `formula_patterns()`, `term_roles()`, and `term_transformations()` expose the vocabularies

* `fmls` families combine with `c()`; conflicting term definitions resolve left-most-wins with an explicit message (#42)

* Printing a `fmls` now leads with a deck summary: formula count, outcomes, exposures, strata (with levels), random effects, and subsets

* Term and formula printing now uses `cli` named ANSI colors by role, with `mesa.color` for user control

## Fixes

* The `tm.formula()` parser is a recursive walk of the formula syntax tree, replacing positional `all.names()` scanning; nested runes like `.x(log(x))` now parse correctly, and group tiers accept multiple digits (`.g10`)

* Grouped covariates in the parallel pattern were dropped for every tier except zero; they now stay together (was `group == 0L`)

* `fit()` no longer misreads `.fn` when arguments are supplied in a different order

* Labeling formulas with vector values (e.g. `am ~ c("Manual", "Automatic")`) now evaluate properly instead of deparsing to a string

* `degrees_freedom` follows each model family's own accounting (`df.residual()` with a fallback) instead of an `lm`-shaped guess

* The unfinished `apply_rolling_interaction_pattern()` stub was removed; it will return as a registered pattern

## Housekeeping

* Internal vocabularies moved from `sysdata.rda` into `R/vocabulary.R`; `{lifecycle}` declared; `{survival}` moved to Suggests behind guards; `{parsnip}`, `{lme4}`, and `{broom.mixed}` added to Suggests

* Author-only tests against private datasets moved to `tests/manual/`; R CMD check runs clean

* Renamed package from `{rmdl}` to `{mesa}`.

* Remove additional imports, e.g. `{janitor}`, with bespoke function rewrites, to help decrease dependency burden

* Updated package title as software has evolved

# mesa 0.1.0

This first CRAN release contains the basic functions for the package, and introduces the new basic classes. 

* `tm` gives variables in formulas specific roles and behaviors (vectorized)

* `fmls` expands the base formula class into a list of related formulas (vectorized)

* `mdl` are a thin wrapper (vectorized) for statistical models, with important metadata maintained, and are used to generate `mdl_tbl` objects, which serve as a reference `data.frame` of a family of modeling objects
