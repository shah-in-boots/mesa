# mesa

## Installation

The development version can be installed from
[Github](https://github.com/shah-in-boots/mesa). Once
[mesa](https://shah-in-boots.github.io/mesa/) is accepted on CRAN, it
can be installed from CRAN as well.

``` r

# Development version
remotes::install_github("shah-in-boots/mesa")
# CRAN installation after release
install.packages("mesa")
```

## Introduction

The package [mesa](https://shah-in-boots.github.io/mesa/) (Models for
Epidemiology and Statistical Analysis) was intended as a way to handle
causal- and epidemiology-based modeling by the following principles:

1.  Role determination of variables
2.  Generativity in formula creation
3.  Multiple model management

## Usage

The package is simple to use. The `mtcars` dataset will serve as the
example, and we will use linear regressions as the primary test. This
toy example shows that we will be building six models in parallel, with
the key exposure being the **wt** term, and the two outcomes being
**mpg** and **hp**.

``` r

library(mesa)
#> Loading required package: vctrs
#> Loading required package: tibble
#> 
#> Attaching package: 'tibble'
#> The following object is masked from 'package:vctrs':
#> 
#>     data_frame

f <- fmls(mpg + hp ~ .x(wt) + disp + cyl + am, pattern = "parallel")
m <- fit(f, .fn = lm, data = mtcars, raw = FALSE)
mt <- model_table(mileage = m)
print(mt)
#> <mdl_tbl>
#>   id        formula_index data_id name  model_call formula_call outcome exposure
#>   <chr>     <list>        <chr>   <chr> <chr>      <chr>        <chr>   <chr>   
#> 1 453532fa… <dbl [6]>     mtcars  mile… lm         mpg ~ wt + … mpg     wt      
#> 2 d90b656e… <dbl [6]>     mtcars  mile… lm         mpg ~ wt + … mpg     wt      
#> 3 5d2f00cc… <dbl [6]>     mtcars  mile… lm         mpg ~ wt + … mpg     wt      
#> 4 49495c60… <dbl [6]>     mtcars  mile… lm         hp ~ wt + d… hp      wt      
#> 5 dd309c8d… <dbl [6]>     mtcars  mile… lm         hp ~ wt + c… hp      wt      
#> 6 b10fc492… <dbl [6]>     mtcars  mile… lm         hp ~ wt + am hp      wt      
#> # ℹ 7 more variables: mediator <chr>, interaction <chr>, strata <lgl>,
#> #   level <lgl>, model_parameters <list>, model_summary <list>,
#> #   fit_status <lgl>
```

## Classes

There are several important extended classes that this package
introduces, however they are primarily used for internal validation and
for shortcuts to allow more effective communication.

- `fmls` are a *version* of the base `R` formula object, but contain
  additional information and have extra features
- `tm` are atomic elements used to describe individual variables, and
  departs from how terms are generally treated in the `{stats}` package
- `mdl` and `mdl_tbl` exist primarily as *tidy* versions of class
  regression modeling

## Advanced Usage

The [`{mesa}`](https://cran.r-project.org/package=mesa) package is
intended to be flexible, extensible, and easy-to-use (albeit
opinionated). Please see the vignettes for additional information.
