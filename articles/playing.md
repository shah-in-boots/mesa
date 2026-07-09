# 3. Playing with Data

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

The feeling [mesa](https://shah-in-boots.github.io/mesa/) is meant to
give is *fluidity* — picking terms up off a dataset and playing with the
modeling: swap strata, add a random effect, subset the data, roll an
interaction through, and watch the family of models unfold. This
vignette covers the fluent verb layer that makes that possible, and
\[set_data()\], the step where a family finally meets a dataset.

``` r

d <- mtcars
d$cyl <- factor(d$cyl)
d$am <- factor(d$am, labels = c("Automatic", "Manual"))
```

## The fluent verbs

Every verb here is pipeable, and every one returns a modified `fmls` —
so they compose into a single readable chain, the way
[dplyr](https://dplyr.tidyverse.org) verbs do.

``` r

f <- fmls(mpg ~ .x(wt) + hp)

f |>
  add_strata(am) |>
  add_terms(cyl) |>
  subset_data(disp > 100)
#> <fmls: 1 formula>
#>   outcome: mpg
#>   exposure: wt
#>   strata: am
#>   subsets: disp > 100
#> mpg ~ wt + hp + cyl
```

- **[`add_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  /
  [`remove_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)**
  promote a term to (or release it from) the `strata` role. A stratified
  family is not fit once —
  [`fit()`](https://generics.r-lib.org/reference/fit.html) fits one
  model per stratum level, automatically.
- **[`add_terms()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
  /
  [`remove_terms()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)**
  add or drop covariates from every formula in the family at once.
- **[`swap_outcome()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)**
  exchanges one outcome for another, keeping the rest of the family —
  its exposure, its covariates, its pattern — intact. Either
  `old ~ new`, or a bare replacement name when the family has a single
  outcome.
- **[`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)**
  records data-filtering instructions — plain logical expressions in the
  data’s variables — that
  [`fit()`](https://generics.r-lib.org/reference/fit.html) applies
  later, fitting the family once per subset. The filter is not applied
  here; it is *recorded* as an instruction, the same way a stratum level
  is.

``` r

f |> swap_outcome(qsec)
#> <fmls: 1 formula>
#>   outcome: qsec
#>   exposure: wt
#> qsec ~ wt + hp
```

## Meeting the data

Everything above is structural — roles, strata, subsets — decided before
any dataset is consulted. \[set_data()\] is the step where a family
actually meets one: it classifies every term’s `type` and
`distribution`, and — this is the detail that matters for strata —
stamps the *observed levels* onto any categorical term, strata included.

Call it **last**, after the roles it needs to classify are already
assigned:

``` r

f2 <-
  fmls(mpg ~ .x(wt) + hp) |>
  add_strata(am) |>
  set_data(d)

f2
#> <fmls: 1 formula>
#>   outcome: mpg
#>   exposure: wt
#>   strata: am (2 levels)
#> mpg ~ wt + hp
```

The deck header now reads `strata: am (2 levels)` — before a single
model has been fit, the family already knows how many models a
stratified fit will produce. Calling
[`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
*before*
[`add_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
would classify `am` as a plain predictor first, so the strata levels
would not appear;
[`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
reflects the roles that exist at the moment it runs, which is why it
reads naturally as the last step in a chain of structural verbs.

## Subsets are not a role

A filter like `am == "Manual"` is not a variable in the formula — it is
an instruction about the data, so
[`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
deliberately does not reuse any of the causal roles. It records the
instruction on the family, prints in the deck header, and expands the
fitting plan exactly like a stratum level does: one model per subset
(and, combined with strata, one per stratum-by-subset combination).

``` r

f3 <-
  fmls(mpg ~ .x(wt) + hp) |>
  subset_data(am == "Manual", cyl == 4) |>
  set_data(d)

f3
#> <fmls: 1 formula>
#>   outcome: mpg
#>   exposure: wt
#>   subsets: am == "Manual", cyl == 4
#> mpg ~ wt + hp
```

## Random effects

Random (hierarchical) grouping is a role like any other — `.r()` — and
it composes, prints, and rebuilds into the `(1 | term)` syntax
mixed-model engines expect.
[mesa](https://shah-in-boots.github.io/mesa/) also parses that native
`lme4` syntax directly, so both spellings land on the same term:

``` r

fr <- fmls(mpg ~ .x(wt) + hp + .r(gear))
formula(fr)
#> [[1]]
#> mpg ~ wt + hp + (1 | gear)

fr_native <- fmls(mpg ~ .x(wt) + hp + (1 | gear))
identical(formula(fr), formula(fr_native))
#> [1] TRUE
```

Unlike a plain covariate, a random-effects term is excluded from
covariate *expansion* — a `sequential` or `parallel` pattern never
rotates it in or out the way it does `hp` or `cyl` — but it rides along
on every formula the pattern produces.

## What’s next

A family that knows its strata, its subsets, and the shape of its data
is ready to actually meet a fitting function.
[`vignette("fitting")`](https://shah-in-boots.github.io/mesa/articles/fitting.md)
covers [`fit()`](https://generics.r-lib.org/reference/fit.html), the
plan it builds, and the `mdl_tbl` collection that stores the resulting
models.
