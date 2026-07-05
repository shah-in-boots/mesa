# nocov start

utils::globalVariables(c(
	"conf_high",
	"conf_low",
	"data",
	"estimate",
	"exposure",
	"ggplots",
	"level",
	"mask",
	"number",
	"outcome",
	"p_value",
	"term"
))

.onLoad <- function(libname, pkgname) {
	if (!exists("possible_tidy")) {
		possible_tidy <-
			purrr::possibly(my_tidy, otherwise = NA, quiet = FALSE)
	}
	if (!exists("possible_glance")) {
		possible_glance <-
			purrr::possibly(my_glance, otherwise = NA, quiet = FALSE)
	}
  
}

# nocov end
