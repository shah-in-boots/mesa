# Convert labeling formulas to named lists

Take list of formulas, or a similar construct, and returns a named list.
The convention here is similar to reading from left to right, where the
name or position is the term is the on the *LHS* and the output label or
target instruction is on the *RHS*.

If no label is desired, then the *LHS* can be left empty, such as `~ x`.

## Usage

``` r
labeled_formulas_to_named_list(x)
```

## Arguments

- x:

  An argument that may represent a formula to label variables, or can be
  converted to one. This includes, `list`, `formula`, or `character`
  objects. Other types will error.

## Value

A named list with the index as a `character` representing the term or
variable of interest, and the value at that position as a `character`
representing the label value.
