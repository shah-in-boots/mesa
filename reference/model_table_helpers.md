# Model table helper functions

**\[experimental\]**

These functions are used to help manage the `mdl_tbl` object. They allow
for specific manipulation of the internal components, and are intended
to generally extend the functionality of the object.

- `attach_data()`: Attaches a dataset to a `mdl_tbl` object

- `flatten_models()`: Flattens a `mdl_tbl` object down to its specific
  parameters

## Usage

``` r
attach_data(x, data, ...)

flatten_models(x, exponentiate = FALSE, which = NULL, ...)
```

## Arguments

- x:

  A `mdl_tbl` object

- data:

  A `data.frame` object that has been used by models

- ...:

  Arguments to be passed to or from other methods

- exponentiate:

  A `logical` value that determines whether to exponentiate the
  estimates of the models. Default is `FALSE`. If `TRUE`, the user can
  specify which models to exponentiate by name using the **which**
  argument.

- which:

  A `character` vector of model names to exponentiate. Default is
  `NULL`. If **exponentiate** is set to `TRUE` and **which** is set to
  `NULL`, then all estimates will be exponentiated, which is often a
  *bad idea*.

## Value

When using `attach_data()`, this returns a modified version of the
`mdl_tbl` object however with the dataset attached. When using the
`flatten_models()` function, this returns a simplified `data.frame` of
the original model table that contains the model-level and
parameter-level statistics.

## Attaching Data

When models are built, oftentimes the included matrix of data is
available within the raw model, however when handling many models, this
can be expensive in terms of memory and space. By attaching datasets
independently that persist regardless of the underlying models, and by
knowing which models used which datasets, it can be ease to
back-transform information.

## Flattening Models

A `mdl_tbl` object can be flattened to its specific parameters, their
estimates, and model-level summary statistics. This function
additionally helps by allowing for exponentiation of estimates when
deemed appropriate. The user can specify which models to exponentiate by
name. This heavily relies on the
[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html)
functionality.
