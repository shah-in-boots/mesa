# Update `tm` objects

This updates properties or attributes of a `tm` vector. This only
updates objects that already exist.

## Usage

``` r
# S3 method for class 'tm'
update(object, ...)
```

## Arguments

- object:

  A `tm` object

- ...:

  A series of `field = term ~ value` pairs that represent the attribute
  to be updated. Can have a value of `NA` if the goal is to remove an
  attribute or property.

## Value

A `tm` object with updated attributes
