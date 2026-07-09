# Design Notes

This file records the design decisions made while working through the milestones in [blueprint.md](blueprint.md).
Each entry says what was decided, why, and where the decision lives in code.
When a decision changes, update it here first.

## The internal representation of `fmls` (M2)

A `fmls` object is a data frame subclass with two structural attributes and one behavioral attribute:

- **The formula matrix** (the data frame itself): one row per formula, one column per term, cells of 1/0 marking membership. This is what patterns produce and what every later layer reads.
- **`termTable`**: the `vec_proxy()` of the `tm` vector — one row per term with its role, side, label, group tier, transformation, levels, and other attributes. Terms with side `meta` (strata, random effects) live only here, never in the matrix, because they instruct *how* to fit rather than *what* to fit.
- **`instructions`**: a list of behavioral instructions that ride along with the family; currently `subsets`, a named list of quosures captured by `subset_data()`.

Reconstruction rules: `formulas_to_terms()` reassembles each row into a `tm` vector by matrix membership, always re-attaching strata and random terms; `formula.tm()` renders the fitting formula, dropping meta terms except random effects, which render as `(1 | term)`.

## Role taxonomy additions (M1)

- **Random effects** are a role (`random`, shortcut `.r()`), side `meta`. `y ~ .x(x) + .r(id)` and the lme4-native `y ~ x + (1 | id)` parse to the same term. Random slopes `(wt | id)` are carried whole and re-rendered in parentheses.
- **Data subsets are not a role.** A filter like `sex == "F"` is not a variable in the formula; it is an instruction about the data. Subsets therefore live in the `fmls` `instructions` attribute via `subset_data()` and expand the fitting plan, exactly like strata levels do. This was the main design fork in M1 and the reason there is no `.f()` rune.

## Transformations keep the call as the name (M1)

`log(x)` stays `log(x)` — the term's name is the full call, so formulas rebuild losslessly without `{mesa}` needing to re-apply anything. The wrapper is *additionally* recorded in the `transformation` field so downstream layers (e.g. `set_data()`, future table labeling) can interpret it. `factor()`/`ordered()` wrappers make `set_data()` classify the term from the converted variable.

## The parser is an AST walk (M1)

`tm.formula()` walks the formula's syntax tree (`collect_formula_terms()`) instead of scanning `all.names()` positionally. Consequences worth remembering:

- Nested runes now work: `.x(log(x))` is an exposure with a `log` transformation.
- Unrecognized calls (`Surv(...)`, `cluster(...)`) are opaque terms, carried whole.
- Group tiers accept any number of digits (`.g10`).
- Only `.i()`/`.m()` *shortcuts* demote (with a warning) when no exposure exists; explicit `a:b` products keep the interaction role silently.

## Patterns are a registry (M2)

`register_pattern(name, fn)` adds a `tm -> tbl_df` function to an environment-backed registry; `fmls()` and `apply_pattern()` look patterns up by name, and `formula_patterns()` lists what is registered. The `rolling_interaction` stub was removed rather than finished — it returns when it can be done properly, as a registered pattern.

## Combining families keeps the first definition (M2, issue #42)

`c()` / `vec_c()` on `fmls` merges term tables; when a term arrives with conflicting definitions, the left-most wins and a message names the conflicted terms. This is a message, not a warning, because keep-first is the intended resolution — the message is there so the resolution is never silent.

## Fitting is plan-then-execute (M4)

`fit_plan(object, data)` crosses formulas x strata levels x subsets into an inspectable tibble; `fit()` executes it row by row. Decisions inside:

- `.fn` resolves **by name** through `match.call()` (a function, a string, or a `{parsnip}` `model_spec`); the old positional `match.call()[[3]]` bug is regression-tested.
- With a parsnip spec, `fit()` runs `parsnip::fit()` and unwraps the engine fit, so `mdl()` and the table layers see familiar objects. The `.models` whitelist is retired; it remains only as documentation.
- Failures are soft: an error becomes a recorded condition (`raw = TRUE`) or a `mdl` stub whose `summaryInfo$error` carries the message; `model_table()` turns that into `fit_status = FALSE`, and `flatten_models()` drops unfit rows.
- Fitted calls are normalized (function name, formula text, data by name) so models compare cleanly against hand-fit references and don't embed copies of the data.
- Subset provenance is recorded in `dataArgs$subsetName` and surfaces as the `subset` column of a `mdl_tbl`.

## Degrees of freedom and the variance-covariance matrix (M4)

`degrees_freedom` now comes from `stats::df.residual()` with a `nobs - length(coef)` fallback (the old `nrow - ncol - 1` was an `lm`-shaped guess, off by one even for `lm`). The full `var_cov` matrix **stays** in `summaryInfo`: `estimate_interaction()` needs the covariance between the exposure and the product term to compute interaction confidence intervals without the original data.

## Naming convention (M5)

Spelled-out names are canonical for the public API; abbreviated forms are kept as documented aliases and as class names. So `model_table()` is the constructor (`mdl_tbl()` is its alias), the documentation topic is `model_table`, and helpers spell things out (`flatten_models()`, `model_failures()`, `term_table()`). The *classes* stay abbreviated (`tm`, `fmls`, `mdl`, `mdl_tbl`) because they appear in pipes and prints where brevity reads better. The same pattern already existed as `mdl()`/`model()`.

## The model table's invariants (M5)

A `mdl_tbl` has seventeen invariant columns (see `model_table_columns()` and the Invariant columns section of `?model_table`), validated by `validate_model_table()` on every construction. Rows may be filtered and reordered and new columns added, but removing or renaming an invariant column downgrades the object to a plain `data.frame` with a message naming the loss. Provenance columns are type-stable (`level` is stored as character; `name`, `data_id`, `subset` as character; `model_parameters`/`model_summary` as list columns even for unfit formulas) so tables from different datasets always combine.

## Combining and reconciling model tables (M5, issue #26)

The three scalar attributes (`formulaMatrix`, `termTable`, `dataList`) are reconciled rather than copied:

