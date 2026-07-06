# The `mesa` vocabulary

The grammar of `{mesa}` is built on small, controlled vocabularies: the
causal *roles* a term can play, the *patterns* by which formulas expand,
and the *transformations* a term can carry. These accessors expose the
vocabularies so they can be inspected (and so error messages can point
somewhere authoritative).

- `term_roles()` returns the named list of roles and their formula
  shortcuts (e.g. `exposure = ".x"`)

- `term_transformations()` returns the recognized transformation
  wrappers (e.g. [`log()`](https://rdrr.io/r/base/Log.html)); a wrapped
  term keeps its full call as its name and records the wrapper in its
  `transformation` field

- `formula_patterns()` returns the names of the registered expansion
  patterns available to
  [`fmls()`](https://shah-in-boots.github.io/mesa/reference/fmls.md)
  (see
  [`register_pattern()`](https://shah-in-boots.github.io/mesa/reference/register_pattern.md)
  to add one)

## Usage

``` r
formula_patterns()

term_roles()

term_transformations()
```

## Value

A named list (`term_roles()`) or character vector (others)
