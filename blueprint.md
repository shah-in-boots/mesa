# The `{mesa}` Blueprint

This document is the guiding map for the development of `{mesa}`.
It exists because the package grew organically — class by class, problem by problem — and it deserves a deliberate architecture that matches its original intent.
Each milestone below is broken into incremental subtasks that can be picked up, completed, and checked off one at a time.
This document is the source of truth for direction; GitHub issues should be triaged against it, and it should be revised as thinking evolves.

# Intent

`{mesa}` is about modeling for epidemiology and causality assessment in a user-friendly way.
It is built from an epistemological perspective: small building blocks that build up to more complex concepts.
It starts with individual model terms, expands as they join and merge into formulas, which can then be fit or combined together, and then tested against different datasets or with different modeling approaches.
The destination is a *grammar* for presenting multiple models in tables for papers, built on top of `{gt}` — which is why the package is called `mesa` (the table upon which the models are laid out).

The feeling the package should give is *fluidity* — being able to pick terms up from a dataset and "play" with the modeling: swap strata, add random effects, subset the data, roll an interaction through, and watch the family of models unfold.
The causal perspective is what makes this different from general-purpose modeling tools: variables have *roles* (exposure, outcome, confounder, mediator, interaction, strata), and those roles carry meaning that shapes how formulas expand, how models are fit, and how results are displayed.

I am not building something that already exists.
Where the ecosystem already solves a problem — `{tidymodels}` and `{parsnip}` for universal model definitions, `{broom}` for tidying, `{gt}` for table rendering — `{mesa}` should lean on it rather than reinvent it.

# The Grammar

The package is organized as layers, each built from the one below it.
This is the epistemology of the package, and the file structure, documentation, and vignettes should all follow it.

| Layer | Class | Metaphor | Question it answers |
| --- | --- | --- | --- |
| 1. Terms | `tm` | atoms | What is this variable, and what role does it play? |
| 2. Formulas | `fmls` | molecules | How do terms combine, and by what pattern do they expand? |
| 3. Models | `mdl` | reactions | What happens when a formula meets data and a fitting approach? |
| 4. Collections | `mdl_tbl` | notebook | How do I store, recall, and compare many models? |
| 5. Tables | `mesa` | the mesa | How do I lay the models out for a paper? |

# Where Things Stand

An honest accounting, as of the July 2026 review.
The test suite passes (with 10 skips), the core pipeline works for the `lm`/`glm`/`coxph` cases, and the layered concept is sound.
But the implementation has drifted from the intent in several places.

> **Revision note (July 2026):** Milestones 0 through 5 are complete.
> Every defect listed below is fixed with a regression test, and the structural debts in the term, formula, fitting, and collection layers are paid down (the `gt` layer debts remain for Milestone 6).
> Design decisions made along the way are recorded in [DESIGN.md](DESIGN.md).
> R CMD check runs clean (0 errors, 0 warnings, 0 notes).

**What works well:**

- The role vocabulary and formula shorthand (`.o()`, `.x()`, `.c()`, `.m()`, `.i()`, `.s()`, `.g()`) — this is the soul of the package and the idea is right.
- The pipeline `fmls() |> fit() |> model_table() |> flatten_models()` runs end-to-end.
- The `vctrs`-based class scaffolding gives principled vector behavior.
- Stratified fitting (`.s()`) already produces one model per stratum level, which is exactly the "play" feeling to build on.

**Known defects (found on review; all but one fixed in Milestones 0–4):**

- ~~`apply_parallel_pattern()` subsets grouped covariates with `group == 0L` instead of `group == g`, so only tier-0 groups are ever collected.~~ *Fixed in M2 with a two-tier regression test.*
- ~~`fit.fmls()` recovers `.fn` positionally via `match.call()[[3]]`, which breaks when arguments are supplied in a different order.~~ *Fixed in M4; `.fn` resolves by name and accepts a function, string, or `{parsnip}` spec.*
- ~~`apply_rolling_interaction_pattern()` is an unfinished stub that returns the outcome/exposure grid without rolling anything.~~ *Removed in M2; it returns as a registered pattern when it can be done properly.*
- ~~`mdl_tbl_cast()` drops the `dataList` attribute when combining tables — this is the root of issue #26 ([model-table.R](R/model-table.R)).~~ *Fixed in M5; combination reconciles all three attributes, with cross-dataset tests.*
- ~~`lifecycle::badge()` is used throughout the documentation but `{lifecycle}` is not declared in `DESCRIPTION`.~~ *Fixed in M0.*
- ~~Group tiers only parse a single digit (`.g1` through `.g9`), and `.transformations` supports only `log`.~~ *Fixed in M1; multi-digit tiers and a fuller transformation vocabulary.*
- ~~`degrees_freedom` is computed as `nrow - ncol - 1` for every model family, which is not correct outside of `lm`.~~ *Fixed in M4 via `df.residual()` with a per-family fallback.*
- *(Found during M1)* ~~The documented `am ~ c("Manual", "Automatic")` labeling idiom deparsed to a junk string in `labeled_formulas_to_named_list()`.~~ *Fixed; vector values now evaluate properly across all table functions.*