- **The formula matrix stays parallel to the table rows** — row *i* of the matrix describes model *i*'s formula. `vec_ptype2()` merges both tables' rows into the prototype (which is what `vec_rbind()`/`vec_c()` restore to), and `vec_cast()` keeps the cast table's own rows widened to the union of terms, so the parity invariant survives combination in both directions. The data list survives the cast too (the original #26 defect).
- **Term tables deduplicate by (term, role, side), left-most wins** — the same resolution, and the same reasoning, as combining `fmls` families (issue #42).
- **Subsetting prunes from the roles the remaining rows still claim.** `filter()`, `arrange()`, `slice()`, and `[` rebuild the attributes around the surviving rows: matrix rows are matched by model `id` (so reordering keeps parity), special-role terms are kept only when a remaining row claims them in that role, plain covariates are kept only when a remaining formula uses them beyond its own outcome, random effects are carried whole (they live outside the matrix), and datasets are kept when referenced — plus any dataset attached deliberately without being referenced.
- **`bind_rows()` cannot combine unrelated tables** — dplyr strips attributes before `dplyr_reconstruct()` runs, so there is nothing left to merge. When the first table covers all the rows it reconciles normally; otherwise it returns a plain `data.frame` with a message pointing to `model_table(x, y)`, which combines tables properly.

## Flattening infers the estimate scale (M5)

`flatten_models()` decides exponentiation per model instead of demanding a by-name `which=` list: `mdl()` records the family's link function (`summaryInfo$model_link`), and Cox-family models or GLMs on a `log`/`logit`/`cloglog` link come back exponentiated (hazard/odds/rate ratios) while everything else stays linear. The decision is reported in a message and an `exponentiated` column; `exponentiate = TRUE/FALSE` overrides globally and `which=` survives for name-based selection. Internal callers (the `gt` layer, `estimate_interaction()`) pin `exponentiate = FALSE` because they need coefficients on the linear scale.

## Imports audit (M0)

- `{ggplot2}` and `{scales}` stay in Imports: the forest-plot column is a core deliverable of the table layer.
- `{survival}` moved to Suggests: it is touched only by the hazard tables (`pyears()`), which now guard with `requireNamespace()`. Dispatching on `coxph` objects does not require the package.
- `{parsnip}`, `{lme4}`, `{broom.mixed}` are Suggests: each is guarded at its point of use.
- `{lifecycle}` added to Imports (badges were already in use without it).

## Formula shorthand requests (M2, issue #25)

Added: `.r()` for random effects; multi-digit `.g` tiers; nested rune/transformation combinations. Declined for now: a `.f()` subset rune (see the subsets decision above) and per-term weights (no clear fitting-layer story yet — revisit with M5).

## The table grammar composes (M6)

Five decisions, made together at the start of M6 (the full specification is subtask 6.1 and extends this entry):

- **Two-stage grammar.** An intermediate table-specification object sits between the model collection and the rendered table: `mesa()` constructs it, composable verbs refine it, `as_gt()` renders it. The constructor is named `mesa()` (the namesake act of laying models on the table), not `tbl()`, which would collide with `dplyr::tbl()`. *Revised (July 2026):* the grammar is the deliverable and the only committed API. The `tbl_*` monoliths are **not** end-points to preserve — their table *shapes* survive as the named layout presets (`"adjustment"`, `"levels"`, `"interaction"`), while the functions themselves are deprecated or deleted in 6.7/6.9 with no signature-compatibility work. The earlier phrasing ("the one-shot call patterns keep working") is withdrawn: tables are grown by iteration and composition, not pre-specified by recipe.
- **Composition over configuration.** `mesa(object)` takes no selection arguments; everything else arrives one decision at a time through pipeable verbs (`select_*`, `modify_labels()`, `add_*`, `modify_*`), each optional and each defaulting sensibly, so a table is grown iteratively the way a `{ggplot2}` plot is (staying with the pipe, not `+`). To make that safe, the spec is *declarative and lazily resolved*: verbs record instructions, and resolution against the `mdl_tbl` happens only when the spec is realized by `print()` or `as_gt()`. Consequences: verb order is irrelevant, repeating a verb replaces its earlier instruction with a message (the ggplot scale-replacement behavior), and relabeling late never requires reselecting.
- **Attached data is canonical.** The `dataList` attribute of the `mdl_tbl` is the single source for data-derived statistics (events, person-years, per-level n, factor levels, reference levels). Table functions that need data and cannot find it error with a pointer to `attach_data()`. *Revised (July 2026):* with the recipes demoted, there is no `data =` argument anywhere in the table layer — `attach_data()` is the single path, and every data-needing error points to it.
- **Forest plots are a column type**, not a separate table family: any table specification can include a `forest` column block, and the interaction-forest shape reduces to *interaction rows + forest column*.
- **Verb naming follows the `{gtsummary}` precedent.** Column verbs use `add_*`; the remaining spec fields are adjusted by `modify_layout()` / `modify_style()`. *Revised (July 2026):* the earlier decision that "the recipe family keeps the `tbl_*` prefix" is moot now that the recipes are not a committed surface. If a one-call convenience ever proves worth shipping, it ships as a documented grammar chain (a preset plus column verbs), not as new `tbl_*` API.

## The table grammar specification (M6.1)

This is the one page that governs every verb, every preset, and every rendered table. It fixes four things before any code is written: the four axes, the cell frame, the statistics vocabulary, and the layouts supported at launch. Everything downstream is an implementation of what follows. (Revised on the July 2026 follow-up review: the cell frame gained `row_scope`, the forest block was pinned down as render-time, and the presets were decoupled from the `tbl_*` function names — the individual revisions are marked below.)

A table is realized in five stages — *select → decorate → compute → layout → render* — but only the last two need a precise contract, because the first three feed a single object (`flatten_models()` output, decorated with term metadata) that the rest of the package already defines. This spec pins down the **layout** (the four axes and the cell frame it produces) and the **statistics** each column can carry.

### The four axes

A publication regression table is a grid, and every cell has a place on four axes. Two axes run vertically (rows, and the bands that group them) and two run horizontally (columns, and the bands that span them):

| Axis | What occupies it | Drawn from |
| --- | --- | --- |
| **rows** | one of: adjustment sets; term levels; interaction levels; named statistic rows | the sequential adjustment index within an outcome × exposure family; the term table `level` / data factor levels; `estimate_interaction()` levels; literal names ("Events", "Rate per 100 py") |
| **row groups** | a labeled band grouping consecutive rows | `outcome`; `strata` + `level`; `interaction`; or none |
| **columns** | a statistic block for one term or term level | the statistics vocabulary (below) × the selected terms from the term table |
| **spanners** | a labeled band grouping consecutive columns | a term `label` (spanning its levels); an `outcome`; or none |

The recurring point of confusion, settled here: for a categorical term, the **levels are columns and the term label is their spanner** — not the other way around. (The blueprint's shorthand "term levels as column spanners" for the hazard layout is imprecise; this table is the authority.)

### The cell frame

Every table reduces to one **cell frame**, and `as_gt()` consumes nothing else. It is a long tibble, one row per *rendered cell* — that is, per (row, displayed column) pair, where "displayed column" is a single finished box (so an estimate-with-CI like `1.4 (1.1, 1.8)` is one cell, not three):

| Field | Type | Meaning |
| --- | --- | --- |
| `row_group` | chr | label of the row-group band (`NA` when ungrouped) |
| `row_key` | chr | the stub label of the row within its group; `NA` for a group-scoped cell; keys beginning with `.` are reserved rows contributed by column blocks (`.axis`) |
| `row_index` | int | order of the row within its group (`NA` for group-scoped cells) |
| `row_scope` | chr | `"row"` (the default) or `"group"` — a group-scoped cell belongs to the whole `row_group` band rather than to one row; see "Cells that span rows" below |
| `spanner` | chr | label of the column-spanner band (`NA` when none) |
| `column_key` | chr | stable identifier of the displayed column within its spanner (e.g. `smoking`, `cyl::cyl8`); never shown — used for pivot, ordering, merges, accents |
| `column_index` | int | order of the column |
| `column_label` | chr | the header shown for the column (a statistic name, a level label, or suppressed) |
| `value` | list | the cell's raw content: a named list of the statistics that render *together* in this cell (`list(estimate =, conf_low =, conf_high =)`), or a single numeric/character. Always plain data — a `type = "plot"` cell holds the same named numeric list, never a built `ggplot`; plots are drawn at render (see "The forest block is resolved at render") |
| `type` | chr | how the cell renders: `"numeric"`, `"text"`, `"reference"`, or `"plot"` |
| `format` | list | the cell's format recipe: `digits`, a merge `pattern` (`"{estimate} ({conf_low}, {conf_high})"`), and any per-cell style override. `format` is constant within a `column_key` *except* for accents, which is exactly why it lives on the cell rather than the column. |

`as_gt()` is then mechanical and lives in one place: (1) expand each named statistic inside `value` into a working column keyed `column_key__stat` and pivot wide, with `row_group` → `groupname_col` and `row_key` → `rowname_col`; (2) `fmt_number()` by `format$digits`; (3) `cols_merge()` each `column_key`'s working columns back into one displayed column via `format$pattern`; (4) `tab_spanner()` from `spanner`, `cols_label()` from `column_label`; (5) apply accents and theme. Because the canonical form is a tibble, testing a table is testing a tibble — snapshot tests compare cell frames, not rendered HTML (this is what makes 6.10 tractable). Two mechanisms extend the mechanical pipeline and live *only* in the renderer: the rowspan emulation for group-scoped cells and the drawing of plot cells — both specified next, and both existing precisely so the cell frame itself can stay plain data.

### Cells that span rows (group-scoped cells)

Some statistics belong to a term, not to any one of its levels. The interaction p-value is the canonical case: `estimate_interaction()` returns one `p_value` *across* the levels, and the old `tbl_interaction_forest()` displayed it floating between the two level rows — implemented as a duplicate-and-white-out hack (the value written into every level row, all but one masked with white zero-size text, the survivor vertically aligned onto the band's seam). The spec makes this a first-class concept instead. The rule, stated once:

**A statistic computed across a term's levels attaches to the term, and its placement follows from where the levels sit.**

- Where the levels are **columns** (the `"levels"` layout), a term-scoped statistic gets a displayed column of its own — the rate difference already works this way.
- Where the levels are **rows** (the `"interaction"` layout), it becomes a **group-scoped cell**: `row_scope = "group"`, `row_key = NA`, `row_group` set to the term's band, one cell per (group, column).

Rendering group-scoped cells is the renderer's job alone, because `{gt}` has no rowspan for body cells: `as_gt()` emulates one by writing the value into each row of the group, keeping it visible in exactly one row, vertically centered on the band (with two level rows: rendered in the first row with `v_align = "bottom"`, which is what makes it float on the seam), and masking the duplicates (white text, zero size, borders suppressed). The mask never appears in the cell frame — it is a render artifact, not data. If `{gt}` ever grows body rowspans, only `as_gt()` changes.

Term-scoped statistics at launch: the interaction `p_value` (inside the `interaction` block) and `rate_difference`. Any future across-levels statistic inherits this rule rather than inventing a placement.

### The forest block is resolved at render

A forest column is deliberately *not* "a column of ggplots". Three properties, all consequences of "cells are data", settle how `add_forest()` interacts with the rest of a table:

1. **Cell values are numbers.** A forest cell's `value` is the same `list(estimate =, conf_low =, conf_high =)` as an estimate cell, with `type = "plot"`. The ggplots are built inside `as_gt()` (via `gt::text_transform()` + `plot_image()`, which renders each cell at its displayed pixel size — `gt::ggplot_image()`'s fixed 5-inch canvas, squashed ~17-fold to the cell height, left every mark sub-pixel and invisible), never stored in the frame — necessarily so, because the x-scale (limits, intercept, breaks, log vs linear) is a property of the *column*, computed across all of its cells and overridable through the block's `axis` options. A cell frame with a forest column snapshots exactly like one without.
2. **One reserved row.** The block contributes the bottom axis strip (the drawn x-axis with ticks, labels, and arrows) as a reserved row: `row_key = ".axis"`, `row_group = NA`, ordered after every row group, every other column blank, stub label suppressed. This is the **only** sanctioned way a column block may alter the row axis, and the reserved row always sorts last — so adding or removing `add_forest()` never reorders, regroups, or relabels the substantive rows, and never changes any existing cell. That invariant is testable and 6.8 tests it.
3. **Style defaults, not style edicts.** The dense look the plots need to read as one continuous canvas (zero row padding, suppressed body borders) enters as the block's *defaults* to the style layer, applied at render and overridable by `modify_style()` — not as scattered `tab_options()` calls the user cannot reach.

`add_forest()` errors unless `estimate` and `conf` are already in the spec (its cells read them); it computes nothing new.

### The statistics vocabulary

These are the column blocks a table can carry. The "attached data" column is the load-bearing distinction, because it decides whether a table can be built from the model collection alone:

| Statistic | Verb | Source | Needs attached data? |
| --- | --- | --- | --- |
| `estimate` | `add_estimates()` | tidy `estimate` | no |
| `conf` | `add_estimates()` | tidy `conf_low`, `conf_high` | no |
| `p` | `add_estimates()` | tidy `p_value` | no |
| `n` | `add_n()` | glance `nobs` (recorded at fit) | no |
| `events` | `add_events()` | `survival::pyears()` event counts per level | **yes** |
| `rate` | `add_events()` | events ÷ person-years | **yes** |
| `rate_difference` | `add_rate_difference()` | `pyears()` across two levels | **yes** |
| `interaction` | `add_interaction()` | estimate/CI from the stored `var_cov` + `degrees_freedom`; **but** level enumeration and per-level `n` need the data | partial (coefficients are dataless; levels and per-level n are not) |
| `forest` | `add_forest()` | derived from `estimate` + `conf` already present | no (requires estimate and conf in the spec) |

Two consequences worth stating: model-level `n` comes free because glance records it at fit time, so a plain estimates-and-n table never needs attached data; but anything *per level* (events, rates, per-level n) does, and its absence is the error that points to `attach_data()`.

Scope is the other load-bearing distinction: most statistics are row-scoped, but `rate_difference` and the interaction `p_value` are **term-scoped** (computed across a term's levels). Their placement follows the group-scoped-cell rule above — a column of their own where levels are columns, a floating group cell where levels are rows.

### Default layouts and what is supported at launch

A layout **preset** is a complete assignment of the four axes, selected by `modify_layout()`. *Revised (July 2026):* presets are named for their *shape*, not for the retired `tbl_*` functions — the shapes are the commitment, the functions are not. Any table a monolith produced is recoverable as *preset + column verbs*, and that chain is the documented form:

| Preset | rows | row groups | columns | spanners |
| --- | --- | --- | --- | --- |
| `"adjustment"` (was `tbl_beta`) | adjustment sets | outcomes | statistic per term/level | terms (over their levels) |
| `"levels"` (was the hazard tables) | Events, Rate, then adjusted-estimate rows | outcomes | term levels | terms |
| `"interaction"` (was `tbl_interaction_forest`) | interaction levels | interaction terms | n, estimate/CI, forest, p (group-scoped) | none (single outcome × exposure) |

Launch ships exactly these three presets plus the bare default (a single estimate + CI column block, adjustment-set rows, outcome groups). `modify_layout()` selects a preset and may swap the row-group dimension between `outcome` and `strata` (and `interaction` for the interaction preset). Everything else **errors clearly rather than half-working**:

- An unrecognized preset errors naming the three supported ones.
- More than one model family per table errors (already enforced); more than one dataset messages.
- A `forest` column without `estimate` + `conf` in the spec errors.
- A data-derived column (`events`, `rate`, `rate_difference`) with no attached data errors, pointing to `attach_data()`.
- `rate_difference` on a non-dichotomous term errors on an actual level count.
- `add_interaction()` under any preset other than `"interaction"` errors — it *defines* the rows (exposure-within-level estimates), so it cannot be an add-on to adjustment-set or statistic rows.

Deliberately deferred past launch (documented as such, not silently unsupported): outcomes on **columns** (multiple outcomes side by side), exposures side by side beyond what the interaction preset does, and free cross-products of the four axes outside the presets. These return when there is a real table asking for them, exactly as patterns did in M2.

## The selection resolver (M6.2)

`resolve_selection()` (in [table-selection.R](R/table-selection.R)) is the single internal engine every table verb runs when a specification is realized. Three decisions were fixed here:

- **Matching is by identity, never `grepl()`.** Outcomes, exposures, and strata are matched by exact membership against the `outcome`/`exposure`/`strata` columns. Terms resolve through the term table's variable–level relationship: a continuous term is its own key; a categorical term expands to its bare name *plus* one key per non-reference level (`paste0(term, level)`, the treatment-contrast naming `broom::tidy()` produces). The bare name is always kept so a dichotomous variable modeled numerically (tidy term `am`) resolves as readily as one modeled as a factor (`am1`). This retires the substring bugs the old `tbl_*` functions carried (`am` selecting `gam`, `wt` selecting `wt2`).
- **Levels come from the attached data, stamped onto the term table.** The fit pipeline (`fmls() |> fit()`) leaves the term table's `level`/`type` fields empty, so `resolve_term_metadata()` runs `set_data()` against the attached dataset before expanding keys. This makes the term table carry the variable–level relationship the blueprint calls for, while keeping the attached data as the canonical source (there is no `data =` argument). When no data is attached, resolution falls back to bare-name matching — which still fixes the `am`/`gam` and `wt`/`wt2` cases, only categorical level expansion needs the data.
- **Adjustment-set identity is the sequential model index, not the term count.** `family_adjustment_index()` groups rows by outcome × exposure × strata × level × subset × data × model, orders each family by adjustment degree (`number`, ties broken by row order), and numbers them `1, 2, 3, …`. Two models that share a right-hand-side term count therefore stay distinct (the old `number %in% ...` selection collided), and each stratum level numbers its own adjustment sets.

The resolver returns a `mesa_selection` list (`models`, `adjustment_index`, `terms`, `term_keys`, `labels`) that the `<mesa>` spec (M6.3) will consume at realization. All selection input passes through `selection_input()` → `labeled_formulas_to_named_list()`, the single documented mechanism.

## The `<mesa>` specification (M6.3)

`mesa()` (in [table-spec.R](R/table-spec.R)) is the constructor of the grammar's declarative object; the verbs refine it and `as_gt()` (in [table-render.R](R/table-render.R)) realizes it. Four decisions were fixed here, all following from the composition-first entry above.

- **The spec carries five instruction slots, never results.** A `<mesa>` is a list of `selection` (the raw labeled-formula input each `select_*` verb records), `labels` (the `modify_labels()` term/level/column relabelings), `columns` (the ordered `add_*` blocks — empty until M6.4), `layout` (preset plus row-group dimension), and `style` (digits, missing text). It also holds the fitted `mdl_tbl` it was built from. Nothing is resolved against the table until realization, which is what makes verb order irrelevant and late overrides cheap. Each verb owns exactly one slot and a repeat replaces that slot with a message (the ggplot scale-replacement behavior) — including `modify_labels()`, whose slot is the whole label set.

- **The constructor validates, then lays out only the fitted rows.** `mesa()` keeps the rows `model_table_status()` calls `"fitted"` and sets the failed/unfit ones aside (erroring if none remain), because an unfit formula has no estimate to display. A table mixing model families (more than one `model_call`) **errors** — `lm` and `coxph` estimates are not interpretable in one table — while more than one attached dataset only **messages**, since data-derived statistics resolve each model against its own `data_id`. This is the M5 status vocabulary and the M6 "attached data is canonical" rule meeting at the constructor.

- **Realization is select → decorate, and it injects reference rows.** `realize_mesa()` runs the M6.2 resolver, flattens the selected models on the inferred scale (`flatten_models()` with the M5 family/link default, so Cox/logit come back as ratios), keeps only the parameter rows whose tidy key maps to a displayed term (via `match_term_keys()`, never `grepl()`), and joins each with its role/label/level/reference metadata. The displayed terms default to the models' exposures when `select_terms()` is unset (falling back to every non-outcome, non-meta term). For every categorical term it then injects one **reference row** per model context — the reference level carrying no estimate — generalizing `tbl_beta`'s `_ref` column into plain data. The per-model adjustment index is carried onto the parameter rows by matching each back to its model by identity, so colliding term counts stay distinct. The output is the decorated long tibble the later stages (compute → layout → render) consume.

- **The bare `as_gt()` is a minimal renderer, deliberately interim.** `render_minimal()` pivots the decorated frame to one displayed column per term level (estimate and CI merged into one box), adjustment sets on rows, outcomes as row groups, categorical terms spanning their level columns with the reference level shown blank. It is the smallest thing that makes the grammar usable from the first verb; the full cell-frame renderer (spanners, `cols_merge`, forest, group-scoped cells) is M6.6, at which point `as_gt.mesa()` moves to consuming the cell frame and `render_minimal()` retires. `as_gt()` itself is a new S3 generic (no collision — `{gt}` does not export one).

## Model-statistic column blocks (M6.4)

`add_estimates()` and `add_n()` (in [table-columns.R](R/table-columns.R)) are the first column verbs. Each records a *column block* — an instruction list on the spec's ordered `columns` slot — and defers all computation and formatting to realization, like every other verb; re-calling a verb replaces its block of the same type, in place, with a message. Decisions fixed here:

- **Exponentiation defaults to the M5 family inference.** `add_estimates(exponentiate = NULL)` passes `NULL` through to `flatten_models()`, whose family/link inference decides the scale per model — this is what corrects the old hazard-scale defect (log-hazards labeled `HR`). `TRUE`/`FALSE` overrides globally. The realized frame keeps the `exponentiated` marker, so the decision is always inspectable.
- **The statistic vocabulary keeps `tbl_beta`'s names.** The recognized estimate statistics are `beta`, `conf`, and `p` (the 6.1 vocabulary's `estimate`/`conf`/`p`, under the labeled-formula names the old `columns =` argument already used). Unknown names error at verb time — recording a bad block and failing at render would waste the laziness.
- **`beta` and `conf` merge into one displayed cell.** Per the cell-frame spec, `1.4 (1.1, 1.8)` is one cell; the merged column's header is composed from both labels (`"HR (95% CI)"`). `p` is its own column. P-values render with three decimals (`<0.001` below); `digits` governs the estimate and interval.
- **An explicit block shows statistic headers; the bare default stays compact.** Without `add_estimates()`, a term's single estimate column carries the term label (and a categorical term's levels are the headers). With an explicit block, the statistic labels are the headers and the term label moves up to a spanner — for categorical terms, each level becomes an inner spanner over its statistic columns (gt stacks the term spanner above). This keeps the bare `mesa(mt) |> as_gt()` render unchanged while making the verb's labels always visible.
- **`add_n()` reads the recorded `nobs`** (glance, recorded at fit), so an estimates-and-n table never needs attached data — the load-bearing distinction in the 6.1 statistics vocabulary. Column-header overrides arrive late through `modify_labels(columns = list(beta ~ "OR", n ~ "Obs"))`.

## Data-statistic column blocks (M6.5)

`add_events()` and `add_rate_difference()` (in [table-columns.R](R/table-columns.R)) are the first data-derived column blocks — the other side of the 6.1 vocabulary's load-bearing distinction. They record like every verb; a *compute* stage in `realize_mesa()` (`compute_data_statistics()`) runs once per dataset × outcome × term at realization, resolving each model's `data_id` against the attached data — there is no `data =` argument anywhere in the table layer, and every data-needing error points to `attach_data()`. Decisions fixed here:

- **The statistics live on the decorated frame, reference rows included.** `events` and `rate` are stamped per level — the reference level has events even though it has no estimate, which is what makes the old hazard tables' reference column recoverable — and the term-scoped `rate_diff`/`rate_diff_low`/`rate_diff_high` repeat down their term's rows. The interim renderer gives the rate difference a column of its own after the term's level columns (the group-scoped-cell rule: levels are columns here, so a term-scoped statistic is a column); M6.6's cell frame will carry the same values with `row_scope`.
- **The event indicator comes from the outcome itself.** A plain outcome names its own event column; a `Surv()` outcome carries it as the `event` argument (or, unnamed, the last argument) — parsed by `outcome_event_column()`, never guessed. `followup` is the verb's one required argument (bare name or string), and `scale` (default `365.25`, `pyears()`'s own convention for follow-up in days) converts it to years.
- **The issue #30 defects die in the compute stage, with regression tests.** The interval uses `qnorm(1 - (1 - conf_level)/2)` — `qnorm(0.975)` at the default, not the old `qnorm(0.9725)`; `person_years` scales the person-time denominator instead of a hard-coded `/ 100` (rates and the difference scale linearly with it); and the dichotomous restriction is `length(levels) != 2` on the attached-data factor — an actual count, where the old gate `length(levels(x) == 2)` was truthy for any level count. The difference is non-reference minus reference (level 2 − level 1), with the Poisson standard error `sqrt(e2/pt2² + e1/pt1²)`.
- **`add_rate_difference()` depends on the events block.** It reads the follow-up, person-years, and scale `add_events()` recorded (one source of truth for the person-time computation, the same precedent as `add_forest()` reading `estimate` + `conf`); the check runs at realization, not verb time, so the verbs stay order-independent. `{survival}` stays in Suggests — the guard errors at realization only when an events block is actually present.

