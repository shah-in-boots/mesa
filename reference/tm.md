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
  level = list(),
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

  Specific roles the variable plays within the formula. Please see the
  *Roles* section for the taxonomy: outcome, exposure, predictor,
  confounder, mediator, interaction, strata, random, unknown.

- side:

  Which side of a formula should the term be on. Options are
  `c("left", "right", "meta", "unknown")`. The *meta* option refers to a
  term that may apply globally to other terms (e.g. strata, random
  effects).

- label:

  Display-quality label describing the variable

- group:

  Grouping variable name for modeling or placing terms together. An
  integer value is given to identify which group the term will be in.

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

  Modification of the term to be applied when combining with data. See
  [`term_transformations()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
  for the recognized vocabulary.

- level:

  The observed levels of a categorical term, given as a `character`
  vector (or a `list` of such vectors when creating several terms at
  once). Usually stamped on by
  [`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
  once a term has met a dataset.

## Value

A `tm` object, which is a series of individual terms with corresponding
attributes, including the role, formula side, label, grouping, levels,
and other related features.

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
how a formula is interpreted. Each role has a causal definition, and
each role changes behavior downstream — in how formulas expand
([`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)),
how models are fit
([`fit()`](https://generics.r-lib.org/reference/fit.html)), and how
results are displayed.

|  |  |  |  |
|----|----|----|----|
| Role | Shortcut | Definition | Downstream behavior |
| outcome | `.o(...)` | the dependent variable; the effect being studied | anchors the LHS; multiple outcomes multiply the formula family |
| exposure | `.x(...)` | the variable whose causal effect is under study | anchored in every expanded formula; pairs with interactions |
| predictor | `.p(...)` | a covariate with no asserted causal position | expanded by the chosen pattern (adjusted for, or rotated through) |
| confounder | `.c(...)` | a common cause of exposure and outcome | treated as a covariate; flagged for adjustment displays |
| mediator | `.m(...)` | on the causal pathway between exposure and outcome | triggers the mediation triad of formulas (see [`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)) |
| interaction | `.i(...)` | a candidate effect modifier of the exposure | crossed with each exposure (`x:i`), grouped so the pair travels together |
| strata | `.s(...)` | a variable defining subpopulations for separate fits | not a covariate; [`fit()`](https://generics.r-lib.org/reference/fit.html) fits one model per stratum level |
| random | `.r(...)` | a grouping variable for random (hierarchical) effects | rendered as `(1 \| term)` for mixed-model engines; excluded from covariate expansion |
| group | `.g(...)` | not a role, but a tier marker for terms that travel together | grouped terms enter and leave expanded formulas as one block |
| *unknown* | `-` | not yet assigned | treated as a predictor at expansion |

Formulas can be condensed by applying their specific role to individual
runes as a function/wrapper. For example, `y ~ .x(x1) + x2 + x3`. This
would signify that `x1` has the specific role of an *exposure*.

Grouped variables are slightly different in that they are placed
together in a hierarchy or tier. To indicate the group and the tier, the
shortcut can have an `integer` following the `.g` (multi-digit tiers
such as `.g10` are allowed). If no number is given, then it is assumed
they are all on the same tier (tier zero). Ex:
`y ~ x1 + .g1(x2) + .g1(x3)`

## Transformations

A term wrapped in a recognized transformation (see
[`term_transformations()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md))
keeps its full call as its name — `log(x)` remains `log(x)` so formulas
rebuild losslessly — and additionally records the wrapper in its
`transformation` field for downstream interpretation. Unrecognized calls
(e.g. `survival::Surv(time, status)`) are carried as opaque term names.

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

## Printing colors

Term printing uses ANSI colors from `cli`, so the user's console or IDE
theme chooses how each named color appears. Set
`options(mesa.color = FALSE)` to disable colors.
