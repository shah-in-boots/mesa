# Register a formula expansion pattern

**\[experimental\]**

Patterns are the rules by which a set of terms expands into a family of
formulas. Each pattern is a function that takes a `tm` vector and
returns a `tbl_df` precursor table (see
[`apply_pattern()`](https://shah-in-boots.github.io/mesa/reference/patterns.md)
for the contract). The built-in patterns (fundamental, direct,
sequential, parallel) are registered this way; user-defined patterns can
join them and become available to
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md) by
name.

## Usage

``` r
register_pattern(name, fn)
```

## Arguments

- name:

  A single string naming the pattern

- fn:

  A function accepting a `tm` vector and returning a `tbl_df` that
  follows the pattern contract

## Value

The pattern name, invisibly

## Examples

``` r
# A pattern that ignores covariates entirely
unadjusted <- function(x) {
  apply_fundamental_pattern(x)
}
register_pattern("unadjusted", unadjusted)
"unadjusted" %in% formula_patterns()
#> [1] TRUE
```
