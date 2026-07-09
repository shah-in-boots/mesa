# 5. Making the Mesa

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

The destination of the grammar is the fifth layer: laying a collection
of fitted models out for a paper. This is the package’s namesake act —
[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md) lays
models on the *mesa*, the table upon which they are displayed — and it
is built as a small composable grammar on top of
[gt](https://gt.rstudio.com), grown the way a
[ggplot2](https://ggplot2.tidyverse.org) plot is grown: one verb, one
decision, in any order.

``` r

d <- mtcars
d$cyl <- factor(d$cyl)

mt <-
  fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential") |>
  fit(.fn = lm, data = d, raw = FALSE) |>
  model_table(data = d)
```

`mt` is the `mdl_tbl` from
[`vignette("fitting")`](https://shah-in-boots.github.io/mesa/articles/fitting.md)
— three nested models, `mpg ~ wt`, `mpg ~ wt + hp`, and
`mpg ~ wt + hp + cyl`.

## A bare mesa is already a table

[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md) is
deliberately bare — it takes no selection arguments — and puts
everything fitted on the mesa with default labels:

``` r

mt |> mesa()
#> <mesa> specification: 3 fitted models × lm
#>   data: d
#>   layout: adjustment (rows: adjustment sets, groups: outcomes)
#>   selection: everything fitted (bare mesa)
#>   columns: estimate + CI (default)
#> 
#> # `as_gt()` renders; `select_*()` / `modify_labels()` refine the mesa
```

Printing a `<mesa>` specification shows what’s on it without rendering
anything: the layout, the current selection, the column blocks so far.
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md)
renders it — and a bare specification already produces a minimal table,
estimate and interval for every displayed term:

``` r

mt |> mesa() |> as_gt()
```

|         | wt                   |
|---------|----------------------|
| mpg     |                      |
| Model 1 | -5.34 (-6.49, -4.20) |
| Model 2 | -3.88 (-5.17, -2.58) |
| Model 3 | -3.18 (-4.66, -1.70) |

## Growing the table, one verb at a time

Nothing has to be decided up front. Each verb narrows or adds exactly
one thing, and verbs compose in any order:

- **[`select_outcomes()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  /
  [`select_exposures()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  /
  [`select_terms()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  /
  [`select_adjustment()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)
  /
  [`select_strata()`](https://shah-in-boots.github.io/mesa/reference/mesa.md)**
  narrow what is shown, and their input is a labeled formula — so
  selecting and labeling are one gesture.
- **[`modify_labels()`](https://shah-in-boots.github.io/mesa/reference/modify_labels.md)**
  relabels terms, levels, or columns late, without reselecting anything.
- **[`add_estimates()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md),
  [`add_n()`](https://shah-in-boots.github.io/mesa/reference/add_estimates.md),
  [`add_events()`](https://shah-in-boots.github.io/mesa/reference/add_events.md),
  [`add_rate_difference()`](https://shah-in-boots.github.io/mesa/reference/add_events.md),
  [`add_forest()`](https://shah-in-boots.github.io/mesa/reference/add_forest.md),
  [`add_interaction()`](https://shah-in-boots.github.io/mesa/reference/add_interaction.md)**
  each append one column block.
- **[`modify_layout()`](https://shah-in-boots.github.io/mesa/reference/modify_layout.md),
  [`modify_style()`](https://shah-in-boots.github.io/mesa/reference/modify_style.md)**
  assign the table’s axes and its accents, digits, and padding.

``` r

mt |>
  mesa() |>
  select_adjustment(1 ~ "Unadjusted", 3 ~ "Fully adjusted") |>
  add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI")) |>
  modify_labels(wt ~ "Weight (1000 lbs)") |>
  as_gt()
```

[TABLE]

Because a `<mesa>` specification is *declarative* — verbs record
instructions, and resolution happens only at
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md) —
repeating a verb replaces just that instruction, with a message, rather
than compounding silently. Rethinking a label, or narrowing the
selection further, is always cheap.

## The three layout presets

A layout **preset** is a complete assignment of the grammar’s four axes
(rows, row groups, columns, spanners), selected with
[`modify_layout()`](https://shah-in-boots.github.io/mesa/reference/modify_layout.md).

### `"adjustment"` (the default)

Adjustment sets on rows, outcomes as row groups — the shape above, and
the one every bare mesa starts from.

### `"levels"`

Event counts and incidence rates, then adjusted-estimate rows, with term
levels on columns — the shape of a hazard-ratio table:

``` r

lung <- survival::lung
lung$sex <- factor(lung$sex, levels = 1:2, labels = c("Male", "Female"))

mtSurv <-
  fmls(Surv(time, status) ~ .x(sex) + age, pattern = "sequential") |>
  fit(.fn = survival::coxph, data = lung, raw = FALSE) |>
  model_table(data = lung)

mtSurv |>
  mesa() |>
  modify_layout(preset = "levels") |>
  select_adjustment(1 ~ "Unadjusted", 2 ~ "Age-adjusted") |>
  add_events(followup = time) |>
  add_rate_difference() |>
  add_estimates(columns = list(beta ~ "HR", conf ~ "95% CI")) |>
  as_gt()
```

[TABLE]

[`add_events()`](https://shah-in-boots.github.io/mesa/reference/add_events.md)
reads the follow-up column from the `Surv()` outcome itself when it can
(`followup = time` above makes it explicit; it is optional when the
data’s follow-up column matches the outcome’s time argument). Because a
Cox model’s estimates come back exponentiated by default (the family
inference from
[`vignette("fitting")`](https://shah-in-boots.github.io/mesa/articles/fitting.md)),
the column is already labeled `HR` on the correct scale.

### `"interaction"`

Interaction levels on rows, grouped by interaction term, with the
across-levels p-value floating over each band — effect modification made
visible:

``` r

mtInt <-
  fmls(mpg ~ .x(hp) + .i(cyl)) |>
  fit(.fn = lm, data = d, raw = FALSE) |>
  model_table(data = d)
#> Interaction term `cyl` was applied to exposure term `hp`

mtInt |>
  mesa() |>
  add_interaction() |>
  add_n(label = "No.") |>
  add_estimates(columns = list(beta ~ "Estimate", conf ~ "95% CI",
                                p ~ "P for interaction")) |>
  as_gt()
#> `add_interaction()` sets the layout to the `interaction` preset.
```

|     | No. | Estimate (95% CI)    | P for interaction |
|-----|-----|----------------------|-------------------|
| cyl |     |                      |                   |
| 4   | 11  | -0.11 (-0.21, -0.02) | 0.121             |
| 6   | 7   | -0.01 (-0.11, 0.10)  | 0.121             |
| 8   | 14  | -0.01 (-0.05, 0.02)  | 0.121             |

[`add_interaction()`](https://shah-in-boots.github.io/mesa/reference/add_interaction.md)
**implies** the `"interaction"` layout — it defines the rows, so
declaring the block is declaring the layout; a separate
`modify_layout(preset = "interaction")` call is never required for the
common case.

## A forest column, on any table

[`add_forest()`](https://shah-in-boots.github.io/mesa/reference/add_forest.md)
appends a forest-plot column to any table that already carries an
estimate and interval — it reads them and computes nothing new, so
adding or dropping it never changes any other cell:

``` r

mtInt |>
  mesa() |>
  add_interaction() |>
  add_estimates() |>
  add_forest() |>
  as_gt()
#> `add_interaction()` sets the layout to the `interaction` preset.
```

|  | Estimate (95% CI) |  | P value |
|----|----|----|----|
| cyl |  |  |  |
| 4 | -0.11 (-0.21, -0.02) | ![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAAA8CAYAAAAjW/WRAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBIWXMAAB2HAAAdhwGP5fFlAAACf0lEQVR4nO3cvWoUURyG8WdXQzYBC0FEMdr4AWKnlnoNClZ2FoKNn42FWNlb6UUIBq1FO4VFsbBRCQgaMaLGC4hEiMVJWAPr2c3O7P5nnOcHB7aYDO8SXjgz5+wBNd0MsAbMRweponZ0AKnKLIiUYUGkDAsiZWyPDqBwq8AFYDE4hyRJkiRJkqSRbIsOoHAd4CVwCHganKVyXAdRCzgOfIwOUkWupEsZFkTKsCBShgWRMiyIJGW0gGlgKjpIFbUK/v0scGf98yJwr+D9VJ7rwNz659vASmCWxtpJ+sH/GtANzqLNXtP73+wIzlJbPoNIGa6k98wBp4BdwE/gObAUmki19z9MsQ4Aj+h9j7/HQ2BfXLRCnGJVQN0Lcgz4Qf9ybIxvwNGogAUMW5A2cBjYO4lQTVPngswAH8iXY2MskF6F1smwBfFkxYwmP6RfBA4Oee0R0skfapgyH9L3AJdLvN+4Xd3i9Teo12La7ugA2jzFclR3OMUaUZOnWNJAZU6xPgF3S7zfuF0j/cx0WAvA/TFlGYebwP7oEE1X57dYV9jaNOVSTMyRDfsWaxp4TCqUSlbngnTwNa8GaPIzyApwBlgecN134Czwa+yJVDlNLgjAW+AkaatJP/PACeD9xBKpUtysCJ+Bc6Q9V6dJmxWXSZsVvwbmUgVYkJ4l4EF0CFVL06dYUlbRo0fbpLdBXeAF8KpwIpVllvSM1QWeAb//cd0UcIu0NeXdZKJJ9eFWkwynWFKGBZEyLIiUYUGkDAsiZbhQqFXgPPAlOogkSZIkSZKkURTdzav66wBvSOfzPgnOUjkuFKpFOsTbI4L6sCBShgWRMiyIlGFBpAwLImX8AbCh79LuHGoEAAAAAElFTkSuQmCC) | 0.121 |
| 6 | -0.01 (-0.11, 0.10) | ![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAAA8CAYAAAAjW/WRAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBIWXMAAB2HAAAdhwGP5fFlAAACd0lEQVR4nO3dv2sTcRzG8Xdsq3VwqC5CEQUVBHHQTaToKq4iiFQcXJ0cRIeCi/gHCK66OIm4WJGOKmInURCdRHQUiz+hVozDnZRg7mt6JvncXd4vCBzp5XhCeZrvjzQBjbqNQBu4HR2kitZFB5CqzIJICRZESrAgUsJ4dACFWwHOAG+Dc0iSJEmSJEkqZSw6gMJNAk+BXcBCcJbKcR9ELeAA8CY6SBW5ky4lWBApwYJICRZESrAgkpTQAjYAE9FBqqgVHaBizgJ78uOrwIfALCrvHLA9P54DvgdmaZR5sg8waAM7g7OovCes/h6n/udCzkGkBHfSR8sUcASYBj4Di8Brsr+00j81dYi1CbgG/GD1+f25PQL2x0UbiL4NsdSpiQXZAjwne06/+LsgbWAZOBUVcACcg6hnN4F9+XHRquV64AawbRiB6sSCNNsMcKzHc8eBSwPMUktO0ovNUv99kONrPH8WeEn9J+1b+3UhNwo7zQNHo0OorzYDS2Uf7BBLSnCIVewyzRhiHV7D+d+Ai9R/iHUe2BEdoomatsw7Q/dl3aLb9ZiYfecyr3ryELjX47lfgSsDzFJLFqT5TgMv8uOiodMycAJ4N5RENWJBmu8jcIjsrSY/u/z8MXAQuD/MUHXhJH00fCH7H4k5skn7dH7fIvAqMFflWZDRsgTcjQ5RJw6xpARfQTrdIXurBcCnyCBDNAFcIBtqNeWroG+Rza0gW4CQSvN70hMcYkkJFkRKsCBSggWREiyIlOAyr1aAk8D76CCSJEmSJEmSyhiLDqBwk8AzYDfwIDhL5bhRqBawFz+XtysLIiVYECnBgkgJFkRKsCBSwm/oxm3P+lFSXwAAAABJRU5ErkJggg==) | 0.121 |
| 8 | -0.01 (-0.05, 0.02) | ![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAAA8CAYAAAAjW/WRAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBIWXMAAB2HAAAdhwGP5fFlAAACVklEQVR4nO3dPWsUURiG4XuyhkTRSpsUgqBB0M7Gn2FlYadgqZ0oWpiAVX6ApVhYWChai6Vf2FkKBlSwErQQRTRoLM6uWRTP7My6ec/u3BcMTJGcPM1DzsfsLKjrdgKbwN3oICWaiw4glcyCSBkWRMqwIFLGjugACrcBnAbeBueQJEmSJEmS1EovOoDCLQLPgUPAw+AsxfEcRBVwDHgdHaREnqRLGRZEyrAgUoYFkTIsiCRlVMACMB8dpERVdAD90zngQP9+BfgSF+W3a6TPsH8GVmOjqOuekF6msAnsC84y8JGU5310kO3iGkTK8CR9tvWA48DR/v0r4DHwLTKU9D+MO8U6CbwZGmNwfQDO02792bkplso1TkFW+bsYf163SFPsOWAZWBphXAuiYrQtyIn+7/ykviQXaPZmxc4VxEX6bKmAtaH7OleB3ZOLM/1cpE+Hs6SzhzpLwOEG4+5hq1AHSWcvOQsNxpYmaniKVdrlFEuSU6xpcZnRp1hXGo59EzgDvABu1PzsGrCr4fjSRLTZxaqAl4w+VfoE7AXuAxdHGL9zu1gq13Zt8zZhQVSMcQ4KV6gvx+CgsAkLomL4qEkBXKTPrjvAPdLDikdIDyuuA4+A74G5pooFmW0/gKf9Sy14DiJl+B+kXLeBZ/37rxP8O/PAJdL2cN0Di9fZ+sit1Al+T3qGUywpw4JIGRZEyrAgUoYFkTLc5tUGcAp4Fx1EkiRJkiRJUhu96AAKt0h6o8ky8CA4S3E8KFRF+nqE/dFBSmRBpAwLImVYECnDgkgZFkTK+AXWhMJccSQa9gAAAABJRU5ErkJggg==) | 0.121 |
|  |  |  |  |
|  |  | ![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAAAsCAYAAAAgjfcKAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBIWXMAAB2HAAAdhwGP5fFlAAADc0lEQVR4nO3bP2gUQRTH8e8lG0MkFywEsbAUUTGYQrAQGyEgiiI24t9OQQtBSxvByiJYWFmJCGI0iAhioxYiETEogikULWwstPAPIhqNsXi75lw34Xbv7c3m+H3gWLK5fffeTOZmd3YDIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiItlqwDrnmL1AN/DNOW4VLAE+hU6iBHWsv6ZDJ+KsC+gHvhQNUANm3NIR6TARcNY55iFgADjvHDe0IWAYGAPeBM7FUwScBF4CNwPn4m0HsBo4B0wFzuWvJ8D70EmU4Cg2224LnYizPqyusdCJlOAqVlu9aIAuv1xEOo8GiMg8NEBE5hGVEPM6sLyEuKE9BO4Dz0In4uw7MArcDp1ICW5hk8DX0ImISIMNwB1sZL7Clgl7mjw2ArYAl4B32E2cB8A+7AZjSK3UlagD27El0ynguWeCOXjU4hnHS+X7aBe2dJZ+jdPcH/jxOY6fAe4S7rqo1boS6eMnfdNsilctXnG8VL6PeoEf2Lf+euyPuQ5cjD9oTxMx9gNHgBXYbNIFrIqTnAE2eyWbg0ddiXHgILAMmKD9A8SrFs828bAg+mg4TmZ3an+EJd7KVDUYxz7cQoyiyqrrMe0fIF61lNnXRQTpo7ynM8m3+73U/l/YSsggsChnzESy0hDilKTMutrNq5aqtUmQfPIOkJXx9nPG75Llz4GCuZyJYzwqeHwryqyr3bxqqVqbBMkn732QAeyqP+sJ4OSR4t4CeZzCptA1wO8Cx7eqrLpC8Kqlam0SJJ/0DNIXJ9H4OpFKZBH2mHxaf7zN89RkDRgBjmGD40OOY/Nod10hedVStTYJkk/WKVZP6tX4ntfxNmsqG4q3WVNglgi4hi3draW8wZFoV12hedVStTapWj6ZtmJT3M7U/m4suRdNxlmMLbVN0sKjyI686koLsYrlVUtZbVLUguijPmzV4CN2SlSL913Akj/QRIyl2D8cTWADpQo86soSYoB41VJWmxS1YPpoL9l3M5/y70V/hJ0TjqaOH4nfP83/1wVTwGnPZHNoti6YuzaAy8zWksRIfr5RRuIZvGrJE6cd2t5HRR7ruAJswtajfwJvsVWojdgIb9STkXjjZ6evC3oI9zxWnrpg7toiZmtpfO98beHNq5a8ccrWSX0kIiId7Q+A0GsaqNdP+QAAAABJRU5ErkJggg==) |  |

## Style: accents, digits, missing text

[`modify_style()`](https://shah-in-boots.github.io/mesa/reference/modify_style.md)
emphasizes cells that meet a criterion — any displayed statistic, not
just a p-value — and controls formatting table-wide:

``` r

mt |>
  mesa() |>
  add_estimates() |>
  modify_style(accents = list(p < 0.05 ~ "bold"), digits = 3) |>
  as_gt()
```

[TABLE]

## What’s next

That is the whole grammar:
[`mesa()`](https://shah-in-boots.github.io/mesa/reference/mesa.md) to
start, `select_*()` to narrow, `add_*()` to add statistics, `modify_*()`
to lay out and style,
[`as_gt()`](https://shah-in-boots.github.io/mesa/reference/as_gt.md) to
render.
[`vignette("causal-reasoning", package = "mesa")`](https://shah-in-boots.github.io/mesa/articles/causal-reasoning.md)
steps back from the mechanics to the reasoning the roles are for — how
they map onto the estimands (total effect, direct effect, effect
modification) the rest of [mesa](https://shah-in-boots.github.io/mesa/)
was built to make fluent.
