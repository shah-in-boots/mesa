# Family identification --------------------------------------------------------
#
# A `fmls` object is born as one family — a single expansion pattern generates
# its rows — but after `c()` the rows just stack, and nothing records which
# family each came from. `identify_family()` recovers that structure from the
# causal roles themselves: it reads each formula's outcome, exposure,
# mediator, and adjustment set, groups the related ones, and names the
# relationship. This is the intended lynchpin for deciding how a set of
# models can be laid out on a `mesa` — a mediation triad, a sequential
# ladder, and a varied-exposure spread each admit different table shapes.

#' Identify the families a set of formulas contains
#'
#' @description
#'
#' `r lifecycle::badge('experimental')`
#'
#' A family is a set of formulas that belong to one analysis: an adjustment
#' ladder climbing toward a fully adjusted model, a mediation triad, parallel
#' adjustment sets around one exposure. `identify_family()` reads the causal
#' roles a `fmls` object carries and sorts its formulas into families, naming
#' each family's *pattern* and — where families relate to one another — the
#' *relation* between them.
#'
#' @details
#'
#' Formulas group into a family by their outcome and exposure; a mediator
#' binds its triad (per [fmls()]'s mediation expansion) into a single family
#' across those boundaries. Within a family the adjustment sets decide the
#' pattern:
#'
#' * `mediation` — the formulas share a mediator-role term (the causal triad)
#'
#' * `sequential` — the adjustment sets nest, each containing the last (the
#'   ladder the `"sequential"` pattern of [fmls()] generates)
#'
#' * `parallel` — several adjustment sets that do not nest (the `"parallel"`
#'   pattern)
#'
#' * `direct` — a single formula
#'
#' Families that share structure relate across their boundaries, and the
#' relation is what decides whether they can sit side by side on one
#' [mdl_gt()]:
#'
#' * `varied exposures` — same outcome, same adjustment ladder, different
#'   exposures: the wide-table shape, exposures as columns over shared
#'   adjustment rows
#'
#' * `varied outcomes` — same exposure and ladder, different outcomes:
#'   outcomes as row groups (or columns) over shared adjustment rows
#'
#' Stratifying terms (`.s()`) do not split a family — stratification expands
#' at [fit()] time, multiplying every member by its stratum levels — so the
#' stratum rides along in the `strata` column. Supplying `data` stamps the
#' terms first (see [set_data()]), so the strata column reports its observed
#' levels, e.g. `am (2 levels)`.
#'
#' @param x A `fmls` or `mdl_tbl` object
#'
#' @param data An optional `data.frame`; when supplied, terms are stamped
#'   with [set_data()] so stratifying terms report their observed levels
#'
#' @param ... Arguments to be passed to or from other methods
#'
#' @return For a `fmls`, a `tbl_df` with one row per formula, in the object's
#'   order: `family` (integer id, by order of first appearance), `pattern`,
#'   `relation` (`NA` for a family that stands alone), `formula_call`,
#'   `outcome`, `exposure`, `mediator`, `strata`, and `covariates` (a list of
#'   the adjustment terms).
#'
#'   For a `mdl_tbl`, the same table with `family`, `pattern`, and `relation`
#'   stamped on as ordinary columns — the table stays a `mdl_tbl`, so the
#'   identification feeds straight into `dplyr` narrowing:
#'   `mt |> identify_family() |> dplyr::filter(family == 1) |> mdl_gt()`.
#'
#' @examples
#' # A sequential ladder and its varied-exposure sibling
#' f <- c(
#'   fmls(mpg ~ .x(wt) + hp + cyl, pattern = "sequential"),
#'   fmls(mpg ~ .x(disp) + hp + cyl, pattern = "sequential")
#' )
#' identify_family(f)
#'
#' # A mediation triad is one family
#' m <- fmls(mpg ~ .x(wt) + .m(hp) + cyl)
#' identify_family(m)
#'
#' # On a model table the identification is stamped on as columns, so the
#' # table can be whittled down to one presentable analysis before `mdl_gt()`
#' f |>
#'   fit(.fn = lm, data = mtcars) |>
#'   model_table(data = mtcars) |>
#'   identify_family()
#'
#' @export
identify_family <- function(x, ...) {
	UseMethod("identify_family", object = x)
}