**Structural debts:**

- ~~The `tm.formula()` parser walks `all.names()` positionally rather than the formula AST, making it fragile and hard to extend (it is also ~370 lines in one function).~~ *Paid down in M1: a recursive AST walk in named helpers, with round-trip property tests.*
- ~~The supported models (`.models`), patterns (`.patterns`), roles (`.roles`), and transformations (`.transformations`) are frozen into `sysdata.rda` — closed vocabularies where extensible ones are wanted.~~ *Paid down in M1/M2: vocabularies live in `R/vocabulary.R` with accessors, and patterns are an open registry.*
- The `gt` layer (`tbl_beta`, `tbl_dichotomous_hazard`, `tbl_categorical_hazard`, `tbl_interaction_forest`) is four monoliths with duplicated filtering/formatting logic, and its meaningful tests are skipped because they depend on private datasets (AFEQT, CARRS). *Still open — this is Milestone 6. The private-data tests moved to `tests/manual/` so the automated suite and R CMD check stand on their own.*
- ~~Naming is split between abbreviated and spelled-out forms (`mdl_tbl` vs `model_table`, `fmls`, `tm`) without a stated convention.~~ *Decided in M5: spelled-out functions are canonical, abbreviated aliases and class names remain (see DESIGN.md).*
- ~~Repository hygiene: `sandbox.R` and `ex.R` sit at the top level, built vignette artifacts (`getting_started.html`, `.R`) are committed, `test-dev.R` is a placeholder, and `test-gt.R` is empty.~~ *Cleaned in M0.*
- ~~Random effects — explicitly part of the vision — have no representation at all yet.~~ *Built in M1–M4: the `.r()` role, `(1 | id)` parsing and rendering, and fitting through `{lme4}`.*

# Design Principles

These are the rules to check every change against.

1. **Roles are causal, and roles are first-class.** A term's role should be knowable, updatable, and should visibly change behavior downstream (expansion, fitting, display).
2. **Each layer only speaks to its neighbors.** Terms know nothing of models; tables consume model collections, not raw fits.
3. **Fluidity over ceremony.** The common path — terms from a dataset, snapped into formulas, fit, tabled — should read as a single pipe with no bookkeeping.
4. **Leverage, don't reinvent.** `{parsnip}` defines models, `{broom}` tidies them, `{gt}` renders tables. `{mesa}` contributes the causal grammar that connects them.
5. **Everything round-trips.** `formula -> tm -> fmls -> formula` should be lossless; a `mdl_tbl` should be able to reconstruct the context of any model it holds.
6. **Fail softly in batches.** When fitting twenty models, one failure should mark `fit_status = FALSE`, not sink the fleet.

# Milestones

Each milestone is scoped so its subtasks are roughly PR-sized.
Work top to bottom within a milestone; milestones 1–2 should land before 3–4, but 0 can be interleaved anywhere.
Every subtask that touches behavior should carry tests.

## Milestone 0 — Clear the workbench ✅

*Housekeeping so the real work is unobstructed.*

- [x] Move `sandbox.R` and `ex.R` out of the package root (`ex.R` became `inst/examples/interaction-forest.R`; `sandbox.R` referenced private data and a function that no longer exists, so it was deleted).
- [x] Remove committed build artifacts: `vignettes/getting_started.html`, `vignettes/getting_started.R`.
- [x] Add `{lifecycle}` to `DESCRIPTION` (badges are already in use).
- [x] Delete the placeholder `test-dev.R` and empty `test-gt.R`.
- [x] Review PR #72 (testthat 3.3.0 compatibility) — its fix already exists on `main`, so the PR is superseded and can be closed on GitHub.
- [x] Audit `Imports`: `{ggplot2}` and `{scales}` stay (the forest layer is core); `{survival}` moved to `Suggests` behind `requireNamespace()` guards. Reasoning recorded in [DESIGN.md](DESIGN.md).
- [x] Organize the `_pkgdown.yml` reference index by grammar layer (validated with `pkgdown::check_pkgdown()`).
- [x] Triage all open GitHub issues against this blueprint (map below). Labeling/closing on GitHub itself remains a by-hand step.

**Issue triage map:**

