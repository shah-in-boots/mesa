# Extending `dplyr` for `tm` class

The [`filter()`](https://rdrr.io/r/stats/filter.html) function extension
subsets `tm` that satisfy set conditions. To be retained, the `tm`
object must produce a value of `TRUE` for all conditions. Note that when
a condition evaluates to `NA`, the row will be dropped, unlike base
subsetting with `[`.

## Usage

``` r
# S3 method for class 'tm'
filter(.data, ...)
```

## Arguments

- .data:

  A data frame, data frame extension (e.g. a tibble), or a lazy data
  frame (e.g. from dbplyr or dtplyr). See *Methods*, below, for more
  details.

- ...:

  \<[`data-masking`](https://rdrr.io/pkg/rlang/man/args_data_masking.html)\>
  Expressions that return a logical vector, defined in terms of the
  variables in `.data`. If multiple expressions are included, they are
  combined with the `&` operator. To combine expressions using `|`
  instead, wrap them in
  [`when_any()`](https://rdrr.io/pkg/dplyr/man/when-any-all.html). Only
  rows for which all expressions evaluate to `TRUE` are kept (for
  [`filter()`](https://rdrr.io/r/stats/filter.html)) or dropped (for
  `filter_out()`).

## Value

An object of the same type as `.data`. The output as the following
properties:

- `tm` objects are a subset of the input, but appear in the same order

- Underlying `data.frame` columns are not modified

- Underlying `data.frame` object's attributes are preserved

## See also

[`dplyr::filter()`](https://rdrr.io/pkg/dplyr/man/filter.html) for
examples of generic implementation
