# Compact and minimal theme for `gt` tables

This theme was used for placing somewhat larger tables into `xaringan`
slides by making the spacing more compact and decreasing the font size.
The exposed variables are to control font size and table width, but any
option from the `gt` package is allowed.

## Usage

``` r
theme_gt_compact(data, table.font.size = pct(80), table.width = pct(90), ...)
```

## Arguments

- data:

  *The gt table data object*

  `obj:<gt_tbl>` // **required**

  This is the **gt** table object that is commonly created through use
  of the [`gt()`](https://gt.rstudio.com/reference/gt.html) function.

- table.font.size:

  Font size passed to
  [`gt::tab_options()`](https://gt.rstudio.com/reference/tab_options.html).

- table.width:

  Table width passed to
  [`gt::tab_options()`](https://gt.rstudio.com/reference/tab_options.html).

- ...:

  For passing additional arguments to the
  [`tab_options()`](https://gt.rstudio.com/reference/tab_options.html)
  function