| Issue | Where it landed |
| --- | --- |
| #5 (level argument for `tm`) | Done in M1 — the `level` field |
| #6 (Terms) | Done in M1 — role taxonomy spec and parser rewrite |
| #18, #46 (`mdl_tbl` construction and warnings) | Done in M5 — validation, rejection of raw fits, the status print/summary |
| #23 (dplyr verb support) | Done in M5 — verbs reconcile attributes, with invariant messaging |
| #25 (formula shorthand requests) | Decided in M1/M2 — see DESIGN.md; close after review |
| #26 (combining tables loses attributes) | Done in M5 — reconciliation on combine and subset |
| #30 (hazard tables) | Milestone 6 |
| #42 (merging formulas with special terms) | Done in M2 — `c()` with collision messaging |
| #47, #48 (`gt` implementation and beta tables) | Milestone 6 |
| PR #72 (testthat 3.3.0) | Superseded — already fixed on `main`; close |

## Milestone 1 — Terms are the atoms (`tm`) ✅

*A term should carry its causal identity reliably; the parser should be trustworthy enough to build everything else on.*

- [x] Write the role taxonomy down as a specification: the Roles table in `R/terms.R` now gives each role its causal definition *and* the downstream behavior it changes (issue #6).
- [x] Decide the representation for random effects and data subsets: random effects became the `.r()` role (side `meta`, rendering as `(1 | term)`, with lme4-native syntax parsed too); subsets are deliberately **not** a role — they are `fmls` instructions via `subset_data()`. Decision recorded in [DESIGN.md](DESIGN.md).
- [x] Rewrite the `tm.formula()` parser as a recursive walk of the formula AST (`collect_formula_terms()` plus named helpers for demotion, interaction expansion, defaults, and overrides). Nested runes like `.x(log(x))` now work.
- [x] Fix group tier parsing to accept multi-digit tiers (`.g10`) and clean up the interaction/grouping bookkeeping.
- [x] Open the transformation vocabulary (log family, `sqrt`, `scale`, `factor`, `ordered`, polynomial/spline markers), and move the vocabularies out of `sysdata.rda` into `R/vocabulary.R` with `term_roles()` / `term_transformations()` accessors.
- [x] Add the `level` field for categorical terms (issue #5); filled by `set_data()` or `update()`.
- [x] Simplify `format.tm()` to a role → color lookup (`.role_colors` in `R/vocabulary.R`).
- [x] Property-style round-trip tests in `test-roundtrip.R`: plain formulas, role shortcuts, opaque calls, meta terms, and random effects.

## Milestone 2 — Formulas as composition (`fmls`) ✅

*Formulas are terms joined by rules; patterns are the rules, and they should be a small open grammar rather than a closed switch statement.*

- [x] Document the internal representation (formula matrix + term table + instructions) in [DESIGN.md](DESIGN.md).
- [x] Fix the parallel-pattern grouping bug (`group == 0L` → `group == g`) with a regression test using two grouped tiers.
- [x] Turn patterns into a registry: `register_pattern()` adds any `tm -> tibble` function by name, `formula_patterns()` lists them, and `fmls()` looks them up — with a test registering a user-defined pattern.
- [x] Remove the `apply_rolling_interaction_pattern()` stub; it returns as a registered pattern when it can be done properly.
- [x] Define formula combination semantics (issue #42): `c()` and `vec_c()` merge families; conflicting term definitions resolve left-most-wins with an explicit message.
- [x] Document the mediation triad (total effect, mediator model, direct effect) in the `fmls()` Mediation section.
- [x] Un-skip and repair the `fmls`/`formula` interchange test — both directions plus casting now round-trip.
- [x] Address the formula shorthand requests (issue #25): `.r()` and multi-digit tiers added; a `.f()` subset rune declined (see DESIGN.md).

## Milestone 3 — Fluency: playing with terms against data ✅

*This is the milestone that makes the package feel the way it is supposed to feel: pick terms up off a dataset and play.*

- [x] Grow the data-classification helpers into a "meet the data" step: `set_data(x, data)` (methods for `tm` and `fmls`) stamps `type`, `distribution`, and `level`s onto terms, classifying transformed terms from their underlying variable.
- [x] Design and implement the fluent verb layer on `fmls` (`R/fluency.R`): `add_strata()`, `remove_strata()`, `add_terms()`, `remove_terms()`, `swap_outcome()`, `subset_data()` — each pipeable, each returning a modified family. Extending them to `mdl_tbl` waits for Milestone 5.
- [x] Make strata data-aware: after `set_data()`, the print method shows `strata: am (2 levels)` before anything is fit.
- [x] Implement data subsets as first-class instructions: `subset_data(f, am == 1, cyl > 4)` records quosures on the family; [fit()] fits once per subset, and the subset lands as provenance in the model table.
- [x] Implement the random-effects role through the formula layer: `y ~ .x(x) + .r(id)` composes, prints, and rebuilds as `y ~ x + (1 | id)`.
- [x] Give `fmls` a print worthy of play: the deck header summarizes formula count, outcomes, exposures, mediators, interactions, strata (with levels), random effects, and subsets.

## Milestone 4 — Fitting through a universal interface ✅

*Stop maintaining a whitelist of model functions; let `{parsnip}` define what a model is, and keep a plain-function escape hatch.*

- [x] Fix the positional `.fn` capture in `fit.fmls()`: `.fn` now resolves by name and accepts a function, a string, or a parsnip spec, with a regression test that scrambles argument order.
- [x] Accept `{parsnip}` model specifications in `fit()`; the `.models` whitelist is retired (it survives only as documentation) and the engine's identity flows into `model_call`.
- [x] Refactor into plan-then-execute: `fit_plan(object, data)` builds the inspectable formula x stratum x subset plan, and `fit()` executes it.
- [x] Fail softly: a failed fit becomes a recorded error — `fit_status = FALSE` with the message in the model table, a warning plus the condition object in raw mode — and `flatten_models()` skips unfit rows.
- [x] Support mixed models through the random-effects role: `fit(f, .fn = lme4::lmer, ...)` works directly (and any parsnip mixed-model engine works through the spec path), tidied by `{broom.mixed}`.
- [x] Correct `degrees_freedom` per model family (`df.residual()` with a `nobs - coef` fallback). Decision on `var_cov`: it stays, because `estimate_interaction()` needs the exposure-product covariance without the original data (see DESIGN.md).

## Milestone 5 — The collection (`mdl_tbl`) ✅

*The notebook of models: storage, recall, and combination must be trustworthy before the table layer can be.*

> Note: M4 already delivered part of this milestone's groundwork — `mdl_tbl` gained a `subset` provenance column, and `fit_status` now truthfully reflects failed fits.

- [x] Fix attribute reconciliation when combining tables: `mdl_tbl_cast()` carries `dataList` through, formula matrices stay row-parallel to the table, and term tables deduplicate left-most-wins (issue #26), with tests that bind tables from different datasets. `model_table(x, y)` combines tables directly.
- [x] Complete `dplyr` verb support with tests for `filter`, `select`, `mutate`, `arrange`, `bind_rows`, `[`, and the invariant-column messaging (issue #23). Subsetting now prunes attributes from the roles the remaining rows claim (the stale-strata TODO); `bind_rows` across unrelated tables downgrades loudly (dplyr strips attributes before reconstruction — see DESIGN.md) and points to `model_table()`.
- [x] Settle the naming convention across the package: spelled-out names canonical for the public API (`model_table()`), abbreviated forms kept as documented aliases (`mdl_tbl()`) and class names. Recorded in [DESIGN.md](DESIGN.md).
- [x] Rework `flatten_models()` exponentiation: inferred from the model family/link (`coxph` and log/logit GLMs exponentiate; `lm` does not) with an `exponentiated` marker, keeping `exponentiate =` and `which =` as explicit overrides. `mdl()` now records the link function to support the inference.
- [x] Run `validate_model_table()` on construction, document the invariant columns (`?model_table`), and improve the warnings around construction — raw fitted models are rejected with directions (issues #18, #46). The `mdl_tbl` print now leads with fitted/failed/unfit status, data attachment, and next-step hints; `summary()` maps the fleet; `model_failures()`, `term_table()`, `formula_matrix()`, and `model_data()` round out the helper set.
- [x] Prune `validation.R` of code referring to retired classes (`model_archetype`) so validation reflects the real object model.

## Milestone 6 — The table grammar (the mesa itself)

*The destination: a grammar for laying out multiple models in publication tables, built on `{gt}`.*

> **Decisions (July 2026, recorded in [DESIGN.md](DESIGN.md)):** the table layer is a **composition-first grammar**.
> A bare `mesa()` constructor lifts a `mdl_tbl` onto an inspectable table specification; small pipeable verbs narrow the selection, add columns, and adjust styling — in any order, each with a sensible default when unset; `as_gt()` renders.
> The user grows a table iteratively the way a `{ggplot2}` plot is grown (staying with the pipe, not `+`), and is never asked for more than one decision per verb.
> **The grammar is the deliverable and the only committed API** (revised July 2026): the old `tbl_*` monoliths are not end-points — their table *shapes* survive as the named layout presets (`"adjustment"`, `"levels"`, `"interaction"`), and the functions themselves are deprecated or deleted in 6.7/6.9 with no signature-compatibility work.
> Attached data (`attach_data()`) is the canonical source for every data-derived statistic; forest plots are a column type, not a separate family.

### The shape of the grammar

Every table is the same five stages; the four monoliths differ only in which options they pick at each stage.
Each stage becomes a pure internal function, and every preset is a path through them:

```
mdl_tbl --select--> model rows --decorate--> labeled estimates --compute--> statistics
                                             --layout--> cell frame --render--> gt
```

1. **Select** — which models (outcomes, exposures, adjustment sets, strata) and which terms, chosen by labeled formulas.
2. **Decorate** — join each estimate row with its term metadata: role and label from the term table, factor levels and reference level from the attached data, `level_labels` overrides.
3. **Compute** — optional statistics beyond the coefficients: n, events and rates by person-years, rate differences, interaction effect estimates.
4. **Layout** — assign content to the four axes and reduce to the *cell frame*, a tidy tibble with one row per table cell (`row_key`, `column_key`, `group`, `spanner`, `value`, `fmt`).
5. **Render** — translate the cell frame into `{gt}` calls; nothing before this stage touches `{gt}`.

The four axes (this vocabulary governs every table; issues #47, #48):

| Axis | Holds | Examples |
| --- | --- | --- |
| rows | terms and their levels, or adjustment sets, or interaction levels | the `"adjustment"` preset puts adjustment sets on rows; the `"levels"` preset puts term levels on columns and statistics rows below |
| columns | statistic blocks | estimate, confidence interval, p, n, events, rate, rate difference, forest |
| spanners | groupings of columns | a term and its levels; a model family; an outcome |
| row groups | groupings of rows | outcomes, strata, subgroups, interaction terms |

The `<mesa>` specification object is **declarative**: it carries instructions, not results — `selection` (which models and terms, recorded by the `select_*` verbs), `labels` (term, level, and column relabelings), `columns` (an ordered list of column *blocks*, each with its type, statistics, labels, and format), `layout` (the axis assignment), and `style` (accents, digits, missing text).
Resolution — running the selection against the `mdl_tbl`, decorating with metadata, computing data statistics — happens when the spec is *realized* by `print()` or `as_gt()`, which is what makes verb order irrelevant and late overrides cheap.

The verb families:

| Family | Verbs | What they do |
| --- | --- | --- |
| construct | `mesa(object)` | bare: everything fitted goes on the mesa, labeled by defaults |
| select | `select_outcomes()`, `select_exposures()`, `select_terms()`, `select_adjustment()`, `select_strata()` | narrow what is shown; labeled-formula input, so selecting and labeling are one gesture |
| relabel | `modify_labels()` | rename terms, levels, or columns late, without reselecting (absorbs the old `level_labels` argument) |
| columns | `add_estimates()`, `add_n()`, `add_events()`, `add_rate_difference()`, `add_interaction()`, `add_forest()` | append column blocks (the `{gtsummary}` precedent) |
| arrange | `modify_layout()`, `modify_style()` | axis assignment; accents, digits, missing text |
| realize | `as_gt()`, `print()` | render; preview the pending specification |

Composition rules: every verb is optional and defaults sensibly (a bare `mesa(mt) |> as_gt()` renders estimate + CI for everything fitted); verbs may arrive in any order; repeating a verb replaces its earlier instruction with a message (the `{ggplot2}` scale-replacement behavior).
So iteration looks like:

```r
mt |> mesa()                                          # look at what's on the mesa
mt |> mesa() |> select_outcomes(death ~ "Death") |>   # narrow as you go
  select_adjustment(1 ~ "Unadjusted", 3 ~ "+ Demographics") |>
  add_estimates(list(beta ~ "HR", conf ~ "95% CI")) |>
  add_events(followup = time) |>
  modify_labels(smoking ~ "Smoking status") |>        # rethink a label late
  as_gt()
```

The constructor is named `mesa()` — laying models on the mesa is the package's namesake act — and not `tbl()`, which would collide with `dplyr::tbl()`.

File layout as the work lands: `R/table-spec.R` (constructor, print, validation), `R/table-columns.R` (the `add_*` verbs), `R/table-render.R` (`as_gt()`, the only file importing `{gt}` layout functions), `R/table-presets.R` (the layout presets and, while they last, the deprecated `tbl_*` shims); `R/gt.R` keeps the shared argument documentation and `theme_gt_compact()`; `gt-beta.R`, `gt-survival.R`, and `gt-forest.R` retire as the presets reproduce their tables.

### Defects found on review (July 2026)

Carried into the subtasks below rather than patched in place, so each fix lands inside the stage that owns it:

- Term and outcome filtering uses `grepl()` substring matching throughout, so term `am` also selects `gam`, and `wt` selects `wt2`; `estimate_interaction()` likewise takes "first grep match" positions. *(fixed by 6.2, 6.9)*
- The hazard tables flatten with `exponentiate = FALSE` and never exponentiate, yet label the column `HR (95% CI)` — the displayed values are log-hazards. *(fixed by 6.4's inference default)*
- The rate-difference confidence interval uses `qnorm(0.9725)` where a 95% interval needs `qnorm(0.975)`, and the `person_years` argument is ignored (person-years are hard-coded `/ 100`). *(fixed by 6.5)*
- `tbl_categorical_hazard()` gates rate differences on `length(levels(dat[[t]]) == 2)` — a precedence bug that is truthy for any level count. *(fixed by 6.5)*
- `tbl_interaction_forest()`'s `invert` argument is dead code (`if (FALSE)`). *(fixed by 6.8)*
- `tbl_beta()` accents only recognize a `p <` criterion and ignore the instruction side (bold is hard-coded). *(fixed by 6.6)*
- Adjustment sets are selected by the `number` column, which is the raw term count — two models in a family with the same term count collide. *(fixed by 6.2)*

### Subtasks

Order: 6.1 → 6.2 → 6.3 are sequential; 6.4 and 6.5 are independent once 6.3 lands; 6.6 needs 6.4; 6.7 needs 6.6; 6.8 and 6.9 build on 6.6; 6.10 rides along every PR with a closing sweep.

- [x] **6.1 Write the grammar specification (one page, in DESIGN.md).**
  Done — see "The table grammar specification (M6.1)" in [DESIGN.md](DESIGN.md). It fixes the four axes (rows, row groups, columns, spanners), the cell frame (the long tibble `as_gt()` consumes), the statistics vocabulary with its attached-data requirements, and the three launch presets (`"adjustment"`, `"levels"`, `"interaction"`) with the combinations that error and those deferred past launch.
  One correction landed while writing it: for categorical terms, the **levels are the columns and the term label is their spanner** (the shorthand "term levels as column spanners" above was imprecise) — the DESIGN.md axes table is the authority.
  Revised on the July 2026 follow-up review, in three places: **(1)** the cell frame gained `row_scope` (`"row"`/`"group"`), so a statistic computed *across* a term's levels — the interaction p-value that visually floats between two level rows in the old forest table — is first-class data rather than the duplicate-and-white-out hack; **(2)** the forest block was pinned down as **render-time** — forest cells hold plain numbers, the shared x-scale is a column property resolved across all its cells, the bottom axis strip is a reserved `.axis` row sorted last, and the block's dense-padding/borderless look enters as style *defaults* `modify_style()` can override — so adding a forest column never changes any other cell; **(3)** the presets were decoupled from the `tbl_*` function names — the shapes are committed, the functions are not.
- [x] **6.2 The selection resolver.**
  Done — `resolve_selection()` in [table-selection.R](R/table-selection.R) is the shared engine: it filters a `mdl_tbl` by outcome, exposure, strata, and adjustment set (exact membership against the provenance columns), and resolves requested terms to the exact tidy-term keys they cover. Term levels (`cyl6`, `cyl8`) resolve through the term table's variable–level relationship — stamped from the attached data via `set_data()`, since the fit pipeline leaves levels empty — so a categorical term expands to its bare name plus one key per non-reference level, and `match_term_keys()` maps tidy names back to variables by identity. Adjustment-set identity is the *sequential model index* within an outcome × exposure (× strata × subset × data) family (`family_adjustment_index()`), ordered by adjustment degree with row-order tie-breaking, so colliding term counts stay distinct.
  All selection input flows through one mechanism (`selection_input()` → `labeled_formulas_to_named_list()`); unresolvable selections error clearly rather than half-working.
  Tests in [test-table-selection.R](tests/testthat/test-table-selection.R) cover the adversarial names (`am`/`gam`, `wt`/`wt2`), categorical level resolution, colliding term counts, per-stratum adjustment numbering, order-independence, and the error paths.
- [x] **6.3 The `<mesa>` specification, constructor, and selection verbs.**
  `mesa(object)` is deliberately bare: it validates — `mdl_tbl` only, fitted rows only, a single model family per table (error), a single dataset (message) — and puts everything fitted on the mesa with default labels from the term table and attached data.
  The `select_*` verbs and `modify_labels()` record instructions on the spec; because resolution is deferred to realization, they compose in any order and a repeated verb replaces its instruction with a message.
  Realization decorates the selected rows with role, label, level, and reference-level metadata, and injects reference rows for categorical terms (generalizing `tbl_beta`'s `_ref` logic); data-derived metadata comes from the `dataList`, and when it is missing the error points to `attach_data()`.
  `print()` shows what is on the mesa — the models, the declared axes, the column blocks so far — so iterating means printing, adjusting one verb, printing again.
  `as_gt()` on a bare spec renders a minimal default table (estimate + CI), so the grammar is usable from the first verb.
  Tests assert order-independence: any permutation of the same verbs realizes to the same table.
  Done — the `<mesa>` object and its five declarative slots (`selection`, `labels`, `columns`, `layout`, `style`) live in [table-spec.R](R/table-spec.R) with the constructor, the five `select_*` verbs, `modify_labels()`, and `print()`; realization and the minimal renderer live in [table-render.R](R/table-render.R). `mesa()` lays only the fitted rows out, errors on a mixed model family, and messages on more than one dataset. The verbs record raw labeled-formula instructions and defer every lookup to `realize_mesa()`, which runs the M6.2 resolver, flattens on the inferred scale, decorates each estimate with its term metadata, and injects one reference row per categorical term per model context. `as_gt()` renders the bare default (estimate + CI, adjustment rows, outcome groups) through an interim `render_minimal()`; the full cell-frame renderer is 6.6. The decision is recorded in "The `<mesa>` specification (M6.3)" in [DESIGN.md](DESIGN.md); tests in [test-table-spec.R](tests/testthat/test-table-spec.R) cover the validation gates, order-independence (permuted verbs realize to identical frames), reference-row injection, lazy error surfacing, `modify_labels()`, and the bare render.
- [x] **6.4 Model-statistic columns.**
  `add_estimates(columns = list(beta ~ ..., conf ~ ..., p ~ ...), exponentiate = NULL, digits = 2)`: estimate/CI/p blocks, with exponentiation deferred to the M5 family inference by default (this is what corrects the hazard-scale defect); `add_n()` from the recorded `nobs`.
  Each verb appends a column block of instructions; computation and formatting happen at realization, and re-calling a verb replaces its block with a message.
  Done — the verbs live in [table-columns.R](R/table-columns.R) and record blocks on the spec's `columns` slot; the interim renderer consumes them (statistic choice, merged `beta (conf)` headers, a `p` column, block digits, the `n` column from the recorded `nobs`), and `realize_mesa()` passes the block's `exponentiate` through to `flatten_models()` — `NULL` defers to the M5 inference, which is the hazard-scale correction. An explicit `add_estimates()` shows its statistic labels as headers with the term label as spanner; the bare default keeps the compact term-label headers. `modify_labels(columns = )` overrides the headers late. Decision notes in "Model-statistic column blocks (M6.4)" in [DESIGN.md](DESIGN.md); tests in [test-table-columns.R](tests/testthat/test-table-columns.R) cover verb validation, block replacement, both exponentiation paths against hand-fit references, labels/digits reaching the render, order-independence, and the nested categorical spanners.
- [x] **6.5 Data-statistic columns.**
  `add_events(followup, person_years = 100)`: events and incidence rates per term level via `survival::pyears()` (Suggests-guarded) on the attached data, resolved through the models' `data_id`.
  `add_rate_difference(conf_level = 0.95)` completes issue #30: correct critical value (`qnorm(0.975)`), `person_years` honored, restricted to dichotomous terms by an actual level-count check. Rate difference is a *term-scoped* statistic (computed across two levels): in the `"levels"` layout it occupies its own column, per the group-scoped-cell rule in the 6.1 spec.
  There is no `data =` argument anywhere in the table layer — `attach_data()` is the single path, and every data-needing error points to it.
  Done — the verbs live in [table-columns.R](R/table-columns.R) with the *compute* stage (`compute_data_statistics()`) that `realize_mesa()` now runs after decoration: events and rates are stamped per term level (reference rows included), the rate difference per term, each dataset × outcome × term computed once through its `data_id`. The event indicator resolves from the outcome itself (a plain column, or the event argument of a `Surv()` outcome); `add_rate_difference()` reads the follow-up/person-years/scale recorded by `add_events()` and errors at realization without it, keeping the verbs order-independent. The interim renderer shows events and rates ahead of the estimates under each level and the rate difference as its own term-scoped column. All three issue-#30 defects have regression tests in [test-table-columns.R](tests/testthat/test-table-columns.R) against hand-computed `pyears()` references; decision notes in "Data-statistic column blocks (M6.5)" in [DESIGN.md](DESIGN.md).
- [ ] **6.6 The renderer.**
  `as_gt(x)`: reduce the column blocks and layout to the cell frame, pivot, and emit the `{gt}` calls — spanners, column merges by pattern, labels, stub indentation, alignment, missing text — in one place; `theme_gt_compact()` remains compatible.
  Two mechanisms live only here (per the 6.1 spec): group-scoped cells (`row_scope = "group"`) are emulated — `{gt}` has no body-cell rowspan — by writing the value into each row of its group, keeping exactly one visible and vertically centered on the band, and masking the duplicates (the old forest table's white-out trick, now documented in one place); and `type = "plot"` cells are drawn here from their numeric values, so a forest column shares one x-scale computed across all of its cells, with the reserved `.axis` row emitted last.
  `modify_style(accents, digits, missing_text)` generalizes the accents machinery: criteria on any statistic (`p < 0.05`, `estimate > 1`), instructions beyond bold (italic, color), applied at render.
- [ ] **6.7 The presets prove the grammar (the monoliths retire).**
  Reproduce the adjustment and hazard monoliths as plain grammar chains on public data (`mtcars`, `survival::lung`, simulated data): the `"adjustment"` chain for `tbl_beta()`, the `"levels"` chain for `tbl_dichotomous_hazard()`/`tbl_categorical_hazard()` — asserting content equivalence where the old outputs were right, and the corrected values where they were wrong (the HR scale). (The `"interaction"` chain closes in 6.9, once `add_interaction()` and `add_forest()` exist.)
  The chains land as documented examples (`?mesa`, the vignette seed), not as new functions: the `tbl_*` signatures are explicitly **not** a compatibility target. Once a chain reproduces its monolith, the corresponding `tbl_*()` is either deprecated with `{lifecycle}` pointing at its chain (the deprecation message is the migration doc) or deleted outright — decide per function here, biased toward deletion while the package is pre-release.
- [ ] **6.8 The forest column.**
  `add_forest(axis, width, options)` appends a column block available to any table, not just interaction tables; it errors unless `estimate` + `conf` are already in the spec, because its cells read them and compute nothing new.
  Per the 6.1 spec, the block is resolved at render: forest cells enter the cell frame as numbers (`type = "plot"`); `as_gt()` resolves the shared x-scale (limits, intercept, breaks, log vs linear) across the whole column with the block's `axis` options overriding the guesses, draws each cell via `gt::text_transform()` + `ggplot_image()`, emits the bottom axis strip as the reserved `.axis` row after all row groups, and applies the block's dense-padding/borderless style *defaults*, which `modify_style()` can override.
  Test the invariant this buys: adding or dropping `add_forest()` changes no other cell in the frame — only the forest column and the `.axis` row appear or disappear.
  Implement `invert` for real (reciprocal estimates, swapped interval bounds, mirrored axis) or remove the argument — today it is dead code behind `if (FALSE)`.
- [ ] **6.9 Interaction rows.**
  Generalize `estimate_interaction()` beyond binary interaction terms (categorical levels, per the TODO in [interaction.R](R/interaction.R)): per-level estimates from the variance–covariance matrix, exact term matching (no more first-`grep`-match positions), tests against hand-computed references.
  `add_interaction()` requires the `"interaction"` layout — it *defines* the rows (one per interaction level, grouped by interaction term) and errors under any other preset. Its statistics carry two scopes, distinct in the cell frame: the per-level cells (estimate/CI; per-level `n`, which needs attached data) are ordinary rows, while the single across-levels `p_value` is a **group-scoped cell** (`row_scope = "group"`) that the renderer floats over the level rows — the 6.1 spec's answer to the white-out hack in today's `tbl_interaction_forest()` (see [test-gt-forest.R](tests/testthat/test-gt-forest.R), which asserts the masked/aligned cells directly).
  The old forest table is then just the chain *`"interaction"` layout + `add_n()` + `add_estimates()` + `add_forest()`*; verify it here the way 6.7 verified the other two monoliths, then deprecate or delete `tbl_interaction_forest()` on the same terms.
- [ ] **6.10 Coverage and the closing sweep.**
  Snapshot tests on the **cell frame** for every preset and the bare default (cell frames are plain tibbles, so table regressions diff cleanly in review), plus a thin layer of rendered-`gt` structure checks; the skipped private-data tests (`test-gt-beta.R`, `test-gt-forest.R`, `test-gt-survival.R`) replaced by the public-data suites grown in 6.2–6.9; `tests/manual/` re-run against the new layer; `_pkgdown.yml` reference regrouped (grammar → column verbs → renderer → presets); NEWS.md entry.

## Milestone 7 — Telling the story

*Documentation that teaches the grammar, and a clean release.*

- [ ] One vignette per layer, in order: terms and causal roles; formulas and patterns; playing with data (strata, subsets, random effects); fitting and model tables; making the mesa (the `{gt}` layer).
- [ ] Rewrite the README around a single narrative arc — one dataset, one causal question, terms to table — so the first impression is the grammar, not the class list.
- [ ] Update the development-log article to reflect this blueprint and the current design.
- [ ] A vignette or article on the causal reasoning itself: how roles map to the estimands (total effect, direct effect, effect modification), with references (Hill, Pearl, VanderWeele) — this is the intellectual home of the package.
- [ ] NEWS.md brought current; `cran-comments.md` refreshed; R CMD check clean on all platforms; CRAN submission.

# The Horizon

Ideas that belong to the vision but should not block the milestones above.
Parked here so they are not lost.

- **DAG integration**: derive adjustment sets from a `{dagitty}`/`{ggdag}` graph and hand them to `fmls()` as a pattern — the causal diagram becomes the formula generator.
- **Effect modification workflows**: build outward from `estimate_interaction()` toward a fuller effect-measure-modification toolkit (additive vs multiplicative scales, RERI).
- **Model diagnostics against attached data**: since `mdl_tbl` can hold its datasets, residual and assumption checks could be recalled per model.
- **Sensitivity analyses**: E-values and unmeasured-confounding checks as a natural extension of the role system.
- **Marginal effects**: interoperate with `{marginaleffects}` for estimands beyond coefficients.

# How to Use This Document

1. Work is drawn from the earliest milestone with unchecked boxes; a subtask is one branch/PR.
2. Every behavioral change lands with tests; bugs listed above get regression tests referencing this document.
3. When a design decision is made (naming, role representation, verb API), record it here — a short "Decisions" note under the relevant milestone beats a lost conversation.
4. When the direction changes, change this document first, then the code.
