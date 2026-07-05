# Describe attributes of a `tm` vector

Describe attributes of a `tm` vector

## Usage

``` r
describe(x, property)
```

## Arguments

- x:

  A vector `tm` objects

- property:

  A character vector of the following attributes of a `tm` object: role,
  side, label, group, description, type, distribution

## Value

A list of `term = property` pairs, where the term is the name of the
element (e.g. could be the \`role' of the term).

## Examples

``` r
f <- .o(output) ~ .x(input) + .m(mediator) + random
t <- tm(f)
describe(t, "role")
#> $output
#> [1] "outcome"
#> 
#> $input
#> [1] "exposure"
#> 
#> $mediator
#> [1] "mediator"
#> 
#> $random
#> [1] "predictor"
#> 
```
