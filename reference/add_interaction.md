# Add interaction rows to a `<mesa>`

**\[experimental\]**

`add_interaction()` puts effect modification on the mesa: one row per
level of each model's interaction variable, grouped by interaction term,
with the exposure's within-level estimate derived from the stored
coefficients and variance-covariance matrix by
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
— nothing is refit.

The block *defines* the rows of the table, so declaring it **implies**
the `"interaction"` layout: if no layout has been declared yet,
`add_interaction()` selects it (with a message); if
[`modify_layout()`](https://shah-in-boots.github.io/mesa/reference/modify_layout.md)
already declared a different preset, `add_interaction()` errors naming
the conflict rather than silently overriding it.
`modify_layout(preset = "interaction")` on its own — without
`add_interaction()` — still errors at realization, since the block is
what defines the rows. Its statistics carry two scopes: the per-level
cells (estimate/CI from
[`add_estimates()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md);
the per-level `n` from
[`add_n()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md),
which counts the attached data) are ordinary rows, while the single
across-levels interaction p-value is a *group-scoped* cell the renderer
floats over the level rows. A forest column
([`add_forest()`](https://shah-in-boots.github.io/mesa/reference/add_forest.md))
reads the same per-level estimates.

## Usage

``` r
add_interaction(x, conf_level = 0.95)
```

## Arguments

- x:

  A `<mesa>` specification (from
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md))

- conf_level:

  Confidence level of the within-level intervals

## Value

The modified `<mesa>` specification.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md),
[`modify_layout()`](https://shah-in-boots.github.io/mesa/reference/modify_layout.md),
[`estimate_interaction()`](https://shah-in-boots.github.io/mesa/reference/estimate_interaction.md)
