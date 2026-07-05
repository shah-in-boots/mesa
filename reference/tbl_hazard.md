# Table of hazard ratios

Function that takes a `<mdl_tbl>` object that includes survival-model
data, usually in the form of Cox proportional hazard models, and allows
them to be displayed.

## Usage

``` r
tbl_dichotomous_hazard(
  object,
  data,
  outcomes = formula(),
  followup = character(),
  terms = formula(),
  adjustment = formula(),
  rate_difference = FALSE,
  person_years = 100,
  ...
)

tbl_categorical_hazard(
  object,
  data,
  outcomes = formula(),
  followup = character(),
  terms = formula(),
  adjustment = formula(),
  rate_difference = FALSE,
  person_years = 100,
  ...
)
```

## Arguments

- object:

  A `<mdl_tbl>` object with the required models. It must also contain
  the original dataset used to create the models of interest. Please see
  [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  for details.

- data:

  The original dataset used to create the models of interest. The
  variables in the model must be contained within this dataset. This may
  also be attached

- outcomes:

  A `<formula>` or list of formulas selecting the outcome variables of
  interest. The **LHS** is always the name of the variable that will be
  selected. The **RHS** is the potential label for the output table.

- followup:

  Character vector naming the followup duration variable. Must be either
  same length as **outcomes** or be of length of 1 (which will be
  recycled).

- terms:

  A `<formula>` or list of formulas selecting the model terms that
  should be used. The **LHS** is always the name of the variable that
  will be selected. The **RHS** is the potential label for the output
  table.

- adjustment:

  A `<formula>` or list of formulas selecting adjustment levels to
  display. The **LHS** should identify the model number or adjustment
  set, and the **RHS** is the display label.

- rate_difference:

  If there are only two levels in the term, the rate difference between
  the levels will be calculated. Defaults to `FALSE`. Presumes a 95%
  confidence interval as the default. If `TRUE` will calculate the rate
  by the **person_years** provided.

- person_years:

  The length or duration of person-years to use. Is an integer, and
  usually is 10 or 100. Default is `100`, which would represent the
  incidence for every *100 person-years*. Argument only used if
  **rate_difference** is set to `TRUE`. Currently not working!

- ...:

  Additional arguments passed to methods.
