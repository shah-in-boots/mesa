# Draw up the fitting plan for a family of formulas

**\[experimental\]**

Every call to [`fit()`](https://generics.r-lib.org/reference/fit.html)
first builds a plan: one row per model that will be fit, crossing each
formula in the family with each stratum level of its `.s()` terms and
each subset instruction from
[`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md).
Exposing the plan lets the shape of an analysis be inspected — and
played with — before any model is run.

## Usage

``` r
fit_plan(object, data = NULL, ...)
```

## Arguments

- object:

  A `fmls` object

- data:

  An optional `data.frame`; when supplied, stratum levels are enumerated
  from the data, otherwise they are left unresolved (`NA`)

- ...:

  Arguments to be passed to or from other methods

## Value

A `tbl_df` with one row per model to be fit and the columns
`formula_index`, `formula_call`, `formula` (as a list),
`strata_variable`, `strata_level` (as a list, since levels keep their
native type), `subset`, and `subset_expr`
