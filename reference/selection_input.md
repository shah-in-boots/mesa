# Normalize a selection input to a named list

Accepts the documented labeled-formula inputs (a `formula`, a `list` of
formulas, or a `character` vector) through the single
[`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md)
mechanism; `NULL` (and the empty
[`formula()`](https://rdrr.io/r/stats/formula.html) default the old
table functions used) means "no filter".

## Usage

``` r
selection_input(x)
```
