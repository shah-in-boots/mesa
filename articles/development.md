# Development Log

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

Last updated on July 09, 2026, although still is a work-in-progress.

## Background

The development of this project was inspired by the a problem of
organizing many different hypotheses while writing my thesis, amongst
other epidemiology/causal-based modeling problems. I had several data
sets and many, many models, and had trouble with how to store and recall
them. I wanted an easier way to pull my thoughts together, creating a
dynamic structure that would unfold along with the research project
itself.

1.  Identifying core data that will be queried with specific hypotheses
2.  Ability to handle grouping/strata of that data for subsets of
    analyses
3.  Forming hypotheses of multiple outcomes and multiple predictors with
    an epidemiological angle (e.g. *exposures*, *outcomes*,
    *covariates*)
4.  Running and updating tests as the data changes
5.  Extracting or recalling models as the research project progresses

The API was inspired by several packages and programming examples as
below, which in no way are supplanted by this package.

| Source | Descriptionn |
|----|----|
| [R4DS](https://r4ds.had.co.nz/many-models.html) | This was the first time I had seen an elegant way of generating multiple models and working with list-columns, particulary the type that could become *tidy*. |
| [{modelr}](https://modelr.tidyverse.org/) | An example of a package that simplifies modeling in R |
| [{modelgrid}](https://github.com/smaakage85/modelgrid) | A framework for creating and managing multiple models, with a focus on the {caret} package |
| [{parsnip}](https://parsnip.tidymodels.org/) | The core of this was based on the single interface for modeling that `tidymodels` provides and serves as a foundation for flexible model definitions |
| [{stacks}](https://stacks.tidymodels.org/) | An influential concept of an API designed for binding together mutliple model definitions, however is meant for a specific formula and pulling together multiple models for blended predictions |
| [{workflowsets}](https://workflowsets.tidymodels.org/index.html) | This fits multiple models in a workflow to identify a potential “best” model, which is very flexible |
| [{easystats}](https://easystats.github.io/easystats/) | Forms a different “universe” in parallel to the `tidyverse` for interpreting results of models, with a focus on the presentation and exploration of statistical analysis |
| [{ggdag}](https://ggdag.malco.io/) | A *tidy* approach to creating directed acyclic graphs |

## Purpose or *raison d’être*

Machine-learning has expanded at a quickening pace, such as the rapid
development the [tidymodels](https://tidymodels.org) universe, where
causality-based modeling has seemed to move from center stage in the
programming world. Some of the differences that I have seen, which are
by no means correct nor exhaustive, are below:

| Machine learning                | Causal modeling    |
|:--------------------------------|:-------------------|
| Large data sets                 | Smaller data sets  |
| High-dimensionality             | Low-dimensionality |
| Model specifications and tuning | Term-selection     |
| Optimization focused            | Hypothesis focused |

## The blueprint: from organic growth to a deliberate grammar

The package grew organically for a long time — class by class, problem
by problem, the sandbox scripts and one-off `tbl_*()` functions
accumulating the way a research project’s helper functions always do. At
some point that stopped being sustainable: the same filtering logic was
duplicated across four table functions, the term parser walked a formula
positionally instead of by its syntax tree, and the causal roles this
article opens with were not actually first-class anywhere in the code
that mattered.

[blueprint.md](https://github.com/shah-in-boots/mesa/blob/main/blueprint.md)
is the response — a milestone-by-milestone map, revised in place as the
thinking evolved, with design decisions recorded as they were made in
`DESIGN.md` rather than left to be reconstructed from commit messages
later. The grammar it settles on is the five-layer build-up this package
is now organized around, matching the “smallest atoms up” epistemology
this article opened with:

| Layer | Class | Question it answers |
|----|----|----|
| 1\. Terms | `tm` | What is this variable, and what role does it play? |
| 2\. Formulas | `fmls` | How do terms combine, and by what pattern do they expand? |
| 3\. Models | `mdl` | What happens when a formula meets data and a fitting approach? |
| 4\. Collections | `mdl_tbl` | How do I store, recall, and compare many models? |
| 5\. Tables | `mesa` | How do I lay the models out for a paper? |

Each layer has its own vignette now
([`vignette("terms")`](https://shah-in-boots.github.io/mesa/articles/terms.md)
through
[`vignette("mesa")`](https://shah-in-boots.github.io/mesa/articles/mesa.md)),
and the causal reasoning behind the role vocabulary — Hill’s viewpoints,
Pearl’s do-calculus, VanderWeele and Robins on mediation and effect
modification — has its own as well
([`vignette("causal-reasoning")`](https://shah-in-boots.github.io/mesa/articles/causal-reasoning.md)),
rather than living only in this article’s inspiration table.

### What changed, milestone by milestone

- **M0–M2** cleared the workbench and rebuilt the term and formula
  layers on firmer ground: the
  [`tm.formula()`](https://shah-in-boots.github.io/mesa/reference/tm.md)
  parser became a recursive walk of the formula’s syntax tree instead of
  a positional scan, the role and pattern vocabularies moved out of a
  frozen `sysdata.rda` into inspectable, extensible registries, and the
  random-effects role (`.r()`) and multi-digit group tiers were added.
- **M3–M4** are where the package started to feel the way it was meant
  to:
  [`set_data()`](https://shah-in-boots.github.io/mesa/reference/set_data.md)
  lets a family classify itself against a dataset, the fluent verbs
  ([`add_strata()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
  [`subset_data()`](https://shah-in-boots.github.io/mesa/reference/fluent_verbs.md),
  and the rest) made formulas something to play with rather than
  construct once and discard, and fitting became plan-then-execute —
  [`fit_plan()`](https://shah-in-boots.github.io/mesa/reference/fit_plan.md)
  builds an inspectable formula × stratum × subset grid,
  [`fit()`](https://generics.r-lib.org/reference/fit.html) executes it,
  and a failure marks `fit_status = FALSE` instead of sinking a batch of
  twenty models.
- **M5** made the model collection (`mdl_tbl`) trustworthy: combining
  tables no longer silently dropped attached data, `dplyr` verbs
  reconcile the table’s internal attributes down to the surviving rows,
  and
  [`flatten_models()`](https://shah-in-boots.github.io/mesa/reference/flatten_models.md)
  started inferring exponentiation from the model’s family and link
  instead of demanding it be named.
- **M6** is the largest single piece of work the blueprint describes:
  the four `tbl_*()` monoliths — each duplicating the same
  filter-decorate-format logic with its own bugs — were replaced by a
  composition-first grammar.
  [`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  lifts a fitted `mdl_tbl` onto a declarative specification; small
  pipeable verbs narrow, label, add columns, and style it, in any order;
  every table reduces to one **cell frame** before
  [`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
  ever touches [gt](https://gt.rstudio.com), which is what makes the
  table layer’s regressions testable as plain tibbles instead of
  rendered HTML. The old monolith shapes survive as named layout presets
  (`"adjustment"`, `"levels"`, `"interaction"`); the functions
  themselves did not survive, deleted outright rather than deprecated,
  on the reasoning that a pre-release package should not carry a
  compatibility burden for an API it is actively trying to leave behind.
- **M7**, the milestone this article’s revision belongs to, is
  documentation and release hygiene: the vignette-per-layer set, this
  rewritten article, and a README built around one dataset and one
  causal question rather than a class list.

The full defect list, the design decisions, and the milestones still
open are in `blueprint.md` and `DESIGN.md` themselves — this article
summarizes the arc; those two documents remain the source of truth and
are kept current as the package continues to evolve.
