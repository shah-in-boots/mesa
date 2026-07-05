# Estimating interaction effect estimates

**\[experimental\]**

When using categorical interaction terms in a `mdl_tbl` object,
estimates on interaction terms and their confidence intervals can be
evaluated. The effect of interaction on the estimates is based on the
levels of interaction term. The estimates and intervals can be derived
through the `estimate_interaction()` function. The approach is based on
the method described by Figueiras et al. (1998).

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

A `data.frame` with `n = levels(interaction)` rows (for the presence or
absence of the interaction term) and `n = 5` columns:

- estimate: beta coefficient for the interaction effect based on level

- conf_low: lower bound of confidence interval for the estimate

- conf_high: higher bound of confidence interval for the estimate

- p_value: p-value for the overall interaction effect *across levels*

- nobs: number of observations within the interaction level

- level: level of the interaction term

## Details

The `estimate_interaction()` requires a `mdl_tbl` object that is a
single row in length. Filtering the `mdl_tbl` should occur prior to
passing it to this function. Additionally, this function assumes the
interaction term is binary. If it is categorical, the current
recommendation is to use dummy variables for the corresponding levels
prior to modeling.

## References

A. Figueiras, J. M. Domenech-Massons, and Carmen Cadarso, 'Regression
models: calculating the confidence intervals of effects in the presence
of interactions', Statistics in Medicine, 17, 2099-2105 (1998)
