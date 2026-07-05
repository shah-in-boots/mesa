# Create vectorized terms

**\[experimental\]**

## Usage

``` r
tm(x = unspecified(), ...)

# S3 method for class 'character'
tm(
  x,
  role = character(),
  side = character(),
  label = character(),
  group = integer(),
  type = character(),
  distribution = character(),
  description = character(),
  transformation = character(),
  ...
)

# S3 method for class 'formula'
tm(
  x,
  role = formula(),
  label = formula(),
  group = formula(),
  type = formula(),
  distribution = formula(),
  description = formula(),
  transformation = formula(),
  ...
)

# S3 method for class 'fmls'
tm(x, ...)

# S3 method for class 'tm'
tm(x, ...)

# Default S3 method
tm(x = unspecified(), ...)

is_tm(x)
```

## Arguments

- x:

  An object that can be coerced to a `tm` object.

- ...:

  Arguments to be passed to or from other methods

- role:

  Specific roles the variable plays within the formula. These are of
  particular importance, as they serve as special terms that can effect
  how a formula is interpreted. Please see the *Roles* section below for
  further details. The options for roles are as below:

  - outcome

  - exposure

  - predictor

  - confounder

  - mediator

  - interaction

  - strata

  - group

  - unknown

- side:

  Which side of a formula should the term be on. Options are
  `c("left", "right", "meta", "unknown")`. The *meta* option refers to a
  term that may apply globally to other terms.

- label:

  Display-quality label describing the variable

- group:

  Grouping variable name for modeling or placing terms together. An
  integer value is given to identify which group the term will be in.
  The hierarchy will be `1` to `n` incrementally.

- type:

  Type of variable, either categorical (qualitative) or continuous
  (quantitative)

- distribution:

  How the variable itself is more specifically subcategorized, e.g.
  ordinal, continuous, dichotomous, etc

- description:

  Option for further descriptions or definitions needed for the tm,
  potentially part of a data dictionary

- transformation:

  Modification of the term to be applied when combining with data

## Value

A `tm` object, which is a series of individual terms with corresponding
attributes, including the role, formula side, label, grouping, and other
related features.

## Details

A vectorized term object that allows for additional information to be
carried with the variable name.

This is not meant to replace traditional
[`stats::terms()`](https://rdrr.io/r/stats/terms.html), but to
supplement it using additional information that is more informative for
causal modeling.

## Roles

Specific roles the variable plays within the formula. These are of
particular importance, as they serve as special terms that can effect
how a formula is interpreted.

|             |           |                                       |
|-------------|-----------|---------------------------------------|
| Role        | Shortcut  | Description                           |
| outcome     | `.o(...)` | **outcome** ~ exposure                |
| exposure    | `.x(...)` | outcome ~ **exposure**                |
| predictor   | `.p(...)` | outcome ~ exposure + **predictor**    |
| confounder  | `.c(...)` | outcome + exposure ~ **confounder**   |
| mediator    | `.m(...)` | outcome **mediator** exposure         |
| interaction | `.i(...)` | outcome ~ exposure \* **interaction** |
| strata      | `.s(...)` | outcome ~ exposure / **strata**       |
| group       | `.g(...)` | outcome ~ exposure + **group**        |
| *unknown*   | `-`       | not yet assigned                      |

Formulas can be condensed by applying their specific role to individual
runes as a function/wrapper. For example, `y ~ .x(x1) + x2 + x3`. This
would signify that `x1` has the specific role of an *exposure*.

Grouped variables are slightly different in that they are placed
together in a hierarchy or tier. To indicate the group and the tier, the
shortcut can have an `integer` following the `.g`. If no number is
given, then it is assumed they are all on the same tier. Ex:
`y ~ x1 + .g1(x2) + .g1(x3)`

**Warning**: Only a single shortcut can be applied to a variable within
a formula directly.

## Pluralized Labeling Arguments

For a single argument, e.g. for the `tm.formula()` method, such as to
identify variable **X** as an exposure, a `formula` should be given with
the term of interest on the *LHS*, and the description or instruction on
the *RHS*. This would look like `role = "exposure" ~ X`.

For the arguments that would be dispatched for objects that are plural,
e.g. containing multiple terms, each
[`formula()`](https://rdrr.io/r/stats/formula.html) should be placed
within a [`list()`](https://rdrr.io/r/base/list.html). For example, the
**role** argument would be written:

`role = list(X ~ "exposure", M ~ "mediator", C ~ "confounder")`

Further implementation details can be seen in the implementation of
[`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md).
