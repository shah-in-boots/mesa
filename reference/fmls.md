# Vectorized formulas

This function defines a modified `formula` class that has been
vectorized. The `fmls` serves as a set of instructions or a *script* for
the formula and its tm. It expands upon the functionality of formulas,
allowing for additional descriptions and relationships to exist between
the tm.

## Usage

``` r
fmls(
  x = unspecified(),
  pattern = c("direct", "sequential", "parallel", "fundamental"),
  ...
)

is_fmls(x)

key_terms(x)
```

## Arguments

- x:

  Objects of the following types can be used as inputs

  - `tm`

  - `formula`

- pattern:

  A `character` from the following choices for pattern expansion. This
  is how the formula will be expanded, and decides how the covariates
  will incorporated. See the details for further explanation.

  - direct: the covariates will all be included in each formula

  - sequential: the covariates will be added sequentially, one by one,
    or by groups, as indicated

  - parallel: the covariates or groups of covariates will be placed in
    parallel

  - fundamental: every formula will be decomposed to a single outcome
    and predictor in an atomic fashion

- ...:

  Arguments to be passed to or from other methods

## Value

An object of class `fmls`

## Details

This is not meant to supersede a
[`stats::formula()`](https://rdrr.io/r/stats/formula.html) object, but
provide a series of relationships that can be helpful in causal
modeling. All `fmls` can be converted to a traditional `formula` with
ease. The base for this object is built on the
[`tm()`](https://shah-in-boots.github.io/mesa/reference/tm.md) object.

## Patterns

The expansion pattern allows for instructions on how the covariates
should be included in different formulas. Below, assuming that *x1*,
*x2*, and *x3* are covariates...

\$\$y = x1 + x2 + x3\$\$

**Direct**:

\$\$y = x1 + x2 + x3\$\$

**Seqential**:

\$\$y = x1\$\$ \$\$y = x1 + x2\$\$ \$\$y = x1 + x2 + x3\$\$

**Parallel**:

\$\$y = x1\$\$ \$\$y = x2\$\$ \$\$y = x3\$\$

New patterns can be registered by name through
[`register_pattern()`](https://shah-in-boots.github.io/mesa/reference/register_pattern.md).

## Mediation

When a term carries the *mediator* role (`.m()`), the expansion
generates the causal triad used to reason about mediation, alongside the
covariates already requested by the pattern:

1.  `outcome ~ exposure + mediator + covariates` — the exposure effect
    with the pathway through the mediator held open

2.  `mediator ~ exposure` — the exposure's effect on the mediator itself

3.  `outcome ~ mediator + exposure` — the mediator's effect on the
    outcome in the presence of the exposure

Comparing the exposure estimate across these formulas is what allows an
epidemiologist to judge how much of the total effect travels through the
mediator (per VanderWeele and Robins).

## Combining

Families of formulas combine with [`c()`](https://rdrr.io/r/base/c.html)
or [`vctrs::vec_c()`](https://vctrs.r-lib.org/reference/vec_c.html). The
term tables of each family are merged; when the same term arrives with
conflicting definitions (e.g. a plain predictor in one family and an
exposure in another), the first (left-most) definition wins and a
message reports the resolution.

## Roles

Specific roles the variable plays within the formula. These are of
particular importance, as they serve as special terms that can effect
how a formula is interpreted. Each role has a causal definition, and
each role changes behavior downstream — in how formulas expand
(`fmls()`), how models are fit
([`fit()`](https://generics.r-lib.org/reference/fit.html)), and how
results are displayed.

|  |  |  |  |
|----|----|----|----|
| Role | Shortcut | Definition | Downstream behavior |
| outcome | `.o(...)` | the dependent variable; the effect being studied | anchors the LHS; multiple outcomes multiply the formula family |
| exposure | `.x(...)` | the variable whose causal effect is under study | anchored in every expanded formula; pairs with interactions |
| predictor | `.p(...)` | a covariate with no asserted causal position | expanded by the chosen pattern (adjusted for, or rotated through) |
| confounder | `.c(...)` | a common cause of exposure and outcome | treated as a covariate; flagged for adjustment displays |
| mediator | `.m(...)` | on the causal pathway between exposure and outcome | triggers the mediation triad of formulas (see `fmls()`) |
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

## Pluralized Labeling Arguments

For a single argument, e.g. for the
[`tm.formula()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
method, such as to identify variable **X** as an exposure, a `formula`
should be given with the term of interest on the *LHS*, and the
description or instruction on the *RHS*. This would look like
`role = "exposure" ~ X`.

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
