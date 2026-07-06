# Apply patterns to formulas

The family of `apply_*_pattern()` functions that are used to expand
`fmls` by specified patterns. These functions are not intended to be
used directly but as internal functions. They have been exposed to allow
for potential user-defined use cases, and new patterns can be added
through
[`register_pattern()`](https://shah-in-boots.github.io/mesa/reference/register_pattern.md).

## Usage

``` r
apply_pattern(x, pattern)

apply_fundamental_pattern(x)

apply_direct_pattern(x)

apply_sequential_pattern(x)

apply_parallel_pattern(x)
```

## Arguments

- x:

  A `tm` object

- pattern:

  A character string that specifies the pattern to use

## Value

Returns a `tbl_df` object that has special column names and rows. Each
row is essentially a precursor to a new formula.

These columns and rows must be present to be used with the
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
function, and generally are the expected result of the specified
pattern. They will undergo further internal modification prior to being
turned into a `fmls` object, but this is an developer consideration. If
developing a pattern, please use this guide to ensure that the output is
compatible with the
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
function.

- outcome: a single term that is the expected outcome variable

- exposure: a single term that is the expected exposure variable, which
  may not be present in every row

- covariate\_\*: the covariates expand based on the number that are
  present (e.g. "covariate_1", "covariate_2", etc)

## Details

Built-in patterns are: fundamental, direct, sequential, parallel.
