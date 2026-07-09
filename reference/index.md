# Package index

## Terms: the atoms

Individual variables carrying their causal identity — a role, a label,
levels, and the other attributes that make a term more than a name.

- [`tm()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
  [`is_tm()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
  **\[experimental\]** : Create vectorized terms

- [`update(`*`<tm>`*`)`](https://shah-in-boots.github.io/mesa/reference/update.tm.md)
  :

  Update `tm` objects

- [`describe()`](https://shah-in-boots.github.io/mesa/reference/describe.md)
  :

  Describe attributes of a `tm` vector

- [`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
  **\[experimental\]** : Stamp data-derived attributes onto terms

- [`filter(`*`<tm>`*`)`](https://shah-in-boots.github.io/mesa/reference/dplyr_extensions.md)
  :

  Extending `dplyr` for `tm` class

## Formulas: composition

Terms join and merge into families of related formulas, expanded by
patterns and played with through fluent verbs.

- [`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
  [`is_fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
  [`key_terms()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
  : Vectorized formulas

- [`add_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  [`remove_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  [`add_terms()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  [`remove_terms()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  [`swap_outcome()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  [`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  **\[experimental\]** : Fluent verbs for playing with formula families

- [`apply_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
  [`apply_fundamental_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
  [`apply_direct_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
  [`apply_sequential_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
  [`apply_parallel_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
  : Apply patterns to formulas

- [`register_pattern()`](https://shah-in-boots.github.io/mesa/reference/register_pattern.md)
  **\[experimental\]** : Register a formula expansion pattern

- [`formula_patterns()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
  [`term_roles()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
  [`term_transformations()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
  :

  The `mesa` vocabulary

## Models: formulas meet data

A plan is drawn up (formula by stratum by subset), executed against a
fitting approach, and wrapped with its causal context intact.

- [`fit(`*`<fmls>`*`)`](https://shah-in-boots.github.io/mesa/reference/fit.fmls.md)
  **\[experimental\]** :

  Fit the family of models a `fmls` object describes

- [`fit_plan()`](https://shah-in-boots.github.io/mesa/reference/fit_plan.md)
  **\[experimental\]** : Draw up the fitting plan for a family of
  formulas

- [`mdl()`](https://shah-in-boots.github.io/mesa/reference/models.md)
  [`model()`](https://shah-in-boots.github.io/mesa/reference/models.md)
  **\[experimental\]** : Model Prototypes

- [`reexports`](https://shah-in-boots.github.io/mesa/reference/reexports.md)
  [`fit`](https://shah-in-boots.github.io/mesa/reference/reexports.md)
  [`tidy`](https://shah-in-boots.github.io/mesa/reference/reexports.md)
  [`glance`](https://shah-in-boots.github.io/mesa/reference/reexports.md)
  : Objects exported from other packages

## Collections: the notebook of models

Many models stored, recalled, and compared in one table.

- [`print(`*`<mdl_tbl>`*`)`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
  [`summary(`*`<mdl_tbl>`*`)`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
  [`model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
  [`mdl_tbl()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
  [`is_model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
  **\[experimental\]** : Model tables
- [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  [`model_failures()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  [`term_table()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  [`formula_matrix()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  [`model_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  **\[experimental\]** : Model table helper functions
- [`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
  **\[experimental\]** : Flatten a model table to its parameter
  estimates
- [`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
  **\[experimental\]** : Estimating interaction effect estimates

## Tables: the mesa

Laying families of models out for papers, built on the
[gt](https://gt.rstudio.com) package: a specification grown by verbs,
rendered in one place.

### The grammar

The declarative specification and the verbs that narrow, relabel, lay
out, and style it.

- [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`select_outcomes()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`select_exposures()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`select_terms()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`select_adjustment()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`select_strata()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`print(`*`<mesa>`*`)`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  [`format(`*`<mesa>`*`)`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  **\[experimental\]** :

  The `<mesa>` table specification

- [`modify_labels()`](https://shah-in-boots.github.io/mesa/reference/modify_labels.md)
  **\[experimental\]** : Relabel terms, levels, or columns late

- [`modify_layout()`](https://shah-in-boots.github.io/mesa/reference/modify_layout.md)
  **\[experimental\]** :

  Choose a layout preset for a `<mesa>`

- [`modify_style()`](https://shah-in-boots.github.io/mesa/reference/modify_style.md)
  **\[experimental\]** :

  Style a `<mesa>` at render

### Column verbs

Each verb appends a column block; computation waits for realization.

- [`add_estimates()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md)
  [`add_n()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md)
  **\[experimental\]** :

  Add model-statistic columns to a `<mesa>`

- [`add_events()`](https://shah-in-boots.github.io/mesa/reference/add_events.md)
  [`add_rate_difference()`](https://shah-in-boots.github.io/mesa/reference/add_events.md)
  **\[experimental\]** :

  Add data-statistic columns to a `<mesa>`

- [`add_forest()`](https://shah-in-boots.github.io/mesa/reference/add_forest.md)
  **\[experimental\]** :

  Add a forest column to a `<mesa>`

- [`add_interaction()`](https://shah-in-boots.github.io/mesa/reference/add_interaction.md)
  **\[experimental\]** :

  Add interaction rows to a `<mesa>`

### The renderer

Realization and the emitted [gt](https://gt.rstudio.com) table.

- [`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
  **\[experimental\]** :

  Render a `<mesa>` specification to a [gt](https://gt.rstudio.com)
  table

- [`theme_gt_compact()`](https://shah-in-boots.github.io/mesa/reference/theme_gt_compact.md)
  :

  Compact and minimal theme for `gt` tables

## Helpers

- [`lhs()`](https://shah-in-boots.github.io/mesa/reference/formula_helpers.md)
  [`rhs()`](https://shah-in-boots.github.io/mesa/reference/formula_helpers.md)
  : Tools for working with formula-like objects
- [`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md)
  : Convert labeling formulas to named lists
- [`number_of_missing()`](https://shah-in-boots.github.io/mesa/reference/data_helpers.md)
  [`is_dichotomous()`](https://shah-in-boots.github.io/mesa/reference/data_helpers.md)
  : Data summarization and classification methods