## The renderer and the layout/style verbs (M6.6)

`as_gt()` (in [table-render.R](R/table-render.R)) now realizes a `<mesa>` in the full five stages: `realize_mesa()` (select → decorate → compute) feeds `mesa_cell_frame()` (*layout*: the column blocks and the preset reduce to the M6.1 cell frame), which feeds `render_cell_frame()` (*render*: the only place in the package emitting `{gt}` layout calls). `render_minimal()` retired on schedule. Decisions fixed here:

- **One formatting authority, ahead of `gt()`.** The renderer applies each cell's format recipe itself (`format_cell()`: `fmt` of `"number"`/`"count"`/`"p"`, `digits`, and the merge `pattern` — `"{estimate} ({conf_low}, {conf_high})"`) and hands `gt()` finished text, rather than round-tripping through `fmt_number()` + `cols_merge()`. This is a deliberate revision of the M6.1 sketch: the output is byte-identical to the interim renderer (existing tests held), missing-statistic behavior is one rule (a parenthetical missing any statistic drops whole; a missing statistic elsewhere yields the `missing_text`), and the wide `_data` a `gt_tbl` carries is directly assertable in tests. The `pattern` field of the frame is honored exactly as specified.
- **The `spanner` field is a path.** Nested spanners (a categorical level under its term when statistic headers are shown) did not fit a single label, so the frame's `spanner` holds the path outermost-first, `"///"`-separated (`"Cylinders///8"`); the renderer creates spanners innermost-first so `{gt}` stacks them. A small revision to the M6.1 field table, recorded here.
- **Digits resolve block → style → 2.** `modify_style(digits =)` is the table-wide default and a column block's own `digits` still wins for its columns; to make that precedence real, `add_estimates(digits =)` now defaults to `NULL` (unset) instead of `2`.
- **Accents are validated at verb time and scoped to the term-level context.** `modify_style(accents = list(p < 0.05 ~ "bold", estimate > 1 ~ c("italic", "red")))` generalizes the old `tbl_beta()` machinery (which parsed only a `p <` criterion and hard-coded bold — the July 2026 defect list): the criterion may compare any displayed statistic (`estimate`/`beta`, `conf_low`, `conf_high`, `p`/`p_value`, `n`, `events`, `rate`, `rate_difference`), and it evaluates once per term-level context within each row — the cells sharing a column-key base — accenting all of that context's cells, so an estimate and its p-value bold together.
- **Group-scoped cells are emulated in one documented place.** `apply_group_scoped()` owns the duplicate-and-mask device (the value written into every row of the band, one copy visible and vertically centered — with an even row count, the row above the seam, bottom-aligned — the rest masked white and zero-size). The mask never appears in the cell frame; if `{gt}` grows body rowspans, only this function changes.
- **Plot cells draw at render on a column-shared x-scale.** `render_plot_columns()` resolves limits/intercept/breaks/log across all of a column's cells (`resolve_plot_scale()`, with the block's `axis` options overriding the guesses), draws each cell via `gt::text_transform()` + `plot_image()`, suppresses the reserved row's stub label, and gives the reserved `.axis` row — which always sorts last, after every row group — the bottom axis strip. Nothing populates plot cells until `add_forest()` (M6.8); the mechanism is tested against hand-built frames. (Revised July 2026, when the drawn plots proved invisible in practice: `plot_image()` — a size-true `ggsave()` + `gt::local_image()`, rendered at 2× for sharpness — replaced `gt::ggplot_image()`, whose fixed 5-inch canvas, squashed to the 30px cell, shrank every mark ~17-fold to sub-pixel weight. The cell's y-scale is pinned to `c(-1, 1)` so the interval caps hold a fixed share of the cell height rather than clipping to full-height bars on the degenerate one-value y range, and out-of-limits values squish onto the axis edge instead of dropping the whole interval.)
- **`modify_layout()` ships the `"adjustment"` and `"levels"` presets; `"interaction"` records but errors at realization** with a pointer to `add_interaction()` (M6.9), which defines its rows. The `"levels"` builder produces the retired hazard-table shape — statistic rows (events, rate) then adjustment rows, term levels on columns, terms as spanners, the term-scoped rate difference in its own column with its value on the rate row — and errors on a requested `p` column, which has no place in the merged level boxes at launch. Stub indentation (the old `tbl_beta` look: crude flush, adjusted rows stepped in) applies under the adjustment preset only. `row_groups = "strata"` swaps the band to the stratum and moves the outcome into the stub qualifier.

