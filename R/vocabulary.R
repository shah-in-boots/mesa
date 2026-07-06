# Vocabulary -------------------------------------------------------------------

# These constants were previously frozen into `R/sysdata.rda`. They now live
# here as inspectable code so the vocabulary can grow with the package (and be
# read by anyone wondering what the grammar supports).

# Roles a term may play in a causal formula, mapped to their shortcut runes
.roles <- list(
	'outcome' = '.o',
	'exposure' = '.x',
	'predictor' = '.p',
	'confounder' = '.c',
	'mediator' = '.m',
	'strata' = '.s',
	'interaction' = '.i',
	'random' = '.r'
)

# Expansion patterns understood by `fmls()`; the registry in `patterns.R` is
# the authoritative lookup, this vector names the built-ins
.patterns <- c(
	'fundamental',
	'direct',
	'sequential',
	'parallel'
)

# Recognized transformation wrappers. A wrapped term keeps its full call as
# its name (so formulas rebuild losslessly); the wrapper is additionally
# recorded in the `transformation` field for downstream interpretation.
.transformations <- c(
	'log',
	'log1p',
	'log2',
	'log10',
	'exp',
	'sqrt',
	'scale',
	'factor',
	'ordered',
	'poly',
	'ns',
	'bs',
	'I'
)

# Legacy list of directly-supported fitting functions. `fit()` no longer
# gates on this (any fitting function or `{parsnip}` specification is
# accepted); it remains for `mdl.character()` bookkeeping and messages.
.models <- c(
	'model_fit',
	'lm',
	'glm',
	'coxph',
	'lmer',
	'glmer'
)

# Role-to-color mapping for terminal printing (see `format.tm()`)
.role_colors <- c(
	'outcome' = 'yellow',
	'exposure' = 'blue',
	'predictor' = 'br_black',
	'mediator' = 'cyan',
	'confounder' = 'green',
	'strata' = 'br_white',
	'interaction' = 'br_blue',
	'random' = 'magenta',
	'unknown' = 'black'
)

#' The `mesa` vocabulary
#'
#' @description
#'
#' The grammar of `{mesa}` is built on small, controlled vocabularies: the
#' causal *roles* a term can play, the *patterns* by which formulas expand,
#' and the *transformations* a term can carry. These accessors expose the
#' vocabularies so they can be inspected (and so error messages can point
#' somewhere authoritative).
#'
#' - `term_roles()` returns the named list of roles and their formula
#'   shortcuts (e.g. `exposure = ".x"`)
#'
#' - `term_transformations()` returns the recognized transformation wrappers
#'   (e.g. `log()`); a wrapped term keeps its full call as its name and
#'   records the wrapper in its `transformation` field
#'
#' - `formula_patterns()` returns the names of the registered expansion
#'   patterns available to [fmls()] (see [register_pattern()] to add one)
#'
#' @return A named list (`term_roles()`) or character vector (others)
#' @name vocabulary
NULL

#' @rdname vocabulary
#' @export
term_roles <- function() {
	.roles
}

#' @rdname vocabulary
#' @export
term_transformations <- function() {
	.transformations
}
