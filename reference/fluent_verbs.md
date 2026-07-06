# Fluent verbs for playing with formula families

**\[experimental\]**

A family of formulas should feel like something to play with: pick terms
up off a dataset, snap them together, swap the pieces, and watch the
family of models unfold. These pipeable verbs each take a `fmls` object
and return a modified one, so a modeling deck can be grown
interactively:

- `add_strata()` / `remove_strata()`: mark terms as stratifying
  variables ([`fit()`](https://generics.r-lib.org/reference/fit.html)
  will fit one model per stratum level)

- `add_terms()` / `remove_terms()`: add or drop covariates from every
  formula in the family

- `swap_outcome()`: exchange one outcome for another, keeping the rest
  of the family intact

- `subset_data()`: record data-filtering instructions (e.g.
  `sex == "F"`) that
  [`fit()`](https://generics.r-lib.org/reference/fit.html) will apply,
  fitting the family once per subset

Terms may be given as bare names or strings. For `swap_outcome()`, a
two-sided formula `old ~ new` swaps a specific outcome; a bare name is
allowed when the family has a single outcome.

## Usage

``` r
add_strata(x, ...)

# S3 method for class 'fmls'
add_strata(x, ...)

remove_strata(x, ...)

# S3 method for class 'fmls'
remove_strata(x, ...)

add_terms(x, ...)

# S3 method for class 'fmls'
add_terms(x, ..., role = "predictor")

remove_terms(x, ...)

# S3 method for class 'fmls'
remove_terms(x, ...)

swap_outcome(x, spec)

# S3 method for class 'fmls'
swap_outcome(x, spec)

subset_data(x, ...)

# S3 method for class 'fmls'
subset_data(x, ...)
```

## Arguments

- x:

  A `fmls` object

- ...:

  Terms as bare names or strings; for `subset_data()`, one or more
  logical expressions in the data's variables; for `remove_strata()`, if
  empty, all strata are removed

- role:

  For `add_terms()`, the role the new terms should carry (defaults to
  `"predictor"`)

- spec:

  For `swap_outcome()`, either a two-sided formula `old ~ new` or a bare
  name/string of the replacement outcome

## Value

A modified `fmls` object

## Examples

``` r
f <- fmls(mpg ~ .x(wt) + hp)
f |>
  add_strata(am) |>
  add_terms(cyl) |>
  subset_data(disp > 100)
#> <fmls: 1 formula>
#>   outcome: mpg
#>   exposure: wt
#>   strata: am
#>   subsets: disp > 100
#> mpg ~ wt + hp + cyl
```
