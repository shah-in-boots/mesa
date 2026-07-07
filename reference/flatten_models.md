# Flatten a model table to its parameter estimates

**\[experimental\]**

A `mdl_tbl` object can be flattened to its specific parameters, their
estimates, and model-level summary statistics – one row per model term.
Models that were not fit (or failed) are dropped with a message; see
[`model_failures()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
for why they failed. This relies on the
[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html) output
stored when the models were made.

## Usage

``` r
flatten_models(x, exponentiate = NULL, which = NULL, ...)
```

## Arguments

- x:

  A `mdl_tbl` object

- exponentiate:

  Controls exponentiation of estimates and confidence intervals. The
  default `NULL` infers per model from its family and link;
  `TRUE`/`FALSE` forces the decision for all models.

- which:

  A `character` vector of model names (the `name` column) to
  exponentiate, overriding the family-based inference for everything
  else.

- ...:

  Arguments to be passed to or from other methods

## Value

A `tibble` with one row per model parameter, carrying the model context
columns (`formula_call`, `outcome`, `strata`, ...), model-level
statistics from
[`broom::glance()`](https://generics.r-lib.org/reference/glance.html),
the parameter estimates from
[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html), and
an `exponentiated` marker.

## Exponentiation

By default (`exponentiate = NULL`), estimates and confidence intervals
are exponentiated when the model family calls for it – Cox models and
generalized linear models on a log, logit, or complementary log-log link
(giving hazard, odds, or rate ratios) – and left on the linear scale
otherwise (e.g. `lm`). A message reports when this happens, and the
`exponentiated` column records the decision per row. Set `exponentiate`
to `TRUE` or `FALSE` to override the inference for every model, or use
`which` to exponentiate only the models named there.
