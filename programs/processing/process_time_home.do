clear all
set_dirs

import delimited using "$derived\Safegraph\Athomeshares_weekly.csv", varn(1) clear

rename state_fips statefip
merge m:1 statefip using "$raw\all_statefip.dta", assert(1 3) keep(3) nogen

frame create jhu
frame jhu {
	use "$derived\jhu\cases.dta", clear
	
	keep abbr date active_pc
	
	egen stid = group(abbr)
	tsset stid date
	
	egen avg_1wk = filter(active_pc), lags(0/6)
	replace avg_1wk = avg_1wk/7
	egen avg_2wk = filter(active_pc), lags(0/13)
	replace avg_2wk = avg_2wk/14
	egen avg_4wk = filter(active_pc), lags(0/27)
	replace avg_4wk = avg_4wk/28
}

gen date = date(week_start,"MDY")
frlink 1:1 abbr date, frame(jhu)
frget avg_?wk, from(jhu)

reg mean_median_perc_home avg_1wk avg_2wk avg_4wk
reg mean_median_perc_home avg_1wk avg_2wk avg_4wk, a(abbr)
reg mean_median_perc_home avg_1wk avg_2wk avg_4wk date, a(abbr)
reg mean_median_perc_home avg_1wk avg_2wk avg_4wk date

reg mean_median_perc_home date
reg mean_median_perc_home date, a(abbr)
