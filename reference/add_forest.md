# Add a forest column to a `<mesa>`

**\[experimental\]**

`add_forest()` appends a forest-plot column block to a
[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
specification — available to any table, not just interaction tables. Its
cells *read* the estimate and interval already on the specification and
compute nothing new, so the block requires `estimate` + `conf`
statistics (the bare default carries them; an
[`add_estimates()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md)
block must keep them).

Per the grammar, the block is resolved at render: forest cells enter the
cell frame as plain numbers,
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
resolves one shared x-scale across the whole column (limits, intercept,
breaks, log versus linear — with `axis` overriding the guesses), draws
each cell, and emits the bottom axis strip as a reserved row after every
row group. Adding or dropping the block never changes any other cell.

The block's dense look (zero vertical padding, borderless plot cells)
enters as *defaults* to the style layer;
[`modify_style()`](https://shah-in-boots.github.io/mesa/reference/modify_style.md)'s
`padding` overrides it.

## Usage

``` r
add_forest(x, axis = list(), width = 100, invert = FALSE)
```

## Arguments

- x:

  A `<mesa>` specification (from
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md))

- axis:

  Options overriding the guessed x-scale, as a named list: `limits`
  (length-2 numeric), `breaks` (numeric), `intercept` (the reference
  line), and `log` (`TRUE` for a log scale)

- width:

  Width of the drawn cells, in pixels

- invert:

  Show reciprocal estimates: each cell draws `1 / estimate` with the
  interval bounds swapped and inverted, so a protective ratio reads as
  risk (and vice versa). The axis mirrors with the cells, since the
  shared scale is resolved from the drawn values.

## Value

The modified `<mesa>` specification.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md),
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md),
[`add_estimates()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md)
