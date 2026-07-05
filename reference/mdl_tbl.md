# Model tables

**\[experimental\]**

The `model_table()` or `mdl_tbl()` function creates a `mdl_tbl` object
that is composed of either `fmls` objects or `mdl` objects, which are
thin/informative wrappers for generic formulas and hypothesis-based
models. The `mdl_tbl` is a data frame of model information, such as
model fit, parameter estimates, and summary statistics about a model, or
a formula if it has not yet been fit.

## Usage

``` r
mdl_tbl(..., data = NULL)

model_table(..., data = NULL)

is_model_table(x)
```

## Arguments

- ...:

  Named or unnamed `mdl` or `fmls` objects

- data:

  A `data.frame` or `tbl_df` object, named correspondingly to the
  underlying data used in the models (to help match)

- x:

  A `mdl_tbl` object

## Value

A `mdl_tbl` object, which is essentially a `data.frame` with additional
information on the relevant data, terms, and formulas used to generate
the models.

## Details

The table itself allows for ease of organization of model information
and has three additional, major components (stored as scalar
attributes).

1.  A formula matrix that describes the terms used in each model, and
    how they are combined.

2.  A term table that describes the terms and their properties and/or
    labels.

3.  A list of datasets used for the analyses that can help support
    additional diagnostic testing.

We go into further detail in the sections below.

## Data List

The `dataList` attribute stores datasets attached to the model table for
later summaries and table-building workflows.

## Term Table

The `termTable` attribute stores terms and their roles, labels, groups,
and other metadata used to reconstruct model context.

## Formula Matrix

The `formulaMatrix` attribute stores the relationship between formulas
and terms represented in the model table.
