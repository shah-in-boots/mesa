# cell frame snapshot: the bare default (adjustment preset)

    Code
      cat(frame_lines(frame), sep = "\n")
    Output
      [mpg | Model 1 | row]  (1) cyl::4::est  <cyl / 4>  reference  estimate=     NA conf_low=     NA conf_high=     NA  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Model 1 | row]  (2) cyl::6::est  <cyl / 6>  numeric  estimate=-6.92078 conf_low=-10.108 conf_high=-3.7336  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Model 1 | row]  (3) cyl::8::est  <cyl / 8>  numeric  estimate=-11.5636 conf_low=-14.2196 conf_high=-8.90765  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Model 2 | row]  (1) cyl::4::est  <cyl / 4>  reference  estimate=     NA conf_low=     NA conf_high=     NA  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Model 2 | row]  (2) cyl::6::est  <cyl / 6>  numeric  estimate=-5.96766 conf_low=-9.32556 conf_high=-2.60975  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Model 2 | row]  (3) cyl::8::est  <cyl / 8>  numeric  estimate=-8.52085 conf_low=-13.2856 conf_high=-3.7561  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})

# cell frame snapshot: the adjustment preset with column blocks

    Code
      cat(frame_lines(frame), sep = "\n")
    Output
      [mpg | Crude | row]  (1) n  < / No.>  numeric  n=     32  |  fmt=count digits=      0 pattern=NULL
      [mpg | Crude | row]  (2) cyl::4::est  <Cylinders///4 / B (CI)>  reference  estimate=     NA conf_low=     NA conf_high=     NA  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Crude | row]  (3) cyl::4::p  <Cylinders///4 / P>  reference  p_value=     NA  |  fmt=p digits=      3 pattern={p_value}
      [mpg | Crude | row]  (4) cyl::6::est  <Cylinders///6 / B (CI)>  numeric  estimate=-6.92078 conf_low=-10.108 conf_high=-3.7336  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Crude | row]  (5) cyl::6::p  <Cylinders///6 / P>  numeric  p_value=0.00011947  |  fmt=p digits=      3 pattern={p_value}
      [mpg | Crude | row]  (6) cyl::8::est  <Cylinders///8 / B (CI)>  numeric  estimate=-11.5636 conf_low=-14.2196 conf_high=-8.90765  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Crude | row]  (7) cyl::8::p  <Cylinders///8 / P>  numeric  p_value=8.56821e-10  |  fmt=p digits=      3 pattern={p_value}
      [mpg | Adjusted | row]  (1) n  < / No.>  numeric  n=     32  |  fmt=count digits=      0 pattern=NULL
      [mpg | Adjusted | row]  (2) cyl::4::est  <Cylinders///4 / B (CI)>  reference  estimate=     NA conf_low=     NA conf_high=     NA  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Adjusted | row]  (3) cyl::4::p  <Cylinders///4 / P>  reference  p_value=     NA  |  fmt=p digits=      3 pattern={p_value}
      [mpg | Adjusted | row]  (4) cyl::6::est  <Cylinders///6 / B (CI)>  numeric  estimate=-5.96766 conf_low=-9.32556 conf_high=-2.60975  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Adjusted | row]  (5) cyl::6::p  <Cylinders///6 / P>  numeric  p_value=0.00109209  |  fmt=p digits=      3 pattern={p_value}
      [mpg | Adjusted | row]  (6) cyl::8::est  <Cylinders///8 / B (CI)>  numeric  estimate=-8.52085 conf_low=-13.2856 conf_high=-3.7561  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [mpg | Adjusted | row]  (7) cyl::8::p  <Cylinders///8 / P>  numeric  p_value=0.00102862  |  fmt=p digits=      3 pattern={p_value}

# cell frame snapshot: the levels preset

    Code
      cat(frame_lines(frame), sep = "\n")
    Output
      [Surv(time, status) | Events | row]  (1) sex::male  <sex / male>  numeric  events=    112  |  fmt=count digits=      0 pattern=NULL
      [Surv(time, status) | Events | row]  (2) sex::female  <sex / female>  numeric  events=     53  |  fmt=count digits=      0 pattern=NULL
      [Surv(time, status) | Rate per 100 person-years | row]  (1) sex::male  <sex / male>  numeric  rate=104.662  |  fmt=number digits=      1 pattern={rate}
      [Surv(time, status) | Rate per 100 person-years | row]  (2) sex::female  <sex / female>  numeric  rate=63.4551  |  fmt=number digits=      1 pattern={rate}
      [Surv(time, status) | Rate per 100 person-years | row]  (3) sex::rate_difference  <sex / Rate difference (95% CI)>  numeric  estimate=-41.2064 conf_low=-67.0435 conf_high=-15.3693  |  fmt=number digits=      1 pattern={estimate} ({conf_low}, {conf_high})
      [Surv(time, status) | Model 1 | row]  (1) sex::male  <sex / male>  reference  estimate=     NA conf_low=     NA conf_high=     NA  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [Surv(time, status) | Model 1 | row]  (2) sex::female  <sex / female>  numeric  estimate=0.588003 conf_low=0.423718 conf_high=0.815985  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})

# cell frame snapshot: the interaction preset (with forest)

    Code
      cat(frame_lines(frame), sep = "\n")
    Output
      [am | 0 | row]  (1) n  < / No.>  numeric  n=     19  |  fmt=count digits=      0 pattern=NULL
      [am | 0 | row]  (2) est  < / B (CI)>  numeric  estimate=-0.059137 conf_low=-0.0856533 conf_high=-0.0326206  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [am | 0 | row]  (3) forest  < / >  plot  estimate=-0.059137 conf_low=-0.0856533 conf_high=-0.0326206  |  fmt=number digits=      2 pattern=NULL axis=list() width=    100
      [am | 1 | row]  (1) n  < / No.>  numeric  n=     13  |  fmt=count digits=      0 pattern=NULL
      [am | 1 | row]  (2) est  < / B (CI)>  numeric  estimate=-0.0587341 conf_low=-0.0795604 conf_high=-0.0379078  |  fmt=number digits=      2 pattern={estimate} ({conf_low}, {conf_high})
      [am | 1 | row]  (3) forest  < / >  plot  estimate=-0.0587341 conf_low=-0.0795604 conf_high=-0.0379078  |  fmt=number digits=      2 pattern=NULL axis=list() width=    100
      [ | .axis | row]  (3) forest  < / >  plot  estimate=     NA  |  fmt=number digits=      2 pattern=NULL axis=list() width=    100
      [am |  | group]  (4) p  < / P>  numeric  p_value=0.980646  |  fmt=p digits=      3 pattern={p_value}

