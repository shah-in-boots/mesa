# The tidy-term keys a term expands to

A continuous term is its own key. A categorical term keeps its bare name
*and* gains one key per non-reference level (`paste0(term, level)`, the
treatment-contrast naming
[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html)
produces). The bare name is always kept so a dichotomous variable
modeled numerically (tidy term `am`) resolves as readily as one modeled
as a factor (tidy term `am1`).

## Usage

``` r
expand_term_keys(term, levels)
```
