# mesa

[mesa](https://shah-in-boots.github.io/mesa/) is a grammar for causal
modeling in R: pick terms up off a dataset, give them causal roles,
watch a family of formulas unfold, fit them, and lay the results out on
the *mesa* — the table upon which the models are displayed. It is built
from an epistemological perspective: small building blocks that build up
to more complex concepts.

| Layer | Class | Question it answers |
|----|----|----|
| 1\. Terms | `tm` | What is this variable, and what role does it play? |
| 2\. Formulas | `fmls` | How do terms combine, and by what pattern do they expand? |
| 3\. Models | `mdl` | What happens when a formula meets data and a fitting approach? |
| 4\. Collections | `mdl_tbl` | How do I store, recall, and compare many models? |
| 5\. Tables | `mesa` | How do I lay the models out for a paper? |

Where the ecosystem already solves a problem,
[mesa](https://shah-in-boots.github.io/mesa/) leans on it rather than
reinvent it: [parsnip](https://github.com/tidymodels/parsnip) defines
models, [broom](https://broom.tidymodels.org/) tidies them,
[gt](https://gt.rstudio.com) renders tables.
[mesa](https://shah-in-boots.github.io/mesa/)’s own contribution is the
causal grammar that connects them — variables have *roles* (exposure,
outcome, confounder, mediator, interaction, strata), and those roles
carry meaning that shapes how formulas expand, how models are fit, and
how results are displayed.

## Installation

The development version can be installed from
[GitHub](https://github.com/shah-in-boots/mesa). Once
[mesa](https://shah-in-boots.github.io/mesa/) is accepted on CRAN, it
can be installed from CRAN as well.

``` r

# Development version
remotes::install_github("shah-in-boots/mesa")
# CRAN installation after release
install.packages("mesa")
```

## One dataset, one causal question

Does a car’s weight (`wt`) predict its fuel economy (`mpg`), and does
that relationship hold once engine power (`hp`) and cylinder count
(`cyl`) are taken into account? That is a causal question — `wt` is the
*exposure*, `hp`/`cyl` are *confounders* — and
[mesa](https://shah-in-boots.github.io/mesa/) is built to carry that
framing all the way from the formula to the published table.

**Terms** carry roles right inside the formula, with a rune for each one
(`.x()` for exposure, `.c()` for confounder, and more — see
[`vignette("terms")`](https://shah-in-boots.github.io/mesa/articles/terms.md)):

``` r

library(mesa)
#> Loading required package: vctrs
#> Loading required package: tibble
#> 
#> Attaching package: 'tibble'
#> The following object is masked from 'package:vctrs':
#> 
#>     data_frame

d <- mtcars
d$cyl <- factor(d$cyl)
```

**Formulas** expand a single causal idea into the family it implies —
here, `pattern = "sequential"` builds the
unadjusted-then-progressively-adjusted formulas a table like this one
usually wants
([`vignette("formulas")`](https://shah-in-boots.github.io/mesa/articles/formulas.md)):

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

**Models** are fit through one interface, whatever the fitting function
([`vignette("fitting")`](https://shah-in-boots.github.io/mesa/articles/fitting.md)),
and **collections** hold the resulting fleet with its causal context
intact:

``` r

mt <-
  f |>
  fit(.fn = lm, data = d, raw = FALSE) |>
  model_table(data = d)
mt
#> <model_table> 3 models × 3 formulas
#>   ✔ 3 fitted
#>   data: d [attached]
#> 
#>        model  formula              outcome  exposure  n 
#>   ✔ 1  lm     mpg ~ wt             mpg      wt        32
#>   ✔ 2  lm     mpg ~ wt + hp        mpg      wt        32
#>   ✔ 3  lm     mpg ~ wt + hp + cyl  mpg      wt        32
#> # `summary()` maps the fleet; `flatten_models()` extracts estimates
```

**Tables** grow one decision at a time — narrow the selection, add a
column of statistics, relabel a term — and
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
renders the specification through [gt](https://gt.rstudio.com)
([`vignette("mesa")`](https://shah-in-boots.github.io/mesa/articles/mesa.md)):

``` r

spec <-
  mt |>
  mesa() |>
  select_adjustment(1 ~ "Unadjusted", 3 ~ "Adjusted") |>
  add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI")) |>
  modify_labels(wt ~ "Weight (1000 lbs)")
spec
#> <mesa> specification: 3 fitted models × lm
#>   data: d
#>   layout: adjustment (rows: adjustment sets, groups: outcomes)
#>   selection:
#>     adjustment: 1, 3
#>   columns: estimates (beta + conf)
#>   labels: wt
#> 
#> # `as_gt()` renders; `select_*()` / `modify_labels()` refine the mesa
```

Printing the specification shows what’s on the mesa without rendering
anything — `spec |> as_gt()` is the one call that turns it into the
[gt](https://gt.rstudio.com) table itself (see it rendered in
[`vignette("mesa")`](https://shah-in-boots.github.io/mesa/articles/mesa.md)).

That is the whole arc: terms to table, one causal question all the way
through. The same grammar handles stratified fits, random effects,
mediation triads, and effect-modification tables with a forest-plot
column — each covered in its own vignette, and the reasoning behind the
role vocabulary itself (Hill, Pearl, VanderWeele) has one too.

## Learn more

- [`vignette("terms")`](https://shah-in-boots.github.io/mesa/articles/terms.md)
  — terms and causal roles
- [`vignette("formulas")`](https://shah-in-boots.github.io/mesa/articles/formulas.md)
  — formulas and patterns
- [`vignette("playing")`](https://shah-in-boots.github.io/mesa/articles/playing.md)
  — strata, subsets, and random effects
- [`vignette("fitting")`](https://shah-in-boots.github.io/mesa/articles/fitting.md)
  — fitting and model tables
- [`vignette("mesa")`](https://shah-in-boots.github.io/mesa/articles/mesa.md)
  — making the mesa (the [gt](https://gt.rstudio.com) layer)
- [`vignette("causal-reasoning")`](https://shah-in-boots.github.io/mesa/articles/causal-reasoning.md)
  — the causal reasoning behind the grammar

The full design history lives in
[`blueprint.md`](https://github.com/shah-in-boots/mesa/blob/main/blueprint.md)
(the milestone map) and
[`DESIGN.md`](https://github.com/shah-in-boots/mesa/blob/main/DESIGN.md)
(the decisions made along the way), with a narrative version in the
[development
log](https://shah-in-boots.github.io/mesa/articles/development.html)
article.