`theme_gt_compact()` remains compatible: it takes the finished `gt_tbl`.

## The presets prove the grammar; the monoliths are deleted (M6.7)

The `"adjustment"` and `"levels"` chains reproduce the `tbl_beta()` and hazard-table shapes on public data ([test-table-presets.R](tests/testthat/test-table-presets.R)), asserted against hand-fitted references rather than the old outputs — deliberately, because the equivalence target is *content where the monoliths were right and corrections where they were wrong* (the exponentiated hazard scale, the `qnorm(0.975)` rate difference). With the chains proven, `tbl_beta()`, `tbl_dichotomous_hazard()`, and `tbl_categorical_hazard()` were **deleted outright**, not `{lifecycle}`-deprecated: the package is pre-release, the blueprint's bias is deletion, and the chain examples under `?mesa` are the migration doc. `tbl_interaction_forest()` follows in M6.9 once `add_interaction()` + `add_forest()` recover its shape. `theme_gt_compact()` and the shared `tbls` argument docs stay in gt.R until the last monolith goes.

## The forest column block (M6.8)

`add_forest(axis, width, invert)` (in [table-columns.R](R/table-columns.R)) records a block; the estimate + `conf` requirement — its cells read them and compute nothing — surfaces at realization like `add_rate_difference()`'s dependency, keeping the verbs order-independent. Decisions: **(1)** in the adjustment preset the forest is a statistic column per term level, trailing that level's estimate columns, so the vocabulary's "forest is derived from estimate + conf" is literal — the plot cell's `value` is copied from the estimate cell's; **(2)** `invert` is data-level and real: reciprocal estimates with the interval bounds swapped (1/x reverses order), and the axis mirrors for free because the shared scale resolves from the drawn values; **(3)** the dense look is two style *defaults* applied at render — table-wide zero vertical padding when any plot column is present (overridable by the new `modify_style(padding =)`) and hidden top/bottom borders on the plot columns only; **(4)** the `levels` preset defers the forest column with a clear error (its level columns are single merged boxes). The invariant the blueprint asks for — add/drop `add_forest()` and no other cell changes, only the forest columns and `.axis` row appear — is tested cell-for-cell.

