# Resolve requested terms to their metadata and exact keys

Resolve requested terms to their metadata and exact keys

## Usage

``` r
resolve_term_metadata(x, tmSel)
```

## Arguments

- x:

  A `mdl_tbl` object.

- tmSel:

  A named list (from
  [`selection_input()`](https://shah-in-boots.github.io/mesa/reference/selection_input.md))
  of requested terms; the names are variables in the term table, the
  values are display labels.

## Value

A `tibble`, one row per requested term, carrying its role, label, type,
distribution, observed levels, reference level, and the exact tidy-term
keys it covers.
