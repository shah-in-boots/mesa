# normalized semantic cell frames are stable

    Code
      dput(normalize_cell_frame(cells))
    Output
      structure(list(group = c("n", "effect", "forest", "p", "effect", 
      "forest", "p", "effect", "forest", "p", "n", "effect", "forest", 
      "p", "effect", "forest", "p", "effect", "forest", "p"), subgroup = c("n", 
      "effect", "forest", "p", "effect", "forest", "p", "effect", "forest", 
      "p", "n", "effect", "forest", "p", "effect", "forest", "p", "effect", 
      "forest", "p"), scope = c("row", "row", "row", "row", "row", 
      "row", "row", "row", "row", "row", "row", "row", "row", "row", 
      "row", "row", "row", "row", "row", "row"), row = c("mpg > Model 1", 
      "mpg > Model 1", "mpg > Model 1", "mpg > Model 1", "mpg > Model 1", 
      "mpg > Model 1", "mpg > Model 1", "mpg > Model 1", "mpg > Model 1", 
      "mpg > Model 1", "mpg > Model 2", "mpg > Model 2", "mpg > Model 2", 
      "mpg > Model 2", "mpg > Model 2", "mpg > Model 2", "mpg > Model 2", 
      "mpg > Model 2", "mpg > Model 2", "mpg > Model 2"), column = c("N", 
      "cyl > 4 > Estimate (95% CI)", "cyl > 4 > ", "cyl > 4 > P value", 
      "cyl > 6 > Estimate (95% CI)", "cyl > 6 > ", "cyl > 6 > P value", 
      "cyl > 8 > Estimate (95% CI)", "cyl > 8 > ", "cyl > 8 > P value", 
      "N", "cyl > 4 > Estimate (95% CI)", "cyl > 4 > ", "cyl > 4 > P value", 
      "cyl > 6 > Estimate (95% CI)", "cyl > 6 > ", "cyl > 6 > P value", 
      "cyl > 8 > Estimate (95% CI)", "cyl > 8 > ", "cyl > 8 > P value"
      ), renderer = c("text", "text", "forest", "text", "text", "forest", 
      "text", "text", "forest", "text", "text", "text", "forest", "text", 
      "text", "forest", "text", "text", "forest", "text"), type = c("numeric", 
      "reference", "reference", "reference", "numeric", "plot", "numeric", 
      "numeric", "plot", "numeric", "numeric", "reference", "reference", 
      "reference", "numeric", "plot", "numeric", "numeric", "plot", 
      "numeric"), value = c("n=32.000", "estimate=NA;conf_low=NA;conf_high=NA", 
      "estimate=NA;conf_low=NA;conf_high=NA", "p_value=NA", "estimate=-6.9208;conf_low=-10.108;conf_high=-3.7336", 
      "estimate=-6.9208;conf_low=-10.108;conf_high=-3.7336", "p_value=0.00011947", 
      "estimate=-11.564;conf_low=-14.220;conf_high=-8.9077", "estimate=-11.564;conf_low=-14.220;conf_high=-8.9077", 
      "p_value=0.00000000085682", "n=32.000", "estimate=NA;conf_low=NA;conf_high=NA", 
      "estimate=NA;conf_low=NA;conf_high=NA", "p_value=NA", "estimate=-5.9677;conf_low=-9.3256;conf_high=-2.6097", 
      "estimate=-5.9677;conf_low=-9.3256;conf_high=-2.6097", "p_value=0.0010921", 
      "estimate=-8.5209;conf_low=-13.286;conf_high=-3.7561", "estimate=-8.5209;conf_low=-13.286;conf_high=-3.7561", 
      "p_value=0.0010286")), class = "data.frame", row.names = c(NA, 
      -20L))

# normalized gt HTML structure is stable

    Code
      writeLines(normalize_html_tags(gtbl))
    Output
      <table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false" bgcolor="#FFFFFF">
      <thead>
      <tr class="gt_col_headings gt_spanner_row">
      <th rowspan="1" colspan="1" scope="col">
      <th class="gt_center gt_columns_top_border gt_column_spanner_outer" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" align="center">
      <th class="gt_center gt_columns_top_border gt_column_spanner_outer" rowspan="1" colspan="6" scope="colgroup" bgcolor="#FFFFFF" align="center">
      <tr class="gt_col_headings gt_spanner_row">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="2" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="left">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="2" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <th class="gt_center gt_columns_top_border gt_column_spanner_outer" rowspan="1" colspan="2" scope="colgroup" bgcolor="#FFFFFF" align="center">
      <th class="gt_center gt_columns_top_border gt_column_spanner_outer" rowspan="1" colspan="2" scope="colgroup" bgcolor="#FFFFFF" align="center">
      <th class="gt_center gt_columns_top_border gt_column_spanner_outer" rowspan="1" colspan="2" scope="colgroup" bgcolor="#FFFFFF" align="center">
      <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" bgcolor="#FFFFFF" valign="bottom" align="center">
      <tbody class="gt_table_body">
      <tr class="gt_group_heading_row">
      <th colspan="8" class="gt_group_heading" scope="colgroup" bgcolor="#FFFFFF" valign="middle" align="left">
      <tr class="gt_row_group_first">
      <th scope="row" class="gt_row gt_left gt_stub" align="left" valign="middle" bgcolor="#FFFFFF">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <tr>
      <th scope="row" class="gt_row gt_left gt_stub" align="left" valign="middle" bgcolor="#FFFFFF">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <tr class="gt_group_heading_row">
      <th colspan="8" class="gt_group_heading" scope="colgroup" bgcolor="#FFFFFF" valign="middle" align="left">
      <tr class="gt_row_group_first">
      <th scope="row" class="gt_row gt_left gt_stub" align="left" valign="middle" bgcolor="#FFFFFF">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <tr>
      <th scope="row" class="gt_row gt_left gt_stub" align="left" valign="middle" bgcolor="#FFFFFF">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">
      <td class="gt_row gt_center" valign="middle" align="center">

