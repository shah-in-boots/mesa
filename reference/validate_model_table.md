# Model table object validation

Runs on every construction: the invariant columns must be present with
their expected types (see the Invariant columns section of
[model_table](https://shah-in-boots.github.io/mesa/reference/model_table.md)).

## Usage

``` r
validate_model_table(x)
```

## Arguments

- x:

  data frame that will have invariants checked
