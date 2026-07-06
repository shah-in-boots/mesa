# mesa (developmental version)

This development cycle works through Milestones 0–4 of [blueprint.md](https://github.com/shah-in-boots/mesa/blob/main/blueprint.md), rebuilding the term, formula, and fitting layers so the package feels fluid to play with. Design decisions are recorded in `DESIGN.md`.

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
