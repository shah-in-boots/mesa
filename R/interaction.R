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
#' The exposure may also be **categorical**: its non-reference levels each
#' carry their own coefficient (`exposureLEVEL`), so the within-level effect
#' is derived per exposure level, and the returned tibble gains an
#' `exposure_level` column naming the exposure contrast each row belongs to.
#' A numeric (including binary 0/1) exposure keeps the six-column shape.
#'
#' The `p_value` is the single across-levels test of interaction: with one
#' interaction coefficient (a binary interaction) it is that coefficient's
#' p-value; with several (a categorical interaction, a categorical exposure,
#' or both) it is the joint Wald chi-square test of all the interaction
#' coefficients against zero.
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
#'   When the exposure is categorical, one such set of rows is returned per
#'   non-reference exposure level, and an `exposure_level` column names the
#'   exposure contrast.
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

	# The exposure's coefficient key(s): the bare name when it was modeled
	# numerically, or one key per non-reference level (`exposureLEVEL`, the
	# treatment-contrast naming) when the exposure is categorical
	if (exposure %in% nms) {
		expKeys <- stats::setNames(exposure, NA_character_)
	} else if (exposure %in% names(dat)) {
		expLvls <- levels(factor(dat[[exposure]]))
		candidates <- paste0(exposure, expLvls[-1])
		found <- candidates %in% nms
		if (length(expLvls) < 2 || !any(found)) {
			stop(
				"The exposure term `", exposure, "` was not found among the ",
				"model's terms, neither as itself nor as level coefficients (",
				paste0("`", nms, "`", collapse = ", "), ").",
				call. = FALSE
			)
		}
		if (!all(found)) {
			stop(
				"The exposure `", exposure, "` is categorical, but the level ",
				"coefficient(s) ",
				paste0("`", candidates[!found], "`", collapse = ", "),
				" were not found among the model's terms. The attached dataset `",
				object$data_id, "` may not be the data the model was fit on.",
				call. = FALSE
			)
		}
		expKeys <- stats::setNames(candidates, expLvls[-1])
	} else {
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
	interaction_key <- function(expKey, lvl) {
		candidates <- c(
			paste0(expKey, ":", interaction, lvl),
			paste0(interaction, lvl, ":", expKey),
			paste0(expKey, ":", interaction),
			paste0(interaction, ":", expKey)
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
	intKeys <- unlist(lapply(expKeys, function(k) {
		vapply(lvls[-1], interaction_key, character(1), expKey = k)
	}), use.names = FALSE)

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

	# One row per interaction level (per exposure level, when the exposure is
	# categorical): the reference level is the exposure coefficient alone;
	# level j adds its interaction coefficient, with the covariance in the
	# variance
	rows <- list()
	for (e in seq_along(expKeys)) {
		expKey <- expKeys[[e]]
		expLvl <- names(expKeys)[e]
		rows[[length(rows) + 1]] <- list(
			estimate = coefs[[expKey]],
			variance = vc(expKey, expKey),
			level = lvls[1],
			nobs = counts[[lvls[1]]],
			exposure_level = expLvl
		)
		for (lvl in lvls[-1]) {
			key <- interaction_key(expKey, lvl)
			rows[[length(rows) + 1]] <- list(
				estimate = coefs[[expKey]] + coefs[[key]],
				variance = vc(expKey, expKey) + vc(key, key) +
					2 * vc(expKey, key),
				level = lvl,
				nobs = counts[[lvl]],
				exposure_level = expLvl
			)
		}
	}

	out <- dplyr::bind_rows(lapply(rows, function(r) {
		half <- critical * sqrt(r$variance)
		tibble::tibble(
			estimate = r$estimate,
			conf_low = r$estimate - half,
			conf_high = r$estimate + half,
			p_value = pval,
			nobs = r$nobs,
			level = r$level,
			exposure_level = r$exposure_level
		)
	}))

	# The `exposure_level` column only appears when the exposure is
	# categorical; a numeric exposure keeps the documented six columns
	if (all(is.na(out$exposure_level))) {
		out$exposure_level <- NULL
	}

	out
}
