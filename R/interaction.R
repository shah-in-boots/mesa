#' Estimating interaction effect estimates
#'
#' @description
#'
#' `r lifecycle::badge("experimental")`
#'
#' When a model in a `mdl_tbl` carries an interaction term, the exposure's
#' effect *within each level* of the interaction variable — and its
#' confidence interval — can be derived from the stored coefficients and
#' variance-covariance matrix, without refitting. The approach follows
#' Figueiras et al. (1998): within the reference level the effect is the
#' exposure coefficient; within level *j* it is the exposure coefficient plus
#' the level's interaction coefficient, with variance
#' `var(b_exp) + var(b_j) + 2 cov(b_exp, b_j)`.
#'
#' @details
#'
#' `estimate_interaction()` requires a `mdl_tbl` subset to a single row;
#' filter before calling. The interaction variable may be **binary or
#' categorical**: every level of the attached-data factor yields a row, the
#' reference level first. Terms are matched to the model's coefficients by
#' **identity** (the tidy keys `exposure:interactionLevel`, either variable
#' order), and the variance-covariance matrix is indexed by coefficient name
#' — never by `grepl()` position.
#'
#' The `p_value` is the single across-levels test of interaction: with one
#' interaction coefficient (a binary interaction) it is that coefficient's
#' p-value; with several (a categorical interaction) it is the joint Wald
#' chi-square test of all the interaction coefficients against zero.
#'
#' @param object A `mdl_tbl` object subset to a single row
#'
#' @param exposure The exposure variable in the model
#'
#' @param interaction The interaction variable in the model
#'
#' @param conf_level The confidence level for the confidence interval
#'
#' @param ... Arguments to be passed to or from other methods
#'
#' @return A `tibble` with one row per level of the interaction variable
#'   (the reference level first) and `n = 6` columns:
#'
#'   - estimate: the exposure's effect within the interaction level
#'
#'   - conf_low: lower bound of the confidence interval for the estimate
#'
#'   - conf_high: upper bound of the confidence interval for the estimate
#'
#'   - p_value: p-value for the overall interaction effect *across levels*
#'     (the same value on every row)
#'
#'   - nobs: number of observations within the interaction level
#'
#'   - level: level of the interaction term
#'
#' @references
#' A. Figueiras, J. M. Domenech-Massons, and Carmen Cadarso, 'Regression models:
#' calculating the confidence intervals of effects in the presence of
#' interactions', Statistics in Medicine, 17, 2099-2105 (1998)
#'
#' @export
estimate_interaction <- function(object,
																 exposure,
																 interaction,
																 conf_level = 0.95,
																 ...) {

	validate_class(object, "mdl_tbl")
	if (nrow(object) > 1) {
		stop(
			"The `mdl_tbl` object must be subset to single row to estimate ",
			"interactions.",
			call. = FALSE
		)
	}

	if (!exposure %in% object$exposure) {
		stop("The exposure variable is not in the model set.", call. = FALSE)
	}
	# Identity, not `grepl()`: `sex` must not match a model interacting on
	# `sexes` (the old substring bug)
	if (is.na(object$interaction) ||
			!identical(object$interaction, interaction)) {
		stop("The interaction variable is not in the model set.", call. = FALSE)
	}

	datLs <- attr(object, "dataList")
	if (length(datLs) == 0 || !object$data_id %in% names(datLs)) {
		stop(
			"The model table object does not have the data available. ",
			"Attach the fitting data with `attach_data()`.",
			call. = FALSE
		)
	}
	dat <- datLs[[object$data_id]]
	if (!interaction %in% names(dat)) {
		stop(
			"The interaction variable `", interaction, "` is not a column of ",
			"the attached dataset `", object$data_id, "`.",
			call. = FALSE
		)
	}

	# The model's coefficients, on the linear scale, with the stored
	# variance-covariance matrix and residual degrees of freedom
	mod <- suppressMessages(flatten_models(object, exponentiate = FALSE))
	nms <- mod$term
	coefs <- stats::setNames(mod$estimate, nms)
	varCov <- mod$var_cov[[1]]
	degFree <- unique(mod$degrees_freedom)[1]

	if (!exposure %in% nms) {
		stop(
			"The exposure term `", exposure, "` was not found among the model's ",
			"terms (", paste0("`", nms, "`", collapse = ", "), ").",
			call. = FALSE
		)
	}

	# Levels and per-level counts come from the attached data
	intFct <- factor(dat[[interaction]])
	lvls <- levels(intFct)
	if (length(lvls) < 2) {
		stop(
			"The interaction variable `", interaction, "` needs at least two ",
			"levels.",
			call. = FALSE
		)
	}
	counts <- table(intFct)

	# The tidy key of a level's interaction coefficient, by identity: the
	# factor form (`exposure:interactionLevel`, either variable order), or the
	# bare form when the interaction was modeled numerically
	interaction_key <- function(lvl) {
		candidates <- c(
			paste0(exposure, ":", interaction, lvl),
			paste0(interaction, lvl, ":", exposure),
			paste0(exposure, ":", interaction),
			paste0(interaction, ":", exposure)
		)
		hit <- candidates[candidates %in% nms]
		if (length(hit) == 0) {
			stop(
				"No interaction coefficient matches level `", lvl, "` of `",
				interaction, "` (looked for ",
				paste0("`", candidates[1:2], "`", collapse = ", "),
				" among the model's terms).",
				call. = FALSE
			)
		}
		hit[1]
	}
	intKeys <- vapply(lvls[-1], interaction_key, character(1))

	# The variance-covariance matrix is indexed by coefficient name
	if (is.null(rownames(varCov))) {
		stop(
			"The stored variance-covariance matrix carries no coefficient names, ",
			"so terms cannot be matched by identity.",
			call. = FALSE
		)
	}
	vc <- function(a, b) varCov[a, b]

	# The single across-levels interaction p-value: the coefficient's own test
	# when there is one, the joint Wald chi-square when there are several
	pval <-
		if (length(intKeys) == 1) {
			mod$p_value[match(intKeys, nms)]
		} else {
			b <- coefs[intKeys]
			V <- varCov[intKeys, intKeys]
			stat <- drop(t(b) %*% solve(V) %*% b)
			stats::pchisq(stat, df = length(b), lower.tail = FALSE)
		}

	critical <-
		if (is.na(degFree)) {
			stats::qnorm(conf_level / 2 + 0.5)
		} else {
			stats::qt(conf_level / 2 + 0.5, df = degFree)
		}

	# One row per level: the reference level is the exposure coefficient
	# alone; level j adds its interaction coefficient, with the covariance in
	# the variance
	rows <- vector("list", length(lvls))
	rows[[1]] <- list(
		estimate = coefs[[exposure]],
		variance = vc(exposure, exposure),
		level = lvls[1],
		nobs = counts[[lvls[1]]]
	)
	for (i in seq_along(intKeys)) {
		key <- intKeys[[i]]
		rows[[i + 1]] <- list(
			estimate = coefs[[exposure]] + coefs[[key]],
			variance = vc(exposure, exposure) + vc(key, key) +
				2 * vc(exposure, key),
			level = lvls[i + 1],
			nobs = counts[[lvls[i + 1]]]
		)
	}

	dplyr::bind_rows(lapply(rows, function(r) {
		half <- critical * sqrt(r$variance)
		tibble::tibble(
			estimate = r$estimate,
			conf_low = r$estimate - half,
			conf_high = r$estimate + half,
			p_value = pval,
			nobs = r$nobs,
			level = r$level
		)
	}))
}
