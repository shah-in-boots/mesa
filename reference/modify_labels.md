# Relabel terms, levels, or columns late

**\[experimental\]**

`modify_labels()` rethinks a label without reselecting anything. It
absorbs the old `level_labels` argument of the retired `tbl_*`
functions, so its labeled formulas may name either a term (the variable)
or a specific level:

- a variable with a scalar label relabels the **term**
  (`smoking ~ "Smoking status"`);

- a variable with a vector label relabels the term's **levels** in
  ascending order (`am ~ c("Manual", "Automatic")`);

- a bare level value relabels that **level** wherever it appears
  (`0 ~ "Absent"`).

Column (statistic) relabelings are supplied through `columns` and
consumed by the column verbs. Like every verb, `modify_labels()` merges:
naming a term, level, or column again replaces just that one label, with
a message naming it, while every other label already recorded — from
this call or an earlier one — stands (the `{ggplot2}` `labs()` merge
behavior). So rethinking one label late never forces restating the rest.

## Usage

``` r
modify_labels(x, ..., columns = NULL)
```

## Arguments

- x:

  A `<mesa>` specification

- ...:

  Labeled formulas relabeling terms or levels (see Description)

- columns:

  A labeled-formula input relabeling statistic columns

## Value

The modified `<mesa>` specification.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
