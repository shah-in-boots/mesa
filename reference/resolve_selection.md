# Resolve a table selection against a model table

The shared engine behind every table verb: filter a `mdl_tbl` by
outcome, exposure, strata, and adjustment set, and resolve the requested
terms to the exact tidy-term keys they cover. All matching is by
identity — against the `outcome`/`exposure` columns and the term table —
never [`grepl()`](https://rdrr.io/r/base/grep.html).

## Usage

``` r
resolve_selection(
  x,
  outcomes = NULL,
  exposures = NULL,
  terms = NULL,
  adjustment = NULL,
  strata = NULL
)
```

## Arguments

- x:

  A `mdl_tbl` object.

- outcomes, exposures, terms, adjustment, strata:

  Selection instructions in the documented labeled-formula forms (see
  [`labeled_formulas_to_named_list()`](https://shah-in-boots.github.io/mesa/reference/labeled_formulas_to_named_list.md));
  `NULL` leaves that dimension unfiltered. `adjustment` selects by the
  sequential adjustment index (see
  [`family_adjustment_index()`](https://shah-in-boots.github.io/mesa/reference/family_adjustment_index.md)),
  so its left-hand sides are integers.

## Value

A `mesa_selection` object (a list) with: `models`, the filtered
`mdl_tbl`; `adjustment_index`, the sequential index aligned to those
rows; `terms`, the resolved-term metadata tibble; `term_keys`, the union
of exact tidy-term keys (or `NULL` when no terms were requested); and
`labels`, the recorded labels for each dimension.
