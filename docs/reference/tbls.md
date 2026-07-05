# Extensions of `{gt}` package for multiple models

The related functions in this package combine multiple models to help
show the relationship between variables.

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

- exposures:

  A `<formula>` or list of formulas of strata that should be evaluated,
  with the **LHS** referring to the strata and the **RHS** referring to
  its label.

- interactions:

  A `<formula>` or list of formulas of the interaction terms that should
  be evaluated, with the **LHS** referring to the term and the **RHS**
  referring to its label. Currently only supports binary interaction
  terms.

- strata:

  A `<formula>` or list of formulas of strata that should be evaluated,
  with the **LHS** referring to the strata and the **RHS** referring to
  its label.

- level_labels:

  A `<formula>` or list of formulas where each list-element is a formula
  with the **LHS** reflecting either the variable to re-label or a
  specific level, and the **RHS** reflecting what the new level should
  be called (for display). If there are conflicting labels, the most
  recent will be used.

  For example, `list(am ~ c("Manual", "Automatic")` would take, from the
  `mtcars` dataset, the `am` variable, which consists of `c(0, 1)`, and
  relabel them in the order described. They are sorted in ascendinng
  order prior to re-labeling.

  The alternative approach is to use the specific level itself and have
  it re-labeled. `list(0 ~ "Absent")` would take all levels that are
  zero, and change their value.

- terms:

  A `<formula>` or list of formulas selecting the model terms that
  should be used. The **LHS** is always the name of the variable that
  will be selected. The **RHS** is the potential label for the output
  table.

- adjustment:

  A `<formula>` or list of formulas selecting adjustment levels to
  display. The **LHS** should identify the model number or adjustment
  set, and the **RHS** is the display label.

- columns:

  Columns that help to describe the individual terms of a model.
  Generally describes the statistical estimates or properties of an
  exposure term. At least one column should likely be selected from this
  list. The sequence listed will reflect the sequence shown in the
  table. This is given as a `<formula>` or list of formulas, with the
  **LHS** is the name of an acceptable variable, and the **RHS** is the
  potential column label. The current options are:

  - beta = point estimate value, such as odds ratio or hazard ratio

  - conf = inclusion of the confidence interval (presumed to be
    ~95%-ile)

  - n = number of observations in each group or subset

  - p = p_value for model or interaction term

  For example: `list(beta ~ "Hazard", conf ~ "95% CI" n ~ "No.")"`

  Notably, the columns do not describe the terms, but the data contained
  in the rows below. The `terms` and `level_labels` arguments serve as
  the spanning labels for the related columns. Please see
  [`gt::tab_spanner()`](https://rdrr.io/pkg/gt/man/tab_spanner.html) for
  more information on how spanners work.

- accents:

  A `<formula>` or list of formulas that provide instructions on how to
  emphasize or accentuate certain data cells within the table. Similar
  to the `columns` argument, the **LHS** refers to the data available in
  the columns, such as the *p* or *beta* value, but is stated as a
  criteria, e.g. `p < 0.05`. The **RHS** is the instruction on what type
  of accentuation to perform. This applies to *ALL* data columns of the
  table, if the criteria are met.

  The **LHS** options are:

  - beta = point estimate value

  - conf_low = lower bound of the confidence interval

  - conf_high = upper bound of the confidence interval

  - p = p-value for a model term

  The current **RHS** options are:

  - bold = apply bold labeling to text

- suppress_column_labels:

  A `<logical>` value that determines if the column labels should be
  suppressed and replaced by the term labels.

  This defaults to `TRUE` when only a single column label is chosen. In
  this case, the individual term level labels are used, which are
  obtained either explicitly through the **level_labels** argument or
  through the default levels from the original data.

  If multiple columns are chosen to be displayed, then the column labels
  by default are retained (argument is `FALSE`). Occasionally, several
  columns will be initially selected and subsequently *hidden* by the
  user such that only a single column (per term) remains. This is a use
  case to force the column labels to be suppressed.

- exponentiate:

  A `<logical>` value that determines if the point estimates should be
  exponentiated. This is useful for odds ratios or hazard ratios. It
  will apply to all estimate values, including confidence intervals, in
  a table. It is defaulted to `FALSE`.

- ...:

  Additional arguments passed to methods.

## Details

The extensions that combine the modeling functions of the `{mesa}`
package and table-making functions of the `{gt}` package require some
conventions to simplify the process. These conventions are listed and
explained below.

## Formula inputs

When providing pluralized arguments, such as for **outcomes**,
**exposures**, **interactions**, and **strata**, both the variable
itself and its potential label are of interest. These *labeled formulas*
are handled generally by the function
[`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md)
The input types are (in order of preference/informativity):

- `<list>` of `<formula>` objects: The **LHS** is always the name of the
  variable that will be selected. The **RHS** is the potential label for
  the output table.

- `<formula>` object

- `<character>` vector
