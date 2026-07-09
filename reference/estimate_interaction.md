# Estimating interaction effect estimates

**\[experimental\]**

When a model in a `mdl_tbl` carries an interaction term, the exposure's
effect *within each level* of the interaction variable — and its
confidence interval — can be derived from the stored coefficients and
variance-covariance matrix, without refitting. The approach follows
Figueiras et al. (1998): within the reference level the effect is the
exposure coefficient; within level *j* it is the exposure coefficient
plus the level's interaction coefficient, with variance
`var(b_exp) + var(b_j) + 2 cov(b_exp, b_j)`.

## Usage

``` r
estimate_interaction(object, exposure, interaction, conf_level = 0.95, ...)
```

## Arguments

- object:

  A `mdl_tbl` object subset to a single row

- exposure:

  The exposure variable in the model

- interaction:

  The interaction variable in the model

- conf_level:

  The confidence level for the confidence interval

- ...:

  Arguments to be passed to or from other methods

## Value

A `tibble` with one row per level of the interaction variable (the
reference level first) and `n = 6` columns:

- estimate: the exposure's effect within the interaction level

- conf_low: lower bound of the confidence interval for the estimate

- conf_high: upper bound of the confidence interval for the estimate

- p_value: p-value for the overall interaction effect *across levels*
  (the same value on every row)

- nobs: number of observations within the interaction level

- level: level of the interaction term

## Details

`estimate_interaction()` requires a `mdl_tbl` subset to a single row;
filter before calling. The interaction variable may be **binary or
categorical**: every level of the attached-data factor yields a row, the
reference level first. Terms are matched to the model's coefficients by
**identity** (the tidy keys `exposure:interactionLevel`, either variable
order), and the variance-covariance matrix is indexed by coefficient
name — never by [`grepl()`](https://rdrr.io/r/base/grep.html) position.

The `p_value` is the single across-levels test of interaction: with one
interaction coefficient (a binary interaction) it is that coefficient's
p-value; with several (a categorical interaction) it is the joint Wald
chi-square test of all the interaction coefficients against zero.

## References

A. Figueiras, J. M. Domenech-Massons, and Carmen Cadarso, 'Regression
models: calculating the confidence intervals of effects in the presence
of interactions', Statistics in Medicine, 17, 2099-2105 (1998)
