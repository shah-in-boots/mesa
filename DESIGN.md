# Design Notes

This file records the design decisions made while working through the
milestones in
[blueprint.md](https://shah-in-boots.github.io/mesa/blueprint.md). Each
entry says what was decided, why, and where the decision lives in code.
When a decision changes, update it here first.

## The internal representation of `fmls` (M2)

A `fmls` object is a data frame subclass with two structural attributes
and one behavioral attribute:

- **The formula matrix** (the data frame itself): one row per formula,
  one column per term, cells of 1/0 marking membership. This is what
  patterns produce and what every later layer reads.
- **`termTable`**: the `vec_proxy()` of the `tm` vector — one row per
  term with its role, side, label, group tier, transformation, levels,
  and other attributes. Terms with side `meta` (strata, random effects)
  live only here, never in the matrix, because they instruct *how* to
  fit rather than *what* to fit.
- **`instructions`**: a list of behavioral instructions that ride along
  with the family; currently `subsets`, a named list of quosures
  captured by
  [`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md).

Reconstruction rules: `formulas_to_terms()` reassembles each row into a
`tm` vector by matrix membership, always re-attaching strata and random
terms; `formula.tm()` renders the fitting formula, dropping meta terms
except random effects, which render as `(1 | term)`.

## Role taxonomy additions (M1)

- **Random effects** are a role (`random`, shortcut `.r()`), side
  `meta`. `y ~ .x(x) + .r(id)` and the lme4-native `y ~ x + (1 | id)`
  parse to the same term. Random slopes `(wt | id)` are carried whole
  and re-rendered in parentheses.
- **Data subsets are not a role.** A filter like `sex == "F"` is not a
  variable in the formula; it is an instruction about the data. Subsets
  therefore live in the `fmls` `instructions` attribute via
  [`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  and expand the fitting plan, exactly like strata levels do. This was
  the main design fork in M1 and the reason there is no `.f()` rune.

## Transformations keep the call as the name (M1)

`log(x)` stays `log(x)` — the term’s name is the full call, so formulas
rebuild losslessly without [mesa](https://shah-in-boots.github.io/mesa/)
needing to re-apply anything. The wrapper is *additionally* recorded in
the `transformation` field so downstream layers
(e.g. [`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md),
future table labeling) can interpret it.
[`factor()`](https://rdrr.io/r/base/factor.html)/[`ordered()`](https://rdrr.io/r/base/factor.html)
wrappers make
[`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
classify the term from the converted variable.

## The parser is an AST walk (M1)

[`tm.formula()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
walks the formula’s syntax tree (`collect_formula_terms()`) instead of
scanning [`all.names()`](https://rdrr.io/r/base/allnames.html)
positionally. Consequences worth remembering:

- Nested runes now work: `.x(log(x))` is an exposure with a `log`
  transformation.
- Unrecognized calls (`Surv(...)`, `cluster(...)`) are opaque terms,
  carried whole.
- Group tiers accept any number of digits (`.g10`).
- Only `.i()`/`.m()` *shortcuts* demote (with a warning) when no
  exposure exists; explicit `a:b` products keep the interaction role
  silently.

## Patterns are a registry (M2)

`register_pattern(name, fn)` adds a `tm -> tbl_df` function to an
environment-backed registry;
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md) and
[`apply_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
look patterns up by name, and
[`formula_patterns()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
lists what is registered. The `rolling_interaction` stub was removed
rather than finished — it returns when it can be done properly, as a
registered pattern.

## Combining families keeps the first definition (M2, issue \#42)

[`c()`](https://rdrr.io/r/base/c.html) / `vec_c()` on `fmls` merges term
tables; when a term arrives with conflicting definitions, the left-most
wins and a message names the conflicted terms. This is a message, not a
warning, because keep-first is the intended resolution — the message is
there so the resolution is never silent.

## Fitting is plan-then-execute (M4)

`fit_plan(object, data)` crosses formulas x strata levels x subsets into
an inspectable tibble;
[`fit()`](https://generics.r-lib.org/reference/fit.html) executes it row
by row. Decisions inside:

- `.fn` resolves **by name** through
  [`match.call()`](https://rdrr.io/r/base/match.call.html) (a function,
  a string, or a [parsnip](https://github.com/tidymodels/parsnip)
  `model_spec`); the old positional `match.call()[[3]]` bug is
  regression-tested.
- With a parsnip spec,
  [`fit()`](https://generics.r-lib.org/reference/fit.html) runs
  [`parsnip::fit()`](https://generics.r-lib.org/reference/fit.html) and
  unwraps the engine fit, so
  [`mdl()`](https://shah-in-boots.github.io/mesa/reference/models.md)
  and the table layers see familiar objects. The `.models` whitelist is
  retired; it remains only as documentation.
- Failures are soft: an error becomes a recorded condition
  (`raw = TRUE`) or a `mdl` stub whose `summaryInfo$error` carries the
  message;
  [`model_table()`](https://shah-in-boots.github.io/mesa/reference/mdl_tbl.md)
  turns that into `fit_status = FALSE`, and
  [`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  drops unfit rows.
- Fitted calls are normalized (function name, formula text, data by
  name) so models compare cleanly against hand-fit references and don’t
  embed copies of the data.
- Subset provenance is recorded in `dataArgs$subsetName` and surfaces as
  the `subset` column of a `mdl_tbl`.

## Degrees of freedom and the variance-covariance matrix (M4)

`degrees_freedom` now comes from
[`stats::df.residual()`](https://rdrr.io/r/stats/df.residual.html) with
a `nobs - length(coef)` fallback (the old `nrow - ncol - 1` was an
`lm`-shaped guess, off by one even for `lm`). The full `var_cov` matrix
**stays** in `summaryInfo`:
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
needs the covariance between the exposure and the product term to
compute interaction confidence intervals without the original data.

## Imports audit (M0)

- [ggplot2](https://ggplot2.tidyverse.org) and
  [scales](https://scales.r-lib.org) stay in Imports: the forest-plot
  column is a core deliverable of the table layer.
- [survival](https://github.com/therneau/survival) moved to Suggests: it
  is touched only by the hazard tables (`pyears()`), which now guard
  with [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html).
  Dispatching on `coxph` objects does not require the package.
- [parsnip](https://github.com/tidymodels/parsnip),
  [lme4](https://github.com/lme4/lme4/),
  [broom.mixed](https://github.com/bbolker/broom.mixed) are Suggests:
  each is guarded at its point of use.
- [lifecycle](https://lifecycle.r-lib.org/) added to Imports (badges
  were already in use without it).

## Formula shorthand requests (M2, issue \#25)

Added: `.r()` for random effects; multi-digit `.g` tiers; nested
rune/transformation combinations. Declined for now: a `.f()` subset rune
(see the subsets decision above) and per-term weights (no clear
fitting-layer story yet — revisit with M5).

## Private-data tests (M0/M6)

The author-only checks against AFEQT/CARRS/MIMS
[targets](https://docs.ropensci.org/targets/) stores moved to
`tests/manual/` (build-ignored, not run by testthat) so R CMD check is
clean. Milestone 6 replaces them with public-data equivalents.
