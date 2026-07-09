# Render a `<mesa>` specification to a `{gt}` table

**\[experimental\]**

`as_gt()` realizes a
[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
specification: it resolves the recorded selection against the model
table, decorates each estimate with its term metadata, and emits a
`{gt}` table. On a bare specification it renders a minimal default –
each displayed term's point estimate and 95% confidence interval, with
adjustment sets on rows and outcomes as row groups.

## Usage

``` r
as_gt(x, ...)

# S3 method for class 'mesa'
as_gt(x, ...)
```

## Arguments

- x:

  A `<mesa>` specification (from
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md))

- ...:

  Passed to methods

## Value

A `gt_tbl` object.

## See also

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