## Interaction rows (M6.9)

`estimate_interaction()` was rewritten around three rules. **Identity, never position:** the exposure must match a tidy term exactly; each level's interaction coefficient resolves through its exact keys (`exposure:interactionLevel`, either variable order, or the bare `exposure:interaction` for a numerically-coded modifier); and the variance-covariance matrix is indexed by coefficient *name* — retiring the `grep()[1]` positions. **Levels generalize:** one row per level of the attached-data factor (binary or categorical), the reference level carrying the exposure coefficient alone and level *j* adding its interaction coefficient with `var(b_e) + var(b_j) + 2cov` (Figueiras et al. 1998), critical values from the recorded residual df (falling to the normal when a family records none). **One across-levels p-value:** the coefficient's own test when there is a single interaction coefficient (preserving the binary behavior), the joint Wald chi-square of all of them when there are several.

`add_interaction()` and the `"interaction"` layout come as a pair — the block *defines* the preset's rows, so each errors without the other, and the frame is built by a dedicated realization (`realize_interaction()`, single outcome × exposure at launch, exponentiation deferred to the estimates block / M5 inference as everywhere). In the frame, per-level statistics are ordinary rows while the interaction p-value is the first shipped **group-scoped cell** (`row_scope = "group"`), exercising the M6.6 rowspan emulation for real. The old forest table is exactly the chain *`"interaction"` layout + `add_n()` + `add_estimates()` + `add_forest()`*; with that verified, `tbl_interaction_forest()` was deleted on the M6.7 terms (outright, pre-release), taking gt-forest.R, its skipped private-data test, and the now-unused `tbls` shared-argument docs with it — gt.R keeps only `theme_gt_compact()`.

