# Stamp data-derived attributes onto terms

**\[experimental\]**

Terms begin as names; once they meet a dataset they gain a character.
The `set_data()` function inspects each term's column in `data` and
stamps on its `type` (categorical or continuous), `distribution`
(dichotomous, ordinal, nominal, or continuous), and observed `level`s.
This is the step that makes strata and interactions *data-aware* — a
stratifying term knows its levels before anything is fit.

Terms wrapped in transformations (e.g. `log(x)`) are classified from
their underlying variable. Terms without a matching column are left
untouched.

## Usage

``` r
set_data(x, data, ...)

# S3 method for class 'tm'
set_data(x, data, ...)

# S3 method for class 'fmls'
set_data(x, data, ...)
```

## Arguments

- x:

  A `tm` or `fmls` object

- data:

  A `data.frame` containing the variables the terms refer to

- ...:

  Arguments to be passed to or from other methods

## Value

An object of the same class as `x` with `type`, `distribution`, and
`level` fields filled in from the data

## Examples

``` r
t <- tm(mpg ~ wt + .s(am))
t <- set_data(t, mtcars)
describe(t, "level")
#> $mpg
#> character(0)
#> 
#> $wt
#> character(0)
#> 
#> $am
#> [1] "0" "1"
#> 
```
