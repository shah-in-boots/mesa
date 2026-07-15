normalize_cell_frame <- function(cells) {
	value_text <- function(value) {
		if (!length(value)) return("")
		parts <- vapply(names(value), function(name) {
			value <- value[[name]]
			shown <- if (length(value) != 1 || is.na(value)) "NA" else
				formatC(value, digits = 5, format = "fg", flag = "#")
			paste0(name, "=", shown)
		}, character(1))
		paste(parts, collapse = ";")
	}
	data.frame(
		group = cells$group_id,
		subgroup = cells$subgroup,
		scope = cells$scope,
		row = vapply(cells$row_path, paste, character(1), collapse = " > "),
		column = vapply(cells$column_path, paste, character(1), collapse = " > "),
		renderer = cells$renderer,
		type = cells$type,
		value = vapply(cells$value, value_text, character(1)),
		stringsAsFactors = FALSE
	)
}

normalize_html_tags <- function(gtbl) {
	html <- suppressWarnings(gt::as_raw_html(gtbl))
	tags <- regmatches(
		html,
		gregexpr("<(?:table|thead|tbody|tr|th|td)(?:\\s[^>]*)?>", html,
			perl = TRUE)
	)[[1]]
	tags <- gsub(" (?:id|headers|style)=\"[^\"]*\"", "", tags,
		perl = TRUE)
	gsub("[[:space:]]+", " ", tags)
}

test_that("normalized semantic cell frames are stable", {
	cells <- regression_mdl_tbl() |>
		mdl_gt() |>
		add_n() |>
		add_estimates() |>
		add_forest() |>
		inspect_mdl_gt("cells")
	expect_snapshot(dput(normalize_cell_frame(cells)))
})

test_that("normalized gt HTML structure is stable", {
	gtbl <- multi_outcome_mdl_tbl() |>
		mdl_gt() |>
		add_n() |>
		add_estimates() |>
		as_gt()
	expect_snapshot(writeLines(normalize_html_tags(gtbl)))
})
