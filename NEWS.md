# mesa (developmental version)

This development is working on expanding the formula expansion methods, allowing custom patterns, and introducing the second major sets of classes for visualizing data.

* Renamed package from `{rmdl}` to `{mesa}`.

* Remove additional imports, e.g. `{janitor}`, with bespoke function rewrites, to help decrease dependency burden

* Updated package title as software has evolved

# mesa 0.1.0

This first CRAN release contains the basic functions for the package, and introduces the new basic classes. 

* `tm` gives variables in formulas specific roles and behaviors (vectorized)

* `fmls` expands the base formula class into a list of related formulas (vectorized)

* `mdl` are a thin wrapper (vectorized) for statistical models, with important metadata maintained, and are used to generate `mdl_tbl` objects, which serve as a reference `data.frame` of a family of modeling objects
