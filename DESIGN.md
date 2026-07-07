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
  [`model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
  turns that into `fit_status = FALSE`, and
  [`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
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

## Naming convention (M5)

Spelled-out names are canonical for the public API; abbreviated forms
are kept as documented aliases and as class names. So
[`model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
is the constructor
([`mdl_tbl()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
is its alias), the documentation topic is `model_table`, and helpers
spell things out
([`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md),
[`model_failures()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md),
[`term_table()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)).
The *classes* stay abbreviated (`tm`, `fmls`, `mdl`, `mdl_tbl`) because
they appear in pipes and prints where brevity reads better. The same
pattern already existed as
[`mdl()`](https://shah-in-boots.github.io/mesa/reference/models.md)/[`model()`](https://shah-in-boots.github.io/mesa/reference/models.md).

## The model table’s invariants (M5)

A `mdl_tbl` has seventeen invariant columns (see `model_table_columns()`
and the Invariant columns section of
[`?model_table`](https://shah-in-boots.github.io/mesa/reference/model_table.md)),
validated by
[`validate_model_table()`](https://shah-in-boots.github.io/mesa/reference/validate_model_table.md)
on every construction. Rows may be filtered and reordered and new
columns added, but removing or renaming an invariant column downgrades
the object to a plain `data.frame` with a message naming the loss.
Provenance columns are type-stable (`level` is stored as character;
`name`, `data_id`, `subset` as character;
`model_parameters`/`model_summary` as list columns even for unfit
formulas) so tables from different datasets always combine.

## Combining and reconciling model tables (M5, issue \#26)

The three scalar attributes (`formulaMatrix`, `termTable`, `dataList`)
are reconciled rather than copied:

- **The formula matrix stays parallel to the table rows** — row *i* of
  the matrix describes model *i*’s formula. `vec_ptype2()` merges both
  tables’ rows into the prototype (which is what `vec_rbind()`/`vec_c()`
  restore to), and `vec_cast()` keeps the cast table’s own rows widened
  to the union of terms, so the parity invariant survives combination in
  both directions. The data list survives the cast too (the original
  \#26 defect).
- **Term tables deduplicate by (term, role, side), left-most wins** —
  the same resolution, and the same reasoning, as combining `fmls`
  families (issue \#42).
- **Subsetting prunes from the roles the remaining rows still claim.**
  [`filter()`](https://rdrr.io/r/stats/filter.html), `arrange()`,
  `slice()`, and `[` rebuild the attributes around the surviving rows:
  matrix rows are matched by model `id` (so reordering keeps parity),
  special-role terms are kept only when a remaining row claims them in
  that role, plain covariates are kept only when a remaining formula
  uses them beyond its own outcome, random effects are carried whole
  (they live outside the matrix), and datasets are kept when referenced
  — plus any dataset attached deliberately without being referenced.
- **`bind_rows()` cannot combine unrelated tables** — dplyr strips
  attributes before `dplyr_reconstruct()` runs, so there is nothing left
  to merge. When the first table covers all the rows it reconciles
  normally; otherwise it returns a plain `data.frame` with a message
  pointing to `model_table(x, y)`, which combines tables properly.

## Flattening infers the estimate scale (M5)

[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
decides exponentiation per model instead of demanding a by-name `which=`
list:
[`mdl()`](https://shah-in-boots.github.io/mesa/reference/models.md)
records the family’s link function (`summaryInfo$model_link`), and
Cox-family models or GLMs on a `log`/`logit`/`cloglog` link come back
exponentiated (hazard/odds/rate ratios) while everything else stays
linear. The decision is reported in a message and an `exponentiated`
column; `exponentiate = TRUE/FALSE` overrides globally and `which=`
survives for name-based selection. Internal callers (the `gt` layer,
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md))
pin `exponentiate = FALSE` because they need coefficients on the linear
scale.

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

## The table grammar composes (M6)

Five decisions, made together at the start of M6 (the full specification
is subtask 6.1 and extends this entry):

- **Two-stage grammar.** An intermediate table-specification object sits
  between the model collection and the rendered table:
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa-package.md)
  constructs it, composable verbs refine it, `as_gt()` renders it. The
  constructor is named
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa-package.md)
  (the namesake act of laying models on the table), not `tbl()`, which
  would collide with
  [`dplyr::tbl()`](https://dplyr.tidyverse.org/reference/tbl.html).
  *Revised (July 2026):* the grammar is the deliverable and the only
  committed API. The `tbl_*` monoliths are **not** end-points to
  preserve — their table *shapes* survive as the named layout presets
  (`"adjustment"`, `"levels"`, `"interaction"`), while the functions
  themselves are deprecated or deleted in 6.7/6.9 with no
  signature-compatibility work. The earlier phrasing (“the one-shot call
  patterns keep working”) is withdrawn: tables are grown by iteration
  and composition, not pre-specified by recipe.
- **Composition over configuration.** `mesa(object)` takes no selection
  arguments; everything else arrives one decision at a time through
  pipeable verbs (`select_*`, `modify_labels()`, `add_*`, `modify_*`),
  each optional and each defaulting sensibly, so a table is grown
  iteratively the way a [ggplot2](https://ggplot2.tidyverse.org) plot is
  (staying with the pipe, not `+`). To make that safe, the spec is
  *declarative and lazily resolved*: verbs record instructions, and
  resolution against the `mdl_tbl` happens only when the spec is
  realized by [`print()`](https://rdrr.io/r/base/print.html) or
  `as_gt()`. Consequences: verb order is irrelevant, repeating a verb
  replaces its earlier instruction with a message (the ggplot
  scale-replacement behavior), and relabeling late never requires
  reselecting.
- **Attached data is canonical.** The `dataList` attribute of the
  `mdl_tbl` is the single source for data-derived statistics (events,
  person-years, per-level n, factor levels, reference levels). Table
  functions that need data and cannot find it error with a pointer to
  [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md).
  *Revised (July 2026):* with the recipes demoted, there is no `data =`
  argument anywhere in the table layer —
  [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  is the single path, and every data-needing error points to it.
- **Forest plots are a column type**, not a separate table family: any
  table specification can include a `forest` column block, and the
  interaction-forest shape reduces to *interaction rows + forest
  column*.
- **Verb naming follows the
  [gtsummary](https://github.com/ddsjoberg/gtsummary) precedent.**
  Column verbs use `add_*`; the remaining spec fields are adjusted by
  `modify_layout()` / `modify_style()`. *Revised (July 2026):* the
  earlier decision that “the recipe family keeps the `tbl_*` prefix” is
  moot now that the recipes are not a committed surface. If a one-call
  convenience ever proves worth shipping, it ships as a documented
  grammar chain (a preset plus column verbs), not as new `tbl_*` API.

## The table grammar specification (M6.1)

This is the one page that governs every verb, every preset, and every
rendered table. It fixes four things before any code is written: the
four axes, the cell frame, the statistics vocabulary, and the layouts
supported at launch. Everything downstream is an implementation of what
follows. (Revised on the July 2026 follow-up review: the cell frame
gained `row_scope`, the forest block was pinned down as render-time, and
the presets were decoupled from the `tbl_*` function names — the
individual revisions are marked below.)

A table is realized in five stages — *select → decorate → compute →
layout → render* — but only the last two need a precise contract,
because the first three feed a single object
([`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
output, decorated with term metadata) that the rest of the package
already defines. This spec pins down the **layout** (the four axes and
the cell frame it produces) and the **statistics** each column can
carry.

### The four axes

A publication regression table is a grid, and every cell has a place on
four axes. Two axes run vertically (rows, and the bands that group them)
and two run horizontally (columns, and the bands that span them):

| Axis | What occupies it | Drawn from |
|----|----|----|
| **rows** | one of: adjustment sets; term levels; interaction levels; named statistic rows | the sequential adjustment index within an outcome × exposure family; the term table `level` / data factor levels; [`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md) levels; literal names (“Events”, “Rate per 100 py”) |
| **row groups** | a labeled band grouping consecutive rows | `outcome`; `strata` + `level`; `interaction`; or none |
| **columns** | a statistic block for one term or term level | the statistics vocabulary (below) × the selected terms from the term table |
| **spanners** | a labeled band grouping consecutive columns | a term `label` (spanning its levels); an `outcome`; or none |

The recurring point of confusion, settled here: for a categorical term,
the **levels are columns and the term label is their spanner** — not the
other way around. (The blueprint’s shorthand “term levels as column
spanners” for the hazard layout is imprecise; this table is the
authority.)

### The cell frame

Every table reduces to one **cell frame**, and `as_gt()` consumes
nothing else. It is a long tibble, one row per *rendered cell* — that
is, per (row, displayed column) pair, where “displayed column” is a
single finished box (so an estimate-with-CI like `1.4 (1.1, 1.8)` is one
cell, not three):

| Field | Type | Meaning |
|----|----|----|
| `row_group` | chr | label of the row-group band (`NA` when ungrouped) |
| `row_key` | chr | the stub label of the row within its group; `NA` for a group-scoped cell; keys beginning with `.` are reserved rows contributed by column blocks (`.axis`) |
| `row_index` | int | order of the row within its group (`NA` for group-scoped cells) |
| `row_scope` | chr | `"row"` (the default) or `"group"` — a group-scoped cell belongs to the whole `row_group` band rather than to one row; see “Cells that span rows” below |
| `spanner` | chr | label of the column-spanner band (`NA` when none) |
| `column_key` | chr | stable identifier of the displayed column within its spanner (e.g. `smoking`, `cyl::cyl8`); never shown — used for pivot, ordering, merges, accents |
| `column_index` | int | order of the column |
| `column_label` | chr | the header shown for the column (a statistic name, a level label, or suppressed) |
| `value` | list | the cell’s raw content: a named list of the statistics that render *together* in this cell (`list(estimate =, conf_low =, conf_high =)`), or a single numeric/character. Always plain data — a `type = "plot"` cell holds the same named numeric list, never a built `ggplot`; plots are drawn at render (see “The forest block is resolved at render”) |
| `type` | chr | how the cell renders: `"numeric"`, `"text"`, `"reference"`, or `"plot"` |
| `format` | list | the cell’s format recipe: `digits`, a merge `pattern` (`"{estimate} ({conf_low}, {conf_high})"`), and any per-cell style override. `format` is constant within a `column_key` *except* for accents, which is exactly why it lives on the cell rather than the column. |

`as_gt()` is then mechanical and lives in one place: (1) expand each
named statistic inside `value` into a working column keyed
`column_key__stat` and pivot wide, with `row_group` → `groupname_col`
and `row_key` → `rowname_col`; (2) `fmt_number()` by `format$digits`;
(3) `cols_merge()` each `column_key`’s working columns back into one
displayed column via `format$pattern`; (4) `tab_spanner()` from
`spanner`, `cols_label()` from `column_label`; (5) apply accents and
theme. Because the canonical form is a tibble, testing a table is
testing a tibble — snapshot tests compare cell frames, not rendered HTML
(this is what makes 6.10 tractable). Two mechanisms extend the
mechanical pipeline and live *only* in the renderer: the rowspan
emulation for group-scoped cells and the drawing of plot cells — both
specified next, and both existing precisely so the cell frame itself can
stay plain data.

### Cells that span rows (group-scoped cells)

Some statistics belong to a term, not to any one of its levels. The
interaction p-value is the canonical case:
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
returns one `p_value` *across* the levels, and the old
[`tbl_interaction_forest()`](https://shah-in-boots.github.io/mesa/reference/tbl_forest.md)
displayed it floating between the two level rows — implemented as a
duplicate-and-white-out hack (the value written into every level row,
all but one masked with white zero-size text, the survivor vertically
aligned onto the band’s seam). The spec makes this a first-class concept
instead. The rule, stated once:

**A statistic computed across a term’s levels attaches to the term, and
its placement follows from where the levels sit.**

- Where the levels are **columns** (the `"levels"` layout), a
  term-scoped statistic gets a displayed column of its own — the rate
  difference already works this way.
- Where the levels are **rows** (the `"interaction"` layout), it becomes
  a **group-scoped cell**: `row_scope = "group"`, `row_key = NA`,
  `row_group` set to the term’s band, one cell per (group, column).

Rendering group-scoped cells is the renderer’s job alone, because
[gt](https://gt.rstudio.com) has no rowspan for body cells: `as_gt()`
emulates one by writing the value into each row of the group, keeping it
visible in exactly one row, vertically centered on the band (with two
level rows: rendered in the first row with `v_align = "bottom"`, which
is what makes it float on the seam), and masking the duplicates (white
text, zero size, borders suppressed). The mask never appears in the cell
frame — it is a render artifact, not data. If
[gt](https://gt.rstudio.com) ever grows body rowspans, only `as_gt()`
changes.

Term-scoped statistics at launch: the interaction `p_value` (inside the
`interaction` block) and `rate_difference`. Any future across-levels
statistic inherits this rule rather than inventing a placement.

### The forest block is resolved at render

A forest column is deliberately *not* “a column of ggplots”. Three
properties, all consequences of “cells are data”, settle how
`add_forest()` interacts with the rest of a table:

1.  **Cell values are numbers.** A forest cell’s `value` is the same
    `list(estimate =, conf_low =, conf_high =)` as an estimate cell,
    with `type = "plot"`. The ggplots are built inside `as_gt()` (via
    [`gt::text_transform()`](https://gt.rstudio.com/reference/text_transform.html) +
    `ggplot_image()`), never stored in the frame — necessarily so,
    because the x-scale (limits, intercept, breaks, log vs linear) is a
    property of the *column*, computed across all of its cells and
    overridable through the block’s `axis` options. A cell frame with a
    forest column snapshots exactly like one without.
2.  **One reserved row.** The block contributes the bottom axis strip
    (the drawn x-axis with ticks, labels, and arrows) as a reserved row:
    `row_key = ".axis"`, `row_group = NA`, ordered after every row
    group, every other column blank, stub label suppressed. This is the
    **only** sanctioned way a column block may alter the row axis, and
    the reserved row always sorts last — so adding or removing
    `add_forest()` never reorders, regroups, or relabels the substantive
    rows, and never changes any existing cell. That invariant is
    testable and 6.8 tests it.
3.  **Style defaults, not style edicts.** The dense look the plots need
    to read as one continuous canvas (zero row padding, suppressed body
    borders) enters as the block’s *defaults* to the style layer,
    applied at render and overridable by `modify_style()` — not as
    scattered `tab_options()` calls the user cannot reach.

`add_forest()` errors unless `estimate` and `conf` are already in the
spec (its cells read them); it computes nothing new.

### The statistics vocabulary

These are the column blocks a table can carry. The “attached data”
column is the load-bearing distinction, because it decides whether a
table can be built from the model collection alone:

| Statistic | Verb | Source | Needs attached data? |
|----|----|----|----|
| `estimate` | `add_estimates()` | tidy `estimate` | no |
| `conf` | `add_estimates()` | tidy `conf_low`, `conf_high` | no |
| `p` | `add_estimates()` | tidy `p_value` | no |
| `n` | `add_n()` | glance `nobs` (recorded at fit) | no |
| `events` | `add_events()` | [`survival::pyears()`](https://rdrr.io/pkg/survival/man/pyears.html) event counts per level | **yes** |
| `rate` | `add_events()` | events ÷ person-years | **yes** |
| `rate_difference` | `add_rate_difference()` | `pyears()` across two levels | **yes** |
| `interaction` | `add_interaction()` | estimate/CI from the stored `var_cov` + `degrees_freedom`; **but** level enumeration and per-level `n` need the data | partial (coefficients are dataless; levels and per-level n are not) |
| `forest` | `add_forest()` | derived from `estimate` + `conf` already present | no (requires estimate and conf in the spec) |

Two consequences worth stating: model-level `n` comes free because
glance records it at fit time, so a plain estimates-and-n table never
needs attached data; but anything *per level* (events, rates, per-level
n) does, and its absence is the error that points to
[`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md).

Scope is the other load-bearing distinction: most statistics are
row-scoped, but `rate_difference` and the interaction `p_value` are
**term-scoped** (computed across a term’s levels). Their placement
follows the group-scoped-cell rule above — a column of their own where
levels are columns, a floating group cell where levels are rows.

### Default layouts and what is supported at launch

A layout **preset** is a complete assignment of the four axes, selected
by `modify_layout()`. *Revised (July 2026):* presets are named for their
*shape*, not for the retired `tbl_*` functions — the shapes are the
commitment, the functions are not. Any table a monolith produced is
recoverable as *preset + column verbs*, and that chain is the documented
form:

| Preset | rows | row groups | columns | spanners |
|----|----|----|----|----|
| `"adjustment"` (was `tbl_beta`) | adjustment sets | outcomes | statistic per term/level | terms (over their levels) |
| `"levels"` (was the hazard tables) | Events, Rate, then adjusted-estimate rows | outcomes | term levels | terms |
| `"interaction"` (was `tbl_interaction_forest`) | interaction levels | interaction terms | n, estimate/CI, forest, p (group-scoped) | none (single outcome × exposure) |

Launch ships exactly these three presets plus the bare default (a single
estimate + CI column block, adjustment-set rows, outcome groups).
`modify_layout()` selects a preset and may swap the row-group dimension
between `outcome` and `strata` (and `interaction` for the interaction
preset). Everything else **errors clearly rather than half-working**:

- An unrecognized preset errors naming the three supported ones.
- More than one model family per table errors (already enforced); more
  than one dataset messages.
- A `forest` column without `estimate` + `conf` in the spec errors.
- A data-derived column (`events`, `rate`, `rate_difference`) with no
  attached data errors, pointing to
  [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md).
- `rate_difference` on a non-dichotomous term errors on an actual level
  count.
- `add_interaction()` under any preset other than `"interaction"` errors
  — it *defines* the rows (exposure-within-level estimates), so it
  cannot be an add-on to adjustment-set or statistic rows.

Deliberately deferred past launch (documented as such, not silently
unsupported): outcomes on **columns** (multiple outcomes side by side),
exposures side by side beyond what the interaction preset does, and free
cross-products of the four axes outside the presets. These return when
there is a real table asking for them, exactly as patterns did in M2.

## The selection resolver (M6.2)

[`resolve_selection()`](https://shah-in-boots.github.io/mesa/reference/resolve_selection.md)
(in
[table-selection.R](https://shah-in-boots.github.io/mesa/R/table-selection.R))
is the single internal engine every table verb runs when a specification
is realized. Three decisions were fixed here:

- **Matching is by identity, never
  [`grepl()`](https://rdrr.io/r/base/grep.html).** Outcomes, exposures,
  and strata are matched by exact membership against the
  `outcome`/`exposure`/`strata` columns. Terms resolve through the term
  table’s variable–level relationship: a continuous term is its own key;
  a categorical term expands to its bare name *plus* one key per
  non-reference level (`paste0(term, level)`, the treatment-contrast
  naming
  [`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html)
  produces). The bare name is always kept so a dichotomous variable
  modeled numerically (tidy term `am`) resolves as readily as one
  modeled as a factor (`am1`). This retires the substring bugs the old
  `tbl_*` functions carried (`am` selecting `gam`, `wt` selecting
  `wt2`).
- **Levels come from the attached data, stamped onto the term table.**
  The fit pipeline (`fmls() |> fit()`) leaves the term table’s
  `level`/`type` fields empty, so
  [`resolve_term_metadata()`](https://shah-in-boots.github.io/mesa/reference/resolve_term_metadata.md)
  runs
  [`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
  against the attached dataset before expanding keys. This makes the
  term table carry the variable–level relationship the blueprint calls
  for, while keeping the attached data as the canonical source (there is
  no `data =` argument). When no data is attached, resolution falls back
  to bare-name matching — which still fixes the `am`/`gam` and
  `wt`/`wt2` cases, only categorical level expansion needs the data.
- **Adjustment-set identity is the sequential model index, not the term
  count.**
  [`family_adjustment_index()`](https://shah-in-boots.github.io/mesa/reference/family_adjustment_index.md)
  groups rows by outcome × exposure × strata × level × subset × data ×
  model, orders each family by adjustment degree (`number`, ties broken
  by row order), and numbers them `1, 2, 3, …`. Two models that share a
  right-hand-side term count therefore stay distinct (the old
  `number %in% ...` selection collided), and each stratum level numbers
  its own adjustment sets.

The resolver returns a `mesa_selection` list (`models`,
`adjustment_index`, `terms`, `term_keys`, `labels`) that the `<mesa>`
spec (M6.3) will consume at realization. All selection input passes
through
[`selection_input()`](https://shah-in-boots.github.io/mesa/reference/selection_input.md)
→
[`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md),
the single documented mechanism.

## Private-data tests (M0/M6)

The author-only checks against AFEQT/CARRS/MIMS
[targets](https://docs.ropensci.org/targets/) stores moved to
`tests/manual/` (build-ignored, not run by testthat) so R CMD check is
clean. Milestone 6 replaces them with public-data equivalents.
