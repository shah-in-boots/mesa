# Data summarization and classification methods

These related functions are intended to analyze a single data vector
(e.g. column from a dataset) and help predict its classification, or
other relevant attributes. These are simple yet opionated convenience
functions.

## Usage

``` r
number_of_missing(x)

is_dichotomous(x)
```

## Arguments

- x:

  A vector of any of the atomic types (see
  \[[`base::vector()`](https://rdrr.io/r/base/vector.html)\])

## Value

Returns a single value determined by the individual functions

## Details

The functions that are currently supported are:

- `number_of_missing()` returns the number of missing values in a vector

- `is_dichotomous()` returns TRUE if the vector is dichotomous, FALSE
  otherwise
