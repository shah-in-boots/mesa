# 4. Fitting and Model Tables

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

A family of formulas is still just instructions. Layer 3 answers “what
happens when a formula meets data and a fitting approach?”
([`fit()`](https://generics.r-lib.org/reference/fit.html)), and layer 4
answers “how do I store, recall, and compare many models?” (`mdl_tbl`).
This vignette covers both, because in practice they are always used
together: fit, then collect.

``` r

d <- mtcars
d$cyl <- factor(d$cyl)
d$am <- factor(d$am, labels = c("Automatic", "Manual"))
```

## Fitting is plan-then-execute

[`fit()`](https://generics.r-lib.org/reference/fit.html) accepts a
family, a fitting function (`.fn`), and the data. It first builds an
inspectable plan — every formula crossed with every stratum level and
every subset — with
[`fit_plan()`](https://shah-in-boots.github.io/mesa/reference/fit_plan.md),
then executes it row by row:

``` r

f <- fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential")
fit_plan(f, data = d)
#> # A tibble: 3 × 7
#>   formula_index formula_call       formula   strata_variable strata_level subset
#>           <int> <chr>              <list>    <chr>           <list>       <chr> 
#> 1             1 mpg ~ wt           <formula> NA              <lgl [1]>    NA    
#> 2             2 mpg ~ wt + hp      <formula> NA              <lgl [1]>    NA    
#> 3             3 mpg ~ wt + hp + c… <formula> NA              <lgl [1]>    NA    
#> # ℹ 1 more variable: subset_expr <list>
```

`.fn` resolves **by name**, so argument order never matters, and it
accepts three things: a plain function (`lm`), a string naming one
(`"lm"`), or a [parsnip](https://github.com/tidymodels/parsnip) model
specification.

``` r

spec <- parsnip::linear_reg() |> parsnip::set_engine("lm")
fit(fmls(mpg ~ .x(wt) + hp), .fn = spec, data = d, raw = FALSE)
#> <model[1]>
#> lm(mpg ~ wt + hp)
```

## Wrapped models, not raw fits

`fit(..., raw = TRUE)` (the default) returns the plain list of fitted
objects the fitting function itself produces — useful for a quick look,
but nothing downstream can use it as a
[mesa](https://shah-in-boots.github.io/mesa/) object. `raw = FALSE`
wraps each fit into a `mdl` — the object that carries a model’s causal
context (its formula, its term roles, its degrees of freedom, its
variance–covariance matrix) alongside the fit itself:

``` r

m <- fit(f, .fn = lm, data = d, raw = FALSE)
m
#> <model[3]>
#> lm(mpg ~ wt)
#> lm(mpg ~ wt + hp)
#> lm(mpg ~ wt + hp + cyl)
```

## Collecting models: `mdl_tbl`

A single family already produces several models; a research project
produces many families.
[`model_table()`](https://shah-in-boots.github.io/mesa/reference/model_table.md)
(alias
[`mdl_tbl()`](https://shah-in-boots.github.io/mesa/reference/model_table.md))
is the notebook that stores them:

``` r

mt <- model_table(m, data = d)
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

The print leads with the fleet’s status at a glance — how many fitted,
how many failed, whether data is attached — then one line per model.
Passing `data =` attaches the fitting dataset, which the table remembers
for everything downstream that needs it (categorical levels, event
counts, the table layer in the next vignette).

[`summary()`](https://rdrr.io/r/base/summary.html) gives the aggregate
view: models grouped by dataset, fitting function, outcome, and
exposure, with their adjustment range and the terms by causal role.

``` r

summary(mt)
#> <model_table> summary: 3 models
#>   data  model  outcome  exposure  fitted  adjustment  strata
#>   d     lm     mpg      wt        3/3     1–3 terms   —     
#> 
#>   terms | outcome: mpg | exposure: wt | predictor: hp, cyl
```

## Stratified fits produce one model per level

A family stratified with
[`add_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md)
(see
[`vignette("playing")`](https://shah-in-boots.github.io/mesa/articles/playing.md))
is not fit once —
[`fit()`](https://generics.r-lib.org/reference/fit.html) fits one model
per stratum level automatically, and the level lands as provenance in
the table:

``` r

fs <- fmls(mpg ~ .x(wt) + hp) |> add_strata(am) |> set_data(d)
ms <- fit(fs, .fn = lm, data = d, raw = FALSE)
mts <- model_table(ms, data = d)
mts
#> <model_table> 2 models × 1 formula
#>   ✔ 2 fitted
#>   data: d [attached]
#>   strata: am
#> 
#>        model  formula        outcome  exposure  strata        n 
#>   ✔ 1  lm     mpg ~ wt + hp  mpg      wt        am=Manual     13
#>   ✔ 2  lm     mpg ~ wt + hp  mpg      wt        am=Automatic  19
#> # `summary()` maps the fleet; `flatten_models()` extracts estimates
```

`mdl_tbl` is a [dplyr](https://dplyr.tidyverse.org)-friendly tibble
subclass — [`filter()`](https://rdrr.io/r/stats/filter.html),
`select()`, `arrange()`, and `[` all work, and reconcile the table’s
internal attributes (the formula matrix, the term table, the attached
data) down to the rows that remain:

``` r

dplyr::filter(mts, level == "Manual")
#> <model_table> 1 model × 1 formula
#>   ✔ 1 fitted
#>   data: d [attached]
#>   strata: am
#> 
#>        model  formula        outcome  exposure  strata     n 
#>   ✔ 1  lm     mpg ~ wt + hp  mpg      wt        am=Manual  13
#> # `summary()` maps the fleet; `flatten_models()` extracts estimates
```

## Fitting fails softly

Twenty models in a batch should not sink because one formula references
a column that does not exist. A failure is recorded, not thrown:
`fit_status` is `FALSE`, the error is stored, and the fleet keeps its
shape.

``` r

fbad <- fmls(mpg ~ .x(wt) + not_a_real_column)
mbad <- fit(fbad, .fn = lm, data = d, raw = FALSE)
mtbad <- model_table(mbad, data = d)
mtbad
#> <model_table> 1 model × 1 formula
#>   ✖ 1 failed
#>   data: d [attached]
#> 
#>        model  formula                       outcome  exposure
#>   ✖ 1  lm     mpg ~ wt + not_a_real_column  mpg      wt      
#> # 1 model(s) failed: `model_failures()` shows why
#> # `summary()` maps the fleet; `flatten_models()` extracts estimates
model_failures(mtbad)
#> # A tibble: 1 × 8
#>   name  model_call formula_call                data_id strata level subset error
#>   <chr> <chr>      <chr>                       <chr>   <chr>  <chr> <chr>  <chr>
#> 1 NA    lm         mpg ~ wt + not_a_real_colu… d       NA     NA    NA     obje…
```

## Mixed models fit through the same interface

A family carrying a `.r()` random-effects term
([`vignette("playing")`](https://shah-in-boots.github.io/mesa/articles/playing.md))
fits directly through a mixed-model engine — no special-casing required:

``` r

fr <- fmls(mpg ~ .x(wt) + hp + .r(gear))
fit(fr, .fn = lme4::lmer, data = d, raw = FALSE)
#> boundary (singular) fit: see help('isSingular')
#> <model[1]>
#> lmerMod(mpg ~ wt + hp + (1 | gear))
```

## Extracting estimates: `flatten_models()`

`mdl_tbl` stores models;
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
unpacks them into one tidy row per coefficient, ready for analysis or a
quick look before building a publication table:

``` r

flatten_models(mt)[c("number", "term", "estimate", "conf_low", "conf_high", "p_value")]
#> # A tibble: 10 × 6
#>    number term        estimate conf_low conf_high  p_value
#>     <int> <chr>          <dbl>    <dbl>     <dbl>    <dbl>
#>  1      1 (Intercept)  37.3     33.5     41.1     8.24e-19
#>  2      1 wt           -5.34    -6.49    -4.20    1.29e-10
#>  3      2 (Intercept)  37.2     34.0     40.5     2.57e-20
#>  4      2 wt           -3.88    -5.17    -2.58    1.12e- 6
#>  5      2 hp           -0.0318  -0.0502  -0.0133  1.45e- 3
#>  6      3 (Intercept)  35.8     31.7     40.0     2.67e-16
#>  7      3 wt           -3.18    -4.66    -1.70    1.44e- 4
#>  8      3 hp           -0.0231  -0.0476   0.00140 6.36e- 2
#>  9      3 cyl6         -3.36    -6.24    -0.483   2.37e- 2
#> 10      3 cyl8         -3.19    -7.64     1.27    1.54e- 1
```

Exponentiation is inferred, not requested by name: a Cox model or a GLM
on a `log`/`logit`/`cloglog` link comes back as a ratio (hazard, odds,
or rate); everything else stays on the linear scale.
`exponentiate = TRUE/FALSE` overrides the inference when needed.

``` r

mOr <-
  fmls(am ~ .x(wt)) |>
  fit(.fn = glm, family = stats::binomial, data = d, raw = FALSE) |>
  model_table(data = d)

flatten_models(mOr)[c("term", "estimate", "exponentiated")]
#> Exponentiating estimates for 1 model(s) on a ratio scale (glm(logit)); use `exponentiate = FALSE` for the linear scale.
#> # A tibble: 2 × 3
#>   term           estimate exponentiated
#>   <chr>             <dbl> <lgl>        
#> 1 (Intercept) 169460.     TRUE         
#> 2 wt               0.0179 TRUE
```

## What’s next

A `mdl_tbl` full of fitted models is the raw material for a publication
table.
[`vignette("mesa")`](https://shah-in-boots.github.io/mesa/articles/mesa.md)
covers the last layer: laying those models out on the *mesa* itself,
built on [gt](https://gt.rstudio.com).