## The interface refinement pass (M6.11–M6.14)

A post-launch review of the table layer (July 2026) settled four decisions ahead of the refinement subtasks. The grammar — five stages, four axes, the cell frame, the verb families — is unchanged; these tighten how the verbs behave and where their shared vocabulary lives.

- **A verb replaces only what you name.** The replacement behavior was inconsistent across verbs: `modify_layout()` merged per-field while `modify_style()` and `modify_labels()` replaced their whole slot — so `modify_style(digits = 3)` wiped earlier accents, and one late relabel forced restating every label. The rule, stated once and obeyed everywhere: repeating a verb replaces the *specific instructions it names* (a selection dimension, a block type, a style field, a label name) with a message, and leaves the rest standing — the `{ggplot2}` `labs()` merge, which is what "rethink one decision late" always meant. Corollaries: `mesa()` errors on unused `...`; calling a `select_*` verb with no arguments is the documented way to clear that dimension; an unknown column name in `modify_labels(columns =)` errors at realization instead of silently doing nothing.
- **A block that defines a layout implies it.** `add_interaction()` and `modify_layout(preset = "interaction")` were a mandatory pair, each erroring without the other — two gestures for one decision. Since the block *defines* the preset's rows, declaring the block is declaring the layout: `add_interaction()` sets the preset when none was declared (message), errors on an explicit conflicting preset, and `modify_layout(preset = "interaction")` alone keeps its pointer error.
- **Follow-up defaults from the `Surv()` outcome.** `add_events()` required `followup` even when the outcome already names the time column. It now parses the `Surv()` outcome's time argument exactly (the `outcome_event_column()` precedent — identity, never guessing), keeping `followup` as the override and required for plain outcomes.
- **The statistics vocabulary is a registry.** The recognized statistics, their aliases, default headers, and format recipes were restated in five places (verb validation, accent validation, accent aliasing, `frame_context()`, the print method). They become one internal registry beside the package's other controlled vocabularies (the M2 patterns-registry precedent): each statistic is a row — name, aliases, owning verb, default header, format recipe — and every consumer reads it, so a new statistic is one row, not five edits.

