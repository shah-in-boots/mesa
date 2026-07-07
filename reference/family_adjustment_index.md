# The sequential adjustment index of every model row

Within an outcome x exposure (x strata x level x subset x data x model)
family, models are ordered by their adjustment degree (`number`, ties
broken by row order) and numbered `1, 2, 3, ...`. This index — not the
raw term count — is the identity an adjustment set is selected by, so
models with equal term counts stay distinct.

## Usage

``` r
family_adjustment_index(x)
```

## Value

An integer vector, one entry per row of `x`.
