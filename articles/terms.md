# 1. Terms and Causal Roles

``` r

library(mesa)
#> Loading required package: vctrs
#> Loading required package: tibble
#> 
#> Attaching package: 'tibble'
#> The following object is masked from 'package:vctrs':
#> 
#>     data_frame
```

[mesa](https://shah-in-boots.github.io/mesa/) is built from an
epistemological perspective: small building blocks that build up to more
complex concepts. The smallest block is the **term** — a single
variable, carrying not just its name but its causal identity. This
vignette covers layer 1 of the grammar: what a term is, the roles it can
play, and how it learns about the data it will eventually be fit
against.

## A term is more than a name

A plain `R` formula only knows a variable’s *position* — left of the
tilde or right of it. It has no way to say that `wt` is the exposure
whose effect you care about, that `cyl` is a confounder you are
adjusting for, or that `am` defines subpopulations you want fit
separately. The `tm` class fills that gap.

``` r

t <- tm(mpg ~ wt + hp)
t
#> <term[3]>
#> mpg
#> wt
#> hp
```

Printed, a `tm` vector looks almost like the formula it came from — but
every element already carries a role (here, everything but `mpg`
defaulted to `predictor`, and `mpg` was inferred as the `outcome` from
its position on the left-hand side).

## The role taxonomy

Roles are causal, and they are first-class: a term’s role is knowable,
updatable, and visibly changes what happens downstream — how formulas
expand (\[fmls()\]), how models are fit (\[fit()\]), and how results are
labeled once they reach a table (\[mesa()\]).

``` r

term_roles()
#> $outcome
#> [1] ".o"
#> 
#> $exposure
#> [1] ".x"
#> 
#> $predictor
#> [1] ".p"
#> 
#> $confounder
#> [1] ".c"
#> 
#> $mediator
#> [1] ".m"
#> 
#> $strata
#> [1] ".s"
#> 
#> $interaction
#> [1] ".i"
#> 
#> $random
#> [1] ".r"
```

| Role | Shortcut | Definition | Downstream behavior |
|----|----|----|----|
| outcome | `.o(...)` | the dependent variable; the effect being studied | anchors the left-hand side; multiple outcomes multiply the formula family |
| exposure | `.x(...)` | the variable whose causal effect is under study | anchored in every expanded formula; pairs with interactions |
| predictor | `.p(...)` | a covariate with no asserted causal position | expanded by the chosen pattern (adjusted for, or rotated through) |
| confounder | `.c(...)` | a common cause of exposure and outcome | treated as a covariate; flagged for adjustment displays |
| mediator | `.m(...)` | on the causal pathway between exposure and outcome | triggers the mediation triad of formulas |
| interaction | `.i(...)` | a candidate effect modifier of the exposure | crossed with each exposure (`x:i`), grouped so the pair travels together |
| strata | `.s(...)` | a variable defining subpopulations for separate fits | not a covariate; [`fit()`](https://generics.r-lib.org/reference/fit.html) fits one model per stratum level |
| random | `.r(...)` | a grouping variable for random (hierarchical) effects | rendered as `(1 \| term)` for mixed-model engines |
| group | `.g(...)` | not a role, but a tier marker for terms that travel together | grouped terms enter and leave expanded formulas as one block |

A role is applied by wrapping the variable in its shortcut, right inside
the formula:

``` r

t <- tm(mpg ~ .x(wt) + hp + .c(cyl))
t
#> <term[4]>
#> mpg
#> wt
#> hp
#> cyl
describe(t, "role")
#> $mpg
#> [1] "outcome"
#> 
#> $wt
#> [1] "exposure"
#> 
#> $hp
#> [1] "predictor"
#> 
#> $cyl
#> [1] "confounder"
```

`hp` was left bare and defaulted to `predictor` — the role assumed for
any right-hand term with no asserted causal position, and the one a
pattern rotates through or adjusts for. Nothing about this is permanent:
roles are updated after the fact with \[update.tm()\], just like a label
is.

``` r

t2 <- update(t, role = hp ~ "confounder")
describe(t2, "role")
#> $mpg
#> [1] "outcome"
#> 
#> $wt
#> [1] "exposure"
#> 
#> $hp
#> [1] "confounder"
#> 
#> $cyl
#> [1] "confounder"
```

## Transformations round-trip losslessly

Wrapping a term in a recognized transformation —
[`log()`](https://rdrr.io/r/base/Log.html),
[`sqrt()`](https://rdrr.io/r/base/MathFun.html),
[`scale()`](https://rdrr.io/r/base/scale.html),
[`factor()`](https://rdrr.io/r/base/factor.html),
[`ordered()`](https://rdrr.io/r/base/factor.html), polynomial and spline
markers — keeps the *full call* as the term’s name, so a formula
rebuilds exactly, without [mesa](https://shah-in-boots.github.io/mesa/)
needing to re-apply anything itself. The wrapper is additionally
recorded for downstream interpretation.

``` r

t3 <- tm(mpg ~ .x(log(wt)) + hp)
t3
#> <term[3]>
#> mpg
#> log(wt)
#> hp
describe(t3, "transformation")
#> $mpg
#> [1] NA
#> 
#> $`log(wt)`
#> [1] "log"
#> 
#> $hp
#> [1] NA
formula(t3)
#> mpg ~ log(wt) + hp
```

[`term_transformations()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
lists every wrapper [mesa](https://shah-in-boots.github.io/mesa/)
recognizes; an unrecognized call (`survival::Surv(time, status)`, say)
is carried whole as an opaque term rather than rejected.

## Meeting the data

A term’s role is knowable before it ever sees data, but its *shape* —
continuous or categorical, and which levels a categorical term actually
has — is not. \[set_data()\] is the “meet the data” step: it classifies
every term against a data frame and stamps `type`, `distribution`, and
`level` directly onto it.

``` r

d <- mtcars
d$cyl <- factor(d$cyl)

t4 <- tm(mpg ~ .x(wt) + hp + .c(cyl)) |> set_data(d)

# vctrs::vec_proxy() exposes a term vector's full attribute table
vctrs::vec_proxy(t4)[c("term", "role", "type", "level")]
#>   term       role        type   level
#> 1  mpg    outcome  continuous        
#> 2   wt   exposure  continuous        
#> 3   hp  predictor  continuous        
#> 4  cyl confounder categorical 4, 6, 8
```

`cyl` is now known to be categorical with three observed levels —
information the table layer (\[mesa()\]) later needs to decide how many
columns a categorical term needs and which level is the reference. A
transformed term classifies from its *underlying* variable:
[`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
looks through `log(wt)` to `wt` itself when deciding whether it is
continuous.

## Labeling

A term’s `label` is what a table eventually prints instead of its bare
variable name — set at creation, or rethought later with the same
\[update.tm()\] verb used for roles:

``` r

t5 <- update(t4, label = wt ~ "Weight (1000 lbs)")
describe(t5, "label")
#> $mpg
#> [1] NA
#> 
#> $wt
#> [1] "Weight (1000 lbs)"
#> 
#> $hp
#> [1] NA
#> 
#> $cyl
#> [1] NA
```

## What’s next

A single term is an atom; the next vignette,
[`vignette("formulas")`](https://shah-in-boots.github.io/mesa/articles/formulas.md),
covers how terms join into **families of formulas** — one model idea,
expanded by a pattern into the several formulas that idea implies.
