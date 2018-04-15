*Set default preferences and graph schemes
cd "/Users/nwheinrich/Documents/Stata/460"
set more off
capture log close
clear all
set scheme economist
log using ec460_forecast_log, replace text

*Download time-series data from the FRED database
freduse DBAA DAAA HOUSTNSA BUSLOANSNSA PCEPILFE UNRATENSA LNU04032231 TLPRVCON
rename DBAA baa_rate
rename DAAA aaa_rate
rename HOUSTNSA housing_starts
rename BUSLOANSNSA commind_loans
rename PCEPILFE corepceind
rename UNRATENSA u_rate
rename LNU04032231 u_rate_constr
rename TLPRVCON total_ps_construction

*Collapse the time-series data from daily/weekly data into monthly data via averaging
gen dm = mofd(daten)
format dm %tm
collapse u_rate_constr housing_starts commind_loans corepceind aaa_rate baa_rate u_rate total_ps_construction, by(dm)
rename dm time
tsset time, monthly
drop if time>tm(2017m2)

*Label the potential explanatory variables
label variable housing_starts "Total Privately Owned New Housing Starts"
label variable commind_loans "Total Amount of Commercial/Industrial Loans"
label variable corepceind "Core P.C.E. Index"
label variable aaa_rate "Moody's Seasoned AAA Corporate Bond Yield"
label variable baa_rate "Moody's Seasoned BAA Corporate Bond Yield"
label variable u_rate "Unemployment Rate"
label variable time "Time, Monthly"
label variable total_ps_construction "Nominal Private Sector Construction" //new as of 11.26.2017

*Merge data from FRED database with U.S. Census Bureau data
// merge 1:1 time using total_ps_construction
// label variable total_ps_construction "Nominal Private Sector Construction"
// drop _merge //all values matched, drop variable

*Create a junk bond spread as a predictor of recessions
gen corp_spread = baa_rate - aaa_rate
label variable corp_spread "Spread: BAA and AAA Bond Yields"

*Convert nominal construction data into a real-valued time-series using Core PCE index
gen rtotal_ps_construction = (100/corepceind)*total_ps_construction
label variable rtotal_ps_construction "Real Private Sector Construction"

*Save the data
save raw_data.dta, replace