The structural work riding with these (extracting the shared cell-frame builders, splitting table-render.R along its stage seams into realize/presets/render, unifying the interaction dispatch, replacing `format_cell()`'s collision-prone `"NA"` sentinel) is specified in the blueprint's 6.13–6.14 and is behavior-preserving: the 6.10 cell-frame snapshots are the contract that it stays so.

**M6.11 done.** The first bullet above is implemented: `modify_style()` ([table-spec.R](R/table-spec.R)) assigns `accents`, `digits`, `missing_text`, and `padding` independently — each argument replaces only its own field on `x$style`, and the replacement message names the specific field, so `modify_style(digits = 3)` after `modify_style(accents = ...)` no longer wipes the accents. `modify_labels()` merges `x$labels$relabels` and `x$labels$columns` by name (list-index assignment, `x$labels$relabels[names(new)] <- new`), so a later call naming one term or column replaces only that entry; the message names the repeated key(s). `mesa()` errors when `...` carries any argument (named or not), since the constructor deliberately takes none. The unknown-column gap closed in `frame_context()`: before applying the `modify_labels(columns =)` overrides, it assembles the vocabulary actually on the mesa (`names(statistics)` plus `events`/`rate` when an events block is present, `rate_difference` when a rate-difference block is present, `n` and `forest` when their blocks are present) and errors on any labeled name outside it, naming the displayed columns — the check lives in the one function both the adjustment/levels path and the interaction path call. The `select_*()` no-argument clearing behavior already existed in `record_selection()`; it is now stated in `?mesa` and has a regression test rather than being an undocumented side effect.

**M6.12 done.** `add_interaction()` ([table-columns.R](R/table-columns.R)) now implies the `"interaction"` layout instead of forming a mandatory pair with `modify_layout(preset = "interaction")`: when no layout has been declared, it sets the preset itself (with a message so the decision is never silent); when a *different* preset was already explicitly declared, it errors naming the conflict rather than overriding it quietly. `modify_layout(preset = "interaction")` alone is unchanged — it still errors at realization pointing to `add_interaction()`, because the block is what defines the rows, not the layout declaration. The test suite's `interaction_chain()` helper dropped its `modify_layout()` call entirely, which is the intended common case now exercised throughout `test-table-interaction.R`.
`add_events()` no longer requires `followup` when it can be inferred: `parse_surv_outcome()` ([table-columns.R](R/table-columns.R)) parses a `Surv(time, event)` (or `Surv(time, time2, event)`) outcome's arguments by identity — the same discipline `outcome_event_column()` already used for the event column — and `infer_followup_column()` applies it across every outcome on the mesa, requiring them to agree on the time column. A plain outcome, or disagreeing outcomes, still require `followup` explicitly; an explicit `followup` always overrides the inference (needed when the attached data's follow-up column differs from the one named in the fitted formula).

