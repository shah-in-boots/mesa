# Model table helper functions

**\[experimental\]**

These functions manage and interrogate a `mdl_tbl` object – they are the
working verbs of the notebook of models:

- `attach_data()`: attaches a dataset to the table for later recall

- `model_failures()`: returns the models that were attempted but failed,
  with their error messages

- `term_table()`: the terms behind the table, as a `tm` vector with
  their causal roles

- `formula_matrix()`: the model-by-term membership matrix

- `model_data()`: the datasets attached to the table

See
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
for extracting parameter estimates.

## Usage

``` r
attach_data(x, data, name = NULL, ...)

model_failures(x, ...)

term_table(x, ...)

# S3 method for class 'mdl_tbl'
term_table(x, ...)

# S3 method for class 'fmls'
term_table(x, ...)

formula_matrix(x, ...)

# S3 method for class 'mdl_tbl'
formula_matrix(x, ...)

# S3 method for class 'fmls'
formula_matrix(x, ...)

model_data(x, name = NULL, ...)
```

## Arguments

- x:

  A `mdl_tbl` object (or, for `term_table()` and `formula_matrix()`, a
  `fmls` object)

- data:

  A `data.frame` object that has been used by models

- name:

  For `attach_data()`, the name to store the dataset under (defaults to
  the expression `data` was passed as); for `model_data()`, the name of
  a single attached dataset to return (when `NULL`, the full named list
  is returned)

- ...:

  Arguments to be passed to or from other methods

## Value

`attach_data()` returns the modified `mdl_tbl`; `model_failures()`
returns a `tibble` with one row per failed model and its `error`
message; `term_table()` returns a `tm` vector; `formula_matrix()`
returns a `tibble`; `model_data()` returns a named `list` of data frames
(or a single `data.frame` when `name` is given).

## Attaching Data

When models are built, oftentimes the included matrix of data is
available within the raw model, however when handling many models, this
can be expensive in terms of memory and space. By attaching datasets
independently that persist regardless of the underlying models, and by
knowing which models used which datasets, it can be easy to
back-transform information. The dataset is stored under the name it was
passed as (or an explicit `name`), and should match the `data_id` column
of the models that used it.
