# Add data-statistic columns to a `<mesa>`

**\[experimental\]**

These verbs append *column blocks* whose statistics come from the
models' **attached data** (see
[`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)),
not from the fitted coefficients — the M6.1 statistics vocabulary's
load-bearing distinction. Like every `<mesa>` verb they only record
instructions; the statistics are computed when the table is realized by
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md),
against the dataset each model's `data_id` resolves to.

- `add_events()` adds the event count and the incidence rate per
  `person_years` for every displayed term level, computed by
  [`survival::pyears()`](https://rdrr.io/pkg/survival/man/pyears.html)
  from the follow-up time column and the outcome's event indicator.

- `add_rate_difference()` adds the incidence-rate difference between a
  dichotomous term's two levels (non-reference minus reference), with a
  normal-approximation confidence interval. It is a *term-scoped*
  statistic — computed across the levels, displayed in a column of its
  own — and it reads the follow-up, person-years, and scale recorded by
  `add_events()`, so the specification must carry both blocks.

## Usage

``` r
add_events(x, followup, person_years = 100, scale = 365.25, digits = 1)

add_rate_difference(x, conf_level = 0.95)
```

## Arguments

- x:

  A `<mesa>` specification (from
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md))

- followup:

  The column of the attached data holding each subject's follow-up time,
  as a bare name or a string

- person_years:

  The person-time denominator the rates are expressed in (`100` shows
  rates per 100 person-years)

- scale:

  The divisor turning the `followup` units into years, passed to
  [`survival::pyears()`](https://rdrr.io/pkg/survival/man/pyears.html):
  the default `365.25` reads follow-up recorded in days; use `1` when
  follow-up is already in years

- digits:

  Number of digits the rates (and the rate difference) are formatted to

- conf_level:

  Confidence level of the rate-difference interval

## Value

The modified `<mesa>` specification.

## Details

### The rate computations

Person-time per level comes from
`survival::pyears(Surv(followup, event) ~ term, scale = scale)`; the
event indicator is the outcome itself when it is a column of the data,
or the event argument of a `Surv()` outcome. The incidence rate is
`events / (person-time / person_years)`. The rate difference between
levels `2` and `1` has standard error
`sqrt(events_2 / persontime_2^2 + events_1 / persontime_1^2)` (the
Poisson variance of each rate), and the interval uses the
`qnorm(1 - (1 - conf_level) / 2)` critical value — for the default
`conf_level = 0.95`, `qnorm(0.975)`.

`add_rate_difference()` errors on any displayed term whose attached-data
factor does not have exactly two levels.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md),
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md),
[`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
