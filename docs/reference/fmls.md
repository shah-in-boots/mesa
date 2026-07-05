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
