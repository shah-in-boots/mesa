# 2. Formulas and Patterns

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

Layer 2 of the grammar answers the question a single term cannot: how do
terms *combine*, and by what pattern do they expand? A `fmls`
(“formulas”) is a **family** — one model idea, expanded into every
formula that idea implies.

## From terms to a family

[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md) takes
the same rune-decorated formula \[tm()\] does, and expands it by a
**pattern**: the rule for how the covariates enter.

``` r

f <- fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential")
f
#> <fmls: 3 formulas>
#>   outcome: mpg
#>   exposure: wt
#> mpg ~ wt
#> mpg ~ wt + hp
#> mpg ~ wt + hp + cyl
```

The deck header up top is a summary — how many formulas, the outcome,
the exposure — the way a [ggplot2](https://ggplot2.tidyverse.org) plot
summarizes its layers. The formulas themselves come out with
\[formula()\]:

``` r

formula(f)
#> [[1]]
#> mpg ~ wt
#> 
#> [[2]]
#> mpg ~ wt + hp
#> 
#> [[3]]
#> mpg ~ wt + hp + cyl
```

## The patterns

Assuming `wt`, `hp`, and `cyl` are covariates alongside the exposure
`wt` (here doing double duty as both the exposure and a pattern input),
four built-in patterns answer “how many formulas, and what’s in each”:

- **`direct`** (the default): every covariate at once, one formula.
- **`sequential`**: covariates enter one at a time, each formula nesting
  the last — the classic “unadjusted, then progressively adjusted”
  table.
- **`parallel`**: one formula per covariate, each paired with the
  exposure — useful for screening many candidate adjustors
  independently.
- **`fundamental`**: every right-hand term, the exposure included,
  entirely alone and unadjusted — one formula per term, the univariate
  screen the other patterns build outward from.

``` r

formula(fmls(mpg ~ .x(wt) + hp + cyl, pattern = "direct"))
#> [[1]]
#> mpg ~ wt + hp + cyl
formula(fmls(mpg ~ .x(wt) + hp + cyl, pattern = "parallel"))
#> [[1]]
#> mpg ~ wt + hp
#> 
#> [[2]]
#> mpg ~ wt + cyl
formula(fmls(mpg ~ .x(wt) + hp + cyl, pattern = "fundamental"))
#> Using `fundamental` decomposition pattern: 
#> - Mediation term: NA
#> - Stratifying term: NA
#> [[1]]
#> mpg ~ wt
#> 
#> [[2]]
#> mpg ~ hp
#> 
#> [[3]]
#> mpg ~ cyl
```

[`formula_patterns()`](https://shah-in-boots.github.io/mesa/reference/vocabulary.md)
lists every pattern currently available — the four built-ins plus
anything registered:

``` r

formula_patterns()
#> [1] "direct"      "fundamental" "parallel"    "sequential"
```

## Interactions travel with their exposure

A term wrapped `.i()` is a candidate effect modifier. It is crossed with
the exposure automatically, and the pair is grouped so it travels
through the pattern together:

``` r

fi <- fmls(mpg ~ .x(wt) + .i(am))
#> Interaction term `am` was applied to exposure term `wt`
formula(fi)
#> [[1]]
#> mpg ~ wt + am + wt:am
```

## The mediation triad

A term wrapped `.m()` is not just adjusted for — its presence asks a
causal question, so
[`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
builds the three formulas an epidemiologist needs to reason about
mediation (VanderWeele and Robins 2007), instead of the one
`.x()`/`.c()` would produce:

``` r

fm <- fmls(mpg ~ .x(wt) + .m(qsec) + hp)
fm
#> <fmls: 3 formulas>
#>   outcome: mpg
#>   exposure: wt
#>   mediator: qsec
#> mpg ~ wt + qsec + hp
#> qsec ~ wt
#> mpg ~ wt + qsec
formula(fm)
#> [[1]]
#> mpg ~ wt + qsec + hp
#> 
#> [[2]]
#> qsec ~ wt
#> 
#> [[3]]
#> mpg ~ wt + qsec
```

1.  `mpg ~ wt + qsec + hp` — the exposure’s effect with the pathway
    through the mediator held open (adjusted for the mediator).
2.  `qsec ~ wt` — the exposure’s effect on the mediator itself.
3.  `mpg ~ wt + qsec` — the mediator’s effect on the outcome in the
    exposure’s presence.

Comparing the exposure’s estimate across (1) and (3) is what lets you
judge how much of the total effect travels through the mediator.

## Grouped terms move as one block

Terms that should always enter or leave a formula together — a set of
dummy-coded categories from one variable, say — are tagged with the same
`.g()` tier instead of being split apart by a `sequential` or `parallel`
pattern:

``` r

fg <- fmls(mpg ~ wt + .g1(hp) + .g1(cyl), pattern = "sequential")
formula(fg)
#> [[1]]
#> mpg ~ wt
#> 
#> [[2]]
#> mpg ~ wt + hp + cyl
```

`hp` and `cyl` enter the second formula together, as one adjustment
step, rather than one at a time.

## Combining families

Two families merge with [`c()`](https://rdrr.io/r/base/c.html) (or
[`vctrs::vec_c()`](https://vctrs.r-lib.org/reference/vec_c.html)); when
the same term arrives from both sides with conflicting definitions, the
left-most definition wins and a message names the resolution — never a
silent overwrite.

``` r

f1 <- fmls(mpg ~ .x(wt) + hp)
f2 <- fmls(mpg ~ .x(wt) + cyl)
formula(c(f1, f2))
#> [[1]]
#> mpg ~ wt + hp
#> 
#> [[2]]
#> mpg ~ wt + cyl
```

## Patterns are an open registry

The four built-ins are not a closed switch statement — a pattern is any
function from a `tm` vector to a formula-matrix precursor, and
[`register_pattern()`](https://shah-in-boots.github.io/mesa/reference/register_pattern.md)
adds one by name:

``` r

unadjusted <- function(x) {
  apply_fundamental_pattern(x)
}
register_pattern("unadjusted", unadjusted)
"unadjusted" %in% formula_patterns()
#> [1] TRUE

formula(fmls(mpg ~ .x(wt) + hp + cyl, pattern = "unadjusted"))
#> Using `fundamental` decomposition pattern: 
#> - Mediation term: NA
#> - Stratifying term: NA
#> [[1]]
#> mpg ~ wt
#> 
#> [[2]]
#> mpg ~ hp
#> 
#> [[3]]
#> mpg ~ cyl
```

## What’s next

A family of formulas is still just instructions — no data has been
consulted yet.
[`vignette("playing")`](https://shah-in-boots.github.io/mesa/articles/playing.md)
covers how a family learns about a dataset: strata, subsets, and random
effects, the tools that make working with
[mesa](https://shah-in-boots.github.io/mesa/) feel like *play*.