**M6.13 done.** The statistics vocabulary — previously restated by hand in `add_estimates()`, `validate_accent()`, `apply_accents()`, and `frame_context()` — is now one registry, `.table_statistics` in [vocabulary.R](R/vocabulary.R), read through `table_statistics()` (optionally filtered by owning verb), `table_statistic_names()`, and `table_statistic_aliases()` (the M2 patterns-registry precedent applied to a second vocabulary). Each entry carries the statistic's block-declaration name (`beta`, `conf`, `p`, `n`, `events`, `rate`, `rate_difference`, `forest`), its accent-criterion aliases (`beta`'s aliases are `estimate` and `beta`, since a decorated cell's raw field is `estimate` but the accent/verb vocabulary also calls it `beta`), the verb that records it, its default header, and whether an accent criterion may compare it (`forest` cannot — it draws a plot, not a comparable value). `apply_accents()`'s two hand-written alias-propagation lines became a small loop over the registry's `accentable` entries, so adding a future aliased statistic needs no change there. `validate_scalar()` (a ride-along, in [validation.R](R/validation.R)) collapsed the repeated `!is.numeric(x) || length(x) != 1 || is.na(x) || x < 0`-shaped blocks across `add_estimates()`, `add_events()`, `add_interaction()`, `add_forest()`, `add_rate_difference()`, and `modify_style()` into one call with optional bounds, an `allow_null` escape for the "unset, falls back to a default" arguments, and an `nzchar` flag for non-empty-string checks; validations with a domain-specific error message (`followup`'s "single column name", `axis$limits`'s length-2 shape) were deliberately left bespoke rather than forced through a generic message. The dead `render_minimal()`-era leftovers `format_estimate()`, `format_count()`, and `format_p_value()` — unused by any code path since M6.6, exercised only by their own direct tests — are deleted along with those tests; `format_cell()` is the package's only formatting authority, as its own documentation already claimed.

**M6.14 done.** [table-render.R](R/table-render.R) split along the stage seams its own file header already named, with no behavior change (the full test suite, including the M6.10 cell-frame snapshots, passes unchanged; R CMD check is clean): [table-realize.R](R/table-realize.R) holds `realize_mesa()` and its decorate/compute helpers (`mesa_display_terms()`, `inject_reference_rows()`, `apply_context_labels()`, `apply_relabels()`, and the row-identity helpers); [table-presets.R](R/table-presets.R) holds the layout stage — `frame_context()`, the three preset builders (`cell_frame_adjustment()`, `cell_frame_levels()`, `cell_frame_interaction()`), and `assemble_cell_frame()` — plus the interaction preset's `realize_interaction()`/`mesa_interaction_frame()` pair, kept together rather than split across realize/presets because the interaction preset does not pass through the standard flatten-and-decorate frame `realize_mesa()` produces; [table-render.R](R/table-render.R) keeps only the render stage proper (`as_gt()`/`as_gt.mesa()`, `render_cell_frame()`, `format_cell()`, the plot-drawing functions, `apply_accents()`, `apply_group_scoped()`).
The interaction dispatch — previously re-derived in three places (`as_gt.mesa()`'s branch, a redundant guard inside `mesa_cell_frame()`'s preset `switch()`, and `mesa_interaction_frame()`'s own checks) — is now one function, `mesa_frame(x)` (in table-presets.R): `as_gt.mesa()` calls only `render_cell_frame(mesa_frame(x), x)`, and the now-unreachable `interaction = stop(...)` branch inside `mesa_cell_frame()`'s switch was removed. `mesa_interaction_frame()` keeps its own two `stop()`s, because those are substantive validation (layout declared without the block, or vice versa), not a copy of the dispatch condition.
`format_cell()`'s missing-value sentinel was checked directly rather than assumed broken: it already read a non-colliding control-character token, not the literal string `"NA"` the blueprint's defect list described, so a character statistic whose value is genuinely the text `"NA"` already survived formatting untouched (confirmed with a direct call before writing the regression test in [test-table-render.R](tests/testthat/test-table-render.R), which now pins the behavior down either way).
Scoped down from the full 6.14 description: extracting a shared column-descriptor constructor and cells-builder atom across the three `cell_frame_*` preset builders was attempted only in review, not in code. The three builders' shapes diverge enough — levels-as-columns vs. levels-as-rows, the term-scoped rate-difference column, the interaction preset's group-scoped p-value — that a forced shared abstraction read as less clear than the current explicit-but-repetitive code, for three call sites. Revisit if a fourth preset makes the duplication three-plus-one rather than three.

## Private-data tests (M0/M6)

The author-only checks against AFEQT/CARRS/MIMS `{targets}` stores moved to `tests/manual/` (build-ignored, not run by testthat) so R CMD check is clean. Milestone 6 replaces them with public-data equivalents.

## Telling the story (M7)

Three decisions, made while writing the documentation set:

- **The causal-reasoning piece is a full vignette, not a pkgdown-only article.** `development.Rmd` (the personal history) stays in `vignettes/articles/`, built by pkgdown but not by `R CMD check`, because it is a narrative aside. `causal-reasoning.Rmd` sits alongside the five layer vignettes in `vignettes/` instead — the blueprint calls it "the intellectual home of the package," and the intellectual home should be as reachable as the mechanics (`vignette("causal-reasoning")`, built and checked like the others), not relegated to a lower-visibility tier.
- **The README shows the `<mesa>` specification's print, not a live-rendered `{gt}` table.** An embedded `as_gt()` HTML table renders correctly but carries `{gt}`'s full inline CSS block — several hundred lines — which would dominate a generated `README.md` and turn every re-render into a large, noisy diff for a cosmetic reason. Printing the specification is deterministic plain text, shows exactly what is about to be rendered, and points to `vignette("mesa")` for the rendered table itself.
- **`getting_started.Rmd` is retired outright, not updated.** Its content predated Milestone 5 (default `raw = TRUE`, no `set_data()`, no table grammar) and updating it in place would have duplicated the new layer vignettes' content under a stale frame. The README's narrative arc plus the five layer vignettes replace it as the onboarding path; per the pre-release deletion bias already used for the `tbl_*()` monoliths (M6.7), there is no reason to keep a compatibility stub for a vignette, which CRAN does not version.

What M7 does not include: a version bump in `DESCRIPTION` (still `0.0.0.9000`) and the CRAN submission itself. Both are real-world, account-holding, public-consequence actions that stay with the maintainer — `cran-comments.md` is prepared and the local check is clean, but "prepared to submit" and "submitted" are deliberately kept distinct.
