# Fit the family of models a `fmls` object describes

**\[experimental\]**

Fitting happens in two steps: a *plan* is drawn up, then executed. The
plan crosses every formula in the family with every stratum level (from
`.s()` terms) and every subset instruction (from
[`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)),
so one `fmls` object can quietly describe dozens of models. The plan
itself can be inspected before anything is fit through
[`fit_plan()`](https://shah-in-boots.github.io/mesa/reference/fit_plan.md)
— this is the "play" step, where the shape of the analysis is visible
before it runs.

Failures are soft: if one model in a batch cannot be fit, it is recorded
with its error message (`fit_status` becomes `FALSE` in a downstream
[`model_table()`](https://shah-in-boots.github.io/mesa/reference/mdl_tbl.md))
rather than sinking the rest of the fleet.

## Usage

``` r
# S3 method for class 'fmls'
fit(object, .fn, ..., data, raw = TRUE)
```

## Arguments

- object:

  A `fmls` object

- .fn:

  The modeling approach, given as any of:

  - a fitting function, e.g. `lm` or
    [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html)

  - the name of a fitting function, e.g. `"glm"`

  - a `{parsnip}` model specification, e.g.
    `parsnip::logistic_reg() |> parsnip::set_engine("glm")`, which lets
    any engine `{parsnip}` knows about serve as the modeling approach

- ...:

  Additional arguments passed to the fitting function (e.g.
  `family = "binomial"`)

- data:

  A `data.frame` containing the modeling variables

- raw:

  A `logical`. When `TRUE` (default), returns the list of fitted model
  objects as the fitting function made them (for `{parsnip}`
  specifications, the underlying engine fit). When `FALSE`, returns a
  `mdl` vector that carries the causal context forward into
  [`model_table()`](https://shah-in-boots.github.io/mesa/reference/mdl_tbl.md).

## Value

A `list` of models (when `raw = TRUE`) or a `mdl` vector
