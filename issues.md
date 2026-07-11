# Issues

Working list for pre-release repair, ordered by urgency. Found during the
codebase review that produced `vignettes/articles/usage.qmd` and
`vignettes/articles/internals.qmd`; file references are approximate anchors.
Items verified by execution are marked ✓.

## High — wrong results or broken contracts

- [x] ✓ **`apply_fundamental_pattern()` violates the pattern contract**
  ([patterns.R:106](R/patterns.R#L106)). *Fixed 2026-07-09*: the pattern now
  returns the documented `outcome`/`exposure`/`covariate_1` columns — the
  exposure keeps its key-pair column, every other RHS term rides one row as
  the single covariate — so `check_groups()` shields the outcome again.
- [x] ✓ **Fundamental pattern turns strata into covariates**
  ([patterns.R:133](R/patterns.R#L133)). *Fixed 2026-07-09*: documented as
  intentional decomposition. `fmls(pattern = "fundamental")` demotes meta
  terms (strata, random) to plain predictors *before* expansion, with a
  message, and the demotion is recorded in the family's term table.
- [x] ✓ **Strata/random leak when families combine**
  ([formulas.R:600](R/formulas.R#L600)). *Fixed 2026-07-09*: meta terms are
  now recorded in the formula matrix like any other member, and
  `formulas_to_terms()`/`key_terms()` read membership alone — a stratum only
  applies to the family that declared it. `add_strata()`/`remove_strata()`
  write the matrix membership too.
- [x] **Interaction layout collides when several models share an interaction
  term** ([table-presets.R:696](R/table-presets.R#L696)). *Fixed
  2026-07-09*: `realize_interaction()` errors when several selected models
  share an interaction term, pointing at `select_adjustment()`. Relatedly,
  the `mdl_tbl` `interaction` column records one term per model (first wins,
  with a message). Qualifying rows per model — and displaying several
  interaction terms per model — is the future extension.
- [x] **`estimate_interaction()` cannot handle a categorical exposure**
  ([interaction.R:113](R/interaction.R#L113)). *Fixed 2026-07-09*: a factor
  exposure resolves through its `exposureLEVEL` keys; one row-set per
  non-reference exposure level comes back with an `exposure_level` column,
  and the joint Wald p-value spans all interaction coefficients. The
  interaction *layout* still shows one contrast (a two-level exposure) and
  errors otherwise.
- [x] **Two definitions of "categorical"**. *Fixed 2026-07-09*: binary and
  categorical are different definitions now. `classify_distribution()`
  stamps a numeric 2-valued column (e.g. a 0/1 survival outcome) as
  `binary`, keeping the continuous type — matching how the model treats it —
  and only factor-like columns are categorical. Strata get their levels
  stamped regardless of type. `add_events()` still requires a factor, and
  its error now says how to convert.

## Medium — design friction and visible quality

- [x] **Forest column reads as pasted-on, not native**
  ([table-render.R:376](R/table-render.R#L376)). Three render defects,
  each verified against the usage-vignette interaction example
  (2026-07-10). (1) *Uneven row and rule lines*: the plot cells' `gt::
  cell_borders(style = "hidden")` meets `border-collapse: collapse`, where
  CSS gives `hidden` top priority on a shared edge — so the forest column
  punches gaps in the header rule and the table's bottom rule while every
  other column keeps its 1px row hlines. (2) *Axis strip width drifts off
  the cells' scale*: `plot_image()` pins only `height:` in em and lets the
  width follow the SVG's intrinsic aspect ratio, but `grDevices::svg()`
  rounds the canvas to whole points (cells 22.5 → 22pt, axis 16.5 → 16pt),
  distorting the two aspect ratios differently, so the axis renders a
  different width than the cells above it. (3) *The reference line dies at
  the last row*: `draw_forest_axis()` draws no intercept line, so the
  dashed vline stops instead of running down into the axis. *Fixed
  2026-07-10*: `plot_image()` pins both `width:` and `height:` in em from
  the requested pixel size; the hidden-border style is gone — a plot
  column now defaults the *whole body* borderless
  (`table_body.hlines.style = "none"`, quiet `row_group.border.*` and
  `stub.border.*`), the booktabs look journals use, so every column is
  even and the outer rules run continuously across the forest column; the
  dashed intercept carries into the axis strip; and the block grew
  `axis = list(title = )`, an axis title drawn beneath the tick labels
  (the titled strip takes 34px against the untitled 22). Remaining
  follow-on polish: "favors left/right" annotations via the block's
  `axis` options.
- [x] ✓ **Strata is invisible in every formula representation**
  ([terms.R:719](R/terms.R#L719)). *Fixed 2026-07-09*: the printed family
  (`format.fmls`) now annotates meta terms in their declared rune form —
  `.s(am)`, `.r(id)` — after the right-hand terms. `formula()`,
  `formula_call`, and the model's recorded call deliberately stay the true
  fitted (unstratified) formula: they are consumed programmatically
  (re-fitting, term counting), so annotating them would corrupt real syntax.
  The engine-native strata question is decided below: `strata()` is
  conditioning and passes through; `.s()` is the data split.
- [x] **`fit()` defaults to `raw = TRUE`**. *Fixed 2026-07-09*: the default
  is `raw = FALSE` — a `mdl` vector, the grammar's main path — and the
  vignettes no longer repeat the argument. `raw = TRUE` remains the opt-out
  for a quick look at the plain fits.
- [x] ✓ **`formula_index` column is not an index**. *Fixed 2026-07-09*:
  dropped. The formula matrix's rows stay parallel to the table's rows, so
  a row-index column carried no information; nothing consumed it.
- [x] **Forest cells are fixed-size PNGs**
  ([table-render.R:432](R/table-render.R#L432)). *Fixed 2026-07-09*: cells
  draw as inline vector SVG (each its own base64 `data:` document, so glyph
  ids cannot collide), sized in `em` units so they scale with the text
  beside them. A build without cairo falls back to the old PNG path.
- [x] **Group-scoped cell mask is white text**. *Fixed 2026-07-09*: the
  rowspan emulation blanks duplicates with a `gt::text_transform()` — a
  content substitution rather than styling, which holds on dark themes and
  on every output format (LaTeX/RTF/Word).
- [x] **`mesa()`'s one-family check compares `model_call` strings only**.
  *Fixed 2026-07-09*: the check now folds in each model's recorded link
  (`summary_info$model_link`), so two `glm`s on different links error as
  `glm (logit)` vs `glm (identity)`.
- [x] **`selection_data()` picks the first referenced dataset**. *Fixed
  2026-07-09*: `selection_data()` returns all attached datasets in
  reference order, and `resolve_term_metadata()` stamps each term's levels
  from the first dataset that carries its column — models spanning several
  datasets each find their own terms stamped. (When two datasets share a
  column name with different levels, the first-referenced one still wins:
  the term table is table-wide by design.)
- [x] **Silent exponentiation skip in the interaction realizer**. *Fixed
  2026-07-09*: a scale flag that does not resolve to one decision per
  interaction term errors, pointing at `add_estimates(exponentiate = )`,
  instead of falling silently to the linear scale.
- [x] **Two `mdl()` construction paths in `fit.fmls`**. *Fixed 2026-07-09*:
  one shared context (formulas, data name, strata, subset) feeds both
  paths; an error only swaps the model object for its message.
- [x] **`_pkgdown.yml` articles index references `causal-reasoning`**.
  *Fixed 2026-07-09*: the references are dropped (`_pkgdown.yml` and the
  `mesa.Rmd` closing pointer, which now sends readers to the terms
  vignette). Writing the article remains an option for later.
- [x] **`attach_data()` matches by deparsed name**. *Fixed 2026-07-09*: an
  inline expression passed as `data` now takes a stable content-derived id
  (`data_<hash>`) at `fit()`, `model_table()`, and `attach_data()` alike, so
  identical content meets itself; and a frame arriving under a different
  name is aliased — with a message — to the one referenced-but-detached
  `data_id` whose models' variables it fully carries. An explicit `name = `
  always wins.

## Low — parsimony and clarity

- [x] **Role-extraction block copy-pasted 6×**. *Fixed 2026-07-09*:
  `pattern_roles()` pulls every role once and `key_pair_grid()` replaces the
  outcome × exposure ladder; the patterns and `check_mediation()` draw from
  them, and `check_groups()` (which never used the roles) dropped the pulls.
- [x] **`construct_table_from_models()` / `construct_table_from_formulas()`
  are ~80% identical**. *Improved 2026-07-09*: the four near-identical
  role-pulls in each collapsed into shared `role_term()` /
  `interaction_term()` helpers. The two constructors themselves stay
  separate — their sources (fitted `mdl` fields vs a bare `fmls` matrix)
  differ enough that a full merge would obscure more than it saves.
- [x] **`mdl.lm` / `mdl.lmerMod` are ~80% identical**. *Fixed 2026-07-09*:
  both are thin wrappers over `new_model_from_fit()`, each computing only
  its own tidy/glance pieces (and the S4 call slot).
- [x] **Formula matrix built via `table() |> rbind()` per row**. *Fixed
  2026-07-09*: membership (0/1) is built directly from each precursor row's
  unique non-`NA` terms, and the downstream membership tests read `>= 1`.
- [x] **`my_tidy()` exposes an `exponentiate` argument it ignores**. *Fixed
  2026-07-09*: parameter dropped; exponentiation stays deferred to
  `flatten_models()`, and the docstring says so.
- [x] **`rhs.formula()` splits deparsed text on `+|-`**. *Fixed
  2026-07-09*: `split_additive()` walks the expression tree, so `I(a + b)`
  stays one term and labels containing `+`/`-` (e.g. `"Weight (+/- SD)"`)
  stay whole; `lhs.formula()` uses the same walk.
- [x] **`apply_sequential_pattern()` generates all 2^n rows then culls**.
  *Fixed 2026-07-09*: the n+1 covariate prefixes are built directly (the
  bare key-pair row only when an exposure anchors it).
- [x] **`format.fmls` brace/indent confusion**. *Fixed 2026-07-09*: both
  branches now select their sides and one shared tail formats and returns.
- [x] **Duplicated section header** in table-render.R. *Fixed 2026-07-09*.
- [x] **`frame_context(dec, spec)` never uses `dec`**. *Fixed 2026-07-09*:
  the parameter is gone; `frame_context(spec)`.
- [x] **Dead role pulls** in the direct, sequential, and parallel patterns.
  *Fixed 2026-07-09*: subsumed by `pattern_roles()` — each pattern reads
  only the roles it uses.

## Decided — the former open design questions (2026-07-09)

- [x] **Engine-native strata is conditioning; `.s()` is the data split**.
  The two constructs work differently and both stay available:
  `strata(x)` (bare or `survival::`-qualified) *conditions within* one
  model, so it passes through the formula untouched — whole, as one term,
  which the engine consumes — traced as `transformation = "strata"`.
  `.s()` remains the grammar's own stratum: an actual segregation of the
  data, one fit per level. Neither is rewritten into the other. (An
  earlier convert-to-`.s()` approach was walked back 2026-07-09: the
  mechanisms are not interchangeable.)
- [x] **The term × effect cell is the core column concept**. A mesa is
  composed of term (or term level) × effect cells — estimate, interval,
  p-value, events, rate, n. The `add_*()` verbs append *groups* of effects
  that travel together (an estimate with its CI and p), so groups compose,
  move, and drop without touching each other's cells, and the presets place
  the same cells wide (levels on columns) or long (levels on rows) without
  recomputing. Documented in `mesa()`/table-columns.R and the vignettes.
  *Future extension*: an explicit wide/long orientation choice on
  `modify_layout()`, moving whole groups between the column and row axes.
- [x] **Attached data attaches whole, at the `mdl_tbl` level only**. The
  full frame is retained: later work routinely reaches for columns no
  current formula names (an `add_events()` follow-up column, a variable
  for the next family of models added to the same table), so pruning to
  referenced columns was tried and walked back 2026-07-09. What stands is
  the layering: `set_data()` on a `tm` or `fmls` only *teaches* (stamps
  type/distribution/levels) and retains nothing, since formulas stay
  abstract and source data keeps evolving; the `mdl_tbl` — where formulas
  and data come together — is the one layer that retains data.

## Family identity (2026-07-10)

- [x] ✓ **A stratum missing from the data silently erased its models**
  ([fit.R:204](R/fit.R#L204)). `data[[strataVar]]` on a missing column
  returned `NULL`, the stratum table expanded to zero rows, and
  `expand_grid()` dropped the formula's every model from the plan —
  `fit()` returned `<model[0]>` with no message. *Fixed 2026-07-10*:
  `plan_fit()` errors when a stratifying term is not a column of `data`,
  pointing at `remove_strata()`; without `data` the plan still forms with
  unresolved levels. Regression test in test-fit.R.
- [x] **`fit_plan()` renamed `plan_fit()`** (2026-07-10). The old name read
  as a fitting function; the new one says what it does — plan the fit.
  Pre-release, so renamed without a deprecation cycle.
- [x] **`identify_family()` recovers family structure from causal roles**
  ([family.R](R/family.R), 2026-07-10). A `fmls` is born as one family but
  `c()` records no lineage; downstream, `family_adjustment_index()` derives
  families as outcome × exposure groups — which misfiles a mediation triad
  (its `mediator ~ exposure` member has a different left-hand side).
  `identify_family()` reads the roles directly: formulas group by outcome ×
  exposure, a mediator binds its triad across that boundary, adjustment
  sets decide the pattern (`sequential` when nested, `parallel` when not,
  `direct` for a lone formula, `mediation`), and families sharing an
  adjustment-ladder signature relate as `varied exposures` (same outcome —
  the wide-table shape) or `varied outcomes` (same exposure). Strata ride
  along without splitting the family; `data` stamps their observed levels.
- [ ] **Wire family identity into the table layer.** `identify_family()`
  is the intended lynchpin for deciding how a set of models can sit on one
  `mesa`: a `varied exposures` relation *is* the wide table (exposures as
  column blocks over shared adjustment rows — which the `"adjustment"`
  preset already renders, but aligned positionally by sequential index,
  not by verified adjustment-set identity); a `mediation` family wants its
  own preset; a stratified family wants estimates-by-level or a forest.
  The likely steps: an `identify_family()` method for `mdl_tbl` (reading
  the same roles off the formula matrix), a family id carried from `fmls`
  through `fit()` into the `mdl_tbl` so lineage survives `c()`, and
  `family_adjustment_index()` / row alignment keyed by the actual
  adjustment set rather than position, warning when ladders do not match.

## Parsimony pass (2026-07-10)

- [x] **Single-use internal helpers inlined at their call sites.** A sweep
  of every internal function's call count found ~30 helpers called exactly
  once, most under 25 lines. Inlined (their doc comments kept as plain
  comments): the `message_*()`/`warning_*()` wrappers (output.R is gone;
  `has_cli()` moved to utils.R), `validate_classes()`, `new_mesa()` and its
  four `default_*()` slot builders, `table_statistic_names()`/`_aliases()`,
  `accent_style()`, `pe_or_na()`, `model_link_function()`,
  `model_degrees_freedom()`, `validate_model_table()`,
  `model_table_reconstructable()`, `data_expression_name()`,
  `model_table_nobs()`, `infer_exponentiation()`, `data_id_candidates()`,
  `infer_followup_column()`, `outcome_event_column()`,
  `expand_term_keys()`, `selection_data()`, `key_to_level()`,
  `row_qualifier()`, and `classify_distribution()`. Dead code removed:
  `check_classes()`, `message_empty_models()`, `message_formula_to_fmls()`.
  *Deliberately kept*: the named pipeline stages (`parse_formula_terms()` →
  `demote_orphan_roles()` → `expand_shortcut_interactions()` → ... in
  terms.R; the realize/lay-out/render stages), S3 methods, vctrs
  cast/ptype2 boilerplate, and multi-use utilities — single-use but
  load-bearing units like `draw_forest_cell()` and `apply_group_scoped()`
  stay because inlining them would bloat their callers past reading.
- [x] **Test suite trimmed of cosmetic and duplicated tests.** Removed the
  ANSI-palette assertion test (the `format(color =)` behavior test stays),
  a duplicate order-independence render test, a duplicate `print.mesa`
  block-description test, an empty test, a trivial row-count test, the
  internals-only `my_tidy()` smoke test, and merged the two overlapping
  `fmls`-combination tests. The rest encode one grammar promise each and
  stay.
