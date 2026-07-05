# Model Prototypes

**\[experimental\]**

## Usage

``` r
mdl(x = unspecified(), ...)

# S3 method for class 'character'
mdl(
  x,
  formulas,
  parameter_estimates = data.frame(),
  summary_info = list(),
  data_name,
  strata_variable = NA_character_,
  strata_level = NA_character_,
  ...
)

# S3 method for class 'lm'
mdl(
  x = unspecified(),
  formulas = fmls(),
  data_name = character(),
  strata_variable = character(),
  strata_level = character(),
  ...
)

# S3 method for class 'glm'
mdl(
  x = unspecified(),
  formulas = fmls(),
  data_name = character(),
  strata_variable = character(),
  strata_level = character(),
  ...
)

# S3 method for class 'coxph'
mdl(
  x = unspecified(),
  formulas = fmls(),
  data_name = character(),
  strata_variable = character(),
  strata_level = character(),
  ...
)

# Default S3 method
mdl(x, ...)

model(x = unspecified(), ...)
```

## Arguments

- x:

  Model object or representation

- ...:

  Arguments to be passed to or from other methods

- formulas:

  Formula(s) given as either an `formula` or as a `fmls` object

- parameter_estimates:

  A `data.frame` that contains columns representing terms and individual
  estimates or coefficients, can be accompanied by additional statistic
  columns. By default, assumes

  - **term** = term name

  - **estimate** = estimate or coefficient

- summary_info:

  A `list` that contains columns representing summary statistic of a
  model. By default, assumes...

  - **nobs** = number of observations

  - **degrees_freedom** = degrees of freedom

  - **statistic** = test statistic

  - **p_value** = p-value for overall model

  - **var_cov** = variance-covariance matrix for predicted coefficients

- data_name:

  String representing name of dataset that was used

- strata_variable:

  String of a term that served as a stratifying variable

- strata_level:

  Value of the level of the term specified by `strata_variable`

## Value

An object of the `mdl` class, which is essentially an equal-length list
of parameters that describe a single model. It retains the original
formula call and the related roles in the formula.
