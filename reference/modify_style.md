# Style a `<mesa>` at render

**\[experimental\]**

`modify_style()` records style instructions, applied when the table is
rendered by
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md):

- `accents` emphasize the cells that meet a criterion. Each accent is a
  two-sided formula whose **left side** is a criterion on any displayed
  statistic (`p < 0.05`, `estimate > 1`, `rate >= 10`) and whose **right
  side** is the instruction: `"bold"`, `"italic"`, or a text color (any
  color name or hex value); several may be combined
  (`p < 0.05 ~ c("bold", "italic")`). A criterion is evaluated once per
  term-level within each row, against all of that context's statistics,
  and accents every cell of the context — so `p < 0.05 ~ "bold"` bolds
  both the estimate and the p-value it belongs to. The recognized
  statistic names are `estimate` (alias `beta`), `conf_low`,
  `conf_high`, `p` (alias `p_value`), `n`, `events`, `rate`, and
  `rate_difference`.

- `digits` sets the table-wide formatting default. A column block's own
  `digits` still wins for its columns; p-values keep their three-decimal
  rule.

- `missing_text` fills every cell with nothing to show (reference
  levels, estimates a model did not produce). The default is an empty
  cell.

- `padding` scales the table's vertical row padding (as
  [`gt::opt_vertical_padding()`](https://gt.rstudio.com/reference/opt_vertical_padding.html)
  does). A table carrying a forest column defaults to `0` — the dense
  canvas its plot cells need to read as one — and this overrides that
  default.

Like every verb, `modify_style()` merges: naming `digits` again after an
earlier `accents` call replaces only `digits`, with a message naming it
— the accents already recorded stand. Each of `accents`, `digits`,
`missing_text`, and `padding` replaces only itself.

## Usage

``` r
modify_style(
  x,
  accents = NULL,
  digits = NULL,
  missing_text = NULL,
  padding = NULL
)
```

## Arguments

- x:

  A `<mesa>` specification

- accents:

  A formula or list of formulas: `criterion ~ instruction` (see
  Description)

- digits:

  Number of digits estimates are formatted to

- missing_text:

  Text shown in cells with nothing to display

- padding:

  Vertical padding scale, `0` (dense) upward

## Value

The modified `<mesa>` specification.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md),
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
