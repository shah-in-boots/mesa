# The `{gt}` helpers that outlived the retired `tbl_*` monoliths (M6.7/M6.9):
# the compact theme applies to any finished `gt_tbl`, including everything
# `as_gt()` renders.

#' Compact and minimal theme for `gt` tables
#'
#' This theme was used for placing somewhat larger tables into `xaringan` slides
#' by making the spacing more compact and decreasing the font size. The exposed
#' variables are to control font size and table width, but any option from the
#' `gt` package is allowed.
#'
#' @inheritParams gt::tab_options
#' @param table.font.size Font size passed to [gt::tab_options()].
#' @param table.width Table width passed to [gt::tab_options()].
#' @param ... For passing additional arguments to the [tab_options()]
#'   function
#' @family visualizers
#' @importFrom gt tab_options px pct
#' @export
theme_gt_compact <- function(data,
														 table.font.size = pct(80),
														 table.width = pct(90),
														 ...) {

	validate_class(data, "gt_tbl")

	data |>
		tab_options(
			# Preset
			table.margin.left = px(1),
			table.margin.right = px(1),
			row_group.padding = px(1),
			data_row.padding = px(1),
			footnotes.padding = px(1),
			source_notes.padding = px(1),
			stub.border.width = px(1),
			# User supplied
			table.width = table.width,
			table.font.size = table.font.size,
			...
		)

}