#' @rdname identify_family
#' @export
identify_family.fmls <- function(x, data = NULL, ...) {

	validate_class(x, "fmls")
	if (!is.null(data)) {
		checkmate::assert_data_frame(data)
		x <- set_data(x, data)
	}

	empty <- tibble::tibble(
		family = integer(),
		pattern = character(),
		relation = character(),
		formula_call = character(),
		outcome = character(),
		exposure = character(),
		mediator = character(),
		strata = character(),
		covariates = list()
	)
	if (vec_size(x) == 0) {
		return(empty)
	}

	termList <- formulas_to_terms(x)
	n <- length(termList)

	# Per-formula features, read from the roles each row carries. The outcome
	# is taken from the rebuilt formula's left-hand side, not the outcome role:
	# in a mediation triad the `mediator ~ exposure` row has no outcome-role
	# term at all (the mediator stands as its left-hand side)
	feats <- vector("list", n)
	for (i in seq_len(n)) {
		proxy <- vec_proxy(termList[[i]])
		f <- stats::as.formula(termList[[i]])
		lhs <- deparse1(f[[2]])
		collapse <- function(v) {
			if (length(v) == 0) NA_character_ else paste(sort(v), collapse = " + ")
		}
		strataTerms <- proxy$term[proxy$role == "strata"]
		strataLabel <- vapply(strataTerms, function(s) {
			lv <- proxy$level[[match(s, proxy$term)]]
			if (length(lv) > 0) paste0(s, " (", length(lv), " levels)") else s
		}, character(1))
		covariates <- setdiff(
			proxy$term[!proxy$role %in% c("exposure", "mediator", "strata", "random")],
			lhs
		)
		feats[[i]] <- tibble::tibble(
			formula_call = deparse1(f),
			outcome = lhs,
			exposure = collapse(proxy$term[proxy$role == "exposure"]),
			mediator = collapse(proxy$term[proxy$role == "mediator"]),
			strata = collapse(strataLabel),
			covariates = list(sort(covariates))
		)
	}
	feats <- dplyr::bind_rows(feats)

	# Family membership. A mediator binds its triad across outcome boundaries
	# (its own `mediator ~ exposure` member has a different left-hand side), so
	# rows carrying a mediator group by exposure x mediator; everything else
	# groups by outcome x exposure
	naTo <- function(v) ifelse(is.na(v), ".NA", v)
	famKey <- ifelse(
		!is.na(feats$mediator),
		paste("mediation", naTo(feats$exposure), feats$mediator, sep = "\r"),
		paste(feats$outcome, naTo(feats$exposure), sep = "\r")
	)
	feats$family <- match(famKey, unique(famKey))

	# Pattern: how a family's adjustment sets relate to one another
	feats$pattern <- NA_character_
	for (g in unique(feats$family)) {
		rows <- which(feats$family == g)
		feats$pattern[rows] <-
			if (any(!is.na(feats$mediator[rows]))) {
				"mediation"
			} else if (length(rows) == 1) {
				"direct"
			} else {
				sets <- feats$covariates[rows]
				sets <- sets[order(lengths(sets))]
				nested <- all(vapply(seq_along(sets)[-1], function(i) {
					all(sets[[i - 1]] %in% sets[[i]])
				}, logical(1)))
				if (nested) "sequential" else "parallel"
			}
	}

	# Relations across families: two families sharing an adjustment ladder are
	# one analysis spread over different exposures (the wide-table shape) or
	# different outcomes. The ladder signature is the ordered multiset of
	# adjustment sets, so alignment is by the sets themselves, not by position
	fams <- feats[!duplicated(feats$family), c("family", "outcome", "exposure"),
								drop = FALSE]
	fams$ladder <- vapply(fams$family, function(g) {
		ladder_signature(feats$covariates[feats$family == g])
	}, character(1))
	fams$mediation <- vapply(fams$family, function(g) {
		any(feats$pattern[feats$family == g] == "mediation")
	}, logical(1))

	fams$relation <- NA_character_
	std <- fams[!fams$mediation, , drop = FALSE]
	addRelation <- function(ids, label) {
		hit <- match(ids, fams$family)
		fams$relation[hit] <<- ifelse(
			is.na(fams$relation[hit]),
			label,
			paste(fams$relation[hit], label, sep = ", ")
		)
	}
	for (k in unique(paste(std$outcome, std$ladder, sep = "\r"))) {
		grp <- std[paste(std$outcome, std$ladder, sep = "\r") == k, , drop = FALSE]
		if (nrow(grp) > 1 && length(unique(naTo(grp$exposure))) > 1) {
			addRelation(grp$family, "varied exposures")
		}
	}
	for (k in unique(paste(naTo(std$exposure), std$ladder, sep = "\r"))) {
		grp <- std[paste(naTo(std$exposure), std$ladder, sep = "\r") == k, ,
							 drop = FALSE]
		if (nrow(grp) > 1 && length(unique(grp$outcome)) > 1) {
			addRelation(grp$family, "varied outcomes")
		}
	}
	feats$relation <- fams$relation[match(feats$family, fams$family)]

	feats[c("family", "pattern", "relation", "formula_call", "outcome",
					"exposure", "mediator", "strata", "covariates")]
}

#' @rdname identify_family
#' @export
identify_family.mdl_tbl <- function(x, ...) {

	validate_class(x, "mdl_tbl")

	# The table's formula matrix and term table *are* a `fmls`: the matrix rows
	# stay parallel to the table's rows (a stratum-expanded model repeats its
	# formula's row), so the identification is the `fmls` method's, and the
	# result rides back onto the table as ordinary columns ready for
	# `dplyr::filter()` or [keep_models()]. Stamping again simply refreshes
	# the columns.
	fam <- identify_family(model_table_formulas(x))

	x$family <- fam$family
	x$pattern <- fam$pattern
	x$relation <- fam$relation
	x
}

#' The `fmls` view of a model table: its formula matrix and term table,
#' rows parallel to the table's rows
#' @keywords internal
#' @noRd
model_table_formulas <- function(x) {
	new_fmls(
		formulaMatrix = attr(x, "formulaMatrix"),
		termTable = attr(x, "termTable")
	)
}

#' The ordered-multiset signature of a family's adjustment sets: the ladder
#' two families must share to relate (and to sit on one mesa)
#' @keywords internal
#' @noRd
ladder_signature <- function(sets) {
	sets <- sets[order(lengths(sets), vapply(sets, paste, character(1),
																					 collapse = "|"))]
	paste(vapply(sets, paste, character(1), collapse = "|"), collapse = "\r")
}