*Decompose the time-series data from levels into growth rates (avoid problems with non-stationarity)
foreach var in rtotal_ps_construction corp_spread u_rate_constr total_ps_construction u_rate commind_loans housing_starts{
	gen pc_`var' = 100*((`var'-L.`var')/L.`var')
}
*Label variables...
label variable pc_rtotal_ps_construction "Real Private Construction"
label variable pc_u_rate_constr "Unemployment (Construction)"
label variable pc_housing_starts "Private Housing Starts"
label variable pc_corp_spread "BAA/AAA Corp. Bonds Spread"
label variable pc_total_ps_construction "Nominal Private Construction"
label variable pc_commind_loans "Total Commercial/Industrial Loans"

*Time-Series Graph of Growth Rates for all time-series
tsline pc_housing_starts pc_u_rate_constr pc_rtotal_ps_construction pc_corp_spread if tin(2007m11, 2009m11), ///
lpattern(solid solid shortdash solid) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ///
tline(2017m2) ttext(45000 2017m7 "Forecast Projections", color(cranberry)) ylabel(,labsize(small)) ///
ytitle("Percent Change (%)", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Growth Rates for Time-Series Variables", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_tsvariables
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_tsvariables.png", as(png) replace

*Expand the dataset
tsappend, add(12)

*Create monthly factor variables
gen m=month(dofm(time))

*Historical realizations
tsline pc_rtotal_ps_construction if tin(2008m1, 2017m2), ///
yline(0, lcolor(red)) ytitle("Real Private Sector Construction Spending", size(small)) ///
tlabel(#10, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##12) ylabel(,labsize(small)) ///
ttitle("Time" "(Monthly)", size(small)) caption("Source: FRED, U.S. Census Bureau") ///
legend(off) graphregion(margin(large)) xsize(3.5)
graph rename ec460_forecast_historical1
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_historical1.png", as(png) replace

tsline rtotal_ps_construction if tin(2008m1, 2017m2), ///
ytitle("Real Private Sector Construction Spending", size(small)) ///
tlabel(#10, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##12) ///
ylabel(,labsize(small)) ttitle("Time" "(Monthly)", size(small)) ///
caption("Source: FRED, U.S. Census Bureau") legend(off) graphregion(margin(large)) xsize(3.5)
graph rename ec460_forecast_historical2
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_historical2.png", as(png) replace

*Capture and graph seasonal component of the construction time-series (growth rates)
reg pc_rtotal_ps_construction b12.m
predict months1
label variable months1 "Monthly Dummy Variables"
tsline months1 if tin(2014m1, 2017m2), ///
ytitle("Real Private Sector Construction Spending", size(small)) ///
tlabel(#6, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ylabel(,labsize(small)) ///
ttitle("Time" "(Monthly)", size(small)) caption("Source: FRED, U.S. Census Bureau") ///
legend(off) graphregion(margin(large)) xsize(3.5)
graph rename ec460_forecast_seasonality1
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_seasonality1.png", as(png) replace

*Capture and graph seasonal component of the construction time-series (levels)
reg rtotal_ps_construction b12.m
predict months2
label variable months2 "Monthly Dummy Variables"
tsline months2 if tin(2014m1, 2017m2), ytitle("Real Private Sector Construction Spending", size(small)) ///
tlabel(#6, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ylabel(,labsize(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
caption("Source: FRED, U.S. Census Bureau") legend(off) graphregion(margin(large)) xsize(3.5)
graph rename ec460_forecast_seasonality2
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_seasonality2.png", as(png) replace

*Akaike and Bayesian Information Criterion for AR Model Selection:
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar12
reg pc_rtotal_ps_construction b12.m l(1/10).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar10
reg pc_rtotal_ps_construction b12.m l(1/8).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar8
reg pc_rtotal_ps_construction b12.m l(1/6).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar6
reg pc_rtotal_ps_construction b12.m l(1/4).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar4
reg pc_rtotal_ps_construction b12.m l(1/2).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar2
reg pc_rtotal_ps_construction b12.m l(1/1).pc_rtotal_ps_construction if time>tm(2001m1), r
estimates store ar1

*Generate AIC/BIC Table
estimates stats ar1 ar2 ar4 ar6 ar8 ar10 ar12

*Akaike and Bayesian Information Criterion for 3, 6 or 12 lags of housing starts with selected AR(12) model
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_housing_starts if time>tm(2001m1), r
estimates store ar12_housing12
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/6).pc_housing_starts if time>tm(2001m1), r
estimates store ar12_housing6
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/3).pc_housing_starts if time>tm(2001m1), r
estimates store ar12_housing3
estimates stats ar12_housing12 ar12_housing6 ar12_housing3

*Akaike and Bayesian Information Criterion for 3, 6 or 12 lags of construction industry unemployment rate with selected AR(12) model
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr if time>tm(2001m1), r
estimates store ar12_uratec12
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/6).pc_u_rate_constr if time>tm(2001m1), r
estimates store ar12_uratec6
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/3).pc_u_rate_constr if time>tm(2001m1), r
estimates store ar12_uratec3
estimates stats ar12_uratec12 ar12_uratec6 ar12_uratec3

*Akaike and Bayesian Information Criterion for 3, 6 or 12 lags of corporate bond spread with selected AR(12) model
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_corp_spread if time>tm(2001m1), r
estimates store ar12_corp12
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/6).pc_corp_spread if time>tm(2001m1), r
estimates store ar12_corp6
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/3).pc_corp_spread if time>tm(2001m1), r
estimates store ar12_corp3
estimates stats ar12_corp12 ar12_corp6 ar12_corp3

*Akaike and Bayesian Information Criterion for different combinations of explanatory variables with selected AR(12) model
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_corp_spread L(1/3).pc_housing_starts if time>tm(2001m1), r
estimates store ar12_combine3
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_corp_spread if time>tm(2001m1), r
estimates store ar12_combine_uratec_corp
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts if time>tm(2001m1), r
estimates store ar12_combine_uratec_house
estimates stats ar12_combine3 ar12_combine_uratec_corp ar12_combine_uratec_house ar12_corp3 ar12_uratec12 ar12_housing12

*Granger Non-Causality Test: corp_spread
newey pc_rtotal_ps_construction b12.m L(1/12).pc_rtotal_ps_construction L(1/12).corp_spread if tin(1990m1, 2017m2), lag(12)
testparm L(1/12).corp_spread
newey pc_rtotal_ps_construction b12.m L(1/12).pc_rtotal_ps_construction L(1/3).corp_spread if tin(1990m1, 2017m2), lag(12)
testparm L(1/3).corp_spread
*Reverse Direction:
newey corp_spread b12.m L(1/12).corp_spread L(1/12).pc_rtotal_ps_construction  if tin(1990m1, 2017m2), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

*Granger Non-Causality Test: pc_housing_starts
newey pc_rtotal_ps_construction b12.m L(1/12).pc_rtotal_ps_construction L(1/12).pc_housing_starts if tin(1990m1, 2017m2), lag(12)
testparm L(1/12).pc_housing_starts
newey pc_rtotal_ps_construction b12.m L(1/12).pc_rtotal_ps_construction L(1/3).pc_housing_starts if tin(1990m1, 2017m2), lag(12)
testparm L(1/3).pc_housing_starts
*Reverse Direction:
newey pc_housing_starts b12.m L(1/12).pc_housing_starts L(1/12).pc_rtotal_ps_construction  if tin(1990m1, 2017m2), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

*Granger Non-Causality Test: pc_u_rate_constr
newey pc_rtotal_ps_construction b12.m L(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr if tin(1990m1, 2017m2), lag(12)
testparm L(1/12).pc_u_rate_constr
*Reverse Direction:
newey pc_u_rate_constr b12.m L(1/12).pc_u_rate_constr L(1/12).pc_rtotal_ps_construction  if tin(1990m1, 2017m2), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

/*
Granger Non-Causality Test: AIC, BIC Selected Models...

1. reg pc_total_ps_construction l(1/12).pc_total_ps_construction L(1/12).pc_u_rate_constr
2. reg pc_total_ps_construction l(1/12).pc_total_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts
3. reg pc_total_ps_construction l(1/12).pc_total_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_corp_spread
4. reg pc_total_ps_construction l(1/12).pc_total_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_corp_spread L(1/3).pc_housing_starts
*/

*Model 1
newey pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr if time>tm(2001m1), lag(12)
testparm L(1/12).pc_u_rate_constr
*Reverse Direction:
newey pc_u_rate_constr l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

*Model 2
newey pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_u_rate_constr
testparm L(1/3).pc_housing_starts
*Reverse Direction:
newey pc_u_rate_constr l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction
newey pc_housing_starts l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

*Model 3
newey pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread if time>tm(2001m1), lag(12)
testparm L(1/12).pc_u_rate_constr
testparm L(1/3).corp_spread
*Reverse Direction:
newey corp_spread l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction
newey pc_u_rate_constr l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

*Model 4
newey pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_u_rate_constr
testparm L(1/3).corp_spread
testparm L(1/3).pc_housing_starts
*Reverse Direction:
newey pc_housing_starts l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction
newey corp_spread l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction
newey pc_u_rate_constr l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread L(1/3).pc_housing_starts if time>tm(2001m1), lag(12)
testparm L(1/12).pc_rtotal_ps_construction

/*
Generate forecast models with the following regressions...

1. reg pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr
2. reg pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts
3. reg pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_corp_spread
4. reg pc_rtotal_ps_construction l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_corp_spread L(1/3).pc_housing_starts

- Generate point forecast, standard deviation of forecast (12 step forecast horizon, 12 regressions)
- Calculate interval forecasts (upper, lower bounds for 90% and 50% normal intervals)

*/


*1. Model 1:
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr if time<tm(2017m3)
est sto m1
predict y11
predict s11,stdf
gen y11L=y11-1.645*s11
gen y11U=y11+1.645*s11
gen y11L2=y11-0.675*s11
gen y11U2=y11+0.675*s11
quietly reg pc_rtotal_ps_construction b12.m l(2/13).pc_rtotal_ps_construction L(2/13).pc_u_rate_constr if time<tm(2017m3)
predict y12
predict s12,stdf
gen y12L=y12-1.645*s12
gen y12U=y12+1.645*s12
gen y12L2=y12-0.675*s12
gen y12U2=y12+0.675*s12
quietly reg pc_rtotal_ps_construction b12.m l(3/14).pc_rtotal_ps_construction L(3/14).pc_u_rate_constr if time<tm(2017m3)
predict y13
predict s13,stdf
gen y13L=y13-1.645*s13
gen y13U=y13+1.645*s13
gen y13L2=y13-0.675*s13
gen y13U2=y13+0.675*s13
quietly reg pc_rtotal_ps_construction b12.m l(4/15).pc_rtotal_ps_construction L(4/15).pc_u_rate_constr if time<tm(2017m3)
predict y14
predict s14,stdf
gen y14L=y14-1.645*s14
gen y14U=y14+1.645*s14
gen y14L2=y14-0.675*s14
gen y14U2=y14+0.675*s14
quietly reg pc_rtotal_ps_construction b12.m l(5/16).pc_rtotal_ps_construction L(5/16).pc_u_rate_constr if time<tm(2017m3)
predict y15
predict s15,stdf
gen y15L=y15-1.645*s15
gen y15U=y15+1.645*s15
gen y15L2=y15-0.675*s15
gen y15U2=y15+0.675*s15
quietly reg pc_rtotal_ps_construction b12.m l(6/17).pc_rtotal_ps_construction L(6/17).pc_u_rate_constr if time<tm(2017m3)
predict y16
predict s16,stdf
gen y16L=y16-1.645*s16
gen y16U=y16+1.645*s16
gen y16L2=y16-0.675*s16
gen y16U2=y16+0.675*s16
quietly reg pc_rtotal_ps_construction b12.m l(7/18).pc_rtotal_ps_construction L(7/18).pc_u_rate_constr if time<tm(2017m3)
predict y17
predict s17,stdf
gen y17L=y17-1.645*s17
gen y17U=y17+1.645*s17
gen y17L2=y17-0.675*s17
gen y17U2=y17+0.675*s17
quietly reg pc_rtotal_ps_construction b12.m l(8/19).pc_rtotal_ps_construction L(8/19).pc_u_rate_constr if time<tm(2017m3)
predict y18
predict s18,stdf
gen y18L=y18-1.645*s18
gen y18U=y18+1.645*s18
gen y18L2=y18-0.675*s18
gen y18U2=y18+0.675*s18
quietly reg pc_rtotal_ps_construction b12.m l(9/20).pc_rtotal_ps_construction L(9/20).pc_u_rate_constr if time<tm(2017m3)
predict y19
predict s19,stdf
gen y19L=y19-1.645*s19
gen y19U=y19+1.645*s19
gen y19L2=y19-0.675*s19
gen y19U2=y19+0.675*s19
quietly reg pc_rtotal_ps_construction b12.m l(10/21).pc_rtotal_ps_construction L(10/21).pc_u_rate_constr if time<tm(2017m3)
predict y110
predict s110,stdf
gen y110L=y110-1.645*s110
gen y110U=y110+1.645*s110
gen y110L2=y110-0.675*s110
gen y110U2=y110+0.675*s110
quietly reg pc_rtotal_ps_construction b12.m l(11/22).pc_rtotal_ps_construction L(11/22).pc_u_rate_constr if time<tm(2017m3)
predict y111
predict s111,stdf
gen y111L=y111-1.645*s111
gen y111U=y111+1.645*s111
gen y111L2=y111-0.675*s111
gen y111U2=y111+0.675*s111
quietly reg pc_rtotal_ps_construction b12.m l(12/23).pc_rtotal_ps_construction L(12/23).pc_u_rate_constr if time<tm(2017m3)
predict y112
predict s112,stdf
gen y112L=y112-1.645*s112
gen y112U=y112+1.645*s112
gen y112L2=y112-0.675*s112
gen y112U2=y112+0.675*s112

*2. Model 2
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread if time<tm(2017m3)
est sto m2
predict y21
predict s21,stdf
gen y21L=y21-1.645*s21
gen y21U=y21+1.645*s21
gen y21L2=y21-0.675*s21
gen y21U2=y21+0.675*s21
quietly reg pc_rtotal_ps_construction b12.m l(2/13).pc_rtotal_ps_construction L(2/13).pc_u_rate_constr L(2/4).corp_spread if time<tm(2017m3)
predict y22
predict s22,stdf
gen y22L=y22-1.645*s22
gen y22U=y22+1.645*s22
gen y22L2=y22-0.675*s22
gen y22U2=y22+0.675*s22
quietly reg pc_rtotal_ps_construction b12.m l(3/14).pc_rtotal_ps_construction L(3/14).pc_u_rate_constr L(3/5).corp_spread if time<tm(2017m3)
predict y23
predict s23,stdf
gen y23L=y23-1.645*s23
gen y23U=y23+1.645*s23
gen y23L2=y23-0.675*s23
gen y23U2=y23+0.675*s23
quietly reg pc_rtotal_ps_construction b12.m l(4/15).pc_rtotal_ps_construction L(4/15).pc_u_rate_constr L(4/6).corp_spread if time<tm(2017m3)
predict y24
predict s24,stdf
gen y24L=y24-1.645*s24
gen y24U=y24+1.645*s24
gen y24L2=y24-0.675*s24
gen y24U2=y24+0.675*s24
quietly reg pc_rtotal_ps_construction b12.m l(5/16).pc_rtotal_ps_construction L(5/16).pc_u_rate_constr L(5/7).corp_spread if time<tm(2017m3)
predict y25
predict s25,stdf
gen y25L=y25-1.645*s25
gen y25U=y25+1.645*s25
gen y25L2=y25-0.675*s25
gen y25U2=y25+0.675*s25
quietly reg pc_rtotal_ps_construction b12.m l(6/17).pc_rtotal_ps_construction L(6/17).pc_u_rate_constr L(6/8).corp_spread if time<tm(2017m3)
predict y26
predict s26,stdf
gen y26L=y26-1.645*s26
gen y26U=y26+1.645*s26
gen y26L2=y26-0.675*s26
gen y26U2=y26+0.675*s26
quietly reg pc_rtotal_ps_construction b12.m l(7/18).pc_rtotal_ps_construction L(7/18).pc_u_rate_constr L(7/9).corp_spread if time<tm(2017m3)
predict y27
predict s27,stdf
gen y27L=y27-1.645*s27
gen y27U=y27+1.645*s27
gen y27L2=y27-0.675*s27
gen y27U2=y27+0.675*s27
quietly reg pc_rtotal_ps_construction b12.m l(8/19).pc_rtotal_ps_construction L(8/19).pc_u_rate_constr L(8/10).corp_spread if time<tm(2017m3)
predict y28
predict s28,stdf
gen y28L=y28-1.645*s28
gen y28U=y28+1.645*s28
gen y28L2=y28-0.675*s28
gen y28U2=y28+0.675*s28
quietly reg pc_rtotal_ps_construction b12.m l(9/20).pc_rtotal_ps_construction L(9/20).pc_u_rate_constr L(9/11).corp_spread if time<tm(2017m3)
predict y29
predict s29,stdf
gen y29L=y29-1.645*s29
gen y29U=y29+1.645*s29
gen y29L2=y29-0.675*s29
gen y29U2=y29+0.675*s29
quietly reg pc_rtotal_ps_construction b12.m l(10/21).pc_rtotal_ps_construction L(10/21).pc_u_rate_constr L(10/12).corp_spread if time<tm(2017m3)
predict y210
predict s210,stdf
gen y210L=y210-1.645*s210
gen y210U=y210+1.645*s210
gen y210L2=y210-0.675*s210
gen y210U2=y210+0.675*s210
quietly reg pc_rtotal_ps_construction b12.m l(11/22).pc_rtotal_ps_construction L(11/22).pc_u_rate_constr L(11/13).corp_spread if time<tm(2017m3)
predict y211
predict s211,stdf
gen y211L=y211-1.645*s211
gen y211U=y211+1.645*s211
gen y211L2=y211-0.675*s211
gen y211U2=y211+0.675*s211
quietly reg pc_rtotal_ps_construction b12.m l(12/23).pc_rtotal_ps_construction L(12/23).pc_u_rate_constr L(12/14).corp_spread if time<tm(2017m3)
predict y212
predict s212,stdf
gen y212L=y212-1.645*s212
gen y212U=y212+1.645*s212
gen y212L2=y212-0.675*s212
gen y212U2=y212+0.675*s212

*3. Model 3
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).pc_housing_starts if time<tm(2017m3)
est sto m3
predict y31
predict s31,stdf
gen y31L=y31-1.645*s31
gen y31U=y31+1.645*s31
gen y31L2=y31-0.675*s31
gen y31U2=y31+0.675*s31
quietly reg pc_rtotal_ps_construction b12.m l(2/13).pc_rtotal_ps_construction L(2/13).pc_u_rate_constr L(2/4).pc_housing_starts if time<tm(2017m3)
predict y32
predict s32,stdf
gen y32L=y32-1.645*s32
gen y32U=y32+1.645*s32
gen y32L2=y32-0.675*s32
gen y32U2=y32+0.675*s32
quietly reg pc_rtotal_ps_construction b12.m l(3/14).pc_rtotal_ps_construction L(3/14).pc_u_rate_constr L(3/5).pc_housing_starts if time<tm(2017m3)
predict y33
predict s33,stdf
gen y33L=y33-1.645*s33
gen y33U=y33+1.645*s33
gen y33L2=y33-0.675*s33
gen y33U2=y33+0.675*s33
quietly reg pc_rtotal_ps_construction b12.m l(4/15).pc_rtotal_ps_construction L(4/15).pc_u_rate_constr L(4/6).pc_housing_starts if time<tm(2017m3)
predict y34
predict s34,stdf
gen y34L=y34-1.645*s34
gen y34U=y34+1.645*s34
gen y34L2=y34-0.675*s34
gen y34U2=y34+0.675*s34
quietly reg pc_rtotal_ps_construction b12.m l(5/16).pc_rtotal_ps_construction L(5/16).pc_u_rate_constr L(5/7).pc_housing_starts if time<tm(2017m3)
predict y35
predict s35,stdf
gen y35L=y35-1.645*s35
gen y35U=y35+1.645*s35
gen y35L2=y35-0.675*s35
gen y35U2=y35+0.675*s35
quietly reg pc_rtotal_ps_construction b12.m l(6/17).pc_rtotal_ps_construction L(6/17).pc_u_rate_constr L(6/8).pc_housing_starts if time<tm(2017m3)
predict y36
predict s36,stdf
gen y36L=y36-1.645*s36
gen y36U=y36+1.645*s36
gen y36L2=y36-0.675*s36
gen y36U2=y36+0.675*s36
quietly reg pc_rtotal_ps_construction b12.m l(7/18).pc_rtotal_ps_construction L(7/18).pc_u_rate_constr L(7/9).pc_housing_starts if time<tm(2017m3)
predict y37
predict s37,stdf
gen y37L=y37-1.645*s37
gen y37U=y37+1.645*s37
gen y37L2=y37-0.675*s37
gen y37U2=y37+0.675*s37
quietly reg pc_rtotal_ps_construction b12.m l(8/19).pc_rtotal_ps_construction L(8/19).pc_u_rate_constr L(8/10).pc_housing_starts if time<tm(2017m3)
predict y38
predict s38,stdf
gen y38L=y38-1.645*s38
gen y38U=y38+1.645*s38
gen y38L2=y38-0.675*s38
gen y38U2=y38+0.675*s38
quietly reg pc_rtotal_ps_construction b12.m l(9/20).pc_rtotal_ps_construction L(9/20).pc_u_rate_constr L(9/11).pc_housing_starts if time<tm(2017m3)
predict y39
predict s39,stdf
gen y39L=y39-1.645*s39
gen y39U=y39+1.645*s39
gen y39L2=y39-0.675*s39
gen y39U2=y39+0.675*s39
quietly reg pc_rtotal_ps_construction b12.m l(10/21).pc_rtotal_ps_construction L(10/21).pc_u_rate_constr L(10/12).pc_housing_starts if time<tm(2017m3)
predict y310
predict s310,stdf
gen y310L=y310-1.645*s310
gen y310U=y310+1.645*s310
gen y310L2=y310-0.675*s310
gen y310U2=y310+0.675*s310
quietly reg pc_rtotal_ps_construction b12.m l(11/22).pc_rtotal_ps_construction L(11/22).pc_u_rate_constr L(11/13).pc_housing_starts if time<tm(2017m3)
predict y311
predict s311,stdf
gen y311L=y311-1.645*s311
gen y311U=y311+1.645*s311
gen y311L2=y311-0.675*s311
gen y311U2=y311+0.675*s311
quietly reg pc_rtotal_ps_construction b12.m l(12/23).pc_rtotal_ps_construction L(12/23).pc_u_rate_constr L(12/14).pc_housing_starts if time<tm(2017m3)
predict y312
predict s312,stdf
gen y312L=y312-1.645*s312
gen y312U=y312+1.645*s312
gen y312L2=y312-0.675*s312
gen y312U2=y312+0.675*s312

*Model 4
reg pc_rtotal_ps_construction b12.m l(1/12).pc_rtotal_ps_construction L(1/12).pc_u_rate_constr L(1/3).corp_spread L(1/3).pc_housing_starts if time<tm(2017m3)
est sto m4
predict y41
predict s41,stdf
gen y41L=y41-1.645*s41
gen y41U=y41+1.645*s41
gen y41L2=y41-0.675*s41
gen y41U2=y41+0.675*s41
quietly reg pc_rtotal_ps_construction b12.m l(2/13).pc_rtotal_ps_construction L(2/13).pc_u_rate_constr L(2/4).corp_spread L(2/4).pc_housing_starts if time<tm(2017m3)
predict y42
predict s42,stdf
gen y42L=y42-1.645*s42
gen y42U=y42+1.645*s42
gen y42L2=y42-0.675*s42
gen y42U2=y42+0.675*s42
quietly reg pc_rtotal_ps_construction b12.m l(3/14).pc_rtotal_ps_construction L(3/14).pc_u_rate_constr L(3/5).corp_spread L(3/5).pc_housing_starts if time<tm(2017m3)
predict y43
predict s43,stdf
gen y43L=y43-1.645*s43
gen y43U=y43+1.645*s43
gen y43L2=y43-0.675*s43
gen y43U2=y43+0.675*s43
quietly reg pc_rtotal_ps_construction b12.m l(4/15).pc_rtotal_ps_construction L(4/15).pc_u_rate_constr L(4/6).corp_spread L(4/6).pc_housing_starts if time<tm(2017m3)
predict y44
predict s44,stdf
gen y44L=y44-1.645*s44
gen y44U=y44+1.645*s44
gen y44L2=y44-0.675*s44
gen y44U2=y44+0.675*s44
quietly reg pc_rtotal_ps_construction b12.m l(5/16).pc_rtotal_ps_construction L(5/16).pc_u_rate_constr L(5/7).corp_spread L(5/7).pc_housing_starts if time<tm(2017m3)
predict y45
predict s45,stdf
gen y45L=y45-1.645*s45
gen y45U=y45+1.645*s45
gen y45L2=y45-0.675*s45
gen y45U2=y45+0.675*s45
quietly reg pc_rtotal_ps_construction b12.m l(6/17).pc_rtotal_ps_construction L(6/17).pc_u_rate_constr L(6/8).corp_spread L(6/8).pc_housing_starts if time<tm(2017m3)
predict y46
predict s46,stdf
gen y46L=y46-1.645*s46
gen y46U=y46+1.645*s46
gen y46L2=y46-0.675*s46
gen y46U2=y46+0.675*s46
quietly reg pc_rtotal_ps_construction b12.m l(7/18).pc_rtotal_ps_construction L(7/18).pc_u_rate_constr L(7/9).corp_spread L(7/9).pc_housing_starts if time<tm(2017m3)
predict y47
predict s47,stdf
gen y47L=y47-1.645*s47
gen y47U=y47+1.645*s47
gen y47L2=y47-0.675*s47
gen y47U2=y47+0.675*s47
quietly reg pc_rtotal_ps_construction b12.m l(8/19).pc_rtotal_ps_construction L(8/19).pc_u_rate_constr L(8/10).corp_spread L(8/10).pc_housing_starts if time<tm(2017m3)
predict y48
predict s48,stdf
gen y48L=y48-1.645*s48
gen y48U=y48+1.645*s48
gen y48L2=y48-0.675*s48
gen y48U2=y48+0.675*s48
quietly reg pc_rtotal_ps_construction b12.m l(9/20).pc_rtotal_ps_construction L(9/20).pc_u_rate_constr L(9/11).corp_spread L(9/11).pc_housing_starts if time<tm(2017m3)
predict y49
predict s49,stdf
gen y49L=y49-1.645*s49
gen y49U=y49+1.645*s49
gen y49L2=y49-0.675*s49
gen y49U2=y49+0.675*s49
quietly reg pc_rtotal_ps_construction b12.m l(10/21).pc_rtotal_ps_construction L(10/21).pc_u_rate_constr L(10/12).corp_spread L(10/12).pc_housing_starts if time<tm(2017m3)
predict y410
predict s410,stdf
gen y410L=y410-1.645*s410
gen y410U=y410+1.645*s410
gen y410L2=y410-0.675*s410
gen y410U2=y410+0.675*s410
quietly reg pc_rtotal_ps_construction b12.m l(11/22).pc_rtotal_ps_construction L(11/22).pc_u_rate_constr L(11/13).corp_spread L(11/13).pc_housing_starts if time<tm(2017m3)
predict y411
predict s411,stdf
gen y411L=y411-1.645*s411
gen y411U=y411+1.645*s411
gen y411L2=y411-0.675*s411
gen y411U2=y411+0.675*s411
quietly reg pc_rtotal_ps_construction b12.m l(12/23).pc_rtotal_ps_construction L(12/23).pc_u_rate_constr L(12/14).corp_spread L(12/14).pc_housing_starts if time<tm(2017m3)
predict y412
predict s412,stdf
gen y412L=y412-1.645*s412
gen y412U=y412+1.645*s412
gen y412L2=y412-0.675*s412
gen y412U2=y412+0.675*s412

// esttab m1 m2 m3 m4 using adlmodels.tex, replace label aic nonumber title("Autoregressive Distributed Lag Models") mtitle("Model 1" "Model 2" "Model 3" "Model 4")
// esttab m1 m2 m3 m4 using adlmodels.tex, replace label aic nonumber title("Autoregressive Distributed Lag Models") mtitle("Model 1" "Model 2" "Model 3" "Model 4")

*Combine Model 1 predictions for the 12-step ahead forecasts and intervals

egen p1=rowfirst(y11 y12 y13 y14 y15 y16 y17 y18 y19 y110 y111 y112) if time>tm(2017m2)
egen p1L=rowfirst(y11L y12L y13L y14L y15L y16L y17L y18L y19L y110L y111L y112L) if time>tm(2017m2)
egen p1U=rowfirst(y11U y12U y13U y14U y15U y16U y17U y18U y19U y110U y111U y112U) if time>tm(2017m2)
egen p1L2=rowfirst(y11L2 y12L2 y13L2 y14L2 y15L2 y16L2 y17L2 y18L2 y19L2 y110L2 y111L2 y112L2) if time>tm(2017m2)
egen p1U2=rowfirst(y11U2 y12U2 y13U2 y14U2 y15U2 y16U2 y17U2 y18U2 y19U2 y110U2 y111U2 y112U2) if time>tm(2017m2)
egen se1=rowfirst(s11 s12 s13 s14 s15 s16 s17 s18 s19 s110 s111 s112) if time>tm(2017m2)

*Combine Model 2 predictions for the 12-step ahead forecasts and intervals

egen p2=rowfirst(y21 y22 y23 y24 y25 y26 y27 y28 y29 y210 y211 y212) if time>tm(2017m2)
egen p2L=rowfirst(y21L y22L y23L y24L y25L y26L y27L y28L y29L y210L y211L y212L) if time>tm(2017m2)
egen p2U=rowfirst(y21U y22U y23U y24U y25U y26U y27U y28U y29U y210U y211U y212U) if time>tm(2017m2)
egen p2L2=rowfirst(y21L2 y22L2 y23L2 y24L2 y25L2 y26L2 y27L2 y28L2 y29L2 y210L2 y211L2 y212L2) if time>tm(2017m2)
egen p2U2=rowfirst(y21U2 y22U2 y23U2 y24U2 y25U2 y26U2 y27U2 y28U2 y29U2 y210U2 y211U2 y212U2) if time>tm(2017m2)
egen se2=rowfirst(s21 s22 s23 s24 s25 s26 s27 s28 s29 s210 s211 s212) if time>tm(2017m2)

*Combine Model 3 predictions for the 12-step ahead forecasts and intervals

egen p3=rowfirst(y31 y32 y33 y34 y35 y36 y37 y38 y39 y310 y311 y312) if time>tm(2017m2)
egen p3L=rowfirst(y31L y32L y33L y34L y35L y36L y37L y38L y39L y310L y311L y312L) if time>tm(2017m2)
egen p3U=rowfirst(y31U y32U y33U y34U y35U y36U y37U y38U y39U y310U y311U y312U) if time>tm(2017m2)
egen p3L2=rowfirst(y31L2 y32L2 y33L2 y34L2 y35L2 y36L2 y37L2 y38L2 y39L2 y310L2 y311L2 y312L2) if time>tm(2017m2)
egen p3U2=rowfirst(y31U2 y32U2 y33U2 y34U2 y35U2 y36U2 y37U2 y38U2 y39U2 y310U2 y311U2 y312U2) if time>tm(2017m2)
egen se3=rowfirst(s31 s32 s33 s34 s35 s36 s37 s38 s39 s310 s311 s312) if time>tm(2017m2)


*Combine Model 4 predictions for the 12-step ahead forecasts and intervals

egen p4=rowfirst(y41 y42 y43 y44 y45 y46 y47 y48 y49 y410 y411 y412) if time>tm(2017m2)
egen p4L=rowfirst(y41L y42L y43L y44L y45L y46L y47L y48L y49L y410L y411L y412L) if time>tm(2017m2)
egen p4U=rowfirst(y41U y42U y43U y44U y45U y46U y47U y48U y49U y410U y411U y412U) if time>tm(2017m2)
egen p4L2=rowfirst(y41L2 y42L2 y43L2 y44L2 y45L2 y46L2 y47L2 y48L2 y49L2 y410L2 y411L2 y412L2) if time>tm(2017m2)
egen p4U2=rowfirst(y41U2 y42U2 y43U2 y44U2 y45U2 y46U2 y47U2 y48U2 y49U2 y410U2 y411U2 y412U2) if time>tm(2017m2)
egen se4=rowfirst(s41 s42 s43 s44 s45 s46 s47 s48 s49 s410 s411 s412) if time>tm(2017m2)

*Label point and interval forecast variables accordingly...

label variable p1 "Point Forecast, Model 1"
label variable time "Time (Monthly, m)"
label variable p1L "Model 1: Lower Forecast Interval (90%)"
label variable p1U "Model 1: Upper Forecast Interval (90%)"
label variable p1L2 "Model 1: Lower Forecast Interval (50%)"
label variable p1U2 "Model 1: Upper Forecast Interval (50%)"

label variable p2 "Point Forecast, Model 2"
label variable p2L "Model 2: Lower Forecast Interval (90%)"
label variable p2U "Model 2: Upper Forecast Interval (90%)"
label variable p2L2 "Model 2: Lower Forecast Interval (50%)"
label variable p2U2 "Model 2: Upper Forecast Interval (50%)"

label variable p3 "Point Forecast, Model 3"
label variable p3L "Model 3: Lower Forecast Interval (90%)"
label variable p3U "Model 3: Upper Forecast Interval (90%)"
label variable p3L2 "Model 3: Lower Forecast Interval (50%)"
label variable p3U2 "Model 3: Upper Forecast Interval (50%)"

label variable p4 "Point Forecast, Model 4"
label variable p4L "Model 4: Lower Forecast Interval (90%)"
label variable p4U "Model 4: Upper Forecast Interval (90%)"
label variable p4L2 "Model 4: Lower Forecast Interval (50%)"
label variable p4U2 "Model 4: Upper Forecast Interval (50%)"


*Create time anchor at time = 2017m2
foreach var in p1 p2 p3 p4 p1L p1U p2L p2U p3L p3U p4L p4U p1L2 p1U2 p2L2 p2U2 p3L2 p3U2 p4L2 p4U2{
	replace `var' = -.1543152 in 842
}

