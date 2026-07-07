# Match tidy-term names to their resolved variable

Given the tidy-term names present after flattening and a resolved-term
tibble (from
[`resolve_term_metadata()`](https://shah-in-boots.github.io/mesa/reference/resolve_term_metadata.md)),
returns the variable each tidy term belongs to (exact key membership) or
`NA` when it belongs to none. This is how a table's parameter rows are
kept and grouped without [`grepl()`](https://rdrr.io/r/base/grep.html).

## Usage

``` r
match_term_keys(tidyTerms, resolvedTerms)
```
