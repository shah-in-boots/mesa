# Forest plot and table

Forest plots are usually ways to describe contrasting data, such as
between strata, or to show interaction (if present). We can show the
estimates of each parameter along a dichotomous subgroup, or we can show
the estimates of a primary exposure along a multitude of subgroups. This
function allows both methods (and some spectrum in between) to
demonstrate these.

## Usage

``` r
tbl_interaction_forest(
  object,
  outcomes = formula(),
  exposures = formula(),
  interactions = formula(),
  level_labels = formula(),
  columns = list(beta ~ "Estimate", conf ~ "95% CI", n ~ "No."),
  axis = list(scale ~ "continuous"),
  width = list(),
  forest = list(),
  exponentiate = FALSE,
  invert = FALSE,
  digits = 2,
  ...
)
```

## Arguments

- object:

  A `<mdl_tbl>` object with the required models. It must also contain
  the original dataset used to create the models of interest. Please see
  [`attach_data()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
  for details.

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

- axis:

  Argument to help modify the forest plot itself. This is a `<formula>`
  or list of formulas of the following parameters. If they are not
  named, the function will attempt to "guess" the optimal parameters.
  The options are:

  - title = label or title for the column describing the forest plot

  - lim = x-axis limits

  - breaks = x-axis tick marks or break points that should be numbers

  - int = x-axis intercept

  - lab = label for the x-axis

  - scale = defaults to continuous, but may also use a log
    transformation as well `c("continuous", "log")`

  For example: `list(title ~ "Decreasing Hazard", lab ~ "HR (95% CI))`

- width:

  Describes the width of each column in a `<formula>` or list of
  formulas. The **RHS** is a decimal reflecting the percent each column
  should take of the entire table. The forest plot is usually given 30%
  of the width. The default options attempt to be sensible. Options,
  indicated by the term on the -*LHS*\* of the formula, include:

  - n = Column describing number of observations

  - beta = Column of estimate and confidence intervals (usually
    combined)

  - forest = Column containing forest plots

  For example: `list(n ~ .1, forest ~ 0.3)`

- forest:

  A `<formula>` or list of formulas that can be used to help customize
  the forest plot prior to generation of the table. The options directly
  correspond to `ggplot2` aesthetic specifications that can modify the
  visual aspects of the forest plot. The currently supported arguments:

  - size = Relative size of the marker for point estimate

  - shape = Shape of the marker for point estimate

  - fill = Fill of the marker for point estimate

  - linetype = Vertical line that serves as the x-intercept across the
    table

  - linewidth = Thickness of lines, for both vertical and horixontal
    axes

- exponentiate:

  A `<logical>` value that determines if the point estimates should be
  exponentiated. This is useful for odds ratios or hazard ratios. It
  will apply to all estimate values, including confidence intervals, in
  a table. It is defaulted to `FALSE`.

- invert:

  A `<logical>` to determine if the odds or hazard ratio should be shown
  as the reciprocal values. Instead of a decreasing hazard for every
  unit increase, it describes an increasing hazard for every unit
  decrease. Default is `FALSE`

- digits:

  The number of significant figures to present. If the numbers are not
  scaled in a presentable fashion, can always adjust the table
  subsequently.

- ...:

  Additional arguments passed to methods.
