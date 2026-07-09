# Add model-statistic columns to a `<mesa>`

**\[experimental\]**

These verbs append a *column block* to a
[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
specification — an instruction for a set of statistic columns, computed
and formatted only when the table is realized by
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md).

- `add_estimates()` declares the estimate block: which of the point
  estimate (`beta`), confidence interval (`conf`), and p-value (`p`)
  columns are shown, under what labels, on what scale, and to how many
  digits. The estimate and interval render merged into a single
  displayed column (`1.4 (1.1, 1.8)`); the p-value renders as its own
  column.

- `add_n()` adds the model-level number of observations, read from the
  `nobs` recorded at fit time — so it never needs attached data.

A bare specification without `add_estimates()` already renders
estimate + CI; call the verb when you want to choose the statistics,
their labels (`beta ~ "HR"`), the scale, or the digits. Re-calling a
verb replaces its earlier block with a message (the same replacement
behavior as every other verb).

## Usage

``` r
add_estimates(
  x,
  columns = list(beta ~ "Estimate", conf ~ "95% CI", p ~ "P value"),
  exponentiate = NULL,
  digits = NULL
)

add_n(x, label = "N")
```

## Arguments

- x:

  A `<mesa>` specification (from
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md))

- columns:

  Which estimate statistics to show, as labeled formulas (see
  [`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md)).
  The recognized statistics are `beta` (the point estimate), `conf` (the
  confidence interval), and `p` (the p-value); the labels become the
  column headers

- exponentiate:

  Controls the scale of the estimates: `NULL` (default) infers per model
  family (see Details), `TRUE`/`FALSE` overrides

- digits:

  Number of digits the estimate and interval are formatted to; unset,
  the table-wide default applies (see
  [`modify_style()`](https://shah-in-boots.github.io/mesa/reference/modify_style.md))

- label:

  The column header for the `n` column

## Value

The modified `<mesa>` specification.

## Details

### Exponentiation

`exponentiate = NULL` (the default) defers the scale decision to the
model family inference of
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md):
Cox-family models and GLMs on a `log`/`logit`/`cloglog` link come back
exponentiated (hazard, odds, or rate ratios), everything else stays
linear. `TRUE` or `FALSE` overrides the inference for every model on the
mesa.

### Formatting

`digits` applies to the estimate and its interval; left unset, it falls
to the table-wide default
([`modify_style()`](https://shah-in-boots.github.io/mesa/reference/modify_style.md)'s
`digits`, or 2). P-values render with three decimals, with values below
shown as `<0.001`.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md),
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
