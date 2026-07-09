# The `<mesa>` table specification

**\[experimental\]**

`mesa()` lays a collection of fitted models out on the *mesa* — the
table upon which the models are displayed — as a declarative
specification. It is deliberately bare: it takes no selection arguments
and puts everything fitted on the mesa with default labels drawn from
the term table and the attached data. The table is then grown one
decision at a time with pipeable verbs, exactly the way a `{ggplot2}`
plot is grown:

- `select_outcomes()`, `select_exposures()`, `select_terms()`,
  `select_adjustment()`, `select_strata()` narrow what is shown;

- [`modify_labels()`](https://shah-in-boots.github.io/mesa/reference/modify_labels.md)
  relabels terms and levels late, without reselecting;

- [`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
  renders the specification to a `{gt}` table (see
  [`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)).

Because the specification is declarative — the verbs record instructions
and resolution happens only at
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)/[`print()`](https://rdrr.io/r/base/print.html)
— the verbs may arrive in any order. **A verb replaces only what you
name.** Repeating a verb with the same instruction — the same selection
dimension, block type, style field, or label name — replaces just that
instruction with a message, and leaves everything else recorded on the
specification standing (the `{ggplot2}` `labs()` merge behavior);
calling a `select_*()` verb with no arguments clears that dimension,
which is the way to undo an earlier selection. A bare
`mesa(mt) |> as_gt()` already renders a minimal estimate-and-interval
table, so the grammar is usable from the first verb.

## Usage

``` r
mesa(object, ...)

select_outcomes(x, ...)

select_exposures(x, ...)

select_terms(x, ...)

select_adjustment(x, ...)

select_strata(x, ...)

# S3 method for class 'mesa'
print(x, ...)

# S3 method for class 'mesa'
format(x, ...)
```

## Arguments

- object:

  A `mdl_tbl` object holding at least one fitted model

- ...:

  For `mesa()`, unused — it deliberately takes no selection arguments,
  and an unused argument errors; for the selection verbs,
  labeled-formula selection input (a `formula`, a `list` of formulas, or
  a `character` vector — see
  [`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md)),
  or nothing at all to clear that dimension's selection; for
  [`print()`](https://rdrr.io/r/base/print.html), unused

- x:

  A `<mesa>` specification (for the verbs and
  [`print()`](https://rdrr.io/r/base/print.html))

## Value

`mesa()` and the verbs return a `<mesa>` specification object.

## Details

`mesa()` validates before it builds. The object must be a `mdl_tbl`;
only its fitted rows are laid out (failed and unfit rows are set aside);
the table must hold a single model family (one fitting function) or it
errors; and more than one attached dataset is reported with a message.
See
[`model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
for the collection these are drawn from and
[`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
for supplying the data that categorical levels and data-derived
statistics are read from.

## See also

[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md) to
render,
[`model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
for the model collection

## Examples

``` r
# The "adjustment" chain — adjustment sets on rows, outcomes as row
# groups, a statistic block per term (the retired `tbl_beta()` shape)
d <- mtcars
d$cyl <- factor(d$cyl)
mt <-
  fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential") |>
  fit(.fn = lm, data = d, raw = FALSE) |>
  model_table(data = d)
mt |>
  mesa() |>
  select_adjustment(1 ~ "Unadjusted", 3 ~ "Fully adjusted") |>
  add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI")) |>
  modify_labels(wt ~ "Weight (1000 lbs)") |>
  as_gt()


  

```
