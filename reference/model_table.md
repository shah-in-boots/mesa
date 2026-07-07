# Model tables

**\[experimental\]**

`model_table()` creates a `mdl_tbl` object — the notebook of models. It
collects `mdl` vectors (fitted models from
[`fit()`](https://generics.r-lib.org/reference/fit.html) with
`raw = FALSE`), `fmls` objects (formulas not yet fit), and other
`mdl_tbl` objects into a single data frame where each row is one model:
its formula, its causal roles, its fitting context (data, strata,
subsets), and its results. `mdl_tbl()` is a documented alias; the class
itself is named `mdl_tbl`.

The table is the working surface of an analysis. Its print method
summarizes what has been fit, what failed, and what is still waiting;
[`summary()`](https://rdrr.io/r/base/summary.html) maps the fleet;
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
pulls out estimates;
[`model_failures()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
explains failures. See
[model_table_helpers](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
for the full set.

## Usage

``` r
# S3 method for class 'mdl_tbl'
print(x, ..., n = 10)

# S3 method for class 'mdl_tbl'
summary(object, ...)

model_table(..., data = NULL)

mdl_tbl(..., data = NULL)

is_model_table(x)
```

## Arguments

- x:

  A `mdl_tbl` object

- ...:

  `mdl` or `fmls` objects to tabulate (named arguments become the `name`
  column), or `mdl_tbl` objects to combine. A single bare
  [`list()`](https://rdrr.io/r/base/list.html) of such objects is also
  accepted. Raw fitted models (e.g. an `lm` object) are not: refit with
  `fit(..., raw = FALSE)` or wrap with
  [`mdl()`](https://shah-in-boots.github.io/mesa/reference/models.md).

- n:

  Number of models to show when printing (default 10)

- object:

  A `mdl_tbl` object (for
  [`summary()`](https://rdrr.io/r/base/summary.html))

- data:

  A `data.frame` used by the models, attached under the name it was
  passed as (see
  [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md))

## Value

A `mdl_tbl` object: a `tibble` where each row describes one model, with
the formula matrix, term table, and data list carried as attributes.

## Details

Along with the row-per-model data, three scalar attributes carry the
context needed to reconstruct any model in the table:

1.  A **formula matrix**
    ([`formula_matrix()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md))
    with one row per model and one column per term, marking which terms
    each model's formula contains.

2.  A **term table**
    ([`term_table()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md))
    describing each term's causal role, label, and other metadata.

3.  A **data list**
    ([`model_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md))
    holding datasets attached via
    [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
    or the `data` argument, so models can be diagnosed or re-examined
    later.

These attributes are reconciled automatically when tables are combined,
filtered, or otherwise manipulated with `dplyr` verbs.

## Functions

- `print(mdl_tbl)`: The print method leads with the state of the
  analysis: how many models are fitted, failed, or still unfit; which
  datasets are attached; then one line per model. Control the number of
  rows shown with `n`.

- `summary(mdl_tbl)`: The summary method maps the fleet: models grouped
  by dataset, fitting function, outcome, and exposure, with their
  adjustment ranges and stratification; the terms in play by causal
  role; and any failures with their messages. Returns the overview
  grouping invisibly as a `tibble`.

## Invariant columns

Every `mdl_tbl` carries these columns; they may be reordered by row but
not removed or renamed. Dropping any of them (e.g. through
[`dplyr::select()`](https://dplyr.tidyverse.org/reference/select.html))
returns a plain `data.frame` with a message.

- `id` — hash identifying the model (links rows to the formula matrix)

- `formula_index` — the model's row of the formula matrix

- `data_id` — name of the dataset the model was fit on

- `name` — the label the object was given when added to the table

- `model_call` — the fitting function (e.g. `lm`, `coxph`); `NA` until
  fit

- `formula_call` — the model formula as text

- `number` — number of right-hand-side terms (the "adjustment degree")

- `outcome`, `exposure`, `mediator`, `interaction` — terms by causal
  role

- `strata`, `level` — the stratifying term and this model's stratum

- `subset` — the
  [`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  instruction the model was fit under

- `model_parameters` — parameter-level estimates (a list of data frames)

- `model_summary` — model-level statistics (a list)

- `fit_status` — `TRUE` if the model fit; `FALSE` if it failed or has
  not been fit yet

## Combining tables

Model tables combine through `model_table(x, y)` (or
[`vctrs::vec_rbind()`](https://vctrs.r-lib.org/reference/vec_bind.html));
formula matrices, term tables, and data lists are merged and
deduplicated, with the first (left-most) definition of a term kept.
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
only works when the rows already belong to the first table (it strips
attributes before they can be reconciled); combining unrelated tables
with it returns a plain `data.frame` with a message pointing back to
`model_table()`.
