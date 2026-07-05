# Getting Started

The package is simple to use. First, lets load the basic packages.

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

The `mtcars` dataset will serve as the example, and we will use linear
regressions as the primary test. Next, we will evaluate a toy dataset
and evaluate how a `fmls` object is generated.

``` r

# Look at potential data from the `mtcars` dataset
head(mtcars)
#>                    mpg cyl disp  hp drat    wt  qsec vs am gear carb
#> Mazda RX4         21.0   6  160 110 3.90 2.620 16.46  0  1    4    4
#> Mazda RX4 Wag     21.0   6  160 110 3.90 2.875 17.02  0  1    4    4
#> Datsun 710        22.8   4  108  93 3.85 2.320 18.61  1  1    4    1
#> Hornet 4 Drive    21.4   6  258 110 3.08 3.215 19.44  1  0    3    1
#> Hornet Sportabout 18.7   8  360 175 3.15 3.440 17.02  0  0    3    2
#> Valiant           18.1   6  225 105 2.76 3.460 20.22  1  0    3    1

baseFormula <- mpg ~ wt + hp
rFormula <- fmls(mpg ~ wt + hp)

# Similar to the base formula
rFormula
#> mpg ~ wt + hp
```

Now we can fit the hypothesis to its data - in this case, a simple
linear regression. The option to return the model as raw or not is
given. If `TRUE`, the default, then the expected result from the
modeling fit will be returned in the form of a list of models, based on
the fitting function provided.

``` r

# Uses a custom fit function to return linear models
listModels <-
  rFormula |>
  fit(.fn = lm, data = mtcars, raw = TRUE)
```

For our purposes though, we want to use the custom fit method, which
retains more key information. This creates a `mdl` object, which is
simply a wrapper around base or package-specific models.

``` r

# Uses a custom fit function 
rModel <-
  rFormula |>
  fit(.fn = lm, data = mtcars, raw = FALSE)

rModel
#> <model[1]>
#> lm(mpg ~ wt + hp)
```

The model wrapper is helpful in that it can be unpacked into a table of
elements, which then stores our model for later usage in a research
workflow. For this purpose, we introduce the `mdl_tbl` class, which
another core class with specific and generic dispatch methods.

``` r

# An additional model to work with
r2Model <-
  fmls(am ~ cyl + hp, pattern = "sequential") |>
  fit(.fn = glm, family = "binomial", data = mtcars, raw = FALSE)

# Displays the two additional logistic regressions performed
r2Model
#> <model[2]>
#> glm(am ~ cyl)
#> glm(am ~ cyl + hp)

# Creation of a table of models
rTable <- model_table(mileage = rModel, automatic = r2Model)
rTable
#> <mdl_tbl>
#>   id        formula_index data_id name  model_call formula_call outcome exposure
#>   <chr>     <list>        <chr>   <chr> <chr>      <chr>        <chr>   <chr>   
#> 1 1c2e19cd… <int [3]>     mtcars  mile… lm         mpg ~ wt + … mpg     NA      
#> 2 26faf921… <dbl [3]>     mtcars  auto… glm        am ~ cyl     am      NA      
#> 3 3421e656… <dbl [3]>     mtcars  auto… glm        am ~ cyl + … am      NA      
#> # ℹ 7 more variables: mediator <chr>, interaction <chr>, strata <lgl>,
#> #   level <lgl>, model_parameters <list>, model_summary <list>,
#> #   fit_status <lgl>
```

The `mdl_tbl` class is a useful way to store and manage multiple models,
and can be used to generate tables for publication or for internal use.
To quickly access the content (e.g. estimates, standard errors, etc.),
there is an experimental function called
[`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/model_table_helpers.md)
that can be used. Note that we are also exponentiating the coefficients
for the logistic regression models (called by name).

``` r

fTable <-
  rTable |>
  flatten_models(exponentiate = TRUE, which = "automatic") 

# Display contents
fTable
#> # A tibble: 8 × 34
#>   formula_call  model_call data_id name      number outcome exposure mediator
#>   <chr>         <chr>      <chr>   <chr>      <int> <chr>   <chr>    <chr>   
#> 1 mpg ~ wt + hp lm         mtcars  mileage        2 mpg     NA       NA      
#> 2 mpg ~ wt + hp lm         mtcars  mileage        2 mpg     NA       NA      
#> 3 mpg ~ wt + hp lm         mtcars  mileage        2 mpg     NA       NA      
#> 4 am ~ cyl      glm        mtcars  automatic      1 am      NA       NA      
#> 5 am ~ cyl      glm        mtcars  automatic      1 am      NA       NA      
#> 6 am ~ cyl + hp glm        mtcars  automatic      2 am      NA       NA      
#> 7 am ~ cyl + hp glm        mtcars  automatic      2 am      NA       NA      
#> 8 am ~ cyl + hp glm        mtcars  automatic      2 am      NA       NA      
#> # ℹ 26 more variables: interaction <chr>, strata <lgl>, level <lgl>,
#> #   term <chr>, estimate <dbl>, std_error <dbl>, statistic <dbl>,
#> #   p_value <dbl>, conf_low <dbl>, conf_high <dbl>, r_squared <dbl>,
#> #   adj_r_squared <dbl>, sigma <dbl>, model_statistic <dbl>,
#> #   model_p_value <dbl>, df <dbl>, logLik <dbl>, AIC <dbl>, BIC <dbl>,
#> #   deviance <dbl>, df_residual <int>, nobs <int>, degrees_freedom <dbl>,
#> #   var_cov <list>, null_deviance <dbl>, df_null <int>

# Filter down to relevant models
fTable |>
  dplyr::select(name, number, outcome, term, estimate, conf_low, conf_high, p_value, nobs)
#> # A tibble: 8 × 9
#>   name      number outcome term       estimate conf_low conf_high  p_value  nobs
#>   <chr>      <int> <chr>   <chr>         <dbl>    <dbl>     <dbl>    <dbl> <int>
#> 1 mileage        2 mpg     (Intercep…  37.2     34.0      4.05e+1 2.57e-20    32
#> 2 mileage        2 mpg     wt          -3.88    -5.17    -2.58e+0 1.12e- 6    32
#> 3 mileage        2 mpg     hp          -0.0318  -0.0502  -1.33e-2 1.45e- 3    32
#> 4 automatic      1 am      (Intercep…  43.7      2.58     1.28e+3 1.45e- 2    32
#> 5 automatic      1 am      cyl          0.501    0.286    7.92e-1 6.42e- 3    32
#> 6 automatic      2 am      (Intercep… 341.       9.44     3.91e+4 4.76e- 3    32
#> 7 automatic      2 am      cyl          0.182    0.0436   5.05e-1 4.73e- 3    32
#> 8 automatic      2 am      hp           1.03     1.00     1.06e+0 4.23e- 2    32
```
