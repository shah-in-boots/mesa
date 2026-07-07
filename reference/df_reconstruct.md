# Rebuild the scalar attributes of a model table around the rows of `x`

The formula matrix keeps only `x`'s rows (in `x`'s order), the term
table keeps only terms those rows still use in the roles they still
hold, and the data list keeps datasets those rows reference (plus any
dataset that was attached deliberately without being referenced).

## Usage

``` r
df_reconstruct(x, to)
```