*Time-Series Graph: Historical Time-Series
tsline pc_rtotal_ps_construction if tin(2008m2, 2017m2), ///
tlabel(#10, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##12) ///
ylabel(,labsize(small)) ytitle("", size(small)) ttitle("Time" "(Monthly)", size(small)) ///
caption("Source: FRED, U.S. Census Bureau") legend(size(vsmall)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_realpcpsc
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_realpcpsc.png", as(png) replace

*Time-Series Graph: Forecasts with ADL Models 1-4 (Point Forecasts only)
tsline pc_rtotal_ps_construction p1 p2 p3 p4 if time>tm(2000m1), ///
lpattern(solid shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue erose eltgreen) ///
tlabel(#18, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##12) tline(2017m2) ///
ylabel(,labsize(small)) ytitle("Percent Change", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) ///
graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_models1234
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_models1234.png", as(png) replace

*Time-Series Graph: Forecasts with ADL Model 1 (Point Forecasts only)
tsline pc_rtotal_ps_construction p1 if time>tm(2000m1), ///
lpattern(solid shortdash) lcolor(edkblue emidblue) ///
tlabel(#18, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##12) tline(2017m2) ylabel(,labsize(small)) ///
ytitle("Percent Change", size(small)) ttitle("Time" "(Monthly)", size(small)) ///
 title("Forecast for Total Real Private Sector Construction", size(med)) caption("Source: FRED, U.S. Census Bureau") legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_models1
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_models1.png", as(png) replace

*Time-Series Graph: Forecasts with ADL Model 2 (Point Forecasts only)
tsline pc_rtotal_ps_construction p2 if time>tm(2000m1), ///
lpattern(solid shortdash) lcolor(edkblue eltblue) ///
tlabel(#18, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##12) tline(2017m2) ylabel(,labsize(small)) ytitle("Percent Change", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_models2
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_models2.png", as(png) replace

* Time-Series Graph: Forecasts with ADL Model 3 (Point Forecasts only)
tsline pc_rtotal_ps_construction p3 if time>tm(2000m1), ///
lpattern(solid shortdash) lcolor(edkblue erose) ///
tlabel(#18, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##12) tline(2017m2) ylabel(,labsize(small)) ///
ytitle("Percent Change", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_models3
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_models3.png", as(png) replace

* Time-Series Graph: Forecasts with ADL Model 4 (Point Forecasts only)
tsline pc_rtotal_ps_construction p4 if time>tm(2000m1), ///
lpattern(solid shortdash) lcolor(edkblue eltgreen) ///
tlabel(#18, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##12) tline(2017m2) ylabel(,labsize(small)) ///
ytitle("Percent Change", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_models4
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_models4.png", as(png) replace

* Time-Series Graph: Historical Time-Series, Real and Nominal Values
tsline total_ps_construction rtotal_ps_construction if tin(2008m2, 2017m2), ///
tlabel(#10, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##12) ///
ylabel(,labsize(small)) ytitle("", size(small)) ttitle("Time" "(Monthly)", size(small)) ///
caption("Source: FRED, U.S. Census Bureau") legend(size(vsmall)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_realnominallevels
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_realnominallevels.png", as(png) replace

* Granger-Ramanathan Combination Method (1-step)
constraint 1 y11+y21+y31+y41=1
cnsreg pc_rtotal_ps_construction y11 y21 y31 y41, constraints(1) noconstant

* Granger-Ramanathan Combination Method (2-step)
constraint 2 y12+y22+y32+y42=1
cnsreg pc_rtotal_ps_construction y12 y22 y32 y42, constraints(2) noconstant

* Granger-Ramanathan Combination Method (3-step)
constraint 3 y13+y23+y33+y43=1
cnsreg pc_rtotal_ps_construction y13 y23 y33 y43, constraints(3) noconstant

* Granger-Ramanathan Combination Method (4-step)
constraint 4 y14+y24+y34+y44=1
cnsreg pc_rtotal_ps_construction y14 y24 y34 y44, constraints(4) noconstant

* Granger-Ramanathan Combination Method (5-step)
constraint 5 y15+y25+y35+y45=1
cnsreg pc_rtotal_ps_construction y15 y25 y35 y45, constraints(5) noconstant

* Granger-Ramanathan Combination Method (6-step)
constraint 6 y16+y26+y36+y46=1
cnsreg pc_rtotal_ps_construction y16 y26 y36 y46, constraints(6) noconstant

* Granger-Ramanathan Combination Method (7-step)
constraint 7 y17+y27+y37+y47=1
cnsreg pc_rtotal_ps_construction y17 y27 y37 y47, constraints(7) noconstant

* Granger-Ramanathan Combination Method (8-step)
constraint 8 y18+y28+y38+y48=1
cnsreg pc_rtotal_ps_construction y18 y28 y38 y48, constraints(8) noconstant

* Granger-Ramanathan Combination Method (9-step)
constraint 9 y19+y29+y39+y49=1
cnsreg pc_rtotal_ps_construction y19 y29 y39 y49, constraints(9) noconstant

* Granger-Ramanathan Combination Method (10-step)
constraint 10 y110+y210+y310+y410=1
cnsreg pc_rtotal_ps_construction y110 y210 y310 y410, constraints(10) noconstant

* Granger-Ramanathan Combination Method (11-step)
constraint 11 y111+y211+y311+y411=1
cnsreg pc_rtotal_ps_construction y111 y211 y311 y411, constraints(11) noconstant

* Granger-Ramanathan Combination Method (12-step)
constraint 12 y112+y212+y312+y412=1
cnsreg pc_rtotal_ps_construction y112 y212 y312 y412, constraints(12) noconstant




* Vector Autoregression Forecast Model 1
varbasic pc_rtotal_ps_construction pc_u_rate_constr, lags(1/12) nograph
varsoc pc_rtotal_ps_construction pc_u_rate_constr, maxlag(12)
fcast compute f1_, step(12)
fcast graph f1_pc_rtotal_ps_construction, ///
xtick(#12) ytick(#50) legend(off) subtitle("12-Step Forecast") ///
ytitle("Percent Change") yline(0, lcolor(red)) xtitle("Time, monthly (m)") ///
title("Forecast for Total Real Private Sector Construction") ///
note("Source: FRED, U.S. Census Bureau") legend(off)


quietly varbasic pc_rtotal_ps_construction pc_u_rate_constr, lags(1/12) nograph

*Impulse-Response Graphs (Muted)
/*
irf graph oirf, impulse(pc_rtotal_ps_construction) response(pc_rtotal_ps_construction) subtitle("Change in Construction Shock on Change in Construction") legend(off) xtitle("Month, m") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR1_IR1
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR1_IR1.png", as(png) replace
irf graph oirf, impulse(pc_u_rate_constr) response(pc_rtotal_ps_construction) legend(size(vsmall)) xtitle("Month, m") xtick(#15) ytick(#20) subtitle("Construction Worker Unemployment Rate Shock on Change in Construction") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR1_IR2
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR1_IR2.png", as(png) replace
*/

*Vector Autoregression Forecast Model 2
varbasic pc_rtotal_ps_construction corp_spread, lags(1/12) nograph
varsoc pc_rtotal_ps_construction corp_spread, maxlag(12)
fcast compute f2_, step(12)
fcast graph f2_pc_rtotal_ps_construction, ///
xtick(#12) ytick(#50) legend(off) subtitle("12-Step Forecast") ///
ytitle("Percent Change") yline(0, lcolor(red)) xtitle("Time, monthly (m)") ///
title("Forecast for Total Real Private Sector Construction") ///
note("Source: FRED, U.S. Census Bureau") legend(off)


quietly varbasic pc_rtotal_ps_construction corp_spread, lags(1/12) nograph

*Impulse-Response Graphs (Muted)
/*
irf graph oirf, impulse(pc_rtotal_ps_construction) response(pc_rtotal_ps_construction) legend(off) xtitle("Month, m") subtitle("Change in Construction Shock on Change in Construction") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR2_IR1
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR2_IR1.png", as(png) replace
irf graph oirf, impulse(corp_spread) response(pc_rtotal_ps_construction) legend(off) xtitle("Month, m") subtitle("Corporate Bond Spread Shock on Change in Construction") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR2_IR2
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR2_IR2.png", as(png) replace
*/

*Vector Autoregression Forecast Model 3
varbasic pc_rtotal_ps_construction corp_spread pc_u_rate_constr, lags(1/12) nograph

varsoc pc_rtotal_ps_construction corp_spread pc_u_rate_constr, maxlag(12)

fcast compute f3_, step(12)
fcast graph f3_pc_rtotal_ps_construction, ///
xtick(#12) ytick(#50) legend(off) subtitle("12-Step Forecast") ///
ytitle("Percent Change") yline(0, lcolor(red)) xtitle("Time, monthly (m)") ///
title("Forecast for Total Real Private Sector Construction") ///
note("Source: FRED, U.S. Census Bureau") legend(off)


quietly varbasic pc_rtotal_ps_construction corp_spread pc_u_rate_constr, lags(1/12) nograph

*Impulse-Response Graphs (Muted)
/*
irf graph oirf, impulse(pc_rtotal_ps_construction) response(pc_rtotal_ps_construction) legend(off) xtitle("Month, m") subtitle("Change in Construction Shock on Change in Construction") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR3_IR1
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR3_IR1.png", as(png) replace
irf graph oirf, impulse(corp_spread) response(pc_rtotal_ps_construction) legend(off) xtitle("Month, m") subtitle("Corporate Bond Spread Shock on Change in Construction") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR3_IR2
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR3_IR2.png", as(png) replace
irf graph oirf, impulse(pc_u_rate_constr) response(pc_rtotal_ps_construction) legend(off) xtitle("Month, m") subtitle("Construction Worker Unemployment Rate Shock on Change in Construction") note("Source: FRED, U.S. Census Bureau")
graph rename ec460_forecast_VAR3_IR3
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR3_IR3.png", as(png) replace
*/

*Rename variables from VAR forecast models as forecasts #5-7, with "v_" prefix for "vector autoregression":
rename f1_pc_rtotal_ps_construction v_p5
rename f2_pc_rtotal_ps_construction v_p6
rename f3_pc_rtotal_ps_construction v_p7

*Rename forecast interval bounds according to previous format for ADL models.
rename f1_pc_rtotal_ps_construction_UB v_p5U
rename f2_pc_rtotal_ps_construction_UB v_p6U
rename f3_pc_rtotal_ps_construction_UB v_p7U

rename f1_pc_rtotal_ps_construction_LB v_p5L
rename f2_pc_rtotal_ps_construction_LB v_p6L
rename f3_pc_rtotal_ps_construction_LB v_p7L

*Label variables accordingly.
label variable v_p5U "Upper Forecast Interval (95%)"
label variable v_p5L "Lower Forecast Interval (95%)"
label variable v_p6U "Upper Forecast Interval (95%)"
label variable v_p6L "Lower Forecast Interval (95%)"
label variable v_p7U "Upper Forecast Interval (95%)"
label variable v_p7L "Lower Forecast Interval (95%)"

rename f1_pc_rtotal_ps_construction_SE v_se5
rename f2_pc_rtotal_ps_construction_SE v_se6
rename f3_pc_rtotal_ps_construction_SE v_se7

*Rename forecasted variable "y"
rename pc_rtotal_ps_construction y

*Generate 80% forecast intervals (normal method) for ADL Model 4
gen p4U3 = p4+1.282*se4
gen p4L3 = p4-1.282*se4

*Relabel the variables
label variable p4U "Upper Forecast Interval (90%)"
label variable p4L "Lower Forecast Interval (90%)"
label variable p4U2 "Upper Forecast Interval (50%)"
label variable p4L2 "Lower Forecast Interval (50%)"
label variable p4U3 "Upper Forecast Interval (80%)"
label variable p4L3 "Lower Forecast Interval (80%)"

*Generate 50%, 80% forecast interval bounds for VAR models
gen v_p5U2 = v_p5+0.675*v_se5
gen v_p5L2 = v_p5-0.675*v_se5
gen v_p5U3 = v_p5+1.282*v_se5
gen v_p5L3 = v_p5-1.282*v_se5

gen v_p6U2 = v_p6+0.675*v_se6
gen v_p6L2 = v_p6-0.675*v_se6
gen v_p6U3 = v_p6+1.282*v_se6
gen v_p6L3 = v_p6-1.282*v_se6

gen v_p7U2 = v_p7+0.675*v_se7
gen v_p7L2 = v_p7-0.675*v_se7
gen v_p7U3 = v_p7+1.282*v_se7
gen v_p7L3 = v_p7-1.282*v_se7

*Label the variables accordingly.
label variable v_p7U2 "Upper Forecast Interval (50%)"
label variable v_p7L2 "Lower Forecast Interval (50%)"
label variable v_p7U3 "Upper Forecast Interval (80%)"
label variable v_p7L3 "Lower Forecast Interval (80%)"

label variable v_p6U2 "Upper Forecast Interval (50%)"
label variable v_p6L2 "Lower Forecast Interval (50%)"
label variable v_p6U3 "Upper Forecast Interval (80%)"
label variable v_p6L3 "Lower Forecast Interval (80%)"

label variable v_p5U2 "Upper Forecast Interval (50%)"
label variable v_p5L2 "Lower Forecast Interval (50%)"
label variable v_p5U3 "Upper Forecast Interval (80%)"
label variable v_p5L3 "Lower Forecast Interval (80%)"

label variable p4 "Point Forecast"
label variable v_p5 "Point Forecast"
label variable v_p6 "Point Forecast"
label variable v_p7 "Point Forecast"

label variable y "Historical (Realized)"

*Create level version of historical series
rename rtotal_ps_construction level_y
//21344.424


*Create level versions of point and interval forecasts
foreach var in p4 p4U p4L p4U2 p4L2 p4U3 p4L3 v_p5 v_p5U v_p5L v_p5U2 v_p5L2 v_p5U3 v_p5L3 v_p6 v_p6U v_p6L v_p6U2 v_p6L2 v_p6U3 v_p6L3 v_p7 v_p7U v_p7L v_p7U2 v_p7L2 v_p7U3 v_p7L3{
	gen level_`var' = (1+(`var'/100))*59600.914
	replace level_`var' = (1+(`var'/100))*L.level_`var' if time>tm(2017m3)
	replace level_`var' = 59600.914 in 842
}
*Create level versions of standard errors
foreach var in se4 v_se5 v_se6 v_se7{
	gen level_`var' = (1+(`var'/100))*59600.914
	replace level_`var' = (1+(`var'/100))*L.level_`var' if time>tm(2017m3)
	replace level_`var' = 0 in 842
}
*Create variable labels for level versions
label variable level_y "Historical (Realized)"

label variable level_p4 "Point Forecast"
label variable level_v_p5 "Point Forecast"
label variable level_v_p6 "Point Forecast"
label variable level_v_p7 "Point Forecast"

label variable level_p4U "Upper Forecast Interval (90%)"
label variable level_p4L "Lower Forecast Interval (90%)"
label variable level_v_p5U "Upper Forecast Interval (95%)"
label variable level_v_p5L "Lower Forecast Interval (95%)"
label variable level_v_p6U "Upper Forecast Interval (95%)"
label variable level_v_p6L "Lower Forecast Interval (95%)"
label variable level_v_p7U "Upper Forecast Interval (95%)"
label variable level_v_p7L "Lower Forecast Interval (95%)"

label variable level_p4U2 "Upper Forecast Interval (50%)"
label variable level_p4L2 "Lower Forecast Interval (50%)"
label variable level_v_p5U2 "Upper Forecast Interval (50%)"
label variable level_v_p5L2 "Lower Forecast Interval (50%)"
label variable level_v_p6U2 "Upper Forecast Interval (50%)"
label variable level_v_p6L2 "Lower Forecast Interval (50%)"
label variable level_v_p7U2 "Upper Forecast Interval (50%)"
label variable level_v_p7L2 "Lower Forecast Interval (50%)"

label variable level_p4U3 "Upper Forecast Interval (80%)"
label variable level_p4L3 "Lower Forecast Interval (80%)"
label variable level_v_p5U3 "Upper Forecast Interval (80%)"
label variable level_v_p5L3 "Lower Forecast Interval (80%)"
label variable level_v_p6U3 "Upper Forecast Interval (80%)"
label variable level_v_p6L3 "Lower Forecast Interval (80%)"
label variable level_v_p7U3 "Upper Forecast Interval (80%)"
label variable level_v_p7L3 "Lower Forecast Interval (80%)"



*Generate fan charts for level versions of ADL Model 4, VAR Models 1-3
tsline level_y level_p4 level_p4U level_p4L level_p4U2 level_p4L2 level_p4U3 level_p4L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ///
tline(2017m2) ttext(45000 2017m7 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_model4levelfan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_model4levelfan.png", as(png) replace

tsline level_y level_v_p5 level_v_p5U level_v_p5L level_v_p5U2 level_v_p5L2 level_v_p5U3 level_v_p5L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ///
tline(2017m2) ttext(45000 2017m7 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_VAR1levelfan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR1levelfan.png", as(png) replace

tsline level_y level_v_p6 level_v_p6U level_v_p6L level_v_p6U2 level_v_p6L2 level_v_p6U3 level_v_p6L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ///
tline(2017m2) ttext(45000 2017m7 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_VAR2levelfan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR2levelfan.png", as(png) replace

tsline level_y level_v_p7 level_v_p7U level_v_p7L level_v_p7U2 level_v_p7L2 level_v_p7U3 level_v_p7L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ///
tline(2017m2) ttext(45000 2017m7 "Forecast Projections", color(cranberry)) ylabel(,labsize(small)) ///
ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_VAR3levelfan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR3levelfan.png", as(png) replace

*Create time-anchor at time = 2017m2
foreach var in p4 p4U p4L p4U2 p4L2 p4U3 p4L3 v_p5 v_p5U v_p5L v_p5U2 v_p5L2 v_p5U3 v_p5L3 v_p6 v_p6U v_p6L v_p6U2 v_p6L2 v_p6U3 v_p6L3 v_p7 v_p7U v_p7L v_p7U2 v_p7L2 v_p7U3 v_p7L3{
	replace `var' = -.1543152 in 842
}
*Generate fan charts for forecasted growth rates
tsline y p4 p4U p4L p4U2 p4L2 p4U3 p4L3 if time>tm(2016m2), lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) tline(2017m2) ylabel(,labsize(small)) ytitle("Percent Change", size(small)) ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) caption("Source: FRED, U.S. Census Bureau") legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_model4fan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_model4fan.png", as(png) replace
tsline y v_p5 v_p5U v_p5L v_p5U2 v_p5L2 v_p5U3 v_p5L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) tline(2017m2) ylabel(,labsize(small)) ///
ytitle("Percent Change", size(small)) ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_VAR1fan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR1fan.png", as(png) replace

tsline y v_p6 v_p6U v_p6L v_p6U2 v_p6L2 v_p6U3 v_p6L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) ///
tline(2017m2) ylabel(,labsize(small)) ytitle("Percent Change", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_VAR2fan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR2fan.png", as(png) replace

tsline y v_p7 v_p7U v_p7L v_p7U2 v_p7L2 v_p7U3 v_p7L3 if time>tm(2016m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen) ///
tlabel(#5, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##6) tline(2017m2) ///
ylabel(,labsize(small)) ytitle("Percent Change", size(small)) ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_VAR3fan
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_VAR3fan.png", as(png) replace

*Re-label variables for time-series graph comparing the different forecast estimates
label variable p4 "Point Forecast, ADL Model"
label variable v_p5 "Point Forecast, VAR Model 1"
label variable v_p6 "Point Forecast, VAR Model 2"
label variable v_p7 "Point Forecast, VAR Model 3"

*Time-series graph comparing the different forecast estimates (selected models)
tsline y p4 v_p5 v_p6 v_p7 if tin(2016m7, 2018m2),  lpattern(solid shortdash longdash longdash longdash)  ///
yline(0, lcolor(red)) ///
tlabel(#4, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##2) tline(2017m2) ///
ttext(-5 2017m5 "Forecast Projections", color(cranberry)) ylabel(,labsize(small)) ///
ytitle("Percent Change (%)" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_comparison
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_comparison.png", as(png) replace

*Re-label variables for time-series graph comparing the different forecast estimates
label variable p1 "Point Forecast, ADL Model 1"
label variable p2 "Point Forecast, ADL Model 2"
label variable p3 "Point Forecast, ADL Model 3"
label variable p4 "Point Forecast, ADL Model 4"

*Time-series graph comparing the different forecast estimates (all models)
tsline y p1 p2 p3 p4 v_p5 v_p6 v_p7 if time>tm(2016m10), ///
lpattern(solid shortdash shortdash shortdash shortdash longdash longdash longdash) ///
tlabel(#4, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##3) tline(2017m2) ylabel(,labsize(small)) ///
ytitle("Percent Change", size(small)) ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460_forecast_comparison_all
graph export "/Users/nwheinrich/Documents/Stata/460/ec460_forecast_comparison_all.png", as(png) replace

*List the numerical values of all forecast estimates for ADL Model 4 (Growth Rates)
list time p4 p4L p4U p4L2 p4U2 p4L3 p4U3 if tin(2017m3, 2018m2), clean header noobs

*List the numerical values of all forecast estimates for VAR Model 1 (Growth Rates)
list time v_p5 v_p5L v_p5U v_p5L2 v_p5U2 v_p5L3 v_p5U3 if tin(2017m3, 2018m2), clean header noobs

*List the numerical values of all forecast estimates for VAR Model 2 (Growth Rates)
list time v_p6 v_p6L v_p6U v_p6L2 v_p6U2 v_p6L3 v_p6U3 if tin(2017m3, 2018m2), clean header noobs

*List the numerical values of all forecast estimates for VAR Model 3 (Growth Rates)
list time v_p7 v_p7L v_p7U v_p7L2 v_p7U2 v_p7L3 v_p7U3 if tin(2017m3, 2018m2), clean header noobs

*List the numerical values of all forecast estimates for ADL Model 4 (Levels)
list time level_p4 level_p4L level_p4U level_p4L2 level_p4U2 level_p4L3 level_p4U3 if tin(2017m3, 2018m2), clean header noobs

* List the numerical values of all forecast estimates for VAR Model 1 (Levels)
list time level_v_p5 level_v_p5L level_v_p5U level_v_p5L2 level_v_p5U2 level_v_p5L3 level_v_p5U3 if tin(2017m3, 2018m2), clean header noobs

* List the numerical values of all forecast estimates for VAR Model 2 (Levels)
list time level_v_p6 level_v_p6L level_v_p6U level_v_p6L2 level_v_p6U2 level_v_p6L3 level_v_p6U3 if tin(2017m3, 2018m2), clean header noobs

* List the numerical values of all forecast estimates for VAR Model 3 (Levels)
list time level_v_p7 level_v_p7L level_v_p7U level_v_p7L2 level_v_p7U2 level_v_p7L3 level_v_p7U3 if tin(2017m3, 2018m2), clean header noobs

*Create a variable for releases since initial forecast, replace values as new monthly data is released
gen step12 =.
replace step12 = 59600.914 in 842
replace step12 = (75741*(100/112.536)) in 843
replace step12 = (77518*(100/112.742)) in 844
replace step12 = (82288*(100/112.824)) in 845
replace step12 = (86408*(100/112.974)) in 846
replace step12 = (85712*(100/113.083)) in 847
replace step12 = (84938*(100/113.206)) in 848 // Aug 2017
replace step12 = (85157*(100/113.378)) in 849 // Sep 2017
replace step12 = (84403*(100/113.645)) in 850 // Oct 2017
replace step12 = (81618*(100/113.732)) in 851 // Nov 2017
replace step12 = (76593*(100/113.918)) in 852 // Dec 2017
replace step12 = (69097*(100/114.246)) in 853 // Jan 2018
replace step12 = (69696*(100/114.507)) in 854 // Feb 2018


label variable step12 "Actual Realization"

// /Users/nwheinrich/Documents/Stata/460

*List all the releases since the initial forecast
list time step12 if tin(2017m3, 2018m2), clean header noobs

*Fan Plot with Forecast Projections and Current Releases for ADL Model 4
tsline level_y level_p4 level_p4U level_p4L level_p4U2 level_p4L2 level_p4U3 level_p4L3 step12 if tin(2016m7, 2018m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash solid) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen ebblue) ///
tlabel(#4, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##2) tline(2017m2) ttext(97000 2017m5 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_model4release
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_model4release.png", as(png) replace

*Fan Plot with Forecast Projections and Current Releases for VAR Model 1
tsline level_y level_v_p5 level_v_p5U level_v_p5L level_v_p5U2 level_v_p5L2 level_v_p5U3 level_v_p5L3 step12 if tin(2016m7, 2018m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash solid) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen ebblue) ///
tlabel(#4, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##2) tline(2017m2) ttext(97000 2017m5 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_VAR1release
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_VAR1release.png", as(png) replace

*Fan Plot with Forecast Projections and Current Releases for VAR Model 2
tsline level_y level_v_p6 level_v_p6U level_v_p6L level_v_p6U2 level_v_p6L2 level_v_p6U3 level_v_p6L3 step12 if tin(2016m7, 2018m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash solid) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen ebblue) ///
tlabel(#4, labsize(small) angle(315) format(%tmMon_CCYY)) ///
tmtick(##2) tline(2017m2) ttext(97000 2017m5 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) ///
title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_VAR2release
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_VAR2release.png", as(png) replace

*Fan Plot with Forecast Projections and Current Releases for VAR Model 3
tsline level_y level_v_p7 level_v_p7U level_v_p7L level_v_p7U2 level_v_p7L2 level_v_p7U3 level_v_p7L3 step12 if tin(2016m7, 2018m2), ///
lpattern(solid longdash shortdash shortdash shortdash shortdash shortdash shortdash solid) ///
lcolor(edkblue emidblue eltblue eltblue erose erose eltgreen eltgreen ebblue) ///
tlabel(#4, labsize(small) angle(315) format(%tmMon_CCYY)) tmtick(##2) tline(2017m2) ///
ttext(97000 2017m5 "Forecast Projections", color(cranberry)) ///
ylabel(,labsize(small)) ytitle("Real Construction Expenditures" "Thousands of U.S. Dollars", size(small)) ///
ttitle("Time" "(Monthly)", size(small)) title("Forecast for Total Real Private Sector Construction", size(med)) ///
caption("Source: FRED, U.S. Census Bureau") ///
legend(size(vsmall) pos(12) cols(4) rowgap(0.5) colgap(1.9)) graphregion(margin(sides)) xsize(3.5)
graph rename ec460forecast_VAR3release
graph export "/Users/nwheinrich/Documents/Stata/460/ec460forecast_VAR3release.png", as(png) replace


list time step12 if tin(2017m3, 2018m2), clean header noobs

*Export the forecast estimates and historical time-series data to a CSV file (Muted)
outsheet time level_y level_p4 level_se4 using ec460_forecast.csv, replace

log close
