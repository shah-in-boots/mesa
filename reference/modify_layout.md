# Choose a layout preset for a `<mesa>`

**\[experimental\]**

`modify_layout()` selects the layout preset — the complete assignment of
the grammar's four axes (rows, row groups, columns, spanners) — and,
optionally, the row-group dimension. The launch presets are:

- `"adjustment"` (the default): adjustment sets on rows, outcomes as row
  groups, a statistic block per term or term level on columns, terms
  spanning their levels.

- `"levels"`: statistic rows (the event count and incidence rate when
  [`add_events()`](https://shah-in-boots.github.io/mesa/reference/add_events.md)
  is on the mesa, then one row per adjustment set), term levels on
  columns, terms as spanners — the shape of the retired hazard tables.

- `"interaction"`: interaction levels on rows, grouped by interaction
  term, the across-levels p-value floating over each band. Its rows are
  *defined* by
  [`add_interaction()`](https://shah-in-boots.github.io/mesa/reference/add_interaction.md),
  which the specification must carry.

`row_groups` swaps the row-group dimension between `"outcome"` (the
default) and `"strata"`. Like every verb, a repeated `modify_layout()`
replaces the earlier instruction with a message.

## Usage

``` r
modify_layout(x, preset = NULL, row_groups = NULL)
```

## Arguments

- x:

  A `<mesa>` specification

- preset:

  One of `"adjustment"`, `"levels"`, or `"interaction"`

- row_groups:

  The row-group dimension: `"outcome"` or `"strata"`

## Value

The modified `<mesa>` specification.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md),
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
