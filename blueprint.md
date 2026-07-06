# The {mesa} Blueprint

This document is the guiding map for the development of
[mesa](https://shah-in-boots.github.io/mesa/). It exists because the
package grew organically — class by class, problem by problem — and it
deserves a deliberate architecture that matches its original intent.
Each milestone below is broken into incremental subtasks that can be
picked up, completed, and checked off one at a time. This document is
the source of truth for direction; GitHub issues should be triaged
against it, and it should be revised as thinking evolves.

# Intent

[mesa](https://shah-in-boots.github.io/mesa/) is about modeling for
epidemiology and causality assessment in a user-friendly way. It is
built from an epistemological perspective: small building blocks that
build up to more complex concepts. It starts with individual model
terms, expands as they join and merge into formulas, which can then be
fit or combined together, and then tested against different datasets or
with different modeling approaches. The destination is a *grammar* for
presenting multiple models in tables for papers, built on top of
[gt](https://gt.rstudio.com) — which is why the package is called `mesa`
(the table upon which the models are laid out).

The feeling the package should give is *fluidity* — being able to pick
terms up from a dataset and “play” with the modeling: swap strata, add
random effects, subset the data, roll an interaction through, and watch
the family of models unfold. The causal perspective is what makes this
different from general-purpose modeling tools: variables have *roles*
(exposure, outcome, confounder, mediator, interaction, strata), and
those roles carry meaning that shapes how formulas expand, how models
are fit, and how results are displayed.

I am not building something that already exists. Where the ecosystem
already solves a problem —
[tidymodels](https://tidymodels.tidymodels.org) and
[parsnip](https://github.com/tidymodels/parsnip) for universal model
definitions, [broom](https://broom.tidymodels.org/) for tidying,
[gt](https://gt.rstudio.com) for table rendering —
[mesa](https://shah-in-boots.github.io/mesa/) should lean on it rather
than reinvent it.

# The Grammar

The package is organized as layers, each built from the one below it.
This is the epistemology of the package, and the file structure,
documentation, and vignettes should all follow it.

| Layer | Class | Metaphor | Question it answers |
|----|----|----|----|
| 1\. Terms | `tm` | atoms | What is this variable, and what role does it play? |
| 2\. Formulas | `fmls` | molecules | How do terms combine, and by what pattern do they expand? |
| 3\. Models | `mdl` | reactions | What happens when a formula meets data and a fitting approach? |
| 4\. Collections | `mdl_tbl` | notebook | How do I store, recall, and compare many models? |
| 5\. Tables | `tbl_*` | the mesa | How do I lay the models out for a paper? |

# Where Things Stand

An honest accounting, as of the July 2026 review. The test suite passes
(with 10 skips), the core pipeline works for the `lm`/`glm`/`coxph`
cases, and the layered concept is sound. But the implementation has
drifted from the intent in several places.

> **Revision note (July 2026):** Milestones 0 through 4 are complete.
> Every defect listed below is fixed with a regression test, and the
> structural debts in the term, formula, and fitting layers are paid
> down (the `gt` layer debts remain for Milestone 6). Design decisions
> made along the way are recorded in
> [DESIGN.md](https://shah-in-boots.github.io/mesa/DESIGN.md). R CMD
> check runs clean (0 errors, 0 warnings, 0 notes).

**What works well:**

- The role vocabulary and formula shorthand (`.o()`, `.x()`, `.c()`,
  `.m()`, `.i()`, `.s()`, `.g()`) — this is the soul of the package and
  the idea is right.
- The pipeline `fmls() |> fit() |> model_table() |> flatten_models()`
  runs end-to-end.
- The `vctrs`-based class scaffolding gives principled vector behavior.
- Stratified fitting (`.s()`) already produces one model per stratum
  level, which is exactly the “play” feeling to build on.

**Known defects (found on review; all but one fixed in Milestones
0–4):**

- ~~[`apply_parallel_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
  subsets grouped covariates with `group == 0L` instead of `group == g`,
  so only tier-0 groups are ever collected.~~ *Fixed in M2 with a
  two-tier regression test.*
- ~~[`fit.fmls()`](https://shah-in-boots.github.io/mesa/reference/fit.fmls.md)
  recovers `.fn` positionally via `match.call()[[3]]`, which breaks when
  arguments are supplied in a different order.~~ *Fixed in M4; `.fn`
  resolves by name and accepts a function, string, or
  [parsnip](https://github.com/tidymodels/parsnip) spec.*
- ~~`apply_rolling_interaction_pattern()` is an unfinished stub that
  returns the outcome/exposure grid without rolling anything.~~ *Removed
  in M2; it returns as a registered pattern when it can be done
  properly.*
- `mdl_tbl_cast()` drops the `dataList` attribute when combining tables
  — this is the root of issue \#26
  ([model-table.R](https://shah-in-boots.github.io/mesa/R/model-table.R)).
  *Still open — this is Milestone 5.*
- ~~[`lifecycle::badge()`](https://lifecycle.r-lib.org/reference/badge.html)
  is used throughout the documentation but
  [lifecycle](https://lifecycle.r-lib.org/) is not declared in
  `DESCRIPTION`.~~ *Fixed in M0.*
- ~~Group tiers only parse a single digit (`.g1` through `.g9`), and
  `.transformations` supports only `log`.~~ *Fixed in M1; multi-digit
  tiers and a fuller transformation vocabulary.*
- ~~`degrees_freedom` is computed as `nrow - ncol - 1` for every model
  family, which is not correct outside of `lm`.~~ *Fixed in M4 via
  [`df.residual()`](https://rdrr.io/r/stats/df.residual.html) with a
  per-family fallback.*
- *(Found during M1)* ~~The documented `am ~ c("Manual", "Automatic")`
  labeling idiom deparsed to a junk string in
  [`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md).~~
  *Fixed; vector values now evaluate properly across all table
  functions.*

**Structural debts:**

- ~~The
  [`tm.formula()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
  parser walks [`all.names()`](https://rdrr.io/r/base/allnames.html)
  positionally rather than the formula AST, making it fragile and hard
  to extend (it is also ~370 lines in one function).~~ *Paid down in M1:
  a recursive AST walk in named helpers, with round-trip property
  tests.*
- ~~The supported models (`.models`), patterns (`.patterns`), roles
  (`.roles`), and transformations (`.transformations`) are frozen into
  `sysdata.rda` — closed vocabularies where extensible ones are
  wanted.~~ *Paid down in M1/M2: vocabularies live in `R/vocabulary.R`
  with accessors, and patterns are an open registry.*
- The `gt` layer (`tbl_beta`, `tbl_dichotomous_hazard`,
  `tbl_categorical_hazard`, `tbl_interaction_forest`) is four monoliths
  with duplicated filtering/formatting logic, and its meaningful tests
  are skipped because they depend on private datasets (AFEQT, CARRS).
  *Still open — this is Milestone 6. The private-data tests moved to
  `tests/manual/` so the automated suite and R CMD check stand on their
  own.*
- Naming is split between abbreviated and spelled-out forms (`mdl_tbl`
  vs `model_table`, `fmls`, `tm`) without a stated convention. *Still
  open — decided in Milestone 5.*
- ~~Repository hygiene: `sandbox.R` and `ex.R` sit at the top level,
  built vignette artifacts (`getting_started.html`, `.R`) are committed,
  `test-dev.R` is a placeholder, and `test-gt.R` is empty.~~ *Cleaned in
  M0.*
- ~~Random effects — explicitly part of the vision — have no
  representation at all yet.~~ *Built in M1–M4: the `.r()` role,
  `(1 | id)` parsing and rendering, and fitting through
  [lme4](https://github.com/lme4/lme4/).*

# Design Principles

These are the rules to check every change against.

1.  **Roles are causal, and roles are first-class.** A term’s role
    should be knowable, updatable, and should visibly change behavior
    downstream (expansion, fitting, display).
2.  **Each layer only speaks to its neighbors.** Terms know nothing of
    models; tables consume model collections, not raw fits.
3.  **Fluidity over ceremony.** The common path — terms from a dataset,
    snapped into formulas, fit, tabled — should read as a single pipe
    with no bookkeeping.
4.  **Leverage, don’t reinvent.**
    [parsnip](https://github.com/tidymodels/parsnip) defines models,
    [broom](https://broom.tidymodels.org/) tidies them,
    [gt](https://gt.rstudio.com) renders tables.
    [mesa](https://shah-in-boots.github.io/mesa/) contributes the causal
    grammar that connects them.
5.  **Everything round-trips.** `formula -> tm -> fmls -> formula`
    should be lossless; a `mdl_tbl` should be able to reconstruct the
    context of any model it holds.
6.  **Fail softly in batches.** When fitting twenty models, one failure
    should mark `fit_status = FALSE`, not sink the fleet.

# Milestones

Each milestone is scoped so its subtasks are roughly PR-sized. Work top
to bottom within a milestone; milestones 1–2 should land before 3–4, but
0 can be interleaved anywhere. Every subtask that touches behavior
should carry tests.

## Milestone 0 — Clear the workbench ✅

*Housekeeping so the real work is unobstructed.*

Move `sandbox.R` and `ex.R` out of the package root (`ex.R` became
`inst/examples/interaction-forest.R`; `sandbox.R` referenced private
data and a function that no longer exists, so it was deleted).

Remove committed build artifacts: `vignettes/getting_started.html`,
`vignettes/getting_started.R`.

Add [lifecycle](https://lifecycle.r-lib.org/) to `DESCRIPTION` (badges
are already in use).

Delete the placeholder `test-dev.R` and empty `test-gt.R`.

Review PR \#72 (testthat 3.3.0 compatibility) — its fix already exists
on `main`, so the PR is superseded and can be closed on GitHub.

Audit `Imports`: [ggplot2](https://ggplot2.tidyverse.org) and
[scales](https://scales.r-lib.org) stay (the forest layer is core);
[survival](https://github.com/therneau/survival) moved to `Suggests`
behind [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)
guards. Reasoning recorded in
[DESIGN.md](https://shah-in-boots.github.io/mesa/DESIGN.md).

Organize the `_pkgdown.yml` reference index by grammar layer (validated
with
[`pkgdown::check_pkgdown()`](https://pkgdown.r-lib.org/reference/check_pkgdown.html)).

Triage all open GitHub issues against this blueprint (map below).
Labeling/closing on GitHub itself remains a by-hand step.

**Issue triage map:**

| Issue | Where it landed |
|----|----|
| \#5 (level argument for `tm`) | Done in M1 — the `level` field |
| \#6 (Terms) | Done in M1 — role taxonomy spec and parser rewrite |
| \#18, \#46 (`mdl_tbl` construction and warnings) | Milestone 5 |
| \#23 (dplyr verb support) | Milestone 5 |
| \#25 (formula shorthand requests) | Decided in M1/M2 — see DESIGN.md; close after review |
| \#26 (combining tables loses attributes) | Milestone 5 |
| \#30 (hazard tables) | Milestone 6 |
| \#42 (merging formulas with special terms) | Done in M2 — [`c()`](https://rdrr.io/r/base/c.html) with collision messaging |
| \#47, \#48 (`gt` implementation and beta tables) | Milestone 6 |
| PR \#72 (testthat 3.3.0) | Superseded — already fixed on `main`; close |

## Milestone 1 — Terms are the atoms (`tm`) ✅

*A term should carry its causal identity reliably; the parser should be
trustworthy enough to build everything else on.*

Write the role taxonomy down as a specification: the Roles table in
`R/terms.R` now gives each role its causal definition *and* the
downstream behavior it changes (issue \#6).

Decide the representation for random effects and data subsets: random
effects became the `.r()` role (side `meta`, rendering as `(1 | term)`,
with lme4-native syntax parsed too); subsets are deliberately **not** a
role — they are `fmls` instructions via
[`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md).
Decision recorded in
[DESIGN.md](https://shah-in-boots.github.io/mesa/DESIGN.md).

Rewrite the
[`tm.formula()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
parser as a recursive walk of the formula AST (`collect_formula_terms()`
plus named helpers for demotion, interaction expansion, defaults, and
overrides). Nested runes like `.x(log(x))` now work.

Fix group tier parsing to accept multi-digit tiers (`.g10`) and clean up
the interaction/grouping bookkeeping.

Open the transformation vocabulary (log family, `sqrt`, `scale`,
`factor`, `ordered`, polynomial/spline markers), and move the
vocabularies out of `sysdata.rda` into `R/vocabulary.R` with
[`term_roles()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
/
[`term_transformations()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
accessors.

Add the `level` field for categorical terms (issue \#5); filled by
[`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
or [`update()`](https://rdrr.io/r/stats/update.html).

Simplify `format.tm()` to a role → color lookup (`.role_colors` in
`R/vocabulary.R`).

Property-style round-trip tests in `test-roundtrip.R`: plain formulas,
role shortcuts, opaque calls, meta terms, and random effects.

## Milestone 2 — Formulas as composition (`fmls`) ✅

*Formulas are terms joined by rules; patterns are the rules, and they
should be a small open grammar rather than a closed switch statement.*

Document the internal representation (formula matrix + term table +
instructions) in
[DESIGN.md](https://shah-in-boots.github.io/mesa/DESIGN.md).

Fix the parallel-pattern grouping bug (`group == 0L` → `group == g`)
with a regression test using two grouped tiers.

Turn patterns into a registry:
[`register_pattern()`](https://shah-in-boots.github.io/mesa/reference/register_pattern.md)
adds any `tm -> tibble` function by name,
[`formula_patterns()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
lists them, and
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md) looks
them up — with a test registering a user-defined pattern.

Remove the `apply_rolling_interaction_pattern()` stub; it returns as a
registered pattern when it can be done properly.

Define formula combination semantics (issue \#42):
[`c()`](https://rdrr.io/r/base/c.html) and `vec_c()` merge families;
conflicting term definitions resolve left-most-wins with an explicit
message.

Document the mediation triad (total effect, mediator model, direct
effect) in the
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
Mediation section.

Un-skip and repair the `fmls`/`formula` interchange test — both
directions plus casting now round-trip.

Address the formula shorthand requests (issue \#25): `.r()` and
multi-digit tiers added; a `.f()` subset rune declined (see DESIGN.md).

## Milestone 3 — Fluency: playing with terms against data ✅

*This is the milestone that makes the package feel the way it is
supposed to feel: pick terms up off a dataset and play.*

Grow the data-classification helpers into a “meet the data” step:
`set_data(x, data)` (methods for `tm` and `fmls`) stamps `type`,
`distribution`, and `level`s onto terms, classifying transformed terms
from their underlying variable.

Design and implement the fluent verb layer on `fmls` (`R/fluency.R`):
[`add_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
[`remove_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
[`add_terms()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
[`remove_terms()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
[`swap_outcome()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
[`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
— each pipeable, each returning a modified family. Extending them to
`mdl_tbl` waits for Milestone 5.

Make strata data-aware: after
[`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md),
the print method shows `strata: am (2 levels)` before anything is fit.

Implement data subsets as first-class instructions:
`subset_data(f, am == 1, cyl > 4)` records quosures on the family;
\[fit()\] fits once per subset, and the subset lands as provenance in
the model table.

Implement the random-effects role through the formula layer:
`y ~ .x(x) + .r(id)` composes, prints, and rebuilds as
`y ~ x + (1 | id)`.

Give `fmls` a print worthy of play: the deck header summarizes formula
count, outcomes, exposures, mediators, interactions, strata (with
levels), random effects, and subsets.

## Milestone 4 — Fitting through a universal interface ✅

*Stop maintaining a whitelist of model functions; let
[parsnip](https://github.com/tidymodels/parsnip) define what a model is,
and keep a plain-function escape hatch.*

Fix the positional `.fn` capture in
[`fit.fmls()`](https://shah-in-boots.github.io/mesa/reference/fit.fmls.md):
`.fn` now resolves by name and accepts a function, a string, or a
parsnip spec, with a regression test that scrambles argument order.

Accept [parsnip](https://github.com/tidymodels/parsnip) model
specifications in
[`fit()`](https://generics.r-lib.org/reference/fit.html); the `.models`
whitelist is retired (it survives only as documentation) and the
engine’s identity flows into `model_call`.

Refactor into plan-then-execute: `fit_plan(object, data)` builds the
inspectable formula x stratum x subset plan, and
[`fit()`](https://generics.r-lib.org/reference/fit.html) executes it.

Fail softly: a failed fit becomes a recorded error —
`fit_status = FALSE` with the message in the model table, a warning plus
the condition object in raw mode — and
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
skips unfit rows.

Support mixed models through the random-effects role:
`fit(f, .fn = lme4::lmer, ...)` works directly (and any parsnip
mixed-model engine works through the spec path), tidied by
[broom.mixed](https://github.com/bbolker/broom.mixed).

Correct `degrees_freedom` per model family
([`df.residual()`](https://rdrr.io/r/stats/df.residual.html) with a
`nobs - coef` fallback). Decision on `var_cov`: it stays, because
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
needs the exposure-product covariance without the original data (see
DESIGN.md).

## Milestone 5 — The collection (`mdl_tbl`)

*The notebook of models: storage, recall, and combination must be
trustworthy before the table layer can be.*

> Note: M4 already delivered part of this milestone’s groundwork —
> `mdl_tbl` gained a `subset` provenance column, and `fit_status` now
> truthfully reflects failed fits.

Fix attribute reconciliation when combining tables: `mdl_tbl_cast()`
must carry `dataList` through, and combined formula matrices/term tables
must deduplicate correctly (issue \#26), with tests that bind tables
from different datasets.

Complete `dplyr` verb support with tests for `filter`, `select`,
`mutate`, `arrange`, `bind_rows`, and the invariant-column messaging
(issue \#23).

Settle the naming convention across the package — one canonical public
name per class, with the other kept as a documented alias
(e.g. [`model_table()`](https://shah-in-boots.github.io/mesa/reference/mdl_tbl.md)
canonical,
[`mdl_tbl()`](https://shah-in-boots.github.io/mesa/reference/mdl_tbl.md)
alias) — and state the convention in the design note.

Rework
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
exponentiation: infer sensible defaults from the model family (binomial
`glm`/`coxph` exponentiate; `lm` does not) rather than the by-name
`which=` argument, keeping an explicit override.

Run
[`validate_model_table()`](https://shah-in-boots.github.io/mesa/reference/validate_model_table.md)
on construction, document the invariant columns, and improve the
warnings around construction (issues \#18, \#46).

Prune `validation.R` of code referring to retired classes
(`model_archetype`) so validation reflects the real object model.

## Milestone 6 — The table grammar (the mesa itself)

*The destination: a grammar for laying out multiple models in
publication tables, built on [gt](https://gt.rstudio.com).*

Write the table grammar as a specification before refactoring code: rows
are terms and their levels; columns are statistics (beta, confidence
interval, n, p); spanners are models, adjustment sets, or outcomes; row
groups are strata or subgroups. This one page governs every `tbl_*`
function (issues \#47, \#48).

Extract the shared pipeline from the four monoliths into composable
internal steps: select models → flatten → format estimates → lay out
rows/columns → hand to [gt](https://gt.rstudio.com); each `tbl_*`
function becomes a thin recipe over these steps.

Standardize the labeled-formula argument handling
([`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md))
as the single documented mechanism for variable-plus-label input across
all table functions.

Replace the skipped private-data tests (AFEQT, CARRS) with public-data
equivalents (`mtcars`,
[`survival::lung`](https://rdrr.io/pkg/survival/man/lung.html),
simulated data) so the table layer is actually covered (currently:
`test-gt-beta.R`, `test-gt-forest.R`, `test-gt-survival.R` skips).

Stabilize the hazard tables (`tbl_dichotomous_hazard`,
`tbl_categorical_hazard`), including the unfinished
`rate_difference`/`person_years` machinery (issue \#30).

Stabilize `tbl_interaction_forest` and generalize
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
beyond binary interaction terms (categorical levels, per the TODO in
[interaction.R](https://shah-in-boots.github.io/mesa/R/interaction.R)).

Snapshot tests on rendered `gt` structure so table regressions are
visible in review.

## Milestone 7 — Telling the story

*Documentation that teaches the grammar, and a clean release.*

One vignette per layer, in order: terms and causal roles; formulas and
patterns; playing with data (strata, subsets, random effects); fitting
and model tables; making the mesa (the [gt](https://gt.rstudio.com)
layer).

Rewrite the README around a single narrative arc — one dataset, one
causal question, terms to table — so the first impression is the
grammar, not the class list.

Update the development-log article to reflect this blueprint and the
current design.

A vignette or article on the causal reasoning itself: how roles map to
the estimands (total effect, direct effect, effect modification), with
references (Hill, Pearl, VanderWeele) — this is the intellectual home of
the package.

NEWS.md brought current; `cran-comments.md` refreshed; R CMD check clean
on all platforms; CRAN submission.

# The Horizon

Ideas that belong to the vision but should not block the milestones
above. Parked here so they are not lost.

- **DAG integration**: derive adjustment sets from a
  [dagitty](https://www.dagitty.net)/[ggdag](https://github.com/r-causal/ggdag)
  graph and hand them to
  [`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md) as
  a pattern — the causal diagram becomes the formula generator.
- **Effect modification workflows**: build outward from
  [`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
  toward a fuller effect-measure-modification toolkit (additive vs
  multiplicative scales, RERI).
- **Model diagnostics against attached data**: since `mdl_tbl` can hold
  its datasets, residual and assumption checks could be recalled per
  model.
- **Sensitivity analyses**: E-values and unmeasured-confounding checks
  as a natural extension of the role system.
- **Marginal effects**: interoperate with
  [marginaleffects](https://marginaleffects.com/) for estimands beyond
  coefficients.

# How to Use This Document

1.  Work is drawn from the earliest milestone with unchecked boxes; a
    subtask is one branch/PR.
2.  Every behavioral change lands with tests; bugs listed above get
    regression tests referencing this document.
3.  When a design decision is made (naming, role representation, verb
    API), record it here — a short “Decisions” note under the relevant
    milestone beats a lost conversation.
4.  When the direction changes, change this document first, then the
    code.
